local SkillUtil = require("utils/skillutil")

-- Secret art: Mortal Draw. A short exposed windup, a long straight cut, then a wide return swing.
-- With the Mortal Blade it reaches further, executes weakened foes and leaves a longer scar.
local WINDUP_TIME = 0.4
local STRIKE_HIT_FRAME = 3
local BACKSWING_ANIM_FRAME = 16
local BACKSWING_HIT_FRAME = 19
local SHEATH_FRAME = 30
local STRIKE_TIMEOUT = 45 * FRAMES

local LINE_WIDTH = 2.5
local TARGET_MUST_TAGS = {"_combat", "_health"}
local TARGET_CANT_TAGS = {"INLIMBO", "flight", "invisible", "notarget", "noattack", "playerghost", "FX", "NOCLICK", "player", "companion", "abigail", "wall", "structure"}

local MORTAL = {
    length = 10,
    strike_mult = 4,
    planar_mult = 2, -- vs shadow and lunar foes, matching the blade's own bias
    backswing_radius = 4.5,
    backswing_mult = 1.5,
    scar_time = 10,
    execute_pct = 0.15,
    execute_epic_pct = 0.05,
}

local IMITATION = {
    length = 8,
    strike_mult = 3,
    planar_mult = 1,
    backswing_radius = 3.5,
    backswing_mult = 1,
    scar_time = 5,
}

local function GetWeapon(inst)
    return inst.components.inventory ~= nil and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
end

local function GetTuning(weapon)
    return weapon ~= nil and weapon:HasTag("mortalblade") and MORTAL or IMITATION
end

local function GetWeaponDamage(inst, weapon, target)
    local weapon_cmp = weapon ~= nil and weapon.components.weapon or nil
    if weapon_cmp == nil then
        return 0
    end
    local damage = weapon_cmp.GetDamage ~= nil and weapon_cmp:GetDamage(inst, target) or weapon_cmp.damage
    return math.max(0, damage or 0)
end

local function IsValidTarget(inst, target)
    return target ~= inst
        and target:IsValid()
        and not target:IsInLimbo()
        and target.components.health ~= nil
        and not target.components.health:IsDead()
        and inst.components.combat:CanTarget(target)
        and not SkillUtil.IsProtectedTarget(inst, target)
end

-- Healing is blocked while the scar lasts; see postinit/components/health.lua.
local function ApplyScar(target, duration)
    local until_time = GetTime() + duration
    if target.immortalslash_scar_until == nil or target.immortalslash_scar_until < until_time then
        target.immortalslash_scar_until = until_time
    end
end

local function TryExecute(inst, target, tuning)
    if tuning.execute_pct == nil or not target:IsValid() then
        return false
    end

    local health = target.components.health
    if health == nil or health:IsDead() or health:IsInvincible() then
        return false
    end

    local threshold = target:HasTag("epic") and tuning.execute_epic_pct or tuning.execute_pct
    if health:GetPercent() > threshold then
        return false
    end

    health:DoDelta(-health.currenthealth, false, inst.prefab, false, inst, true)
    SkillUtil.SlashFx(inst, target, "shadowstrike_slash_fx", 4)
    return true
end

local function HitTarget(inst, target, weapon, tuning, mult)
    local damage = GetWeaponDamage(inst, weapon, target) * mult
    if weapon ~= nil and weapon.IsShadow ~= nil and (weapon.IsShadow(target) or weapon.IsLunar(target)) then
        damage = damage * tuning.planar_mult
    end
    target.components.combat:GetAttacked(inst, damage, weapon)
    ApplyScar(target, tuning.scar_time)
end

local function IsInLine(inst, target, x, z, fx, fz, length)
    local tx, _, tz = target.Transform:GetWorldPosition()
    local dx, dz = tx - x, tz - z
    local along = dx * fx + dz * fz
    local radius = target:GetPhysicsRadius(0)
    if along < -radius or along > length + radius then
        return false
    end
    local across = math.abs(dx * fz - dz * fx)
    return across <= LINE_WIDTH / 2 + radius
end

local function DoLineStrike(inst)
    local weapon = GetWeapon(inst)
    local tuning = GetTuning(weapon)
    local x, y, z = inst.Transform:GetWorldPosition()
    local rot = inst.Transform:GetRotation() * DEGREES
    -- DST forward in the XZ plane (z is inverted in world-space formulas).
    local fx, fz = math.cos(rot), -math.sin(rot)

    local swipe = SpawnPrefab("sharkboi_swipe_fx")
    if swipe ~= nil then
        swipe.AnimState:SetScale(5, 5, 5)
        swipe.AnimState:SetDeltaTimeMultiplier(0.2)
        swipe.entity:SetParent(inst.entity)
        swipe.Transform:SetPosition(1, 0, 0)
        swipe.AnimState:SetMultColour(0, 0, 0, 1)
        swipe:Reverse()
    end
    inst.SoundEmitter:PlaySound("dontstarve/creatures/spiderqueen/swipe")

    local hit = 0
    for _, target in ipairs(TheSim:FindEntities(x, y, z, tuning.length + 3, TARGET_MUST_TAGS, TARGET_CANT_TAGS)) do
        if IsValidTarget(inst, target) and IsInLine(inst, target, x, z, fx, fz, tuning.length) then
            HitTarget(inst, target, weapon, tuning, tuning.strike_mult)
            if not TryExecute(inst, target, tuning) then
                SkillUtil.SlashFx(inst, target, "shadowstrike_slash_fx", 3)
            end
            hit = hit + 1
        end
    end
    return hit
