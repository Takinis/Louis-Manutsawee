local AddModRPCHandler = AddModRPCHandler
local AddClientModRPCHandler = AddClientModRPCHandler
local AddShardModRPCHandler = AddShardModRPCHandler
local STRINGS = GLOBAL.STRINGS
local EQUIPSLOTS = GLOBAL.EQUIPSLOTS
GLOBAL.setfenv(1, GLOBAL)

local LEVEL = {
    SKILL1 = 1,
    SKILL2 = 3,
    SKILL3 = 4,
    SKILL4 = 6,
    SKILL5 = 5,
    SKILL6 = 7,
    SKILL7 = 8,
    SKILL8 = 10,
}

local LouisManutsawee = "LouisManutsawee"

local WEAPON_MUST_TAGS = {"tool", "sharp", "weapon", "katana"}
local WEAPON_CANT_TAGS = {"projectile", "whip", "rangedweapon"}

local INPUT_COOLDOWN = {
    Skill1 = "skill1_key_cd",
    Skill2 = "skill2_key_cd",
    Skill3 = "skill3_key_cd",
    Skill4 = "skill4_key_cd",
    SkillCancel = "skill_cancel_cd",
    CounterAttack = "prepare_counter_attack",
}

local SKILL_COOLDOWN = {
    ICHIMONJI = {timer = "ichimonji", message = STRINGS.SKILL.COOLDOWN},
    FLIP = {timer = "flip", message = STRINGS.SKILL.COOLDOWN},
    THRUST = {timer = "thrust", message = STRINGS.SKILL.COOLDOWN},
    ISSHIN = {timer = "isshin", message = STRINGS.SKILL.TIER2_COOLDOWN},
    RYUSEN = {timer = "ryusen", message = STRINGS.SKILL.TIER3_COOLDOWN},
    SORYUHA = {timer = "soryuha", message = STRINGS.SKILL.COOLDOWN},
}

local ACTIVE_SKILL_TAGS = {
    "ichimonji",
    "flip",
    "thrust",
    "isshin",
    "heavenlystrike",
    "ryusen",
    "susanoo",
    "immortalslash",
    "soryuha",
}

local function SkillRemove(inst)
    local controller = inst.components.playerskillcontroller
    if controller ~= nil then
        if controller.DeactivateSkill ~= nil then
            controller:DeactivateSkill()
        elseif controller.DeactiveSkill ~= nil then
            controller:DeactiveSkill()
        end
    end
end

local UI = {}

function UI.Say(inst, script, duration)
    if inst.components.talker ~= nil and script ~= nil then
        inst.components.talker:Say(script, duration or 1, true)
    end
end

function UI.UnlockSkill(inst, level)
    UI.Say(inst, STRINGS.SKILL.UNLOCK_SKILL .. level)
end

function UI.SkillLater(inst)
    UI.Say(inst, STRINGS.SKILL.SKILL_LATER)
end

function UI.Cooldown(inst, script)
    UI.Say(inst, script or STRINGS.SKILL.COOLDOWN)
end

function UI.MindpowerNotEnough(context, required)
    local current = context.kenjutsuka ~= nil and context.kenjutsuka:GetMindpower() or 0
    UI.Say(context.inst, STRINGS.SKILL.MINDPOWER_NOT_ENOUGH .. current .. "/" .. required .. "\n ")
end

function UI.SkillStart(context, skill)
    local current = context.kenjutsuka:GetMindpower()
    local required = skill.display_mindpower or skill.mindpower
    UI.Say(context.inst, skill.start_message .. current .. "/" .. required .. "\n ")
end

local function TimerExists(context, timer_name)
    return context.timer ~= nil and timer_name ~= nil and context.timer:TimerExists(timer_name)
end

local function StartTimer(context, timer_name, time)
    if context.timer ~= nil and timer_name ~= nil then
        context.timer:StartTimer(timer_name, time)
    end
end

local function BuildSkillState(inst)
    local tags = {}
    for _, tag in ipairs(ACTIVE_SKILL_TAGS) do
        tags[tag] = inst:HasTag(tag)
    end
    return tags
end

local function HasSkillState(context, tag)
    return context.skill_state[tag] == true
end

local function HasAnySkillState(context, tags)
    if tags ~= nil then
        for _, tag in ipairs(tags) do
            if HasSkillState(context, tag) then
                return true
            end
        end
    end
    return false
end

local function BuildContext(inst)
    local inventory = inst.components.inventory
    return {
        inst = inst,
        inventory = inventory,
        weapon = inventory ~= nil and inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil,
        timer = inst.components.timer,
        kenjutsuka = inst.components.kenjutsuka,
        skill_state = BuildSkillState(inst),
    }
end

