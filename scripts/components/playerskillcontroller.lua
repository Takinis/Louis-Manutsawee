local INPUT_COOLDOWN_TIME = 1
local COUNTER_ATTACK_COOLDOWN_TIME = .63
local QUICK_SHEATH_LEVEL = 2
local DEFAULT_COOLDOWN_EFFECT = "ghostlyelixir_retaliation_dripfx"

local WEAPON_MUST_TAGS = {"tool", "sharp", "weapon", "katana"}
local WEAPON_CANT_TAGS = {"projectile", "whip", "rangedweapon"}
local INVALID_TARGET_TAGS = {"prey", "bird", "buzzard", "butterfly"}

local function PushDeactivateSkillEvent(inst)
    inst:PushEvent("ms_deactivateskill")
end

local function OnUnEquip(inst, data)
    if data ~= nil and data.eslot == EQUIPSLOTS.HANDS then
        PushDeactivateSkillEvent(inst)
    end
end

local function OnTimerDone(inst, data)
    local name = data ~= nil and data.name or nil
    local controller = inst.components.playerskillcontroller
    if name ~= nil and controller ~= nil then
        local effect = controller:GetCooldownEffect(name)
        if effect ~= nil then
            inst:SpawnPrefabInPos(effect, .9)
        end
    end
end

local function CopyTable(src)
    local dst = {}
    if src ~= nil then
        for k, v in pairs(src) do
            dst[k] = v
        end
    end
    return dst
end

local function AddLookup(lookup, key, value)
    if key ~= nil then
        lookup[key] = value
    end
end

local function AddLookupList(lookup, keys, value)
    if keys ~= nil then
        for _, key in ipairs(keys) do
            AddLookup(lookup, key, value)
        end
    end
end

local function GetCooldownName(data)
    if data.cooldown_name ~= nil then
        return data.cooldown_name
    end
    if type(data.cooldown) == "table" then
        return data.cooldown.timer
    end
    return data.timer or data.tag or data.name
end

local function GetCooldownTime(data)
    if data.cooldown_time ~= nil then
        return data.cooldown_time
    end
    if type(data.cooldown) == "number" then
        return data.cooldown
    end
    return data.time or 0
end

local function GetCooldownMessage(data)
    if data.cooldown_message ~= nil then
        return data.cooldown_message
    end
    if type(data.cooldown) == "table" then
        return data.cooldown.message
    end
    return STRINGS.SKILL.COOLDOWN
end

local function NormalizeSkill(name, data)
    local skill = CopyTable(data)
    skill.name = skill.name or name
    skill.tag = skill.tag or name
    skill.state = skill.state or skill.sg_state or skill.tag
    skill.level = skill.level or skill.require_level or 0
    skill.mindpower = skill.mindpower or skill.require_mindpower or 0
    skill.display_mindpower = skill.display_mindpower or skill.mindpower
    skill.range = skill.range or skill.skill_range or TUNING.DEFAULT_ATTACK_RANGE
    skill.cooldown_name = GetCooldownName(skill)
    skill.cooldown_time = GetCooldownTime(skill)
    skill.cooldown_message = GetCooldownMessage(skill)
    skill.cooldown_effect = skill.cooldown_effect or DEFAULT_COOLDOWN_EFFECT
    skill.release = skill.release or skill.fn or skill.cb
    return skill
end

local PlayerSkillController = Class(function(self, inst)
    self.inst = inst
    self.active_skill = nil
    self.skills = {}
    self.skill_order = {}
    self.tag_to_skill = {}
    self.state_to_skill = {}
    self.cooldown_to_skill = {}
    self.cooldown_effects = {}
    self.input_routes = {}
    self.input_cooldowns = {
        [SKILL_INPUT.ICHIMONJI] = INPUT_COOLDOWN.ICHIMONJI,
        [SKILL_INPUT.FLIP] = INPUT_COOLDOWN.FLIP,
        [SKILL_INPUT.THRUST] = INPUT_COOLDOWN.THRUST,
        [SKILL_INPUT.SORYUHA] = INPUT_COOLDOWN.SORYUHA,
        cancel = "skill_cancel_cd",
    }
    self.input_levels = {}
    self.input_base_mindpower = {}
    self._on_deactivate_skill = function() self:DeactivateSkill() end

    inst:ListenForEvent("unequip", OnUnEquip)
    inst:ListenForEvent("timerdone", OnTimerDone)
    inst:ListenForEvent("mounted", PushDeactivateSkillEvent)
    inst:ListenForEvent("death", PushDeactivateSkillEvent)
    inst:ListenForEvent("ms_playerreroll", PushDeactivateSkillEvent)
    inst:ListenForEvent("ms_deactivateskill", self._on_deactivate_skill)
end)

