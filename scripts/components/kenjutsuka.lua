local _config = M_CONFIG

local function OnAttackOther(self, inst, data)
    local target = data.target
    local weapon = data.weapon

    if target ~= nil and weapon ~= nil and not weapon:HasTag("projectile") and not weapon:HasTag("rangedweapon") and not inst.sg:HasStateTag("skilling") then
        if not inst.components.timer:TimerExists("hit_cd") and weapon:HasTag("katana") then
            inst.components.timer:StartTimer("hit_cd", .5)
            self:SetExp(1 * (_config.KenjutsuExpMultiple or 1))
        end
    end
end

local function LevelNotReached(inst, requirelevel)
    local str = STRINGS.SKILL.UNLOCK_SKILL .. requirelevel
    inst.components.talker:Say(str, 1, true)

    inst:PushEvent("ms_deactiveskill")
end

local function MindpowerNotEnough(inst, requiremindpower)
    local str = STRINGS.SKILL.MINDPOWER_NOT_ENOUGH .. inst.components.kenjutsuka:GetMindpower() .. "/" .. requiremindpower .. "\n "
    inst.components.talker:Say(str, 1, true)

    inst:PushEvent("ms_deactiveskill")
end

local Kenjutsuka = Class(function(self, inst)
    assert(TheWorld.ismastersim, "Kenjutsuka should not exist on client")
    assert(inst:HasTag("player"), "Kenjutsuka should add on player")

    self.inst = inst
    self.onlevelupcallback = {}
    self.onregenindpower = nil
    self.spawnfx = nil

    self.is_tatsujin = _config.IsTatsujin or false

    self.exp = 0
    self.level = 0
	self.max_exp_for_max_level = 0

    self.hitcount = 0

    self.mindpower = 0
    self.max_mindpower = _config.MaxMindPower or 10
    self.regen_mindpower_rate = _config.RegenMindPowerRate or 60
    self.enable_regen_mindpower = false
    self.regen_mindpower_task = nil

    -- Store bound methods for reliable removal
    self._OnLevelUpHandler = function(_, data) self:OnLevelUp(data) end
    self._OnExpDeltaHandler = function(_, data) self:OnExpDelta(data) end
    self._RegenMindPowerHandler = function() self:RegenMindPower() end
    self._OnAttackOtherHandler = function(_, data) OnAttackOther(self, inst, data) end

    self.inst:ListenForEvent("onattackother", self._OnAttackOtherHandler)
    self.inst:ListenForEvent("ms_levelup", self._OnLevelUpHandler)
    self.inst:ListenForEvent("ms_expdelta", self._OnExpDeltaHandler)
    self.inst:ListenForEvent("ms_regenmindpower", self._RegenMindPowerHandler)

    self.inst:ListenForEvent("level_not_reached", LevelNotReached)
    self.inst:ListenForEvent("mindpower_not_enough", MindpowerNotEnough)
end)

function Kenjutsuka:IsLevelReached(level)
    local is_level_reached = (self:GetLevel() >= level)
    if not is_level_reached then
        self.inst:PushEvent("level_not_reached", level)
    end
    return is_level_reached
end

function Kenjutsuka:IsMindpowerEnough(inst, mindpower)
    local is_mindpower_enough = (self:GetMindpower() >= mindpower)
    if not is_mindpower_enough then
        self.inst:PushEvent("mindpower_not_enough", mindpower)
    end
    return is_mindpower_enough
end

function Kenjutsuka:OnPostInit()
    local max_level = self:GetMaxLevel()
    if max_level > 0 then
        local max_level_data = self:IndexLevel(max_level)
        if max_level_data and max_level_data.require_exp then
            self.max_exp_for_max_level = max_level_data.require_exp
        end
    end

    if self:IsTatsujin() then
        if self.max_exp_for_max_level > 0 then
            self:ExpDelta(self.max_exp_for_max_level, true)
        end
    end
end

function Kenjutsuka:RegenMindPower()
    if not self:IsMaxMindPower() then
        self:SetMindpower(self:GetMindpower() + 1)
        if self.onregenindpower ~= nil then
            self.onregenindpower(self.inst, self:GetMindpower())
        end
    end
    if self:IsEnableRegenMindpower() then
        self:StartRegenMindPowerTask()
    end
