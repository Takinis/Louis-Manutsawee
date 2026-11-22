local MakePlayerCharacter = require "prefabs/player_common"
local SpDamageUtil = require "components/spdamageutil"
local AfterImageUtil = require "utils/afterimageutil"

local assets ={
    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
    Asset("ANIM", "anim/rocky_boss_shadow_build.zip"),
    Asset("ANIM", "anim/player_wolfgang_dumbbell.zip"),
    Asset("ANIM", "anim/kiritzuka_guard.zip"),
}

local HIT_FX = {
    "kiritzuka_hit_fx_impact",
    "kiritzuka_hit_fx_ice",
    "kiritzuka_hit_fx_balloon",
    "kiritzuka_hit_fx_puff",
}

local prefabs = {
    "kiritzuka_crater_fx", "superjump_fx", "kiritzuka_slam_ring_fx", "kiritzuka_slam_dust_fx", "splash",
    "rocky_dash_fx", "rocky_snip_fx", "explode_small", "kiritzuka_flurry_image", unpack(HIT_FX),
}
local start_inv = {}

for k, v in pairs(TUNING.GAMEMODE_STARTING_ITEMS) do
    start_inv[string.lower(k)] = v.KIRITZUKA
end

prefabs = FlattenTree({prefabs, start_inv}, true)

local HURT_SPEECH_COOLDOWN = 2
local HURT_SPEECH_KEYS = { "LIGHT", "MEDIUM", "HEAVY" }

local PARRY_WEAPONS = {
    baseballbat = true,
    crowbar = true,
    rebar = true,
}
-- The whole front half counts as facing the attacker.
local PARRY_ANGLE = 90
local ATTACK_STATE = "kiritzuka_attack"
local GUARD_HIT_STATE = "kiritzuka_guard_hit"
local POUNCE_SWAT_STATE = "kiritzuka_pounce_swat"
-- How long the guard stays up after the retreat; moving ends it early.
local PARRY_HOLD_TIME = 0.75
local SUSTAINED_PARRY_STATE = "kiritzuka_sustained_parry"
local BEAM_PREFAB = "wagboss_beam_fx"
local ROCK_MASTERS = {
    rocky_boss = true,
    rocky_boss_shadow = true,
}
-- Far enough back along a Rock Master's dash to stand for where it came from.
local ROCK_DASH_ORIGIN = 20
-- Rock Masters' cuts never push, so the guard supplies its own short retreat.
local ROCK_PARRY_RADIUS = 3
-- These latch onto the head and keep biting, so blocking them would hold the guard up for as long as they stay.
local POUNCERS = {
    slurper = true,
    bat_boss = true,
    bat_boss_shadow = true,
}

local HOMERUN_STATE = "kiritzuka_homerun_charge"
local HOMERUN_SWING_STATE = "kiritzuka_homerun_swing"
local HOMERUN_COOLDOWN = "kiritzuka_homerun"
-- The slide covers most of what is left each frame, so it starts fast and eases out.
local KNOCK_STEP = 0.2
local COUNTER_STATE = "kiritzuka_counter"
local COUNTER_SWING_STATE = "kiritzuka_counter_swing"
local COUNTER_COOLDOWN = "kiritzuka_counter"
local DASH_STATE = "kiritzuka_dash"
local DASH_COOLDOWN = "kiritzuka_dash"
local FLURRY_COOLDOWN = "kiritzuka_flurry"
local FLURRY_IMAGE = "kiritzuka_flurry_image"
local FLURRY_IMAGE_ANIMS = { "atk", "scythe_loop" }
local DASH_BUILD = "rocky_boss_shadow_build"

-- Same list the native giant lasers tear through.
local DESTROY_ONEOF_TAGS = { "CHOP_workable", "HAMMER_workable", "MINE_workable", "DIG_workable" }
local DESTROY_CANT_TAGS = { "INLIMBO", "FX", "DECOR", "NOCLICK", "boat" }
local DESTROY_ACTIONS = { CHOP = true, HAMMER = true, MINE = true, DIG = true }

local SLAM_TARGET_TAGS = { "_combat", "_health" }
local SLAM_EXCLUDE_TAGS = {
    "INLIMBO", "FX", "NOCLICK", "invisible", "notarget", "noattack",
    "player", "playerghost", "companion", "wall",
}
local SLAM_LARGE_TAGS = { "epic", "boss", "largecreature" }
-- Preferred approach first, then spread around the target if that side is blocked.
local SLAM_LANDING_ANGLES = { 0, 45, -45, 90, -90, 135, -135, 180 }
local SLAM_COOLDOWN = "kiritzuka_boss_slam"
local WORM_BURST_SCALE = 1.4
local WORM_LEAP_STATE = "kiritzuka_worm_leap"
local WORM_BREAK_LINE_DELAY = 1
local SLAM_BLIGHT_TAG = "shadowthrall_centipede_controller"
-- The ring art's radius is 12 at scale 1 and grows with the square of the scale.
local SLAM_IMPACT_RINGS = {
    { delay = 0, scale = 1.25 },
    { delay = 0.12, scale = 1.05 },
    { delay = 0.24, scale = 0.8 },
}
local SLAM_IMPACT_DUST = {
    { delay = 0, radius = 2, count = 4 },
    { delay = 0.1, radius = 5.5, count = 7 },
    { delay = 0.2, radius = 9, count = 10 },
    { delay = 0.3, radius = 12.5, count = 13 },
}
local SLAM_HIT_RINGS = { { delay = 0, scale = 0.85 } }
local SLAM_HIT_DUST = { { delay = 0, radius = 3.5, count = 6 } }
local SLAM_BURST_RING_SCALE = 0.45
local SLAM_BURST_DUST_RADIUS = 1
local SLAM_BURST_DUST_COUNT = 3

-- Cooldowns are switched off for now; the setting brings them all back at once.
local function IsOnCooldown(inst, name)
    return TUNING.KIRITZUKA_SKILL_COOLDOWNS and inst.components.timer:TimerExists(name)
end

local function StartSkillCooldown(inst, name, duration)
    if TUNING.KIRITZUKA_SKILL_COOLDOWNS then
        inst.components.timer:StartTimer(name, duration)
    end
end

-- Only reductions are offset: vulnerability stays a bonus and full immunity stays immune.
local function GetReduction(factor)
    return factor > 0 and factor < 1 and factor or 1
end

local function GetHealthReduction(target, attacker)
    local health = target.components.health
    local absorb = health.absorb
    if health.playerabsorb ~= 0 and attacker:HasTag("player") then
        absorb = absorb + health.playerabsorb
    end
    return GetReduction(math.clamp(1 - absorb, 0, 1) * math.max(1 - health.externalabsorbmodifiers:Get(), 0))
end

local function GetEquipDefense(target, attacker, weapon)
    local inventory = target.components.inventory
    local absorbed, resist, equips = 0, 1, {}
    if inventory == nil or inventory.ignorecombat then
        return absorbed, resist, equips
    end
    for _, equip in pairs(inventory.equipslots) do
        if equip.components.armor ~= nil then
            absorbed = math.max(absorbed, equip.components.armor:GetAbsorption(attacker, weapon) or 0)
        end
        if equip.components.damagetyperesist ~= nil then
            resist = resist * equip.components.damagetyperesist:GetResist(attacker, weapon)
        end
        equips[equip] = true
    end
    return absorbed, resist, equips
end

-- Walks Combat:GetAttacked_Internal backwards, so the same damage lands with or without defense.
local function OffsetTargetDefense(inst, target, weapon, damage, spdamage)
    local combat = target.components.combat
    local health_factor = GetHealthReduction(target, inst)
    local absorbed, equip_resist, equips = GetEquipDefense(target, inst, weapon)
    equip_resist = GetReduction(equip_resist)

    local resist = target.components.damagetyperesist ~= nil
        and GetReduction(target.components.damagetyperesist:GetResist(inst, weapon)) or 1
    local taken = GetReduction(combat.externaldamagetakenmultipliers:Get())
    if combat.conditionexternaldamagetakenmultipliers ~= nil then
        -- The native path applies the type resist a second time alongside these.
        taken = taken * resist * GetReduction(combat:ApplyConditionExternalDamageTakenMultiplier(1, inst, weapon))
    end

    if damage > 0 then
        damage = damage / health_factor
        if target.components.planarentity ~= nil then
            -- Inverse of PlanarEntity:AbsorbDamage.
            damage = damage + damage * damage / 64
        end
        damage = damage / (resist * taken * equip_resist * GetReduction(1 - absorbed))
    end

    if spdamage ~= nil then
        for sptype, value in pairs(spdamage) do
            local defense = SpDamageUtil.GetSpDefenseForType(target, sptype)
            for equip in pairs(equips) do
                defense = defense + SpDamageUtil.GetSpDefenseForType(equip, sptype)
            end
            spdamage[sptype] = (value / (health_factor * resist) + defense) / equip_resist
        end
    end

    return damage, spdamage
end

local function CanSlamHit(inst, target)
    return target ~= nil and target ~= inst
        and target.IsValid ~= nil and target:IsValid()
        and target.Transform ~= nil and not target:IsInLimbo()
        and not target:HasAnyTag(unpack(SLAM_EXCLUDE_TAGS))
        -- Of the structures, only monster nests are worth a fight.
        and (not target:HasTag("structure") or target.components.childspawner ~= nil)
        and target.components.health ~= nil and not target.components.health:IsDead()
        and target.components.combat ~= nil
        and inst.components.combat:CanTarget(target)
        and not inst.components.combat:IsAlly(target)