local function CanActivateSkill(context)
    local inst = context.inst
    local inventory = context.inventory
    local weapon = context.weapon

    if inventory == nil or weapon == nil then
        return false
    end

    local is_asleep = inst.components.sleeper ~= nil and inst.components.sleeper:IsAsleep()
    local is_frozen = inst.components.freezable ~= nil and inst.components.freezable:IsFrozen()
    local is_riding = inst.components.rider ~= nil and inst.components.rider:IsRiding()
    local is_heavy_lifting = inventory:IsHeavyLifting()

    if is_asleep or is_frozen or is_riding or is_heavy_lifting or inst:HasTag("playerghost") then
        return false
    end

    if weapon:HasOneOfTags(WEAPON_CANT_TAGS) and not weapon:HasOneOfTags(WEAPON_MUST_TAGS) then
        return false
    end

    return true
end

local function WeaponHasTags(context, tags)
    if tags == nil then
        return true
    end

    local weapon = context.weapon
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

local function RejectBusySkill(context)
    SkillRemove(context.inst)
    UI.SkillLater(context.inst)
    return true
end

local function RejectCooldown(context, cooldown)
    UI.Cooldown(context.inst, cooldown.message)
    SkillRemove(context.inst)
    return true
end

local function RejectMindpower(context, required)
    UI.MindpowerNotEnough(context, required)
    SkillRemove(context.inst)
    return true
end

local function ApplySkill(context, skill)
    local inst = context.inst
    SkillRemove(inst)
    inst:AddTag(skill.tag)

    if inst.components.combat ~= nil then
        inst.components.combat:SetRange(skill.range)
    end

    UI.SkillStart(context, skill)
    return true
end

local function ExecuteSkill(context, skill)
    local level = skill.level or 0
    if level > 0 and context.kenjutsuka:GetLevel() < level then
        UI.UnlockSkill(context.inst, level)
        SkillRemove(context.inst)
        return true
    end

    if context.kenjutsuka:GetMindpower() < skill.mindpower then
        return RejectMindpower(context, skill.mindpower)
    end

    if TimerExists(context, skill.cooldown.timer) then
        return RejectCooldown(context, skill.cooldown)
    end

    return ApplySkill(context, skill)
end

local SKILLS = {
    ichimonji = {
        tag = "ichimonji",
        level = 0,
        mindpower = 3,
        cooldown = SKILL_COOLDOWN.ICHIMONJI,
        range = 3.5,
        start_message = STRINGS.SKILL.SKILL1START,
    },
    flip = {
        tag = "flip",
        level = 0,
        mindpower = 4,
        cooldown = SKILL_COOLDOWN.FLIP,
        range = 3.5,
        start_message = STRINGS.SKILL.SKILL2START,
    },
    thrust = {
        tag = "thrust",
        level = 0,
        mindpower = 4,
        cooldown = SKILL_COOLDOWN.THRUST,
        range = 3,
        start_message = STRINGS.SKILL.SKILL3START,
    },
    isshin = {
        tag = "isshin",
        level = LEVEL.SKILL4,
        mindpower = 7,
        cooldown = SKILL_COOLDOWN.ISSHIN,
        range = 3,
        start_message = STRINGS.SKILL.SKILL4START,
    },
    heavenlystrike = {
        tag = "heavenlystrike",
        level = LEVEL.SKILL5,
        mindpower = 5,
        cooldown = SKILL_COOLDOWN.ISSHIN,
        range = 3,
        start_message = STRINGS.SKILL.SKILL5START,
    },
    ryusen = {
        tag = "ryusen",
        level = LEVEL.SKILL6,
        mindpower = 8,
        cooldown = SKILL_COOLDOWN.RYUSEN,
        range = 10,
        start_message = STRINGS.SKILL.SKILL6START,
    },
    susanoo = {
        tag = "susanoo",
        level = LEVEL.SKILL7,
        mindpower = 10,
        cooldown = SKILL_COOLDOWN.RYUSEN,
        range = 3,
        start_message = STRINGS.SKILL.SKILL7START,
    },
    soryuha = {
        tag = "soryuha",
        level = LEVEL.SKILL8,
        mindpower = 20,
        display_mindpower = 4,
        cooldown = SKILL_COOLDOWN.SORYUHA,
        range = 3,
        start_message = STRINGS.SKILL.SKILL9START,
    },
}

local SKILL_INPUTS = {
    Skill1 = {
        key_cooldown = INPUT_COOLDOWN.Skill1,
        level = LEVEL.SKILL1,
        base_mindpower = 3,
        blocked_tags = {"ichimonji", "isshin", "ryusen"},
        routes = {
            {requires_tags = {"flip"}, weapon_tags = {"katana"}, skill = "isshin"},
            {skill = "ichimonji"},
        },
    },
    Skill2 = {
        key_cooldown = INPUT_COOLDOWN.Skill2,
        level = LEVEL.SKILL2,
        base_mindpower = 4,
        blocked_tags = {"flip", "ryusen", "susanoo"},
        routes = {
            {requires_tags = {"ichimonji"}, weapon_tags = {"katana"}, skill = "ryusen"},
            {requires_tags = {"thrust"}, weapon_tags = {"katana"}, skill = "susanoo"},
            {skill = "flip"},
        },
    },
    Skill3 = {
        key_cooldown = INPUT_COOLDOWN.Skill3,
        level = LEVEL.SKILL3,
        base_mindpower = 4,
        blocked_tags = {"heavenlystrike", "thrust", "susanoo"},
        routes = {
            {requires_tags = {"flip"}, weapon_tags = {"katana"}, skill = "heavenlystrike"},
            {skill = "thrust"},
        },
    },
    Skill4 = {
        key_cooldown = INPUT_COOLDOWN.Skill4,
        level = LEVEL.SKILL8,
        start_key_cooldown_before_level_check = true,
        blocked_tags = {"immortalslash", "soryuha"},
        routes = {
            {weapon_tags = {"onikiba"}, skill = "soryuha"},
        },
    },
}

