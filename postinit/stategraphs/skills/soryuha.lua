local SkillUtil = require("utils/skillutil")

-- Soryuha: gather power in a guard stance, then loose a half-circle of thunder dragons that curve
-- in on the target, tearing through rock and forest on the way. Where they strike, a thunderstorm
-- rages for five seconds. Tokijin/Onikiba carry the full technique; any other katana takes wear
-- and may shatter.
local CHARGE_TIME = 1.5
local CHARGE_STAGES = 3
local INTERRUPT_REFUND = 0.5
local RELEASE_TIMEOUT = 1
local TILE = 4

local BEAM_TICK = 2 * FRAMES
local BEAM_SPEED = 26
local BEAM_TURN_RATE = 220 * DEGREES -- per second: side dragons arc round instead of snapping on
local BEAM_RADIUS = 3
local BEAM_STRAND_OFFSET = 1.2
local BEAM_HIT_SPACING = 0.15
local BEAM_SCAR_EVERY = 3 -- ticks between ground cracks left along each dragon's path
local CHAIN_RADIUS = 6
local CHAIN_TARGETS = 2
local TERRAIN_WORK = 15

local STORM_DURATION = 5
local PIT_LINGER = 10 -- seconds the pits stay open before eroding away

-- Everything struck is held in place: creatures with a shock animation play it the whole time.
local STUN_DURATION = 6
local STUN_EPIC_DURATION = 3
local STORM_TICK = 0.25
local STORM_FX_PER_TICK = 8
local STORM_STRIKE_PERIOD = 1 -- native lightning bolts, each with its own flash and shake

-- One target takes the dragons' hits once per cast, however many pass through it.
local CARRIER = {
    beams = 5,
    half_spread = 90 * DEGREES,
    rear_spread = 150 * DEGREES, -- two more leave from behind and loop round
    length = 8 * TILE,
    hits = 4,
    hit_mult = 1.5,
    chain_mult = 0.75,
    storm_radius = 10,
    storm_mult = 0.75, -- per tick: 20 ticks, about 15x weapon damage over the storm
}

local IMITATION = {
    beams = 3,
    half_spread = 90 * DEGREES,
    length = 6 * TILE,
    hits = 3,
    hit_mult = 1,
    chain_mult = 0.5,
    storm_radius = 6,
    storm_mult = 0.4,
    wear = 0.1,
    break_chance = 0.2,
}

local TARGET_MUST_TAGS = {"_combat", "_health"}
local TARGET_CANT_TAGS = {"INLIMBO", "flight", "invisible", "notarget", "noattack", "playerghost", "FX", "NOCLICK", "player", "companion", "abigail", "wall", "structure"}
local TERRAIN_ONEOF_TAGS = {"boulder", "tree", "stump"}
local TERRAIN_CANT_TAGS = {"INLIMBO", "structure", "FX", "NOCLICK"}
local BEAM_FX = {"electricchargedfx", "electrichitsparks", "thunderbird_fx_idle", "thunderbird_fx_shoot"}
local HIT_FX = {"electrichitsparks", "electricchargedfx"}

local GUARD_PRE_ANIM = "kiritzuka_guard_pre"
local GUARD_LOOP_ANIM = "kiritzuka_guard_loop"
local GUARD_PST_ANIM = "kiritzuka_guard_pst"

local CRACK_RING_COUNT = 7
local CRACK_RING_RADIUS = 1.6

local function GetWeapon(inst)
    return inst.components.inventory ~= nil and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
end

local function GetTuning(weapon)
    return SkillUtil.IsSoryuhaCarrier(weapon) and CARRIER or IMITATION
end

local function SpawnAt(prefab, x, z, scale)
    local fx = SpawnPrefab(prefab)
    if fx ~= nil then
        fx.Transform:SetPosition(x, 0, z)
        if scale ~= nil then
            fx.Transform:SetScale(scale, scale, scale)
        end
    end
    return fx
end

--------------------------------------------------------------------------
-- Charge visuals: the ground cracks a little more at each stage.