function PlayerSkillController:Say(script, duration)
    if self.inst.components.talker ~= nil and script ~= nil then
        self.inst.components.talker:Say(script, duration or 1, true)
    end
end

function PlayerSkillController:ResolveSkillName(skill)
    if type(skill) == "table" then
        skill = skill.skill or skill.name or skill.tag or skill.state or skill.cooldown_name
    end

    return self.skills[skill] ~= nil and skill
        or self.tag_to_skill[skill]
        or self.state_to_skill[skill]
        or self.cooldown_to_skill[skill]
end

function PlayerSkillController:GetSkillData(skill)
    local name = self:ResolveSkillName(skill)
    return name ~= nil and self.skills[name] or nil
end

function PlayerSkillController:GetCooldownEffect(name)
    if self.cooldown_effects[name] ~= nil then
        local effect = self.cooldown_effects[name]
        self.cooldown_effects[name] = nil
        return effect
    end

    local skill = self:GetSkillData(name)
    return skill ~= nil and skill.cooldown_effect or nil
end

function PlayerSkillController:IsLimiterReleased()
    local kenjutsuka = self.inst.components.kenjutsuka
    return kenjutsuka ~= nil and kenjutsuka.IsTatsujin ~= nil and kenjutsuka:IsTatsujin()
end

function PlayerSkillController:AddSkill(name, data)
    if name == nil or data == nil then
        return
    end

    local skill = NormalizeSkill(name, data)
    if self.skills[name] == nil then
        table.insert(self.skill_order, name)
    end

    self.skills[name] = skill
    AddLookup(self.tag_to_skill, skill.tag, name)
    AddLookup(self.state_to_skill, skill.state, name)
    AddLookupList(self.state_to_skill, skill.states, name)
    AddLookup(self.cooldown_to_skill, skill.cooldown_name, name)
    AddLookup(self.cooldown_to_skill, skill.cooldown_name ~= nil and skill.cooldown_name .. "_cd" or nil, name)

    if skill.inputs ~= nil then
        for input_name, input_data in pairs(skill.inputs) do
            self:AddInputRoute(input_name, input_data)
        end
    end
end

function PlayerSkillController:AddInputRoute(input_name, data)
    if input_name == nil or data == nil then
        return
    end

    if self.input_routes[input_name] == nil then
        self.input_routes[input_name] = {}
    end

    table.insert(self.input_routes[input_name], data)
    self.input_cooldowns[input_name] = data.key_cooldown or self.input_cooldowns[input_name] or string.lower(input_name) .. "_key_cd"
    self.input_levels[input_name] = data.input_level or data.level or self.input_levels[input_name] or 0
    self.input_base_mindpower[input_name] = data.base_mindpower or self.input_base_mindpower[input_name]
end

function PlayerSkillController:GetWeapon()
    local inventory = self.inst.components.inventory
    return inventory ~= nil and inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
end

function PlayerSkillController:IsBodyBusy()
    local inst = self.inst
    local inventory = inst.components.inventory
    return inventory == nil
        or (inst.components.sleeper ~= nil and inst.components.sleeper:IsAsleep())
        or (inst.components.freezable ~= nil and inst.components.freezable:IsFrozen())
        or (inst.components.rider ~= nil and inst.components.rider:IsRiding())
        or inventory:IsHeavyLifting()
        or inst:HasTag("playerghost")
        or (inst.components.health ~= nil and inst.components.health:IsDead())
end

function PlayerSkillController:CanUseWeapon()
    local weapon = self:GetWeapon()
    if weapon == nil or self:IsBodyBusy() then
        return false
    end

    return not (weapon:HasOneOfTags(WEAPON_CANT_TAGS) and not weapon:HasOneOfTags(WEAPON_MUST_TAGS))
end

function PlayerSkillController:CanPerformIdleAction()
    local inst = self.inst
    return inst.components.inventory ~= nil
        and not (inst.components.health ~= nil and inst.components.health:IsDead() and not inst:HasTag("playerghost"))
        and inst:HasTag("idle")
        and not (inst.sg:HasStateTag("doing") or inst.components.inventory:IsHeavyLifting())
        and not (inst.sg:HasStateTag("moving") or inst:HasTag("moving"))
end

function PlayerSkillController:IsInputCoolingDown(input_name)
    local timer = self.inst.components.timer
    local cooldown = self.input_cooldowns[input_name]
    return timer ~= nil and cooldown ~= nil and timer:TimerExists(cooldown)
end

function PlayerSkillController:StartInputCooldown(input_name, time)
    local timer = self.inst.components.timer
    local cooldown = self.input_cooldowns[input_name]
    if timer ~= nil and cooldown ~= nil then
        timer:StartTimer(cooldown, time or INPUT_COOLDOWN_TIME)
    end