local function RouteMatches(context, route)
    if route.requires_tags ~= nil then
        for _, tag in ipairs(route.requires_tags) do
            if not HasSkillState(context, tag) then
                return false
            end
        end
    end

    return WeaponHasTags(context, route.weapon_tags)
end

local function ExecuteRoutes(context, request)
    if HasAnySkillState(context, request.blocked_tags) then
        return RejectBusySkill(context)
    end

    for _, route in ipairs(request.routes) do
        if RouteMatches(context, route) then
            return ExecuteSkill(context, SKILLS[route.skill])
        end
    end
end

local function ExecuteSkillInput(inst, input_name)
    local request = SKILL_INPUTS[input_name]
    local context = BuildContext(inst)

    if not CanActivateSkill(context) then
        return
    end

    if TimerExists(context, request.key_cooldown) then
        return
    end

    if request.start_key_cooldown_before_level_check then
        StartTimer(context, request.key_cooldown, 1)
    end

    if context.kenjutsuka == nil then
        if not request.start_key_cooldown_before_level_check then
            UI.UnlockSkill(inst, request.level)
        end
        return
    end

    if context.kenjutsuka:GetLevel() < request.level then
        UI.UnlockSkill(inst, request.level)
        return
    end

    if not request.start_key_cooldown_before_level_check then
        StartTimer(context, request.key_cooldown, 1)
    end

    if request.base_mindpower ~= nil and context.kenjutsuka:GetMindpower() < request.base_mindpower then
        RejectMindpower(context, request.base_mindpower)
        return
    end

    ExecuteRoutes(context, request)
end

local function ExecuteCounterAttack(inst)
    local context = BuildContext(inst)
    if not CanActivateSkill(context) then
        return true
    end

    if not TimerExists(context, INPUT_COOLDOWN.CounterAttack) then
        StartTimer(context, INPUT_COOLDOWN.CounterAttack, 0.63)
        SkillRemove(inst)
        inst.sg:GoToState("start_counter_attack")
    else
        UI.Cooldown(inst, STRINGS.SKILL.COOLDOWN)
        SkillRemove(inst)
    end

    return true
end

local function ExecuteSkillCancel(inst)
    local context = BuildContext(inst)
    if not CanActivateSkill(context) then
        return true
    end

    if not TimerExists(context, INPUT_COOLDOWN.SkillCancel) then
        StartTimer(context, INPUT_COOLDOWN.SkillCancel, 1)
        SkillRemove(inst)
        UI.Say(inst, STRINGS.SKILL.SKILL_CANCEL)
    end

    return true
end

local LouisManutsawee_RPC_HANDLERS = {
    RPC_Handlers = {
        Skill1Key = function(inst)
            if inst.components.playerskillcontroller ~= nil then
                inst.components.playerskillcontroller:ToggleActiveSkill()
            end
            StartTimer(BuildContext(inst), INPUT_COOLDOWN.Skill1, 1)
        end,

        Skill1 = function(inst)
            ExecuteSkillInput(inst, "Skill1")
        end,

        Skill2 = function(inst)
            ExecuteSkillInput(inst, "Skill2")
        end,

        Skill3 = function(inst)
            ExecuteSkillInput(inst, "Skill3")
        end,

        Skill4 = function(inst)
            ExecuteSkillInput(inst, "Skill4")
        end,

        CounterAttackKey = ExecuteCounterAttack,
        SkillCancelKey = ExecuteSkillCancel,
    },

    Client_RPC_Handlers = {},

    Shard_RPC_Handlers = {
        SyncKatanaSpawnerData = function(shardid, active, name)
            if active then
                TheWorld:PushEvent("ms_trackkatana", {name = name})
            else
                TheWorld:PushEvent("ms_forgetkatana", {name = name})
            end
        end,

        SyncDatingManagerData = function(shardid, active, name)
            if active then
            end
        end,
    },
}

for name, handler in pairs(LouisManutsawee_RPC_HANDLERS.RPC_Handlers) do
    AddModRPCHandler(LouisManutsawee, name, handler)
end

for name, handler in pairs(LouisManutsawee_RPC_HANDLERS.Client_RPC_Handlers) do
    if AddClientModRPCHandler ~= nil then
        AddClientModRPCHandler(LouisManutsawee, name, handler)
    end
end

for name, handler in pairs(LouisManutsawee_RPC_HANDLERS.Shard_RPC_Handlers) do
    AddShardModRPCHandler(LouisManutsawee, name, handler)
end