local function SpawnCrackFx(inst, stage, x, z)
    if x == nil then
        x, _, z = inst.Transform:GetWorldPosition()
    end
    local scale = 0.45 + (stage / CHARGE_STAGES) * 0.35
    local theta = math.random() * TWOPI
    local dtheta = TWOPI / CRACK_RING_COUNT

    SpawnAt("sinkhole_spawn_fx_" .. tostring(math.random(3)), x, z)
    for i = 1, CRACK_RING_COUNT do
        local r = CRACK_RING_RADIUS * (1 + math.random() * .1)
        local dust = SpawnAt("sinkhole_spawn_fx_" .. tostring(math.random(3)), x + math.cos(theta) * r, z - math.sin(theta) * r)
        if dust ~= nil then
            local s = scale + math.random() * .2
            dust.Transform:SetScale(i % 2 == 0 and -s or s, s, s)
        end
        theta = theta + dtheta
    end

    inst.SoundEmitter:PlaySoundWithParams(
        "dontstarve/creatures/together/antlion/sfx/ground_break",
        { size = math.pow(stage / CHARGE_STAGES, 2) }
    )
end

local function SpawnSinkholeVisual(x, z)
    local sinkhole = SpawnPrefab("antlion_sinkhole")
    if sinkhole == nil then
        return nil
    end

    sinkhole.Transform:SetPosition(x, 0, z)
    sinkhole.persists = false

    -- Visual-only: do not let it behave like a real collapse hazard.
    if sinkhole.components.timer ~= nil then
        sinkhole:RemoveComponent("timer")
    end
    if sinkhole.components.unevenground ~= nil then
        sinkhole:RemoveComponent("unevenground")
    end
    sinkhole:RemoveTag("antlion_sinkhole_blocker")
    return sinkhole
end

local function UpdateSinkholeStage(sinkhole, stage)
    if sinkhole == nil or not sinkhole:IsValid() then
        return
    end
    if stage >= CHARGE_STAGES then
        sinkhole.AnimState:ClearOverrideSymbol("cracks1")
    else
        sinkhole.AnimState:OverrideSymbol("cracks1", "antlion_sinkhole", "cracks_pre" .. tostring(stage))
    end
end

-- A fully opened pit that stays a while, then erodes away on its own timer.
local function LeavePit(sinkhole, linger)
    if sinkhole == nil or not sinkhole:IsValid() then
        return
    end
    UpdateSinkholeStage(sinkhole, CHARGE_STAGES)
    sinkhole:DoTaskInTime(linger, ErodeAway)
end

local function ClearSinkhole(inst)
    local mem = inst.sg.statemem
    local sinkhole = mem.sinkhole
    mem.sinkhole = nil
    if sinkhole == nil or not sinkhole:IsValid() then
        return
    end
    if mem.charged then
        LeavePit(sinkhole, PIT_LINGER)
    else
        sinkhole:Remove()
    end
end

--------------------------------------------------------------------------
-- Damage

local function IsValidTarget(inst, target)
    return target ~= inst
        and target:IsValid()
        and not target:IsInLimbo()
        and target.components.health ~= nil
        and not target.components.health:IsDead()
        and target.components.combat ~= nil
        and inst.components.combat:CanTarget(target)
        and not SkillUtil.IsProtectedTarget(inst, target)
end

local function GetWeaponDamage(inst, weapon, target)
    local weapon_cmp = weapon ~= nil and weapon:IsValid() and weapon.components.weapon or nil
    if weapon_cmp == nil then
        return 0
    end
    local damage = weapon_cmp.GetDamage ~= nil and weapon_cmp:GetDamage(inst, target) or weapon_cmp.damage
    return math.max(0, damage or 0)
end

-- Lightning bites harder on wet targets, as native electric attacks do.
local function GetElectricMult(target)
    if IsEntityElectricImmune ~= nil and IsEntityElectricImmune(target) then
        return 1
    end
    local wet = target.GetWetMultiplier ~= nil and target:GetWetMultiplier() or 0
    return 1 + (TUNING.ELECTRIC_WET_DAMAGE_MULT or 0) * wet
end

local function ReleaseStun(target)
    target:RestartBrain("soryuha_stun")
