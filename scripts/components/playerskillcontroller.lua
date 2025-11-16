--[[ Player Skill Controller Status class definition ]]
--------------------------------------------------------------------------

--[[
#整体控制的过程

按键触发事件（ms_activeskill）
        ↓
调用 ActiveSkill(data)
        ↓
  ┌─────────────────────────────────────┐
  ↓                                     ↓
当前未激活技能                  当前已有技能被激活, 二级技能
  ↓                                     ↓
正常走技能激活流程         ┌───────────────────────────────┐
        ↓               ↓ 是否为链式（二级）技能？          ↓
添加 tag，改变攻击范围   是：保留状态，继承连击动作      否：取消旧技能 → 重置状态 → 激活新技能
        ↓
设置 is_active_skill = true
        ↓
玩家选择目标（鼠标或锁定）
        ↓
调用 ReleaseSkill(target)
        ↓
检查目标是否合法（如非鸟类/蝴蝶等）
        ↓
合法 → 调用 GetSkillCallback(skill)
        ↓
执行 cb 回调函数（技能逻辑）
        ↓
移除 tag，扣意念值
        ↓
启动冷却计时器（skill_cd）
        ↓
OnTimerDone → 播放冷却完成特效（cooldown_effect）
        ↓
技能完全结束，可再次进入新技能流程

⚠ 特殊情况：
- 在技能激活期间按下其他技能键：
    → 如果是“链式技能”，则作为技能进阶继续执行
    → 否则会中断旧技能、取消 tag、重置状态，再执行新技能

- 以下情况会强制取消技能：
    - 死亡、骑乘、睡眠、冷冻、重物、unequip
    - PushEvent("ms_deactiveskill")
]]

local function PushDeactiveSkillEvent(inst)
    inst:PushEvent("ms_deactiveskill")
end

local function OnUnEquip(inst, data)
    local eslot = data.eslot
    if eslot ~= nil and eslot == EQUIPSLOTS.HANDS then
        PushDeactiveSkillEvent(inst)
    end
end

local function OnTimerDone(inst, data)
    local name = data.name
    if name ~= nil and inst.components.playerskillcontroller ~= nil then
        local cooldown_effect = inst.components.playerskillcontroller:GetCooldownEffect(name)
        if cooldown_effect ~= nil then
            inst:SpawnPrefabInPos(cooldown_effect, .9)
        end
    end
end

local PlayerSkillController = Class(function(self, inst)
    self.inst = inst

    self.current_active_skill = nil
    self.is_active_skill = false

    self.skills = {}

    self.inst:ListenForEvent("unequip", OnUnEquip)
    self.inst:ListenForEvent("timerdone", OnTimerDone)
    self.inst:ListenForEvent("mounted", PushDeactiveSkillEvent)
    self.inst:ListenForEvent("death", PushDeactiveSkillEvent)
    self.inst:ListenForEvent("ms_playerreroll", PushDeactiveSkillEvent)

    self.inst:ListenForEvent("ms_activeskill", function(inst, data)
        self:ActiveSkill(data)
    end)
    self.inst:ListenForEvent("ms_deactiveskill", function(inst)
        self:DeactiveSkill()
    end)
    self.inst:ListenForEvent("ms_toggleactiveskill", function(inst, data)
        self:ToggleActiveSkill(data)
    end)
end)

function PlayerSkillController:GetSkillCallback(skill)
    local skill_data = self:GetSkillData(skill)
    return function(inst, target)
        if skill_data ~= nil then
            skill_data.cb(inst, target)
            inst:RemoveTag(skill_data.tag)
            inst.components.kenjutsuka:SetMindpower(inst.components.kenjutsuka:GetMindpower() - skill_data.require_mindpower)
            inst.components.timer:StartTimer(skill, skill_data.cooldown_time)
            PushDeactiveSkillEvent(inst)
        end
    end
end

function PlayerSkillController:GetSkillData(skill)
    return self.skills[skill]
end

function PlayerSkillController:GetCooldownEffect(skill)
    local skill_data = self:GetSkillData(skill)
    if skill_data ~= nil then
        local cooldown_effect = skill_data.cooldown_effect
        return cooldown_effect ~= nil and cooldown_effect or "ghostlyelixir_retaliation_dripfx"
    end
end

function PlayerSkillController:GetCurrentActiveSkill()
    for k in pairs(self.skills) do
        if self.inst:HasTag(k) then
            self.current_active_skill = k
            break
        end
    end

    return self.current_active_skill
end

