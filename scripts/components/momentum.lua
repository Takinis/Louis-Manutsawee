-- momentum.lua - 气势组件
-- 放置在 scripts/components/ 目录下

local Momentum = Class(function(self, inst)
    self.inst = inst

    -- 气势状态
    self.active = false
    self.momentum_level = "normal" -- 低low、正常normal、高high、巅峰peak
    self.danger_priority = "normal" -- 低low、正常normal、高high、保持maintain

    -- 战斗数据
    self.current_multiplier = 1.0
    self.hit_count = 0 -- 被攻击次数
    self.attack_count = 0 -- 攻击次数
    self.total_damage_taken = 0 -- 总承受伤害

    -- 危险目标追踪
    self.danger_targets = {}
    self.is_in_danger_zone = false

    -- 倒计时
    self.timer_task = nil
    self.duration = TUNING.TOTAL_DAY_TIME -- 一天
    self.time_remaining = 0

    -- 扫描半径
    self.scan_radius = 20
    self.scan_interval = 0.5
    self.scan_task = nil

    -- 监听生命值变化
    self:StartListening()
end)

-- 生命值百分比对应的伤害倍率
local HEALTH_THRESHOLDS = {
    {percent = 0.01, min = 2, max = 10},      -- <=1%: 2-10随机
    {percent = 0.04, min = 1.91, max = 2.00}, -- 1%-4%
    {percent = 0.13, min = 1.75, max = 1.91}, -- 4%-13%
    {percent = 0.18, min = 1.66, max = 1.75}, -- 13%-18%
    {percent = 0.26, min = 1.53, max = 1.66}, -- 18%-26%
    {percent = 0.42, min = 1.49, max = 1.53}, -- 26%-42%
    {percent = 0.49, min = 1.32, max = 1.49}, -- 42%-49%
    {percent = 0.66, min = 1.24, max = 1.32}, -- 49%-66%
    {percent = 0.75, min = 1.13, max = 1.24}, -- 66%-75%
    {percent = 0.89, min = 1.09, max = 1.13}, -- 75%-89%
    {percent = 1.00, min = 1.00, max = 1.09}, -- 89%-100%
}

-- 计算当前伤害倍率
function Momentum:CalculateMultiplier()
    if not self.active then
        return 1.0
    end

    local health = self.inst.components.health
    if not health then
        return 1.0
    end

    local health_percent = health:GetPercent()

    -- 根据生命值百分比找到对应的倍率区间
    for i = 1, #HEALTH_THRESHOLDS do
        if health_percent <= HEALTH_THRESHOLDS[i].percent then
            local min = HEALTH_THRESHOLDS[i].min
            local max = HEALTH_THRESHOLDS[i].max
            -- 返回区间内的随机值
            return min + math.random() * (max - min)
        end
    end

    return 1.0
end

-- 更新气势等级
function Momentum:UpdateMomentumLevel()
    if self.current_multiplier >= 2.0 then
        self.momentum_level = "peak"
    elseif self.current_multiplier >= 1.5 then
        self.momentum_level = "high"
    elseif self.current_multiplier >= 1.2 then
        self.momentum_level = "normal"
    else
        self.momentum_level = "low"
    end
end

-- 检查是否是危险目标
function Momentum:IsDangerousTarget(target)
    if not target or not target:IsValid() then
        return false, "normal"
    end

    -- 检查是否是boss或epic生物
    if target:HasTag("epic") or target:HasTag("boss") then
        return true, "maintain"
    end

    -- 检查是否有战斗组件且是敌对
    local combat = target.components.combat
    if combat and combat:TargetIs(self.inst) then
        -- 根据生物的攻击力判断危险等级
        local damage = combat.defaultdamage or 0
        if damage >= 75 then
            return true, "high"
        elseif damage >= 40 then
            return true, "normal"
        elseif damage >= 20 then
            return true, "low"
        end
    end

    return false, "normal"
end

-- 检查危险区域
function Momentum:CheckDangerZone()
    -- 检查是否在暗影中庭
    if self.inst:HasTag("in_shadow_atrium") then
        return true, "maintain"
    end

    -- 检查是否在月亮蘑菇地
    if self.inst:HasTag("in_mushroom_area") then
        return true, "high"
    end

    -- 可以添加更多区域检测
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 15, {"moonspore", "shadow_aligned"})
    if #ents > 0 then
        return true, "normal"
    end

    return false, "normal"
end