end

local function Stun(target, beam)
    if beam.stunned[target] or not target:IsValid() or target.components.health:IsDead() then
        return
    end
    beam.stunned[target] = true
    local duration = target:HasTag("epic") and STUN_EPIC_DURATION or STUN_DURATION

    -- Native shock: "electrocute" with a duration keeps the creature in its shock loop.
    if target.sg ~= nil and target.sg:HasState("electrocute") and not target.sg.mem.noelectrocute then
        target:PushEvent("electrocute", { duration = duration, noresist = true, numforks = 0, noburn = true })
    end
    -- The brain is held too, so creatures without a shock state, or bosses mid-attack, still stand still.
    if target.StopBrain ~= nil then
        target:StopBrain("soryuha_stun")
        target:DoTaskInTime(duration, ReleaseStun)
    end
    if target.components.locomotor ~= nil then
        target.components.locomotor:Stop()
    end
end

local function Zap(inst, target, beam, mult)
    if not inst:IsValid() or not IsValidTarget(inst, target) then
        return
    end
    local damage = GetWeaponDamage(inst, beam.weapon, target) * mult * GetElectricMult(target)
    target.components.combat:GetAttacked(inst, damage, beam.weapon, "electric")
    local x, _, z = target.Transform:GetWorldPosition()
    SpawnAt(GetRandomItem(HIT_FX), x, z, 1.5)
    Stun(target, beam)
end

local function ChainFrom(inst, source, beam)
    local x, y, z = source.Transform:GetWorldPosition()
    local count = 0
    for _, other in ipairs(TheSim:FindEntities(x, y, z, CHAIN_RADIUS, TARGET_MUST_TAGS, TARGET_CANT_TAGS)) do
        if count >= CHAIN_TARGETS then
            break
        end
        if other ~= source and not beam.touched[other] and not beam.chained[other] and IsValidTarget(inst, other) then
            beam.chained[other] = true
            count = count + 1
            Zap(inst, other, beam, beam.tuning.chain_mult)
        end
    end
end

local function TouchTarget(inst, target, beam)
    beam.touched[target] = true
    Zap(inst, target, beam, beam.tuning.hit_mult)
    ChainFrom(inst, target, beam)
    for i = 1, beam.tuning.hits - 1 do
        inst:DoTaskInTime(i * BEAM_HIT_SPACING, function()
            Zap(inst, target, beam, beam.tuning.hit_mult)
        end)
    end
end

-- Rocks split and trees fall wherever the lightning goes.
local function ShatterTerrain(inst, beam, x, z, radius)
    for _, ent in ipairs(TheSim:FindEntities(x, 0, z, radius, nil, TERRAIN_CANT_TAGS, TERRAIN_ONEOF_TAGS)) do
        if not beam.worked[ent] and ent.components.workable ~= nil and ent.components.workable:CanBeWorked() then
            beam.worked[ent] = true
            ent.components.workable:WorkedBy(inst, TERRAIN_WORK)
        end
    end
end

local function HasLiveTarget(beam)
    local target = beam.target
    return target ~= nil and target:IsValid() and target.components.health ~= nil and not target.components.health:IsDead()
end

--------------------------------------------------------------------------
-- The storm: five seconds of lightning where the dragons strike, following the target while it lives.

local function StormTick(inst, beam)
    local storm = beam.storm
    if HasLiveTarget(beam) then
        local tx, _, tz = beam.target.Transform:GetWorldPosition()
        storm.x, storm.z = tx, tz
    end
    local x, z, radius = storm.x, storm.z, beam.tuning.storm_radius

    for _ = 1, STORM_FX_PER_TICK do
        local theta = math.random() * TWOPI
        local r = math.sqrt(math.random()) * radius
        SpawnAt(GetRandomItem(BEAM_FX), x + math.cos(theta) * r, z - math.sin(theta) * r, 2 + math.random())
    end

    if storm.elapsed >= storm.next_strike then
        storm.next_strike = storm.next_strike + STORM_STRIKE_PERIOD
        local theta = math.random() * TWOPI
        local r = math.random() * radius * .6
        SpawnAt("lightning", x + math.cos(theta) * r, z - math.sin(theta) * r)
        ShatterTerrain(inst, beam, x, z, radius)
    end

    for _, target in ipairs(TheSim:FindEntities(x, 0, z, radius, TARGET_MUST_TAGS, TARGET_CANT_TAGS)) do
        Zap(inst, target, beam, beam.tuning.storm_mult)
    end

    storm.elapsed = storm.elapsed + STORM_TICK
    if storm.elapsed >= STORM_DURATION then
        storm.task:Cancel()
        storm.task = nil
        SpawnAt("thunderbird_fx_charge_pst", x, z, 3)
        SpawnAt("sinkhole_spawn_fx_" .. tostring(math.random(3)), x, z, 1.5)
    end