end

local function IsSlamPointSafe(inst, pos)
    return TheWorld.Map:IsPassableAtPoint(pos.x, 0, pos.z)
        and not TheWorld.Map:IsPointNearHole(pos)
        and not TheWorld.Map:IsGroundTargetBlocked(pos)
end

local function GetSlamLandingDistance(target)
    local tuning = TUNING.KIRITZUKA_BOSS_SLAM
    local distance = tuning.LANDING_DISTANCE.default
    if target:HasAnyTag(unpack(SLAM_LARGE_TAGS)) then
        distance = tuning.LANDING_DISTANCE.large
    elseif target:HasTag("smallcreature") then
        distance = tuning.LANDING_DISTANCE.small
    end
    -- Clear the target's body, but keep its center inside the impact.
    return math.min(math.max(distance, target:GetPhysicsRadius(0) + 1), tuning.RADIUS - 1)
end

local function GetSlamLanding(inst, target, origin)
    if not CanSlamHit(inst, target) then
        return
    end
    local pos = target:GetPosition()
    local range = TUNING.KIRITZUKA_BOSS_SLAM.RANGE + target:GetPhysicsRadius(0)
    local range_dx, range_dz = pos.x - origin.x, pos.z - origin.z
    if range_dx * range_dx + range_dz * range_dz > range * range then
        return
    end
    local current = inst:GetPosition()
    current.y = 0
    local dx, dz = current.x - pos.x, current.z - pos.z
    local distance = GetSlamLandingDistance(target)
    -- Already close enough: hop in place rather than backing away from the target.
    if dx * dx + dz * dz <= distance * distance and IsSlamPointSafe(inst, current) then
        return current
    end
    local target_x, target_z = pos.x, pos.z
    local angle = math.atan2(dz, dx)
    pos.y = 0
    for _, offset in ipairs(SLAM_LANDING_ANGLES) do
        local rotated = angle + math.rad(offset)
        pos.x = target_x + math.cos(rotated) * distance
        pos.z = target_z + math.sin(rotated) * distance
        if IsSlamPointSafe(inst, pos) then
            return pos
        end
    end
end