end

function PlayerSkillController:IsSkillActive(tag)
    return tag ~= nil and self.inst:HasTag(tag)
end

function PlayerSkillController:HasAnyActiveSkill(tags)
    if tags ~= nil then
        for _, tag in ipairs(tags) do
            if self:IsSkillActive(tag) then
                return true
            end
        end
    end
    return false
end

function PlayerSkillController:WeaponHasTags(tags)
    if tags == nil then
        return true
    end

    local weapon = self:GetWeapon()
    if weapon == nil then
        return false
    end

    for _, tag in ipairs(tags) do
        if not weapon:HasTag(tag) then
            return false
        end
    end

    return true
end

function PlayerSkillController:RouteMatches(route)
    if route.requires_tags ~= nil then
        for _, tag in ipairs(route.requires_tags) do
            if not self:IsSkillActive(tag) then
                return false
            end
        end
    end

    return self:WeaponHasTags(route.weapon_tags)
end

function PlayerSkillController:CanPaySkill(skill)
    local kenjutsuka = self.inst.components.kenjutsuka
    if kenjutsuka == nil then
        return false
    end

    if kenjutsuka:GetLevel() < skill.level then
        self:Say(STRINGS.SKILL.UNLOCK_SKILL .. skill.level)
        self:DeactivateSkill()
        return false
    end

    if not self:IsLimiterReleased() and kenjutsuka:GetMindpower() < skill.mindpower then
        self:Say(STRINGS.SKILL.MINDPOWER_NOT_ENOUGH .. kenjutsuka:GetMindpower() .. "/" .. skill.mindpower .. "\n ")
        self:DeactivateSkill()
        return false
    end

    if not self:IsLimiterReleased() and self.inst.components.timer ~= nil and skill.cooldown_name ~= nil and self.inst.components.timer:TimerExists(skill.cooldown_name) then
        self:Say(skill.cooldown_message or STRINGS.SKILL.COOLDOWN)
        self:DeactivateSkill()
        return false
    end

    return true
end

function PlayerSkillController:ActivateSkill(skill_name)
    local skill = self:GetSkillData(skill_name)
    local kenjutsuka = self.inst.components.kenjutsuka
    if skill == nil or kenjutsuka == nil or not self:CanPaySkill(skill) then
        return false
    end

    self:DeactivateSkill()
    self.inst:AddTag(skill.tag)
    self.active_skill = skill.name

    if self.inst.components.combat ~= nil then
        self.inst.components.combat:SetRange(skill.range)
    end

    if skill.start_message ~= nil then
        self:Say(skill.start_message .. kenjutsuka:GetMindpower() .. "/" .. skill.display_mindpower .. "\n ")
    end

    return true
end

function PlayerSkillController:HandleSkillInput(input_name)
    if not self:CanUseWeapon() or self:IsInputCoolingDown(input_name) then
        return true
    end

    local kenjutsuka = self.inst.components.kenjutsuka
    local input_level = self.input_levels[input_name] or 0
    if kenjutsuka == nil or kenjutsuka:GetLevel() < input_level then
        self:Say(STRINGS.SKILL.UNLOCK_SKILL .. input_level)
        return true
    end

    self:StartInputCooldown(input_name)

    local base_mindpower = self.input_base_mindpower[input_name]
    if not self:IsLimiterReleased() and base_mindpower ~= nil and kenjutsuka:GetMindpower() < base_mindpower then
        self:Say(STRINGS.SKILL.MINDPOWER_NOT_ENOUGH .. kenjutsuka:GetMindpower() .. "/" .. base_mindpower .. "\n ")
        self:DeactivateSkill()
        return true
    end

    local routes = self.input_routes[input_name]
    if routes ~= nil then
        for _, route in ipairs(routes) do
            if self:HasAnyActiveSkill(route.blocked_tags) then
                self:DeactivateSkill(true)
                return true
            end

            if self:RouteMatches(route) then
                return self:ActivateSkill(route.skill)
            end
        end
    end

    return true
end

function PlayerSkillController:CancelSkill()
    if self:CanUseWeapon() and not self:IsInputCoolingDown("cancel") then
        self:StartInputCooldown("cancel")
        self:DeactivateSkill()
        self:Say(STRINGS.SKILL.SKILL_CANCEL)
    end
    return true
end