end

local function StartStorm(inst, beam, x, z)
    beam.storm = { x = x, z = z, elapsed = 0, next_strike = 0 }
    -- The one shockwave of the technique, and a pit where the dragons struck.
    SpawnAt("groundpoundring_fx", x, z, 2.5)
    LeavePit(SpawnSinkholeVisual(x, z), STORM_DURATION + PIT_LINGER)
    SpawnCrackFx(inst, CHARGE_STAGES, x, z)
    SpawnAt("thunderbird_fx_charge_pst", x, z, 4)
    if ShakeAllCameras ~= nil then
        ShakeAllCameras(CAMERASHAKE.FULL, 1.2, .03, .8, beam.target ~= nil and beam.target:IsValid() and beam.target or inst, 60)
    end
    beam.storm.task = inst:DoPeriodicTask(STORM_TICK, StormTick, 0, beam)
end

--------------------------------------------------------------------------
-- The dragons fan out over a half circle, then home in on the target like seeking missiles.

local function GetDestination(beam)
    if HasLiveTarget(beam) then
        local x, _, z = beam.target.Transform:GetWorldPosition()
        return x, z, BEAM_RADIUS + beam.target:GetPhysicsRadius(0)
    end
    return beam.dest_x, beam.dest_z, BEAM_RADIUS
end

local function WrapAngle(a)
    while a > math.pi do
        a = a - TWOPI
    end
    while a < -math.pi do
        a = a + TWOPI
    end
    return a
end

local function StepDragon(inst, dragon)
    local beam = dragon.cast
    local tx, tz, reach = GetDestination(beam)

    -- DST forward is (cos, -sin) in the XZ plane, so headings are measured with z inverted.
    local desired = math.atan2(-(tz - dragon.z), tx - dragon.x)
    local max_turn = BEAM_TURN_RATE * BEAM_TICK
    local turn = WrapAngle(desired - dragon.heading)
    dragon.heading = dragon.heading + math.max(-max_turn, math.min(max_turn, turn))

    local step = BEAM_SPEED * BEAM_TICK
    local fx, fz = math.cos(dragon.heading), -math.sin(dragon.heading)
    dragon.x = dragon.x + fx * step
    dragon.z = dragon.z + fz * step
    dragon.travel = dragon.travel + step
    dragon.phase = dragon.phase + 0.9
    dragon.ticks = dragon.ticks + 1
    local hx, hz = dragon.x, dragon.z

    -- Strands sit either side of the head, perpendicular to the dragon's path.
    local side = math.sin(dragon.phase) * BEAM_STRAND_OFFSET
    SpawnAt(GetRandomItem(BEAM_FX), hx - fz * side, hz - fx * side, 2.5)
    SpawnAt(GetRandomItem(BEAM_FX), hx + fz * side, hz + fx * side, 2)
    if dragon.ticks % BEAM_SCAR_EVERY == 0 then
        SpawnAt("sinkhole_spawn_fx_" .. tostring(math.random(3)), hx, hz, 1)
    end

    ShatterTerrain(inst, beam, hx, hz, BEAM_RADIUS)
    for _, target in ipairs(TheSim:FindEntities(hx, 0, hz, BEAM_RADIUS + 2, TARGET_MUST_TAGS, TARGET_CANT_TAGS)) do
        if not beam.touched[target] and IsValidTarget(inst, target) then
            local ox, _, oz = target.Transform:GetWorldPosition()
            local r = BEAM_RADIUS + target:GetPhysicsRadius(0)
            local dx, dz = ox - hx, oz - hz
            if dx * dx + dz * dz <= r * r then
                TouchTarget(inst, target, beam)
            end
        end
    end

    local dx, dz = tx - hx, tz - hz
    local arrived = dx * dx + dz * dz <= reach * reach
    if arrived or dragon.travel >= beam.max_travel then
        dragon.task:Cancel()
        dragon.task = nil
        SpawnAt("thunderbird_fx_shoot", hx, hz, 3)
        if beam.storm == nil then
            StartStorm(inst, beam, arrived and tx or hx, arrived and tz or hz)
        end
    end
