local function PushDeactivateSkillEvent(inst)
    inst:PushEvent("ms_deactivateskill")
end

local function OnUnEquip(inst, data)
    local eslot = data.eslot
    if eslot ~= nil and eslot == EQUIPSLOTS.HANDS then
        PushDeactivateSkillEvent(inst)
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

local MUST_TAG = {"tool", "sharp", "weapon", "katana"}
local CANT_TAG = {"projectile", "whip", "rangedweapon"}

local PlayerSkillController = Class(function(self, inst)
    self.inst = inst

    self.current_active_skill = nil
    self.is_active_skill = false

    self.skills = {}

    -- Bound methods for reliable event removal
    self._OnActivateSkill = function(_, data) self:ActivateSkill(data) end
    self._OnDeactivateSkill = function(_) self:DeactivateSkill() end
    self._OnToggleActivateSkill = function(_, data) self:ToggleActiveSkill(data) end

    self.inst:ListenForEvent("unequip", OnUnEquip)
    self.inst:ListenForEvent("timerdone", OnTimerDone)
    self.inst:ListenForEvent("mounted", PushDeactivateSkillEvent)
    self.inst:ListenForEvent("death", PushDeactivateSkillEvent)
    self.inst:ListenForEvent("ms_playerreroll", PushDeactivateSkillEvent)

    self.inst:ListenForEvent("ms_activeskill", self._OnActivateSkill)
    self.inst:ListenForEvent("ms_deactivateskill", self._OnDeactivateSkill)
    -- Also listen to the old name in case other parts of the mod still use it
    self.inst:ListenForEvent("ms_deactiveskill", self._OnDeactivateSkill) 
    self.inst:ListenForEvent("ms_toggleactiveskill", self._OnToggleActivateSkill)
end)

function PlayerSkillController:GetSkillCallback(skill)
    local skill_data = self:GetSkillData(skill)
    return function(inst, target)
        if skill_data ~= nil then
            skill_data.cb(inst, target)
            inst:RemoveTag(skill_data.tag)
            
            if inst.components.kenjutsuka then
                inst.components.kenjutsuka:SetMindpower(inst.components.kenjutsuka:GetMindpower() - skill_data.require_mindpower)
            end
            
            if inst.components.timer then
                inst.components.timer:StartTimer(skill, skill_data.cooldown_time)
            end
            
            PushDeactivateSkillEvent(inst)
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
    return nil
end

function PlayerSkillController:GetCurrentActiveSkill()
    for k in pairs(self.skills) do
        if self.inst:HasTag(k) then
            self.current_active_skill = k
            return k
        end
    end
    self.current_active_skill = nil
    return nil
end

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

    if script ~= nil and type(script) == "string" then
        if inst.components.talker then
            inst.components.talker:Say(script, 1, true)
        end
        return false
    end

    local IsAsleep = inst.components.sleeper ~= nil and inst.components.sleeper:IsAsleep()
    local IsFrozen = inst.components.freezable ~= nil and inst.components.freezable:IsFrozen()
    local IsRiding = inst.components.rider ~= nil and inst.components.rider:IsRiding()
    local IsHeavyLifting = inst.components.inventory ~= nil and inst.components.inventory:IsHeavyLifting()
    local IsDead = inst.components.health ~= nil and inst.components.health:IsDead()

    if weapon == nil or IsAsleep or IsFrozen or IsRiding or IsHeavyLifting or IsDead then
        return false
    end

    if weapon:HasOneOfTags(CANT_TAG) and not weapon:HasOneOfTags(MUST_TAG) then
        return false
    end

    return true
end

function PlayerSkillController:IsActiveSkill()
    return self.is_active_skill
end

function PlayerSkillController:CanActivateSkill(level, mindpower, timer_name)
    local inst = self.inst
    local kenjutsuka = inst.components.kenjutsuka
    
    if not kenjutsuka then return false end
    
    -- Inverted logic fixed: The original returned false if criteria were met! 
    -- Now it checks if we DO NOT meet the criteria to return false.
    if not kenjutsuka:IsLevelReached(level) or
       not kenjutsuka:IsMindpowerEnough(inst, mindpower) or
       (inst.components.timer and inst.components.timer:TimerExists(timer_name)) or
       not inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or
       inst.components.inventory:IsHeavyLifting() or
       (inst.components.sleeper and inst.components.sleeper:IsAsleep()) or
       (inst.components.freezable and inst.components.freezable:IsFrozen()) or
       (inst.components.rider and inst.components.rider:IsRiding()) or
       (inst.components.health and inst.components.health:IsDead())
    then
        return false
    end
    return true
end