end

function Kenjutsuka:OnLevelUp(data)
    if data == nil then return end

    if data.level_to_reach ~= nil and data.level_to_reach > self:GetLevel() and data.level_to_reach <= self:GetMaxLevel() then
        self:SetLevel(data.level_to_reach)

        if data.mindpower then
            self:SetMaxMindpower(data.mindpower)
        end

        if data.fn ~= nil then
            data.fn(self.inst, self:GetLevel())
        end
    end
end

function Kenjutsuka:IsExpEligible(current_exp, require_exp)
    return (current_exp >= require_exp)
end

function Kenjutsuka:OnExpDelta(data)
    if data ~= nil and data.exp ~= nil then
        local current_total_exp = data.exp
        local has_spawned_fx = false

        -- So stupid
        local i = 0
        while not self:IsMaxLevel() do
            i = i + 1
            local next_level = self:GetLevel() + 1
            local level_data = self:IndexLevel(next_level)

            if level_data == nil or level_data.require_exp == nil then
                break
            end

            if self:IsExpEligible(current_total_exp, level_data.require_exp) then
                if not has_spawned_fx and self.spawnfx ~= nil then
                    self.spawnfx(self.inst)
                    has_spawned_fx = true
                end

                self.inst:PushEvent("ms_levelup", {
                    level_to_reach = next_level,
                    mindpower = self:GetMaxMindpower() + 2,
                    fn = level_data.fn
                })
            else
                break
            end
        end

        -- After all potential level-ups, if at max level, cap EXP to that level's requirement.
        if self:IsMaxLevel() then
            local max_level_def = self:IndexLevel(self:GetMaxLevel())
            if max_level_def and max_level_def.require_exp and self.exp > max_level_def.require_exp then
                self.exp = max_level_def.require_exp -- Cap EXP, don't trigger new delta event
            end
        end
    end
end

function Kenjutsuka:GetExp()
    return self.exp
end

-- 'force' is used for loading or special initializations to bypass certain checks.
function Kenjutsuka:ExpDelta(new_exp_value, force)
    if not force then
        if new_exp_value <= self.exp then
            return
        end

        if self:IsMaxLevel() and new_exp_value > self.max_exp_for_max_level then
            new_exp_value = self.max_exp_for_max_level
        end
    end

    self.exp = new_exp_value
    self.inst:PushEvent("ms_expdelta", {exp = self.exp})
end

function Kenjutsuka:SetExp(amount)
    if amount <= 0 then return end
    if self:IsMaxLevel() and self.exp >= self.max_exp_for_max_level then
        return
    end
    self:ExpDelta(self:GetExp() + amount, false) -- Call ExpDelta, not forcing
end

function Kenjutsuka:SetLevel(level)
    if level > self:GetMaxLevel() then
        level = self:GetMaxLevel()
    end
    if level < 0 then
        level = 0
    end
    self.level = level
end

function Kenjutsuka:SetMindpower(power)
    if power > self:GetMaxMindpower()then
        power = self:GetMaxMindpower()
    end
    if power < 0 then
        power = 0
    end
    self.mindpower = power
end

function Kenjutsuka:SetMaxMindpower(power)
    local min_max_power = _config.MaxMindPower or 10
    if power < min_max_power then power = min_max_power end
    self.max_mindpower = power
end

function Kenjutsuka:AddOnLevelUp(onlevelupcallback)
    self.onlevelupcallback = onlevelupcallback or {}
    local max_level = self:GetMaxLevel()
    if max_level > 0 then
        local max_level_data = self:IndexLevel(max_level)
        if max_level_data and max_level_data.require_exp then
            self.max_exp_for_max_level = max_level_data.require_exp
        end
    else
        self.max_exp_for_max_level = 0
    end
end

function Kenjutsuka:AddSpawnFx(spawnfx)
    self.spawnfx = spawnfx
end

function Kenjutsuka:SetOnRegenMindPower(fn)
    self.onregenindpower = fn
end

function Kenjutsuka:GetMaxExpForMaxLevel()
    return self.max_exp_for_max_level
end

function Kenjutsuka:GetLevel()
    return self.level
end