local function SaySlamLine(inst, line)
    if inst.components.talker ~= nil then
        if type(line) == "table" then
            line = line[math.random(#line)]
        end
        inst.components.talker:Say(line, 2, true)
    end
end

local function IsSlamArmed(inst)
    return inst.kiritzuka_armed ~= nil and inst.kiritzuka_armed.skill == "slam"
end

local function IsDashArmed(inst)
    return inst.kiritzuka_armed ~= nil and inst.kiritzuka_armed.skill == "dash"
end

local function IsFlurryArmed(inst)
    return inst.kiritzuka_armed ~= nil and inst.kiritzuka_armed.skill == "flurry"
end

-- Only one skill can be readied at a time, so both share the saved attack range.
local function DisarmSkill(inst)
    local armed = inst.kiritzuka_armed
    if armed ~= nil then
        inst.kiritzuka_armed = nil
        inst.components.combat:SetRange(armed.attack, armed.hit)
    end
end

local function HasExclusiveWeapon(inst)
    local weapon = inst.components.combat:GetWeapon()
    return weapon ~= nil and PARRY_WEAPONS[weapon.prefab] == true
end

local function CanCarryOutSlam(inst)
    return not inst:HasTag("playerghost") and not inst.components.health:IsDead()
        and inst.components.playercontroller:IsEnabled()
        and not inst.components.rider:IsRiding()
        and not inst.components.inventory:IsHeavyLifting()
end

-- First press readies the skill for the next attack; a second press stands down. No range keeps her normal reach.
local function ToggleSkill(inst, skill, cooldown, range, ready_line, cooldown_line, cancel_line)
    if inst.sg == nil or inst.sg:HasStateTag("busy")
        or inst.sg:HasStateTag("dead") or inst.sg:HasStateTag("sleeping")
        or inst.sg:HasStateTag("frozen") or inst.sg:HasStateTag("jumping")
        or not CanCarryOutSlam(inst) then
        return false
    end
    if inst.kiritzuka_armed ~= nil and inst.kiritzuka_armed.skill == skill then
        DisarmSkill(inst)
        SaySlamLine(inst, cancel_line)
        return true
    end
    if IsOnCooldown(inst, cooldown) then
        SaySlamLine(inst, cooldown_line)
        return false
    end
    if not HasExclusiveWeapon(inst) then
        SaySlamLine(inst, STRINGS.SKILL.KIRITZUKA_WEAPON_REFUSE)
        return false
    end
    DisarmSkill(inst)
    local combat = inst.components.combat
    inst.kiritzuka_armed = { skill = skill, attack = combat.attackrange, hit = combat.hitrange }
    if range ~= nil then
        combat:SetRange(range, combat.hitrange)
    end
    SaySlamLine(inst, ready_line)
    return true
end

-- A readied skill belongs to the weapon that readied it; putting that down stands it down.
local function OnUnequip(inst, data)
    if data == nil or data.eslot ~= EQUIPSLOTS.HANDS then
        return
    end
    inst.kiritzuka_armor_break = nil
    if inst.kiritzuka_armed ~= nil then
        DisarmSkill(inst)
        SaySlamLine(inst, STRINGS.SKILL.KIRITZUKA_SLAM_CANCEL)
    end
end

local function ToggleSlam(inst)
    -- A readied slam can still be put away; only readying a new one is refused at sea.
    if not IsSlamArmed(inst) and inst:GetCurrentPlatform() ~= nil then
        SaySlamLine(inst, STRINGS.SKILL.KIRITZUKA_SLAM_SEA)
        return false
    end
    return ToggleSkill(inst, "slam", SLAM_COOLDOWN, TUNING.KIRITZUKA_BOSS_SLAM.ARMED_ATTACK_RANGE,
        STRINGS.SKILL.KIRITZUKA_SLAM_READY, STRINGS.SKILL.KIRITZUKA_SLAM_COOLDOWN, STRINGS.SKILL.KIRITZUKA_SLAM_CANCEL)
end

local function ToggleDash(inst)
    return ToggleSkill(inst, "dash", DASH_COOLDOWN, TUNING.KIRITZUKA_DASH.ARMED_ATTACK_RANGE,
        STRINGS.SKILL.KIRITZUKA_DASH_READY, STRINGS.SKILL.KIRITZUKA_DASH_COOLDOWN, STRINGS.SKILL.KIRITZUKA_SLAM_CANCEL)
end

local function ToggleFlurry(inst)
    return ToggleSkill(inst, "flurry", FLURRY_COOLDOWN, nil,
        STRINGS.SKILL.KIRITZUKA_FLURRY_READY, STRINGS.SKILL.KIRITZUKA_FLURRY_COOLDOWN, STRINGS.SKILL.KIRITZUKA_SLAM_CANCEL)
end

-- Spends the readied slam on the attack's target, whether or not it can be carried out.
local function IsSlamAtSea(inst, target)
    if inst:GetCurrentPlatform() ~= nil then
        return true
    end
    if target == nil or target.Transform == nil then
        return false
    end
    local x, _, z = target.Transform:GetWorldPosition()
    return TheWorld.Map:IsOceanTileAtPoint(x, 0, z)
end

local function TryReleaseSlam(inst, target, origin)
    DisarmSkill(inst)
    if not HasExclusiveWeapon(inst) then
        SaySlamLine(inst, STRINGS.SKILL.KIRITZUKA_WEAPON_REFUSE)
        return false
    end
    if IsSlamAtSea(inst, target) then
        SaySlamLine(inst, STRINGS.SKILL.KIRITZUKA_SLAM_SEA)
        return false
    end
    if CanCarryOutSlam(inst)
        and not IsOnCooldown(inst, SLAM_COOLDOWN)
        and IsSlamPointSafe(inst, origin) and GetSlamLanding(inst, target, origin) ~= nil then
        return true
    end
    SaySlamLine(inst, STRINGS.SKILL.REFUSE_RELEASE)
    return false
end

local function StartSlamCooldown(inst)
    StartSkillCooldown(inst, SLAM_COOLDOWN, TUNING.KIRITZUKA_BOSS_SLAM.COOLDOWN)
end

local function SpawnSlamRing(inst, pos, scale)
    local ring = SpawnPrefab("kiritzuka_slam_ring_fx")
    if ring ~= nil then
        ring.Transform:SetPosition(pos.x, 0, pos.z)
        ring.Transform:SetScale(scale, scale, scale)
    end
end

local function SpawnSlamDustRing(inst, pos, radius, count)
    local offset = math.random() * 2 * math.pi
    for i = 1, count do
        local theta = offset + 2 * math.pi * i / count
        local x, z = pos.x + radius * math.cos(theta), pos.z + radius * math.sin(theta)
        if TheWorld.Map:IsPassableAtPoint(x, 0, z) then
            local dust = SpawnPrefab("kiritzuka_slam_dust_fx")
            if dust ~= nil then
                dust.Transform:SetPosition(x, 0, z)
            end
        end
    end
end

local function SpawnSlamShockwave(inst, pos, rings, dust)
    for _, ring in ipairs(rings) do
        inst:DoTaskInTime(ring.delay, SpawnSlamRing, pos, ring.scale)
    end
    for _, wave in ipairs(dust) do
        inst:DoTaskInTime(wave.delay, SpawnSlamDustRing, pos, wave.radius, wave.count)
    end
end

local function SpawnSlamCrater(inst, pos)
    -- A boat would sail out from under the crater and leave it hanging over the water.
    if TheWorld.Map:GetPlatformAtPoint(pos.x, pos.z) == nil then
        local fx = SpawnPrefab("kiritzuka_crater_fx")
        if fx ~= nil then
            fx.Transform:SetPosition(pos.x, 0, pos.z)
        end
    end
    SpawnSlamRing(inst, pos, 0.8)
end

-- Halfway to the target, falling back to the landing point when the target is gone or that spot is unsafe.
local function GetSlamImpactPoint(inst, landing, target)
    if target == nil or not target:IsValid() then
        return landing
    end
    local x, _, z = target.Transform:GetWorldPosition()
    local impact = inst:GetPosition()
    impact.x, impact.y, impact.z = (landing.x + x) / 2, 0, (landing.z + z) / 2
    return IsSlamPointSafe(inst, impact) and impact or landing
end

-- Anything the native knockback has to clear or block stays with it, as does a real parry.
local function CanGuard(inst)
    local components = inst.components
    local weapon = components.combat:GetWeapon()
    return weapon ~= nil and PARRY_WEAPONS[weapon.prefab]
        and components.combat.redirectdamagefn == nil
        and not components.health:IsDead()
        and not components.rider:IsRiding()
        and not components.inventory:IsHeavyLifting()
        and not components.inventory:EquipHasTag("superheavyarmor")
        and not (components.freezable ~= nil and components.freezable:IsFrozen())
        and not (components.pinnable ~= nil and components.pinnable:IsStuck())
end

local function IsFacingPoint(inst, x, z)
    return DiffAngle(inst.Transform:GetRotation(), inst:GetAngleToPoint(x, 0, z)) <= PARRY_ANGLE
end

-- For anything that plays the guard: it must not cut into a skill that cannot be interrupted.
local function CanParryFrom(inst, x, z)
    return CanGuard(inst) and IsFacingPoint(inst, x, z) and not inst.sg:HasStateTag("nointerrupt")
end

-- A dashing Rock Master is already past the player when its hit lands, so the guard faces the way it came.
local function GetGuardPoint(attacker)
    local x, _, z = attacker.Transform:GetWorldPosition()
    local sg = attacker.sg
    if ROCK_MASTERS[attacker.prefab] and sg ~= nil and sg.currentstate.name == "dash_attack" and sg.statemem.dx ~= nil then
        return x - sg.statemem.dx * ROCK_DASH_ORIGIN, z - sg.statemem.dz * ROCK_DASH_ORIGIN
    end
    return x, z
end

-- Only something that can be hit back qualifies: beams and supernova burns stay with the held guard.
local function StartCounterWhiffCooldown(inst)
    StartSkillCooldown(inst, COUNTER_COOLDOWN, TUNING.KIRITZUKA_COUNTER.COOLDOWN)
end

local function TryCounter(inst, attacker, damage, spdamage)
    if inst.sg.currentstate.name ~= COUNTER_STATE or inst.sg.statemem.whiffed
        or (attacker.sg ~= nil and attacker.sg:HasStateTag("supernovaburning"))
        or not CanSlamHit(inst, attacker) then
        return false
    end
    local x, z = GetGuardPoint(attacker)
    if not CanParryFrom(inst, x, z) then
        return false
    end
    StartSkillCooldown(inst, COUNTER_COOLDOWN, TUNING.KIRITZUKA_COUNTER.SUCCESS_COOLDOWN)
    if inst.components.momentum ~= nil then
        inst.components.momentum:Gain(TUNING.KIRITZUKA_COUNTER.MOMENTUM_GAIN)
    end
    local blocked = (damage or 0) + SpDamageUtil.CalcTotalDamage(spdamage)
    inst.sg:GoToState(COUNTER_SWING_STATE, { target = attacker, blocked = blocked })
    return true
end

-- The native retreat only takes its strength from the knockback, so that is what gets scaled.
-- It works on a copy: other listeners are sharing the same event data.
local function GetParryKnockback(knocker, radius, strengthmult)
    return {
        knocker = knocker,
        radius = radius,
        strengthmult = (strengthmult or 1) * TUNING.KIRITZUKA_PARRY_RETREAT,
    }
end

local function PlayGuardHit(inst, knockbackdata)
    inst.sg:GoToState(GUARD_HIT_STATE, { timeleft = PARRY_HOLD_TIME, knockbackdata = knockbackdata })
end

-- The hit and the knockback of one attack land in the same tick, and only one of them should count.
local function MarkParried(inst, knocker)
    inst.kiritzuka_parried_knocker = knocker
    inst.kiritzuka_parried_tick = GetTick()
end

local function WasParried(inst, knocker)
    return inst.kiritzuka_parried_knocker == knocker and inst.kiritzuka_parried_tick == GetTick()
end

local function ParryKnockback(inst, data)
    local knocker = data ~= nil and data.knocker or nil
    if knocker == nil or not knocker:IsValid() then
        return false
    end
    if TryCounter(inst, knocker, 0) then
        MarkParried(inst, knocker)
        return true
    end
    local x, _, z = knocker.Transform:GetWorldPosition()
    if not CanParryFrom(inst, x, z) then
        return false
    end
    -- The attack usually lands just before its knockback; a few push the knockback first.
    local hits = inst.kiritzuka_pending_hits
    if hits ~= nil then
        for i = #hits, 1, -1 do
            if hits[i].attacker == knocker then
                table.remove(hits, i)
            end
        end
    end
    MarkParried(inst, knocker)
    PlayGuardHit(inst, GetParryKnockback(knocker, data.radius, data.strengthmult))
    return true
end

-- Called every tick of a sustained attack: each call keeps the held guard up and turned to the source.
local function ParrySustained(inst, x, z)
    if not CanParryFrom(inst, x, z) then
        return false
    end
    if inst.sg.currentstate.name == SUSTAINED_PARRY_STATE then
        inst.sg.statemem.parry_time = GetTime()
        inst:ForceFacePoint(x, 0, z)
    elseif not inst.sg:HasStateTag("busy") then
        inst.sg:GoToState(SUSTAINED_PARRY_STATE, { x = x, z = z })
    end
    return true
end

-- The guard has to face W.A.R.B.O.T. itself; the beam comes down on top of the player from anywhere.
local function ParryBeam(inst, beam)
    if beam.kiritzuka_source_x == nil or not ParrySustained(inst, beam.kiritzuka_source_x, beam.kiritzuka_source_z) then
        return false
    end
    inst.kiritzuka_guard_tick = GetTick()
    return true
end

local function RedirectBeamDamage(inst, amount, overtime, cause, ignore_invincible, afflicter)
    return amount < 0 and afflicter ~= nil and afflicter.prefab == BEAM_PREFAB and ParryBeam(inst, afflicter)
end

local function ParryRockMaster(inst, attacker)
    local x, z = GetGuardPoint(attacker)
    if not CanParryFrom(inst, x, z) then
        return false
    end
    PlayGuardHit(inst, GetParryKnockback(attacker, ROCK_PARRY_RADIUS))
    return true
end

local function PlayBlockGuard(inst, attacker)
    PlayGuardHit(inst, { knocker = attacker, radius = ROCK_PARRY_RADIUS })
end

local function PlayBlockImpact(inst)
    local fx = SpawnPrefab("kiritzuka_hit_fx_impact")
    if fx ~= nil then
        local x, _, z = inst.Transform:GetWorldPosition()
        fx.Transform:SetPosition(x, 1, z)
    end
    inst.SoundEmitter:PlaySound("dontstarve/wilson/hit")
end

-- A swing still winding up lands first.
local function IsWindingUpSwing(sg)
    return sg.currentstate.name == ATTACK_STATE and sg:HasStateTag("abouttoattack")
end

-- The states that even a native hit leaves alone.
local function IsPastInterrupting(sg)
    return sg:HasAnyStateTag("nointerrupt", "transform", "dismounting", "drowning", "falling", "electrocute", "shell")
end

-- Called all through a pounce: once she has seen it coming, where it ends up at contact no longer matters.
local function ReadPounce(inst, pouncer)
    local x, _, z = pouncer.Transform:GetWorldPosition()
    if CanGuard(inst) and IsFacingPoint(inst, x, z) then
        pouncer.sg.mem.kiritzuka_pounce_reader = inst
    end
end

-- Swats back a pouncer she saw coming. A counter stance still gets its own swing.
local function RepelPounce(inst, pouncer, damage, spdamage)
    if WasParried(inst, pouncer) then
        return true
    end
    if not TryCounter(inst, pouncer, damage, spdamage) then
        ReadPounce(inst, pouncer)
        if not CanGuard(inst) or pouncer.sg.mem.kiritzuka_pounce_reader ~= inst then
            return false
        end
        PlayBlockImpact(inst)
        if not IsWindingUpSwing(inst.sg) and not IsPastInterrupting(inst.sg) then
            inst.sg:GoToState(POUNCE_SWAT_STATE, pouncer)
        end
        local tuning = TUNING.KIRITZUKA_POUNCE_REPEL
        pouncer:PushEventImmediate("knockback", {
            knocker = inst,
            radius = tuning.RADIUS,
            strengthmult = tuning.STRENGTH,
            kiritzuka_repel = true,
        })
    end
    MarkParried(inst, pouncer)
    return true
end

-- Stops the hit and shows the guard, whatever the player is doing.
local function BlockHit(inst, attacker)
    PlayBlockImpact(inst)
    local sg = inst.sg
    if IsWindingUpSwing(sg) then
        sg.statemem.block_attacker = attacker
    elseif not IsPastInterrupting(sg) then
        PlayBlockGuard(inst, attacker)
    end
end

local function ResolvePendingHits(inst)
    local hits = inst.kiritzuka_pending_hits
    inst.kiritzuka_pending_hits = nil
    inst.kiritzuka_resolving_hit = true
    for _, hit in ipairs(hits) do
        if hit.attacker:IsValid() then
            inst.components.combat:GetAttacked_Internal(hit.attacker, hit.damage, hit.weapon, hit.stimuli, hit.spdamage, hit.from_doattack)
        end
    end
    inst.kiritzuka_resolving_hit = nil
end

-- Damage lands before its knockback event says it was a knockback attack, so hits taken
-- facing the attacker wait out the tick. A knockback in that time takes the hit back.
local function InterceptHit(inst, attacker, damage, weapon, stimuli, spdamage, from_doattack)
    if inst.kiritzuka_resolving_hit or attacker == nil or attacker == inst or attacker.Transform == nil then
        return false
    end
    if WasParried(inst, attacker) then
        return true
    end
    if POUNCERS[attacker.prefab] then
        -- On the head its bites come from her own position, so there is no front to stop them from.
        return not attacker.components.equippable:IsEquipped() and RepelPounce(inst, attacker, damage, spdamage)
    end
    if TryCounter(inst, attacker, damage, spdamage) then
        return true
    end
    if attacker.prefab == BEAM_PREFAB then
        return ParryBeam(inst, attacker)
    elseif ROCK_MASTERS[attacker.prefab] then
        -- Mid-skill the retreat is refused, but with the setting on the hit still gets stopped below.
        if ParryRockMaster(inst, attacker) then
            return true
        elseif not TUNING.KIRITZUKA_PARRY_ALL then
            return false
        end
    end
    local x, _, z = attacker.Transform:GetWorldPosition()
    if attacker.sg ~= nil and attacker.sg:HasStateTag("supernovaburning") then
        return ParrySustained(inst, x, z)
    end
    if TUNING.KIRITZUKA_PARRY_ALL then
        local guard_x, guard_z = GetGuardPoint(attacker)
        if not CanGuard(inst) or not IsFacingPoint(inst, guard_x, guard_z) then
            return false
        end
        BlockHit(inst, attacker)
        return true
    end
    if not CanParryFrom(inst, x, z) then
        return false
    end
    if inst.kiritzuka_pending_hits == nil then
        inst.kiritzuka_pending_hits = {}
        inst:DoTaskInTime(0, ResolvePendingHits)
    end
    table.insert(inst.kiritzuka_pending_hits, {
        attacker = attacker, damage = damage, weapon = weapon, stimuli = stimuli,
        spdamage = spdamage, from_doattack = from_doattack,
    })
    return true
end

-- Misses build toward the next crit, so a long dry streak cannot last.
local function RollCrit(inst, guaranteed)
    local tuning = TUNING.KIRITZUKA_CRIT
    local stage = inst.components.momentum ~= nil and inst.components.momentum:GetStage() or 1
    local bonus = inst.kiritzuka_crit_bonus or 0
    if guaranteed or math.random() < tuning.CHANCE[stage] + bonus then
        inst.kiritzuka_crit_bonus = 0
        return tuning.MULTIPLIER[stage]
    end
    inst.kiritzuka_crit_bonus = bonus + tuning.CHANCE_STEP
    return 1
end

local function GetArmorBreakMult(inst, target)
    local armor_break = inst.kiritzuka_armor_break
    if armor_break == nil or armor_break.target ~= target then
        return 1
    end
    local tuning = TUNING.KIRITZUKA_ARMOR_BREAK
    if GetTime() - armor_break.time > tuning.WINDOW then
        inst.kiritzuka_armor_break = nil
        return 1
    end
    return 1 + armor_break.stacks * tuning.STEP
end

-- Hitting something new starts over; each landed hit on the same target adds a stack.
local function AddArmorBreak(inst, target)
    local tuning = TUNING.KIRITZUKA_ARMOR_BREAK
    if GetArmorBreakMult(inst, target) == 1 and
        (inst.kiritzuka_armor_break == nil or inst.kiritzuka_armor_break.target ~= target) then
        inst.kiritzuka_armor_break = { target = target, stacks = 0 }
    end
    local armor_break = inst.kiritzuka_armor_break
    armor_break.time = GetTime()
    if armor_break.stacks < tuning.MAX_STACKS then
        armor_break.stacks = armor_break.stacks + 1
        return armor_break.stacks == tuning.MAX_STACKS
    end
    return false
end

-- Runs once per attack from Combat:CalcDamage, ahead of the planar multiplier below.
local function GetAttackDamageMult(inst, target)
    local statemem = inst.sg ~= nil and inst.sg.statemem or nil
    local crit = RollCrit(inst, statemem ~= nil and statemem.signature_crit)
    inst.kiritzuka_crit_hit = crit > 1
    inst.kiritzuka_attack_mult = crit * GetArmorBreakMult(inst, target)
    return inst.kiritzuka_attack_mult
end

local function GetAttackSpDamageMult(inst)
    return inst.kiritzuka_attack_mult or 1
end

-- toward is how far along the line from player to target the fx appear.
local function SpawnHitFx(inst, target, count, toward)
    local x, _, z = inst.Transform:GetWorldPosition()
    local target_x, _, target_z = target.Transform:GetWorldPosition()
    for _ = 1, count do
        local fx = SpawnPrefab(HIT_FX[math.random(#HIT_FX)])
        if fx ~= nil then
            fx.Transform:SetPosition(x + (target_x - x) * toward, 1, z + (target_z - z) * toward)
        end
    end
end

local function OnHitOther(inst, data)
    local crit = inst.kiritzuka_crit_hit
    inst.kiritzuka_crit_hit = nil
    local target = data ~= nil and data.target or nil
    if target == nil or not target:IsValid() or target.Transform == nil then
        return
    end
    if (data.damageresolved or 0) > 0 and HasExclusiveWeapon(inst) and AddArmorBreak(inst, target) then
        -- One sharp burst on the target marks that the armor is fully broken.
        local fx = SpawnPrefab("kiritzuka_hit_fx_impact")
        if fx ~= nil then
            local x, _, z = target.Transform:GetWorldPosition()
            fx.Transform:SetPosition(x, 1, z)
        end
    end
    if crit then
        SpawnHitFx(inst, target, TUNING.KIRITZUKA_CRIT.FX_COUNT, TUNING.KIRITZUKA_CRIT.FX_TOWARD)
        ShakeAllCameras(CAMERASHAKE.VERTICAL, .2, .02, .2, inst, 20)
        if (data.damageresolved or 0) > 0 and inst.components.momentum ~= nil then
            inst.components.momentum:Gain(TUNING.KIRITZUKA_CRIT.MOMENTUM_GAIN)
        end
    elseif inst.sg ~= nil and (inst.sg.statemem.signature_step ~= nil or inst.sg.statemem.dash_stage ~= nil
        or inst.sg.statemem.homerun) then
        SpawnHitFx(inst, target, 1, 0.5)
    end
end

local function CanDestroy(target)
    local workable = target.components.workable
    if workable == nil or not workable:CanBeWorked() then
        return false
    end
    local action = workable:GetWorkAction()
    if action == nil or not DESTROY_ACTIONS[action.id] then
        return false
    end
    -- Rooted fights stay fights, and digging up a spawner would end what it spawns for good.
    if action.id == "DIG" and (target.components.spawner ~= nil or target.components.childspawner ~= nil) then
        return false
    end
    -- Felling a tree is enough: its stump stays for the player to dig up.
    if target:HasTag("stump") then
        return false
    end
    -- Anything with health is a fight; a Poison Birchnut has none, so work is the only way to end it.
    return target.components.combat == nil or target.components.health == nil or target:HasTag("wall")
end

local function DestroyInArea(inst, x, z, radius)
    if not inst.kiritzuka_destruction then
        return
    end
    for _, target in ipairs(TheSim:FindEntities(x, 0, z, radius, nil, DESTROY_CANT_TAGS, DESTROY_ONEOF_TAGS)) do
        if target ~= inst and CanDestroy(target) then
            target.components.workable:Destroy(inst)
        end
    end
end

-- Off by default and on each load: this would otherwise flatten a base by accident.
local function ToggleDestruction(inst)
    inst.kiritzuka_destruction = not inst.kiritzuka_destruction or nil
    SaySlamLine(inst, inst.kiritzuka_destruction and STRINGS.SKILL.KIRITZUKA_DESTROY_ON or STRINGS.SKILL.KIRITZUKA_DESTROY_OFF)
    return true
end

-- Mega Blight only takes damage while struggling; the slam breaks through at any time.
-- Its body shares one health pool, so each hit counts once however many segments it covers.
local function DamageSlamBlight(inst, controller, segment, damage)
    local combat, health = controller.components.combat, controller.components.health
    local tough, invincible = combat.tough, health.invincible
    combat.tough = false
    health:SetInvincible(false)
    combat.redirected_from = segment
    if controller.head ~= nil then
        controller.head:PushEvent("attacked")
    end
    combat:GetAttacked(inst, damage)
    combat.redirected_from = nil
    if controller:IsValid() and not health:IsDead() then
        combat.tough = tough
        health:SetInvincible(invincible)
    end
end

-- Each slam hit rolls once for everything it strikes; the small bursts do not roll at all.
local function DamageSlamArea(inst, pos, damage, radius, can_crit)
    DestroyInArea(inst, pos.x, pos.z, radius)
    local mult = can_crit and RollCrit(inst) or 1
    local crit = mult > 1
    local blights = {}
    for _, victim in ipairs(TheSim:FindEntities(pos.x, 0, pos.z, radius, SLAM_TARGET_TAGS, SLAM_EXCLUDE_TAGS)) do
        if CanSlamHit(inst, victim) then
            local controller = victim.controller
            local hit_damage = damage * mult * GetArmorBreakMult(inst, victim)
            if controller ~= nil and controller:HasTag(SLAM_BLIGHT_TAG) then
                if not blights[controller] and controller:IsValid() and not controller.components.health:IsDead() then
                    blights[controller] = true
                    DamageSlamBlight(inst, controller, victim, hit_damage)
                end
            else
                victim.components.combat:GetAttacked(inst, hit_damage)
            end
            if crit and victim:IsValid() then
                SpawnHitFx(inst, victim, TUNING.KIRITZUKA_CRIT.FX_COUNT, TUNING.KIRITZUKA_CRIT.FX_TOWARD)
            end
        end
    end
    if crit and inst.components.momentum ~= nil then
        inst.components.momentum:Gain(TUNING.KIRITZUKA_CRIT.MOMENTUM_GAIN)
    end
end

local function DoSlamBurst(inst, pos, damage)
    SpawnSlamRing(inst, pos, SLAM_BURST_RING_SCALE)
    SpawnSlamDustRing(inst, pos, SLAM_BURST_DUST_RADIUS, SLAM_BURST_DUST_COUNT)
    DamageSlamArea(inst, pos, damage, TUNING.KIRITZUKA_BOSS_SLAM.BURST_RADIUS)
end

local function SpawnSlamBursts(inst, center, damage, count)
    local tuning = TUNING.KIRITZUKA_BOSS_SLAM
    for _ = 1, count do
        local theta = math.random() * 2 * math.pi
        -- The root spreads them evenly over the area rather than bunching at the middle.
        local distance = tuning.RADIUS * math.sqrt(math.random())
        local x, z = center.x + distance * math.cos(theta), center.z + distance * math.sin(theta)
        if TheWorld.Map:IsPassableAtPoint(x, 0, z) then
            inst:DoTaskInTime(math.random() * tuning.BURST_SPREAD, DoSlamBurst,
                { x = x, y = 0, z = z }, damage * tuning.BURST_DAMAGE_MULT)
        end
    end
end

local function DoSlamImpact(inst, landing, target)
    local pos = GetSlamImpactPoint(inst, landing, target)
    SpawnSlamCrater(inst, pos)
    local fx = SpawnPrefab("superjump_fx")
    if fx ~= nil then
        local dx, dz = pos.x - landing.x, pos.z - landing.z
        -- The player faces the target here, so this distance runs along the line between them.
        fx:SetTarget(inst, math.sqrt(dx * dx + dz * dz))
    end
    SpawnSlamShockwave(inst, pos, SLAM_IMPACT_RINGS, SLAM_IMPACT_DUST)
    -- Harder and wider-reaching than Bearger's own pound.
    ShakeAllCameras(CAMERASHAKE.VERTICAL, .9, .03, 1.6, inst, 40)
    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/groundpound")
    local tuning = TUNING.KIRITZUKA_BOSS_SLAM
    local damage = tuning.DAMAGE / tuning.HITS
    local momentum = inst.components.momentum
    -- The stage bonus is read before the cost is paid; an empty gauge only forfeits the bonus.
    if momentum ~= nil then
        local bonus = momentum:GetEffect("slam_damage")
        if momentum:Spend(tuning.MOMENTUM_COST or 0) then
            damage = damage * bonus
        end
    end
    DamageSlamArea(inst, pos, damage, tuning.RADIUS, true)
    SpawnSlamBursts(inst, pos, damage, tuning.IMPACT_BURSTS)
    return pos, damage
end

-- The follow-up hits strike the same spot for the damage the impact settled on.
local function DoSlamHit(inst, pos, damage)
    SpawnSlamShockwave(inst, pos, SLAM_HIT_RINGS, SLAM_HIT_DUST)
    ShakeAllCameras(CAMERASHAKE.VERTICAL, .35, .02, .6, inst, 30)
    inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")
    local tuning = TUNING.KIRITZUKA_BOSS_SLAM
    DamageSlamArea(inst, pos, damage, tuning.RADIUS, true)
    SpawnSlamBursts(inst, pos, damage, tuning.HIT_BURSTS)
end

local function TryReleaseDash(inst, target)
    DisarmSkill(inst)
    if not HasExclusiveWeapon(inst) then
        SaySlamLine(inst, STRINGS.SKILL.KIRITZUKA_WEAPON_REFUSE)
        return false
    end
    if CanCarryOutSlam(inst) and not IsOnCooldown(inst, DASH_COOLDOWN)
        and CanSlamHit(inst, target) and IsSlamPointSafe(inst, inst:GetPosition()) then
        return true
    end
    SaySlamLine(inst, STRINGS.SKILL.REFUSE_RELEASE)
    return false
end

local function CanDashHit(inst, target)
    return CanSlamHit(inst, target)
end

local function StartDashCooldown(inst)
    StartSkillCooldown(inst, DASH_COOLDOWN, TUNING.KIRITZUKA_DASH.COOLDOWN)
end

-- Direction from the target to the player, which the first line runs along.
local function GetDashAngle(inst, target)
    local x, _, z = target.Transform:GetWorldPosition()
    local px, _, pz = inst.Transform:GetWorldPosition()
    return math.atan2(pz - z, px - x)
end

-- A point out from the target on the given side, pulled in if the ground further out is unsafe.
-- A target out on the water has no such point: the lines run through it, and the player would drown.
local function GetDashPoint(inst, target, angle)
    local pos = target:GetPosition()
    pos.y = 0
    if not IsSlamPointSafe(inst, pos) then
        return nil
    end
    local x, z = pos.x, pos.z
    local dx, dz = math.cos(angle), math.sin(angle)
    local distance = 0
    for d = 0.5, TUNING.KIRITZUKA_DASH.RANGE + target:GetPhysicsRadius(0), 0.5 do
        pos.x, pos.z = x + dx * d, z + dz * d
        if not IsSlamPointSafe(inst, pos) then
            break
        end
        distance = d
    end
    pos.x, pos.z = x + dx * distance, z + dz * distance
    return pos
end

local function SpawnDashFx(inst, prefab, x, z)
    local fx = SpawnPrefab(prefab)
    if fx ~= nil then
        fx.AnimState:SetBuild(DASH_BUILD)
        fx.Transform:SetPosition(x, 0, z)
        fx.Transform:SetRotation(inst.Transform:GetRotation())
    end
    return fx
end

local DASH_AFTER_IMAGE = {
    anims = {"lunge_pst"},
    -- Outlasts the 4 frame flight for late clients, but ends before the next stage's blink at frame 8.
    duration = 6 * FRAMES,
    spacing = 0.7,
    lifetime = 0.45,
    peak_alpha = 0.7,
    colour = {0.1, 0.03, 0.15},
    -- One late client update can cover a whole line.
    max_jump = 40,
}

local function StartDashFx(inst)
    local x, _, z = inst.Transform:GetWorldPosition()
    local fx = SpawnDashFx(inst, "rocky_dash_fx", x, z)
    if fx ~= nil then
        fx.target:set(inst)
    end
    inst.net_dash_after_image:push()
    AfterImageUtil.Start(inst, DASH_AFTER_IMAGE)
end

local function OnDashAfterImage(inst)
    AfterImageUtil.Start(inst, DASH_AFTER_IMAGE)
end

local function SpawnDashBlink(inst)
    local fx = SpawnPrefab("kiritzuka_hit_fx_puff")
    if fx ~= nil then
        local x, _, z = inst.Transform:GetWorldPosition()
        fx.Transform:SetPosition(x, 0, z)
    end
end

-- Open water throws up a splash where land or a deck would raise dust.
local function SpawnDashTrail(inst, x, z)
    local map = TheWorld.Map
    local at_sea = map:IsOceanTileAtPoint(x, 0, z) and map:GetPlatformAtPoint(x, z) == nil
    local fx = SpawnPrefab(at_sea and "splash" or "kiritzuka_slam_dust_fx")
    if fx ~= nil then
        fx.Transform:SetPosition(x, 0, z)
    end
    return fx, at_sea
end

-- Called as the dash moves, so everything along the line takes its hit as the player passes it.
local function SweepDash(inst, from, to, stage, hit)
    local tuning = TUNING.KIRITZUKA_DASH
    local dx, dz = to.x - from.x, to.z - from.z
    local lensq = dx * dx + dz * dz
    local mid_x, mid_z = (from.x + to.x) / 2, (from.z + to.z) / 2
    local radius = math.sqrt(lensq) / 2 + tuning.WIDTH + 2
    if inst.kiritzuka_destruction then
        for _, target in ipairs(TheSim:FindEntities(mid_x, 0, mid_z, radius, nil, DESTROY_CANT_TAGS, DESTROY_ONEOF_TAGS)) do
            if target ~= inst and CanDestroy(target) then
                local x, _, z = target.Transform:GetWorldPosition()
                local t = lensq > 0 and math.clamp(((x - from.x) * dx + (z - from.z) * dz) / lensq, 0, 1) or 0
                local near_x, near_z = from.x + dx * t - x, from.z + dz * t - z
                local reach = tuning.WIDTH + target:GetPhysicsRadius(0)
                if near_x * near_x + near_z * near_z <= reach * reach then
                    target.components.workable:Destroy(inst)
                end
            end
        end
    end
    local combat = inst.components.combat
    combat.ignorehitrange = true
    for _, target in ipairs(TheSim:FindEntities(mid_x, 0, mid_z, radius, SLAM_TARGET_TAGS, SLAM_EXCLUDE_TAGS)) do
        if not hit[target] and CanSlamHit(inst, target) then
            local x, _, z = target.Transform:GetWorldPosition()
            local t = lensq > 0 and math.clamp(((x - from.x) * dx + (z - from.z) * dz) / lensq, 0, 1) or 0
            local near_x, near_z = from.x + dx * t - x, from.z + dz * t - z
            local reach = tuning.WIDTH + target:GetPhysicsRadius(0)
            if near_x * near_x + near_z * near_z <= reach * reach then
                hit[target] = true
                combat:DoAttack(target, nil, nil, nil, tuning.DAMAGE_MULT[stage])
            end
        end
    end
    combat.ignorehitrange = false
    SpawnDashTrail(inst, to.x, to.z)
end

-- Lands the last stretch; the locked target is struck whatever it did mid-dash.
local function FinishDash(inst, from, to, stage, locked, hit)
    if locked:IsValid() then
        local x, _, z = locked.Transform:GetWorldPosition()
        SpawnDashFx(inst, "rocky_snip_fx", x, z)
    else
        SpawnDashFx(inst, "rocky_snip_fx", to.x, to.z)
    end
    SweepDash(inst, from, to, stage, hit)
    if not hit[locked] and CanSlamHit(inst, locked) then
        hit[locked] = true
        local combat = inst.components.combat
        combat.ignorehitrange = true
        combat:DoAttack(locked, nil, nil, nil, TUNING.KIRITZUKA_DASH.DAMAGE_MULT[stage])
        combat.ignorehitrange = false
    end
end

-- At sea the three crossing lines would end in the water, so the dash goes out and comes home instead.
local function IsDashAtSea(inst, target)
    return inst:GetCurrentPlatform() ~= nil or not IsSlamPointSafe(inst, target:GetPosition())
end

-- Where to come back to, kept relative to the boat since it keeps sailing during the dash.
local function GetDashHome(inst)
    local x, _, z = inst.Transform:GetWorldPosition()
    local platform = inst:GetCurrentPlatform()
    if platform == nil then
        return { x = x, z = z }
    end
    local px, _, pz = platform.Transform:GetWorldPosition()
    return { x = x, z = z, platform = platform, dx = x - px, dz = z - pz }
end

local function ResolveDashHome(inst, home)
    if home.platform ~= nil and home.platform:IsValid() then
        local px, _, pz = home.platform.Transform:GetWorldPosition()
        return { x = px + home.dx, y = 0, z = pz + home.dz }
    end
    return { x = home.x, y = 0, z = home.z }
end

-- Out past the target; open water is fine here because the player only passes through it in flight.
local function GetDashTurn(inst, target)
    local x, _, z = target.Transform:GetWorldPosition()
    local px, _, pz = inst.Transform:GetWorldPosition()
    local dx, dz = x - px, z - pz
    local length = math.sqrt(dx * dx + dz * dz)
    local past = target:GetPhysicsRadius(0) + TUNING.KIRITZUKA_DASH.SEA_RANGE
    if length <= 0 then
        return { x = x, y = 0, z = z }
    end
    return { x = x + dx / length * past, y = 0, z = z + dz / length * past }
end

-- The turn and the landing throw up more than the trail does.
local function SpawnDashSplash(inst, x, z)
    local fx, at_sea = SpawnDashTrail(inst, x, z)
    if fx ~= nil and at_sea then
        fx.Transform:SetScale(1.5, 1.5, 1.5)
    end
end

local function TryReleaseFlurry(inst, target)
    DisarmSkill(inst)
    if not HasExclusiveWeapon(inst) then
        SaySlamLine(inst, STRINGS.SKILL.KIRITZUKA_WEAPON_REFUSE)
        return false
    end
    if CanCarryOutSlam(inst) and not IsOnCooldown(inst, FLURRY_COOLDOWN) and CanSlamHit(inst, target) then
        StartSkillCooldown(inst, FLURRY_COOLDOWN, TUNING.KIRITZUKA_FLURRY.COOLDOWN)
        return true
    end
    SaySlamLine(inst, STRINGS.SKILL.REFUSE_RELEASE)
    return false
end

-- Alternates sides of the line to her, so the images spread out instead of stacking on one spot.
-- Returns where it stood: she comes back into view wherever the last one was.
local function SpawnFlurryImage(inst, target, hit)
    local fx = SpawnPrefab(FLURRY_IMAGE)
    if fx == nil then
        return
    end
    local tuning = TUNING.KIRITZUKA_FLURRY
    local x, _, z = target.Transform:GetWorldPosition()
    local pos = inst:GetPosition()
    local side = hit % 2 == 0 and 1 or -1
    local angle = math.atan2(pos.z - z, pos.x - x) + side * math.rad(tuning.IMAGE_ARC) * (0.25 + 0.75 * math.random())
    local distance = target:GetPhysicsRadius(0) + tuning.IMAGE_DISTANCE
    pos.x, pos.y, pos.z = x + math.cos(angle) * distance, 0, z + math.sin(angle) * distance
    fx.Transform:SetPosition(pos.x, 0, pos.z)
    fx:ForceFacePoint(x, 0, z)
    fx:Setup(inst, inst.components.combat:GetWeapon(), FLURRY_IMAGE_ANIMS[hit % #FLURRY_IMAGE_ANIMS + 1])
    return pos
end

-- The first hit is her own swing; every one after it is an image.
-- False once there is nothing left to hit, or nothing left to hit it with.
local function DoFlurryHit(inst, target, hit)
    if not HasExclusiveWeapon(inst) or not CanSlamHit(inst, target) then
        return false
    end
    if hit > 1 then
        inst.sg.statemem.landing = SpawnFlurryImage(inst, target, hit) or inst.sg.statemem.landing
    end
    inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")
    local combat = inst.components.combat
    combat.ignorehitrange = true
    combat:DoAttack(target, nil, nil, nil, TUNING.KIRITZUKA_FLURRY.DAMAGE_MULT)
    combat.ignorehitrange = false
    return true
end

local function StartHomeRun(inst)
    if inst.sg == nil or inst.sg:HasStateTag("busy")
        or inst.sg:HasStateTag("dead") or inst.sg:HasStateTag("sleeping")
        or inst.sg:HasStateTag("frozen") or inst.sg:HasStateTag("jumping")
        or not CanCarryOutSlam(inst) then
        return false
    end
    if IsOnCooldown(inst, HOMERUN_COOLDOWN) then
        SaySlamLine(inst, STRINGS.SKILL.KIRITZUKA_HOMERUN_COOLDOWN)
        return false
    end
    if not HasExclusiveWeapon(inst) then
        SaySlamLine(inst, STRINGS.SKILL.KIRITZUKA_WEAPON_REFUSE)
        return false
    end
    DisarmSkill(inst)
    inst.sg:GoToState(HOMERUN_STATE)
    return true
end

-- Only swings out of a charge in progress; a release after it was interrupted does nothing.
local function ReleaseHomeRun(inst)
    if inst.sg == nil or inst.sg.currentstate.name ~= HOMERUN_STATE then
        return false
    end
    local tuning = TUNING.KIRITZUKA_HOMERUN
    local charge = math.clamp((GetTime() - inst.sg.statemem.charge_start) / tuning.CHARGE_TIME, 0, 1)
    StartSkillCooldown(inst, HOMERUN_COOLDOWN, tuning.COOLDOWN)
    if charge >= 1 then
        SaySlamLine(inst, STRINGS.SKILL.KIRITZUKA_HOMERUN_FULL)
    end
    inst.sg:GoToState(HOMERUN_SWING_STATE, { charge = charge })
    return true
end

local function GetHomeRunScale(range, charge)
    return range[1] + (range[2] - range[1]) * charge
end

local function OnKnockSlide(target, slide)
    if not target:IsValid() or target:IsInLimbo() or target.components.health:IsDead() or slide.left < 0.05 then
        slide.task:Cancel()
        return
    end
    local step = slide.left * KNOCK_STEP
    local x, y, z = target.Transform:GetWorldPosition()
    x, z = x + slide.dx * step, z + slide.dz * step
    -- Land creatures stop at the edge rather than get knocked into the sea.
    if not target:HasTag("flying") and not TheWorld.Map:IsPassableAtPoint(x, 0, z) then
        slide.task:Cancel()
        return
    end
    target.Physics:Teleport(x, y, z)
    slide.left = slide.left - step
end

local function KnockBack(inst, target, distance)
    if target.Physics == nil or target.components.locomotor == nil then
        return
    end
    local scale = TUNING.KIRITZUKA_HOMERUN.KNOCK_SCALE
    if target:HasAnyTag("epic", "boss") then
        distance = distance * scale.epic
    elseif target:HasTag("largecreature") then
        distance = distance * scale.large
    end
    local x, _, z = target.Transform:GetWorldPosition()
    local px, _, pz = inst.Transform:GetWorldPosition()
    local dx, dz = x - px, z - pz
    local length = math.sqrt(dx * dx + dz * dz)
    if length <= 0 then
        local theta = inst.Transform:GetRotation() * DEGREES
        dx, dz, length = math.cos(theta), -math.sin(theta), 1
    end
    local slide = { dx = dx / length, dz = dz / length, left = distance }
    slide.task = target:DoPeriodicTask(0, OnKnockSlide, nil, slide)
end

local function DoHomeRunHit(inst, charge)
    local tuning = TUNING.KIRITZUKA_HOMERUN
    local x, _, z = inst.Transform:GetWorldPosition()
    local rot = inst.Transform:GetRotation()
    local mult = GetHomeRunScale(tuning.DAMAGE_MULT, charge)
    local distance = GetHomeRunScale(tuning.KNOCK_DISTANCE, charge)
    local combat = inst.components.combat
    combat.ignorehitrange = true
    for _, target in ipairs(TheSim:FindEntities(x, 0, z, tuning.RANGE + 4, SLAM_TARGET_TAGS, SLAM_EXCLUDE_TAGS)) do
        if CanSlamHit(inst, target) then
            local tx, _, tz = target.Transform:GetWorldPosition()
            local reach = tuning.RANGE + target:GetPhysicsRadius(0)
            local dsq = (tx - x) * (tx - x) + (tz - z) * (tz - z)
            if dsq <= reach * reach and DiffAngle(rot, inst:GetAngleToPoint(tx, 0, tz)) <= tuning.ARC / 2 then
                combat:DoAttack(target, nil, nil, nil, mult)
                if CanSlamHit(inst, target) then
                    KnockBack(inst, target, distance)
                end
                if charge >= 1 then
                    SpawnDashFx(inst, "rocky_snip_fx", tx, tz)
                end
            end
        end
    end
    combat.ignorehitrange = false
    if charge >= 1 then
        SpawnSlamRing(inst, { x = x, y = 0, z = z }, 0.6)
        ShakeAllCameras(CAMERASHAKE.VERTICAL, .4, .02, .6, inst, 30)
    end
end

local function StartCounter(inst)
    -- A second press drops a stance still open. Only a catch or a whiff starts the cooldown.
    if inst.sg ~= nil and inst.sg.currentstate.name == COUNTER_STATE and not inst.sg.statemem.whiffed then
        inst.sg:GoToState("idle", true)
        return true
    end
    if inst.sg == nil or inst.sg:HasStateTag("busy")
        or inst.sg:HasStateTag("dead") or inst.sg:HasStateTag("sleeping")
        or inst.sg:HasStateTag("frozen") or inst.sg:HasStateTag("jumping")
        or not CanCarryOutSlam(inst) then
        return false
    end
    if IsOnCooldown(inst, COUNTER_COOLDOWN) then
        SaySlamLine(inst, STRINGS.SKILL.KIRITZUKA_COUNTER_COOLDOWN)
        return false
    end
    if not HasExclusiveWeapon(inst) then
        SaySlamLine(inst, STRINGS.SKILL.KIRITZUKA_WEAPON_REFUSE)
        return false
    end
    DisarmSkill(inst)
    inst.sg:GoToState(COUNTER_STATE)
    return true
end

local function DoCounterHit(inst, target, blocked)
    if not CanSlamHit(inst, target) then
        return
    end
    local tuning = TUNING.KIRITZUKA_COUNTER
    local x, _, z = target.Transform:GetWorldPosition()
    SpawnDashFx(inst, "rocky_snip_fx", x, z)
    local combat = inst.components.combat
    combat.ignorehitrange = true
    combat:DoAttack(target, nil, nil, nil, tuning.DAMAGE_MULT)
    combat.ignorehitrange = false
    if blocked > 0 and CanSlamHit(inst, target) then
        target.components.combat:GetAttacked(inst, blocked * tuning.BLOCKED_DAMAGE_MULT)
    end
end

local function ClearSpatOut(inst)
    inst.was_spat_out_by_worm = nil
end

-- The part of the body nearest to where she came out, if any of it is above ground.
local function FindNearestWormSegment(worm, x, z)
    local nearest_chunk, nearest_index
    local nearest_distsq = math.huge
    for _, chunk in ipairs(worm.chunks or {}) do
        for index, segment in ipairs(chunk.segments or {}) do
            if segment:IsValid() then
                local sx, _, sz = segment.Transform:GetWorldPosition()
                local distsq = (sx - x) * (sx - x) + (sz - z) * (sz - z)
                if distsq < nearest_distsq then
                    nearest_chunk, nearest_index, nearest_distsq = chunk, index, distsq
                end
            end
        end
    end
    return nearest_chunk, nearest_index
end

-- The body bursts where she tears through it, with the squeeze the worm itself plays when hit.
local function BurstWormBody(inst, worm)
    local x, _, z = inst.Transform:GetWorldPosition()
    local chunk, index = FindNearestWormSegment(worm, x, z)
    local blast_x, blast_y, blast_z = x, 2, z
    if chunk ~= nil then
        chunk.hit = 1
        local segment = chunk.segments[index]
        blast_x, _, blast_z = segment.Transform:GetWorldPosition()
        -- Segments arc out of the ground, so the blast sits on the body rather than at its feet.
        blast_y = math.sin((segment.percentdist or 0.5) * math.pi) * 3.5
    end
    local fx = SpawnPrefab("explode_small")
    if fx ~= nil then
        fx.Transform:SetPosition(blast_x, blast_y, blast_z)
        fx.Transform:SetScale(WORM_BURST_SCALE, WORM_BURST_SCALE, WORM_BURST_SCALE)
    end
    SpawnSlamDustRing(inst, { x = x, y = 0, z = z }, 1.5, 6)
end

-- Leaves the worm the way its own spit does, from wherever it has carried her.
local function BreakOutOfWorm(inst, worm)
    if not inst.sg:HasStateTag("devoured") or inst.sg.statemem.attacker ~= worm or not worm:IsValid() then
        return
    end
    -- The worm's states are already committed to what they swallowed and cannot take the list
    -- going away mid-meal, so she leaves the same filler the native code uses for eaten creatures.
    if worm.devoured ~= nil then
        for i, swallowed in ipairs(worm.devoured) do
            if swallowed == inst then
                worm.devoured[i] = { blankfiller = true }
            end
        end
    end

    local tuning = TUNING.KIRITZUKA_WORM_BREAK
    local radius = inst:GetPhysicsRadius(0) * 2 + 1
    local pos = inst:GetPosition()
    local leap_offset = math.random() < tuning.JUMP_CHANCE
        and FindWalkableOffset(pos, math.random() * TWOPI, tuning.JUMP_DISTANCE, 16, false, true) or nil
    local _, angle = FindWalkableOffset(pos, math.random() * TWOPI, radius + 2, 16, false, true)
    if leap_offset ~= nil then
        inst.sg:GoToState(WORM_LEAP_STATE, { x = pos.x + leap_offset.x, z = pos.z + leap_offset.z })
    else
        inst:PushEventImmediate("spitout", {
            spitter = inst,
            starthigh = true,
            radius = radius,
            -- Harder than the worm's own spit: she is breaking out, not being let go.
            strengthmult = TUNING.KIRITZUKA_WORM_BREAK.LAUNCH,
            rot = angle ~= nil and angle * RADIANS or math.random() * 360,
        })
    end
    -- Native leniency: the worm will not swallow what it has only just lost.
    inst.was_spat_out_by_worm = inst:DoTaskInTime(2, ClearSpatOut)

    local x, _, z = inst.Transform:GetWorldPosition()
    BurstWormBody(inst, worm)
    SpawnSlamRing(inst, { x = x, y = 0, z = z }, 0.8)
    ShakeAllCameras(CAMERASHAKE.VERTICAL, .7, .03, 1, inst, 30)
    if worm.components.health ~= nil and not worm.components.health:IsDead() then
        worm.components.combat:GetAttacked(inst, TUNING.KIRITZUKA_WORM_BREAK.DAMAGE)
    end
    -- Waits for the landing, since talking is shut off until she is properly out.
    inst:DoTaskInTime(WORM_BREAK_LINE_DELAY, SaySlamLine, STRINGS.SKILL.KIRITZUKA_WORM_DISGUST)
end

local function OnDevoured(inst, data)
    local worm = data ~= nil and data.attacker or nil
    if worm ~= nil and worm.prefab ~= nil and worm.prefab:find("worm_boss", 1, true) == 1 then
        inst:DoTaskInTime(TUNING.KIRITZUKA_WORM_BREAK.DELAY, BreakOutOfWorm, worm)
    end
end

local function OnAttacked(inst, data)
    if data == nil
        or data.redirected ~= nil
        or (data.damageresolved or 0) <= 0
        or inst.components.health:IsDead()
        or inst:HasTag("playerghost")
        or inst.components.talker == nil then
        return
    end

    local damage = data.damageresolved
    local severity = damage < 10 and 1 or damage < 25 and 2 or 3
    local now = GetTime()
    if now < (inst._hurt_speech_time or 0)
        and severity <= (inst._hurt_speech_severity or 0) then
        return
    end

    local speech = GetString(inst, "ANNOUNCE_HURT", HURT_SPEECH_KEYS[severity], true)
    if speech ~= nil then
        inst._hurt_speech_time = now + HURT_SPEECH_COOLDOWN
        inst._hurt_speech_severity = severity
        inst.components.talker:Say(speech, 2, true)
        inst.components.combat:ResetBattleCryCooldown(now)
    end
end

local function UpdateLowHealthDamage(inst)
    local health = inst.components.health
    if not health:IsDead() and not inst:HasTag("playerghost") then
        local missing_health = 1 - math.clamp(health:GetPercent(), 0, 1)
        inst.components.momentum:SetSource("low_health", { damage = 1 + missing_health * TUNING.KIRITZUKA_LOW_HEALTH_DAMAGE })
    else
        inst.components.momentum:SetSource("low_health", nil)
    end
end

local function OnSetOwner(inst)
    if inst ~= ThePlayer or inst.components.playerkeyhandler ~= nil then
        return
    end

    inst:AddComponent("playerkeyhandler")
    local handler = inst.components.playerkeyhandler
    -- Bindings come from Options > Controls and are re-registered when they change.
    local function AddSkillKey(bind, action)
        local held = false
        handler:AddRawKeyListener(bind, function(down)
            if not down then
                held = false
                return false
            elseif held or inst ~= ThePlayer then
                return false
            end
            held = true
            return handler:HandleKeyAction("LouisManutsawee", action)
        end)
    end

    AddSkillKey("kiritzuka_slam", "KiritzukaBossSlam")
    -- Unlike the others this one needs the key's release as well.
    local homerun_held = false
    handler:AddRawKeyListener("kiritzuka_homerun", function(down)
        if inst ~= ThePlayer or down == homerun_held then
            return false
        end
        homerun_held = down
        return handler:HandleKeyAction("LouisManutsawee", down and "KiritzukaHomeRunStart" or "KiritzukaHomeRunRelease")
    end)
    AddSkillKey("kiritzuka_destroy", "KiritzukaDestruction")
    AddSkillKey("kiritzuka_counter", "KiritzukaCounter")
    AddSkillKey("kiritzuka_dash", "KiritzukaDash")
    AddSkillKey("kiritzuka_flurry", "KiritzukaFlurry")
end

local common_postinit = function(inst)
    -- Minimap icon
    inst.MiniMapEntity:SetIcon("kiritzuka.tex")

    inst:AddTag("delinquent")
    inst:AddTag("monkeycurse_immune")

    -- Momentum gauge and stage for the client HUD.
    inst.net_momentum_value = net_byte(inst.GUID, "kiritzuka.momentum_value", "momentumdirty")
    inst.net_momentum_stage = net_tinybyte(inst.GUID, "kiritzuka.momentum_stage", "momentumdirty")
    inst.net_dash_after_image = net_event(inst.GUID, "kiritzuka.dash_after_image")
    if not TheWorld.ismastersim then
        inst:ListenForEvent("kiritzuka.dash_after_image", OnDashAfterImage)
    end
    inst:ListenForEvent("setowner", OnSetOwner)
end

local master_postinit = function(inst)
    inst.starting_inventory = start_inv[TheNet:GetServerGameMode()] or start_inv.default
    inst.soundsname = "wortox"

    inst.AnimState:SetScale(0.88, 0.9, 1)

    inst.components.health:SetMaxHealth(TUNING.KIRITZUKA_HEALTH)
    inst.components.hunger:SetMax(TUNING.KIRITZUKA_HUNGER)
    inst.components.sanity:SetMax(TUNING.KIRITZUKA_SANITY)

    if inst.components.eater ~= nil then
        inst.components.eater:SetRejectEatingTag("terriblefood")
    end

    if inst.components.foodaffinity ~= nil then
        inst.components.foodaffinity:AddPrefabAffinity("justeggs", TUNING.AFFINITY_15_CALORIES_LARGE)
        inst.components.foodaffinity:AddPrefabAffinity("icecream", TUNING.AFFINITY_15_CALORIES_MED)
        inst.components.foodaffinity:AddPrefabAffinity("californiaroll", TUNING.AFFINITY_15_CALORIES_LARGE)
        inst.components.foodaffinity:AddPrefabAffinity("unagi", TUNING.AFFINITY_15_CALORIES_LARGE)
        inst.components.foodaffinity:AddPrefabAffinity("blue_cap", TUNING.AFFINITY_15_CALORIES_SMALL)
        inst.components.foodaffinity:AddPrefabAffinity("berries", TUNING.AFFINITY_15_CALORIES_TINY)
        inst.components.foodaffinity:AddPrefabAffinity("berries_juicy", TUNING.AFFINITY_15_CALORIES_SMALL)
    end

    inst.skeleton_prefab = nil

    inst:AddComponent("enemytracker")
    inst:AddComponent("momentum")
    inst:AddComponent("dumbbelllifter")

    local get_battle_cry_string = inst.components.combat.GetBattleCryString
    function inst.components.combat:GetBattleCryString(target)
        local speech, strid, priority = get_battle_cry_string(self, target)
        -- Native lookup can return the GENERIC pool when the target has no specific entry.
        if type(speech) == "table" then
            speech = speech[math.random(#speech)]
        end
        return speech, strid, priority
    end

    inst.components.combat.customdamagemultfn = GetAttackDamageMult
    inst.components.combat.customspdamagemultfn = GetAttackSpDamageMult

    inst.OffsetTargetDefense = OffsetTargetDefense
    inst.ParryKnockback = ParryKnockback
    inst.ParrySustained = ParrySustained
    inst.InterceptHit = InterceptHit
    inst.PlayBlockGuard = PlayBlockGuard
    inst.ReadPounce = ReadPounce
    inst.RepelPounce = RepelPounce
    inst.components.health.redirect = RedirectBeamDamage

    inst.ToggleDestruction = ToggleDestruction
    inst.StartHomeRun = StartHomeRun
    inst.ReleaseHomeRun = ReleaseHomeRun
    inst.DoHomeRunHit = DoHomeRunHit
    inst.StartCounter = StartCounter
    inst.StartCounterWhiffCooldown = StartCounterWhiffCooldown
    inst.DoCounterHit = DoCounterHit
    inst.IsDashArmed = IsDashArmed
    inst.ToggleDash = ToggleDash
    inst.TryReleaseDash = TryReleaseDash
    inst.CanDashHit = CanDashHit
    inst.StartDashCooldown = StartDashCooldown
    inst.GetDashAngle = GetDashAngle
    inst.GetDashPoint = GetDashPoint
    inst.StartDashFx = StartDashFx
    inst.SpawnDashBlink = SpawnDashBlink
    inst.IsDashAtSea = IsDashAtSea
    inst.GetDashHome = GetDashHome
    inst.ResolveDashHome = ResolveDashHome
    inst.GetDashTurn = GetDashTurn
    inst.SpawnDashSplash = SpawnDashSplash
    inst.SweepDash = SweepDash
    inst.FinishDash = FinishDash
    inst.IsFlurryArmed = IsFlurryArmed
    inst.ToggleFlurry = ToggleFlurry
    inst.TryReleaseFlurry = TryReleaseFlurry
    inst.DoFlurryHit = DoFlurryHit
    inst.IsSlamArmed = IsSlamArmed
    inst.DisarmSkill = DisarmSkill
    inst.ToggleSlam = ToggleSlam
    inst.TryReleaseSlam = TryReleaseSlam
    inst.StartSlamCooldown = StartSlamCooldown
    inst.GetSlamLanding = GetSlamLanding
    inst.IsSlamPointSafe = IsSlamPointSafe
    inst.SpawnSlamCrater = SpawnSlamCrater
    inst.DoSlamImpact = DoSlamImpact
    inst.DoSlamHit = DoSlamHit

    inst:ListenForEvent("unequip", OnUnequip)
    inst:ListenForEvent("devoured", OnDevoured)
    inst:ListenForEvent("death", DisarmSkill)
    inst:ListenForEvent("ms_becameghost", DisarmSkill)
    inst:ListenForEvent("attacked", OnAttacked)
    inst:ListenForEvent("onhitother", OnHitOther)
    inst:ListenForEvent("healthdelta", UpdateLowHealthDamage)
    inst:ListenForEvent("ms_becameghost", UpdateLowHealthDamage)
    inst:ListenForEvent("ms_respawnedfromghost", UpdateLowHealthDamage)
end

return MakePlayerCharacter("kiritzuka", prefabs, assets, common_postinit, master_postinit, start_inv)