end

local function LaunchBeam(inst, weapon, target)
    local x, _, z = inst.Transform:GetWorldPosition()
    local rot = inst.Transform:GetRotation() * DEGREES
    local tuning = GetTuning(weapon)
    local beam = {
        weapon = weapon,
        tuning = tuning,
        target = target,
        -- Without a target the dragons meet at full reach straight ahead.
        dest_x = x + math.cos(rot) * tuning.length,
        dest_z = z - math.sin(rot) * tuning.length,
        -- Room for the side dragons to arc round; a target beyond reach is not chased forever.
        max_travel = tuning.length * 1.6,
        touched = {},
        chained = {},
        worked = {},
        stunned = {},
        dragons = {},
    }
    if target ~= nil and target:IsValid() then
        local tx, _, tz = target.Transform:GetWorldPosition()
        if (tx - x) ^ 2 + (tz - z) ^ 2 > tuning.length * tuning.length then
            beam.target = nil
        end
    end

    for i = 1, tuning.beams do
        local t = tuning.beams > 1 and (i - 1) / (tuning.beams - 1) * 2 - 1 or 0
        local heading = rot + t * tuning.half_spread
        local dragon = {
            cast = beam,
            heading = heading,
            x = x + math.cos(heading),
            z = z - math.sin(heading),
            travel = 0,
            phase = i * 1.3,
            ticks = 0,
        }
        dragon.task = inst:DoPeriodicTask(BEAM_TICK, StepDragon, 0, dragon)
        beam.dragons[i] = dragon
    end

    if tuning.rear_spread ~= nil then
        for _, side in ipairs({-1, 1}) do
            local heading = rot + side * tuning.rear_spread
            local dragon = {
                cast = beam,
                heading = heading,
                x = x + math.cos(heading) * 1.5,
                z = z - math.sin(heading) * 1.5,
                travel = 0,
                phase = side * 2.1,
                ticks = 0,
            }
            dragon.task = inst:DoPeriodicTask(BEAM_TICK, StepDragon, 0, dragon)
            beam.dragons[#beam.dragons + 1] = dragon
        end
    end

    inst.SoundEmitter:PlaySound("turnoftides/common/together/moon_glass/mine")
    inst.SoundEmitter:PlaySound("dontstarve/rain/thunder_close")
    if ShakeAllCameras ~= nil then
        ShakeAllCameras(CAMERASHAKE.FULL, .8, .03, .6, inst, 40)
    end
    return beam
end

--------------------------------------------------------------------------
-- An ordinary katana was never meant to hold this power.

local function StrainBlade(inst, weapon)
    if weapon == nil or SkillUtil.IsSoryuhaCarrier(weapon) then
        return
    end

    local uses = weapon.components.finiteuses
    if uses == nil then
        return
    end

    local broken = "broken_" .. tostring(weapon.prefab)
    if math.random() < IMITATION.break_chance and PrefabExists ~= nil and PrefabExists(broken) then
        if inst.components.talker ~= nil then
            inst.components.talker:Say(STRINGS.SKILL.SORYUHA_SHATTERED, 2, true)
        end
        local shard = SpawnPrefab(broken)
        if shard ~= nil and inst.components.inventory ~= nil then
            inst.components.inventory:GiveItem(shard)
        end
        uses:SetUses(0)
        return
    end

    uses:Use(math.max(1, math.ceil(uses.total * IMITATION.wear)))
    if weapon:IsValid() and inst.components.talker ~= nil then
        inst.components.talker:Say(STRINGS.SKILL.SORYUHA_FRAGILE, 2, true)
    end
end

local function RefundCharge(inst)
    local controller = inst.components.playerskillcontroller
    if controller ~= nil and controller.IsLimiterReleased ~= nil and controller:IsLimiterReleased() then
        return
    end
    local kenjutsuka = inst.components.kenjutsuka
    local skill = controller ~= nil and controller.GetSkillData ~= nil and controller:GetSkillData("soryuha") or nil
    if kenjutsuka ~= nil and skill ~= nil then
        kenjutsuka:SetMindpower(kenjutsuka:GetMindpower() + math.floor(skill.mindpower * INTERRUPT_REFUND))
    end
end

return {
    events = {
        EventHandler("soryuha", function(inst, data)
            inst.sg:GoToState("soryuha", data ~= nil and (data.target or data) or nil)
        end),
    },
    states = {
        -- Charging: not immune. Lesser hits are halved and shrugged off (postinit/components/combat.lua);
        -- a blow from a boss breaks the stance and returns half the Mind Power.
        State{
            name = "soryuha",
            tags = {"busy", "nopredict", "nointerrupt", "nomorph", "doing", "notalking", "skilling", "soryuha_charging"},

            onenter = function(inst, target)
                inst.components.locomotor:Stop()
                inst:ClearBufferedAction()
                inst.AnimState:PlayAnimation(GUARD_PRE_ANIM)
                inst.AnimState:PushAnimation(GUARD_LOOP_ANIM, true)
                inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")

                local mem = inst.sg.statemem
                if target ~= nil and target:IsValid() then
                    mem.target = target
                    inst:ForceFacePoint(target.Transform:GetWorldPosition())
                end

                mem.stage = 0
                local px, _, pz = inst.Transform:GetWorldPosition()
                mem.sinkhole = SpawnSinkholeVisual(px, pz)
                mem.charge_task = inst:DoPeriodicTask(CHARGE_TIME / CHARGE_STAGES, function(inst_)
                    mem.stage = math.min(mem.stage + 1, CHARGE_STAGES)
                    UpdateSinkholeStage(mem.sinkhole, mem.stage)
                    SpawnCrackFx(inst_, mem.stage)
                end, 0)
                SkillUtil.AddFollowerFx(inst, "electricchargedfx", 1.5)
                inst.sg:SetTimeout(CHARGE_TIME)
            end,

            ontimeout = function(inst)
                inst.sg.statemem.charged = true
                inst.sg:GoToState("soryuha_release", inst.sg.statemem.target)
            end,

            events = {
                EventHandler("soryuha_interrupted", function(inst)
                    RefundCharge(inst)
                    inst.sg:GoToState("hit")
                end),
                EventHandler("unequip", function(inst)
                    inst.sg:GoToState("idle")
                end),
            },

            onexit = function(inst)
                local mem = inst.sg.statemem
                if mem.charge_task ~= nil then
                    mem.charge_task:Cancel()
                    mem.charge_task = nil
                end
                ClearSinkhole(inst)
                if not mem.charged and inst.components.combat ~= nil then
                    inst.components.combat:SetRange(TUNING.DEFAULT_ATTACK_RANGE)
                end
            end,
        },

        State{
            name = "soryuha_release",
            tags = {"busy", "nopredict", "nointerrupt", "nomorph", "doing", "notalking", "skilling"},

            onenter = function(inst, target)
                inst.inspskill = true
                inst.AnimState:PlayAnimation(GUARD_PST_ANIM)

                local weapon = GetWeapon(inst)
                LaunchBeam(inst, weapon, target)
                StrainBlade(inst, weapon)
                inst.sg:SetTimeout(RELEASE_TIMEOUT)
            end,

            ontimeout = function(inst)
                inst.sg:GoToState("idle")
            end,

            events = {
                EventHandler("animover", function(inst)
                    if inst.AnimState:AnimDone() then
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