local MUST_TAG = {"tool", "sharp", "weapon", "katana"}
local CANT_TAG = {"projectile", "whip", "rangedweapon"}
function PlayerSkillController:IsEligibleForActiveSkill(weapon, skill_key, current_level, require_level, current_mindpower, require_mindpower)
    local script = nil
    local inst = self.inst
    if inst.components.timer ~= nil and inst.components.timer:TimerExists(skill_key .. "_cd") then
        script = STRINGS.SKILL.COOLDOWN
    end

    if current_level < require_level then
        script = STRINGS.SKILL.UNLOCK_SKILL .. require_level
    end

    if current_mindpower < require_mindpower then
        script = STRINGS.SKILL.MINDPOWER_NOT_ENOUGH.. current_mindpower .. "/" .. require_mindpower .. "\n "
    end

    if script ~= nil and checkstring(script) then
        inst.components.talker:Say(script, 1, true)
        return false
    end

    return weapon ~= nil and not inst.components.sleeper:IsAsleep() and not inst.components.freezable:IsFrozen() and not inst.components.rider:IsRiding() and not inst.components.inventory:IsHeavyLifting() and not inst.components.health:IsDead() and weapon:HasOneOfTags(CANT_TAG) and not weapon:HasOneOfTags(MUST_TAG)
end

function PlayerSkillController:IsActiveSkill()
    return self.is_active_skill
end

function PlayerSkillController:CanActivateSkill(level, mindpower, timer_name)
    if self.inst.components.kenjutsuka:IsLevelReached(level) or
        self.inst.components.kenjutsuka:IsHasMindpowerEnough(mindpower) or
        self.inst:IsTimerExists(timer_name) or
        not self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or
        self.inst.components.inventory:IsHeavyLifting() or
        self.inst.components.inventory:IsHeavyLifting() or
        self.inst.components.sleeper:IsAsleep() or
        self.inst.components.freezable:IsFrozen() or
        self.inst.components.rider:IsRiding() or
        self.inst.components.health:IsDead()
    then
        return false
    end
    return true
end

function PlayerSkillController:IsTierSkill(skill)
    local skill_data = self:GetSkillData(skill)
    return skill_data.is_tier_skill
end

function PlayerSkillController:ToggleActiveSkill(data)
    if self:IsActiveSkill() and self:IsTierSkill(data.skill) then
        self:ActiveSkill(data)
    else
        self:DeactiveSkill(true)
    end
end

function PlayerSkillController:ActiveSkill(data, force)
    local weapon = self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    local kenjutsuka = self.inst.components.kenjutsuka
    if kenjutsuka ~= nil then
        local current_level = kenjutsuka:GetLevel()
        local current_mindpower = kenjutsuka:GetMindpower()
        if force or self:IsEligibleForActiveSkill(weapon, data.skill_key, current_level, data.require_level, current_mindpower, data.require_mindpower) then
            self.inst:AddTag(data.tag)
            self.inst.components.combat:SetRange(data.skill_range)
            self.inst.components.talker:Say(data.script .. current_mindpower .. "/" .. data.require_mindpower .. "\n ", 1, true)
            self.is_active_skill = true
        end
    end
end

function PlayerSkillController:DeactiveSkill(later)
    if later then
        self.inst.components.talker:Say(STRINGS.SKILL.SKILL_LATER, 1, true)
    end

    self.current_active_skill = nil
    self.is_active_skill = false

    for k, v in pairs(self.skills) do
        if self.inst:HasTag(k) then
            self.inst:RemoveTag(k)
        end
    end

    self.inst.components.combat:SetRange(TUNING.DEFAULT_ATTACK_RANGE)
    self.inst.components.combat:EnableAreaDamage(false)
    self.inst.AnimState:SetDeltaTimeMultiplier(1)
end

function PlayerSkillController:AddSkill(skill, data)
    self.skills[skill] = data
end

function PlayerSkillController:RemoveSkill(name)
    self.skills[name] = {}
end

local HasOneOfTags = {"prey", "bird", "buzzard", "butterfly"}
function PlayerSkillController:IsValidSkillTarget(target)
    if target ~= nil and target:IsValid() then
        if target:HasOneOfTags(HasOneOfTags) then
            self.inst.sg:GoToState("idle")
            self:DeactivateSkill()
            self.inst.components.talker:Say(STRINGS.SKILL.REFUSE_RELEASE)
            return false
        end
        return true
    end
end

function PlayerSkillController:ReleaseSkill(target)
    if self.inst:HasTag("kenjutsuka") then
        if self:IsValidSkillTarget(target) then
            local fn = self:GetSkillCallback()
            if fn ~= nil then
                fn(self.inst, target)
            end
        end
    end
end

function PlayerSkillController:OnRemoveEntity()
    self:DeactiveSkill()

    for k, v in pairs(self.skills) do
        self:RemoveSkill(k)
    end

    self.inst:RemoveEventCallback("unequip", OnUnEquip)
    self.inst:RemoveEventCallback("timerdone", OnTimerDone)
    self.inst:RemoveEventCallback("mounted", PushDeactiveSkillEvent)
    self.inst:RemoveEventCallback("death", PushDeactiveSkillEvent)
    self.inst:RemoveEventCallback("ms_playerreroll", PushDeactiveSkillEvent)

    self.inst:RemoveEventCallback("ms_activeskill", function(inst, data)
        self:ActiveSkill(data)
    end)
    self.inst:RemoveEventCallback("ms_deactiveskill", function(inst)
        self:DeactiveSkill()
    end)
    self.inst:RemoveEventCallback("ms_toggleactiveskill", function(inst, data)
        self:ToggleActiveSkill(data)
    end)
end

return PlayerSkillController