function Kenjutsuka:GetMaxLevel()
    local max_level = 0
    if self.onlevelupcallback then
        for k, _ in pairs(self.onlevelupcallback) do
            local level = tonumber(string.match(k, "^Level(%d+)$"))
            if level and level > max_level then
                max_level = level
            end
        end
    end
    return max_level
end

function Kenjutsuka:IndexLevel(level)
    if self.onlevelupcallback == nil then return {} end
    local level_key = "Level" .. tostring(level)
    return self.onlevelupcallback[level_key] or {} -- Return empty table if not found, to prevent errors
end

function Kenjutsuka:GetMindpower()
    return self.mindpower
end

function Kenjutsuka:GetMaxMindpower()
    return self.max_mindpower
end

function Kenjutsuka:IsMaxLevel()
    return self:GetLevel() >= self:GetMaxLevel()
end

function Kenjutsuka:IsMaxMindPower()
    return self:GetMindpower() >= self:GetMaxMindpower()
end

function Kenjutsuka:IsTatsujin()
    return self.is_tatsujin
end

function Kenjutsuka:IsEnableRegenMindpower()
    return self.enable_regen_mindpower
end

function Kenjutsuka:StartRegenMindPowerTask()
    self:StopRegenMindPowerTask() -- Clear any existing task
    -- Only start if enabled, not at max mindpower, and rate is positive
    if self:IsEnableRegenMindpower() and self.regen_mindpower_rate > 0 then
        self.regen_mindpower_task = self.inst:DoTaskInTime(self.regen_mindpower_rate, self._RegenMindPowerHandler)
    end
end

function Kenjutsuka:StopRegenMindPowerTask()
    if self.regen_mindpower_task ~= nil then
        self.regen_mindpower_task:Cancel()
        self.regen_mindpower_task = nil
    end
end

-- This function enables or disables the passive mindpower regeneration
function Kenjutsuka:SetRegenMindPower(enable)
    local old_enable_state = self.enable_regen_mindpower
    self.enable_regen_mindpower = enable

    if enable and not old_enable_state then
        self:StartRegenMindPowerTask()
    elseif not enable and old_enable_state then
        self:StopRegenMindPowerTask()
    end
end

function Kenjutsuka:OnSave()
    local data = {
        exp = self:GetExp(),
        mindpower = self:GetMindpower(),
        hitcount = self.hitcount,
        enable_regen_mindpower = self:IsEnableRegenMindpower(),
    }
    return data
end

local has_set_exp = false
function Kenjutsuka:OnLoad(data)
    if data ~= nil then
        -- self.exp = data.exp
        self.mindpower = data.mindpower or 0
        self.hitcount = data.hitcount or 0

        -- After setting raw EXP and Level, call SetExp with force=true.
        -- This will trigger OnExpDelta, which will re-evaluate levels.
        -- This is important if level definitions changed (e.g. mod update) or new levels were added.
        -- The OnLevelUp functions (fn) will run for any *newly achieved* levels based on loaded EXP
        -- compared to loaded Level.
        self:ExpDelta(data.exp, true)
    end
end

function Kenjutsuka:OnRemoveEntity()
    self:StopRegenMindPowerTask()

    self.inst:RemoveEventCallback("onattackother", OnAttackOther)
    self.inst:RemoveEventCallback("ms_levelup", self._OnLevelUpHandler)
    self.inst:RemoveEventCallback("ms_expdelta", self._OnExpDeltaHandler)
    self.inst:RemoveEventCallback("ms_regenmindpower", self._RegenMindPowerHandler)
end

Kenjutsuka.OnRemoveFromEntity = Kenjutsuka.OnRemoveEntity

function Kenjutsuka:GetDebugString()
    return string.format(
        "Is Tatsujin: %s, Level: %s/%s, Exp: %s (Req for MaxLvl: %s), Power: %s/%s, Regen MP: %s, Hitcount: %s",
        tostring(self:IsTatsujin()),
        self:GetLevel(), self:GetMaxLevel(),
        self:GetExp(),
        tostring(self.max_exp_for_max_level),
        self:GetMindpower(), self:GetMaxMindpower(),
        tostring(self:IsEnableRegenMindpower()),
        tostring(self.hitcount)
    )
end

return Kenjutsuka