function PlayerSkillController:CounterAttack()
    if not self:CanUseWeapon() then
        return true
    end

    local timer = self.inst.components.timer
    if timer ~= nil and not timer:TimerExists("prepare_counter_attack") then
        timer:StartTimer("prepare_counter_attack", (M_CONFIG ~= nil and M_CONFIG.CounterAtkCooldown) or COUNTER_ATTACK_COOLDOWN_TIME)
        self:DeactivateSkill()
        self.inst.sg:GoToState("start_counter_attack")
    else
        self:Say(STRINGS.SKILL.COOLDOWN)
        self:DeactivateSkill()
    end

    return true
end

function PlayerSkillController:QuickSheath()
    if not self:CanUseWeapon() then
        return true
    end

    local kenjutsuka = self.inst.components.kenjutsuka
    if kenjutsuka == nil or kenjutsuka:GetLevel() < QUICK_SHEATH_LEVEL then
        self:Say(STRINGS.SKILL.UNLOCK_SKILL .. QUICK_SHEATH_LEVEL)
        return true
    end

    local timer = self.inst.components.timer
    if timer ~= nil and timer:TimerExists("quick_sheath_cd") then
        return true
    end

    local weapon = self:GetWeapon()
    if timer ~= nil and weapon ~= nil and weapon:HasTag("katana") and not weapon:HasTag("tokijin") then
        self.inst.sg:GoToState("quicksheath")
    end

    return true
end

function PlayerSkillController:GetCurrentActiveSkill()
    for _, name in ipairs(self.skill_order) do
        local skill = self.skills[name]
        if skill ~= nil and self.inst:HasTag(skill.tag) then
            self.active_skill = name
            return name
        end
    end

    self.active_skill = nil
    return nil
end

function PlayerSkillController:IsValidSkillTarget(target)
    if target ~= nil and target:IsValid() then
        if target:HasOneOfTags(INVALID_TARGET_TAGS) then
            self.inst.sg:GoToState("idle")
            self:DeactivateSkill()
            self:Say(STRINGS.SKILL.REFUSE_RELEASE)
            return false
        end
        return true
    end
    return false
end

function PlayerSkillController:ReleaseSkill(target)
    if not self.inst:HasTag("kenjutsuka") then
        return false
    end

    local skill = self:GetSkillData(self:GetCurrentActiveSkill())
    if skill == nil then
        -- No active skill: this is a normal attack, do not block it.
        return true
    end

    if not self:IsValidSkillTarget(target) then
        return false
    end

    local released = true
    if skill.release ~= nil then
        released = skill.release(self.inst, target, skill)
    elseif skill.state ~= nil then
        self.inst.sg:GoToState(skill.state, target)
    end

    if self.inst:HasTag(skill.tag) then
        self.inst:RemoveTag(skill.tag)
    end

    if released == false then
        PushDeactivateSkillEvent(self.inst)
        return false
    end

    if not self:IsLimiterReleased() and self.inst.components.kenjutsuka ~= nil then
        self.inst.components.kenjutsuka:SetMindpower(self.inst.components.kenjutsuka:GetMindpower() - skill.mindpower)
    end

    if not self:IsLimiterReleased() and self.inst.components.timer ~= nil and skill.cooldown_name ~= nil then
        self.cooldown_effects[skill.cooldown_name] = skill.cooldown_effect
        self.inst.components.timer:StartTimer(skill.cooldown_name, skill.cooldown_time)
    end

    PushDeactivateSkillEvent(self.inst)
    return true
end

function PlayerSkillController:DeactivateSkill(later)
    if later then
        self:Say(STRINGS.SKILL.SKILL_LATER)
    end

    self.active_skill = nil

    for _, name in ipairs(self.skill_order) do
        local skill = self.skills[name]
        if skill ~= nil and self.inst:HasTag(skill.tag) then
            self.inst:RemoveTag(skill.tag)
        end
    end

    if self.inst.components.combat ~= nil then
        self.inst.components.combat:SetRange(TUNING.DEFAULT_ATTACK_RANGE)
        self.inst.components.combat:EnableAreaDamage(false)
    end

    if self.inst.AnimState ~= nil then
        self.inst.AnimState:SetDeltaTimeMultiplier(1)
    end
end

function PlayerSkillController:OnRemoveEntity()
    self:DeactivateSkill()
    self.inst:RemoveEventCallback("unequip", OnUnEquip)
    self.inst:RemoveEventCallback("timerdone", OnTimerDone)
    self.inst:RemoveEventCallback("mounted", PushDeactivateSkillEvent)
    self.inst:RemoveEventCallback("death", PushDeactivateSkillEvent)
    self.inst:RemoveEventCallback("ms_playerreroll", PushDeactivateSkillEvent)
    self.inst:RemoveEventCallback("ms_deactivateskill", self._on_deactivate_skill)
end

PlayerSkillController.OnRemoveFromEntity = PlayerSkillController.OnRemoveEntity

return PlayerSkillController