end

local function DoBackswing(inst)
    local weapon = GetWeapon(inst)
    local tuning = GetTuning(weapon)
    local x, y, z = inst.Transform:GetWorldPosition()

    local swipe = SpawnPrefab("sharkboi_swipe_fx")
    if swipe ~= nil then
        swipe.AnimState:SetScale(2.5, 2.5, 2.5)
        swipe.AnimState:SetDeltaTimeMultiplier(0.3)
        swipe.entity:SetParent(inst.entity)
        swipe.Transform:SetPosition(.5, 0, 0)
        swipe.AnimState:SetMultColour(.6, 0, 0, 1)
    end
    SkillUtil.GroundPoundFx(inst, .7)

    for _, target in ipairs(TheSim:FindEntities(x, y, z, tuning.backswing_radius, TARGET_MUST_TAGS, TARGET_CANT_TAGS)) do
        if IsValidTarget(inst, target) then
            HitTarget(inst, target, weapon, tuning, tuning.backswing_mult)
            TryExecute(inst, target, tuning)
        end
    end
end

return {
    events = {
        EventHandler("immortalslash", function(inst, data)
            inst.sg:GoToState("immortalslash", data ~= nil and (data.target or data) or nil)
        end),
    },
    states = {
        -- Exposed: no immunity and no "nointerrupt", so a hit here breaks the draw.
        State{
            name = "immortalslash",
            tags = {"busy", "nopredict", "nomorph", "doing", "notalking", "skilling"},

            onenter = function(inst, target)
                inst.components.locomotor:Stop()
                inst:ClearBufferedAction()
                inst.AnimState:PlayAnimation("scythe_pre")
                inst.AnimState:PushAnimation("scythe_lag", true)
                inst.SoundEmitter:PlaySound("dontstarve/common/nightmareAddFuel")

                if target ~= nil and target:IsValid() then
                    inst.sg.statemem.target = target
                    inst:ForceFacePoint(target.Transform:GetWorldPosition())
                end
                inst.sg:SetTimeout(WINDUP_TIME)
            end,

            ontimeout = function(inst)
                inst.sg:GoToState("immortalslash_strike", inst.sg.statemem.target)
            end,

            events = {
                EventHandler("unequip", function(inst)
                    inst.sg:GoToState("idle")
                end),
            },

            onexit = function(inst)
                if inst.components.combat ~= nil then
                    inst.components.combat:SetRange(TUNING.DEFAULT_ATTACK_RANGE)
                end
            end,
        },

        State{
            name = "immortalslash_strike",
            tags = {"busy", "nopredict", "nointerrupt", "nomorph", "doing", "notalking", "skilling", "attack"},

            onenter = function(inst, target)
                inst.inspskill = true
                inst.components.locomotor:Stop()
                if target ~= nil and target:IsValid() then
                    inst:ForceFacePoint(target.Transform:GetWorldPosition())
                end
                inst.AnimState:PlayAnimation("scythe_loop")
                inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")
                inst.sg:SetTimeout(STRIKE_TIMEOUT)
            end,

            timeline = {
                TimeEvent(STRIKE_HIT_FRAME * FRAMES, function(inst)
                    DoLineStrike(inst)
                end),
                TimeEvent(BACKSWING_ANIM_FRAME * FRAMES, function(inst)
                    inst.AnimState:PlayAnimation("scythe_loop")
                    inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_whoosh")
                end),
                TimeEvent(BACKSWING_HIT_FRAME * FRAMES, function(inst)
                    DoBackswing(inst)
                    inst.sg:RemoveStateTag("nointerrupt")
                end),
                TimeEvent(SHEATH_FRAME * FRAMES, function(inst)
                    local weapon = GetWeapon(inst)
                    if weapon ~= nil and weapon.components.spellcaster ~= nil and weapon.IsUnsheath ~= nil and weapon:IsUnsheath() then
                        weapon.components.spellcaster:CastSpell(inst)
                    end
                    if inst.AnimState:AnimDone() then
                        inst.sg:GoToState("idle")
                    end
                end),
            },

            ontimeout = function(inst)
                inst.sg:GoToState("idle")
            end,

            events = {
                EventHandler("animover", function(inst)
                    if inst.sg.timeinstate > SHEATH_FRAME * FRAMES and inst.AnimState:AnimDone() then
                        inst.sg:GoToState("idle")
                    end
                end),
            },

            onexit = function(inst)
                if inst.components.combat ~= nil then
                    inst.components.combat:SetTarget(nil)
                    inst.components.combat:SetRange(TUNING.DEFAULT_ATTACK_RANGE)
                end
                inst.AnimState:SetDeltaTimeMultiplier(1)
                inst.inspskill = nil
            end,
        },
    },
}