function PlayerSkillController:IsTierSkill(skill)
    local skill_data = self:GetSkillData(skill)
    return skill_data and skill_data.is_tier_skill
end

function PlayerSkillController:ToggleActiveSkill(data)
    if not data then 
        -- If called with no data (e.g. from a raw key press), just deactivate
        self:DeactivateSkill(true)
        return
    end

    if self:IsActiveSkill() and self:IsTierSkill(data.skill) then
        self:ActivateSkill(data)
    else
        self:DeactivateSkill(true)
    end
end

function PlayerSkillController:ActivateSkill(data, force)
    if not data then return end
    
    local weapon = self.inst.components.inventory and self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    local kenjutsuka = self.inst.components.kenjutsuka
    
    if kenjutsuka ~= nil then
        local current_level = kenjutsuka:GetLevel()
        local current_mindpower = kenjutsuka:GetMindpower()
        
        if force or self:IsEligibleForActiveSkill(weapon, data.skill_key, current_level, data.require_level, current_mindpower, data.require_mindpower) then
            self.inst:AddTag(data.tag)
            if self.inst.components.combat and data.skill_range then
                self.inst.components.combat:SetRange(data.skill_range)
            end
            if self.inst.components.talker and data.script then
                self.inst.components.talker:Say(data.script .. current_mindpower .. "/" .. data.require_mindpower .. "\n ", 1, true)
            end
            self.is_active_skill = true
        end
    end
end

function PlayerSkillController:DeactivateSkill(later)
    if later and self.inst.components.talker then
        self.inst.components.talker:Say(STRINGS.SKILL.SKILL_LATER, 1, true)
    end

    self.current_active_skill = nil
    self.is_active_skill = false

    for k, _ in pairs(self.skills) do
        if self.inst:HasTag(k) then
            self.inst:RemoveTag(k)
        end
    end

    if self.inst.components.combat then
        self.inst.components.combat:SetRange(TUNING.DEFAULT_ATTACK_RANGE)
        self.inst.components.combat:EnableAreaDamage(false)
    end
    
    if self.inst.AnimState then
        self.inst.AnimState:SetDeltaTimeMultiplier(1)
    end
end

-- Legacy alias just in case
PlayerSkillController.DeactiveSkill = PlayerSkillController.DeactivateSkill
PlayerSkillController.ActiveSkill = PlayerSkillController.ActivateSkill

function PlayerSkillController:AddSkill(skill, data)
    self.skills[skill] = data
end

function PlayerSkillController:RemoveSkill(name)
    self.skills[name] = nil
end

local HasOneOfTags = {"prey", "bird", "buzzard", "butterfly"}
function PlayerSkillController:IsValidSkillTarget(target)
    if target ~= nil and target:IsValid() then
        if target:HasOneOfTags(HasOneOfTags) then
            self.inst.sg:GoToState("idle")
            self:DeactivateSkill()
            if self.inst.components.talker then
                self.inst.components.talker:Say(STRINGS.SKILL.REFUSE_RELEASE)
            end
            return false
        end
        return true
    end
    return false
end

function PlayerSkillController:ReleaseSkill(target)
    if self.inst:HasTag("kenjutsuka") then
        if self:IsValidSkillTarget(target) then
            -- GetSkillCallback requires the name of the skill currently active
            local current_skill = self:GetCurrentActiveSkill()
            if current_skill then
                local fn = self:GetSkillCallback(current_skill)
                if fn ~= nil then
                    fn(self.inst, target)
                end
            end
        end
    end
end

function PlayerSkillController:OnRemoveEntity()
    self:DeactivateSkill()

    for k, _ in pairs(self.skills) do
        self:RemoveSkill(k)
    end

    self.inst:RemoveEventCallback("unequip", OnUnEquip)
    self.inst:RemoveEventCallback("timerdone", OnTimerDone)
    self.inst:RemoveEventCallback("mounted", PushDeactivateSkillEvent)
    self.inst:RemoveEventCallback("death", PushDeactivateSkillEvent)
    self.inst:RemoveEventCallback("ms_playerreroll", PushDeactivateSkillEvent)

    self.inst:RemoveEventCallback("ms_activeskill", self._OnActivateSkill)
    self.inst:RemoveEventCallback("ms_deactivateskill", self._OnDeactivateSkill)
    self.inst:RemoveEventCallback("ms_deactiveskill", self._OnDeactivateSkill)
    self.inst:RemoveEventCallback("ms_toggleactiveskill", self._OnToggleActivateSkill)
end

PlayerSkillController.OnRemoveFromEntity = PlayerSkillController.OnRemoveEntity

return PlayerSkillController