-- 扫描附近的危险
function Momentum:ScanForDangers()
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, self.scan_radius,
        {"_combat"},
        {"player", "wall", "structure"}
    )

    local danger_count = 0
    local highest_priority = "low"
    local new_dangers = {}

    -- 检查每个实体
    for _, ent in ipairs(ents) do
        local is_danger, priority = self:IsDangerousTarget(ent)
        if is_danger then
            danger_count = danger_count + 1
            new_dangers[ent] = priority

            -- 更新最高优先级
            if priority == "maintain" then
                highest_priority = "maintain"
            elseif priority == "high" and highest_priority ~= "maintain" then
                highest_priority = "high"
            elseif priority == "normal" and highest_priority == "low" then
                highest_priority = "normal"
            end
        end
    end

    -- 检查危险区域
    local in_zone, zone_priority = self:CheckDangerZone()
    if in_zone then
        self.is_in_danger_zone = true
        if zone_priority == "maintain" then
            highest_priority = "maintain"
        elseif zone_priority == "high" and highest_priority ~= "maintain" then
            highest_priority = "high"
        end
    else
        self.is_in_danger_zone = false
    end

    -- 更新危险目标列表
    self.danger_targets = new_dangers
    self.danger_priority = highest_priority

    -- 如果检测到高优先级或保持优先级的危险,激活气势
    if (highest_priority == "high" or highest_priority == "maintain") and not self.active then
        self:Activate()
    elseif danger_count == 0 and not self.is_in_danger_zone and self.active then
        -- 如果没有危险了,考虑提前结束
        -- 但保持到计时器自然结束
    end

    return danger_count
end

-- 激活气势
function Momentum:Activate()
    if self.active then
        return
    end

    self.active = true
    self.time_remaining = self.duration
    self.hit_count = 0
    self.attack_count = 0
    self.total_damage_taken = 0

    print("[气势] 激活! 持续时间:", self.duration)

    -- 启动计时器
    if self.timer_task then
        self.timer_task:Cancel()
    end

    self.timer_task = self.inst:DoPeriodicTask(1, function()
        self.time_remaining = self.time_remaining - 1
        if self.time_remaining <= 0 then
            self:Deactivate()
        end
    end)

    -- 启动扫描
    if not self.scan_task then
        self.scan_task = self.inst:DoPeriodicTask(self.scan_interval, function()
            self:ScanForDangers()
        end)
    end

    -- 通知玩家
    if self.inst.components.talker then
        self.inst.components.talker:Say("气势觉醒!")
    end
end

-- 取消气势
function Momentum:Deactivate()
    if not self.active then
        return
    end

    self.active = false
    self.current_multiplier = 1.0

    print("[气势] 结束")

    if self.timer_task then
        self.timer_task:Cancel()
        self.timer_task = nil
    end

    if self.scan_task then
        self.scan_task:Cancel()
        self.scan_task = nil
    end

    -- 通知玩家
    if self.inst.components.talker then
        self.inst.components.talker:Say("气势消退...")
    end
end

-- 监听事件
function Momentum:StartListening()
    -- 监听受伤事件
    self.inst:ListenForEvent("attacked", function(inst, data)
        if not self.active then
            return
        end

        if data and data.damage then
            self.hit_count = self.hit_count + 1
            self.total_damage_taken = self.total_damage_taken + data.damage

            -- 更新倍率
            self.current_multiplier = self:CalculateMultiplier()
            self:UpdateMomentumLevel()

            print(string.format("[气势] 受击! 次数:%d 总伤害:%.1f 倍率:%.2f 等级:%s",
                self.hit_count, self.total_damage_taken, self.current_multiplier, self.momentum_level))
        end
    end)

    -- 监听攻击事件
    self.inst:ListenForEvent("onhitother", function(inst, data)
        if not self.active then
            return
        end

        self.attack_count = self.attack_count + 1
    end)

    -- 监听生命值变化
    self.inst:ListenForEvent("healthdelta", function(inst, data)
        if self.active and data.newpercent then
            -- 生命值变化时重新计算倍率
            self.current_multiplier = self:CalculateMultiplier()
            self:UpdateMomentumLevel()
        end
    end)
end

-- 获取当前伤害倍率
function Momentum:GetDamageMultiplier()
    return self.active and self.current_multiplier or 1.0
end

-- 获取气势信息(用于UI显示)
function Momentum:GetMomentumInfo()
    return {
        active = self.active,
        level = self.momentum_level,
        multiplier = self.current_multiplier,
        time_remaining = self.time_remaining,
        hit_count = self.hit_count,
        attack_count = self.attack_count,
        danger_priority = self.danger_priority,
        danger_count = self:CountDangers()
    }
end

-- 统计危险数量
function Momentum:CountDangers()
    local count = 0
    for _ in pairs(self.danger_targets) do
        count = count + 1
    end
    return count
end

-- 保存/加载
function Momentum:OnSave()
    return {
        active = self.active,
        momentum_level = self.momentum_level,
        current_multiplier = self.current_multiplier,
        hit_count = self.hit_count,
        attack_count = self.attack_count,
        total_damage_taken = self.total_damage_taken,
        time_remaining = self.time_remaining
    }
end

function Momentum:OnLoad(data)
    if data then
        self.active = data.active or false
        self.momentum_level = data.momentum_level or "normal"
        self.current_multiplier = data.current_multiplier or 1.0
        self.hit_count = data.hit_count or 0
        self.attack_count = data.attack_count or 0
        self.total_damage_taken = data.total_damage_taken or 0
        self.time_remaining = data.time_remaining or 0

        -- 如果是激活状态,重新启动计时器
        if self.active then
            self:Activate()
        end
    end
end

return Momentum
