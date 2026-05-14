local SkillUtil = require("utils/skillutil")

local SORYUHA_BASE_DAMAGE = 64
local SORYUHA_RANGE = 14
local SORYUHA_HALF_ARC = 60 * DEGREES
local SORYUHA_TICK_PERIOD = 10 * FRAMES
local SORYUHA_DURATION = 20
local SORYUHA_TARGET_MUST_TAGS = {"_combat"}
local SORYUHA_TARGET_CANT_TAGS = {"INLIMBO", "flight", "invisible", "notarget", "noattack", "playerghost", "FX", "NOCLICK"}
local SORYUHA_TARGET_FX = {"electrichitsparks", "electricchargedfx", "thunderbird_fx_idle"}
local SORYUHA_WAVE_RADIUS = 0.8
local SORYUHA_WAVE_SPAWN_PERIOD = 0
local SORYUHA_WAVE_MAX_COUNT = 20
local SORYUHA_WAVE_MAX_SFX = 10
local SORYUHA_WAVE_SFX_PERIOD = math.ceil(SORYUHA_WAVE_MAX_COUNT / (SORYUHA_WAVE_MAX_SFX / 2 - 1))
local SORYUHA_WAVE_SPACING = SORYUHA_WAVE_RADIUS * 2 + 0.05
local SORYUHA_WAVE_HALF_ARC = 25 * DEGREES
local SORYUHA_WAVE_LANES = 3
local SORYUHA_WAVE_JITTER = 6 * DEGREES
local SORYUHA_CRACK_STAGES = 3
local SORYUHA_CRACK_STAGE_PERIOD = 0.7
local SORYUHA_CRACK_RING_COUNT = 7
local SORYUHA_CRACK_RING_RADIUS = 1.6
local SORYUHA_WAVE_FX = {
    "electricchargedfx",
    "electrichitsparks",
    "thunderbird_fx_idle",
    "thunderbird_fx_shoot",
    "thunderbird_fx_charge_loop",
    "thunderbird_fx_charge_pre",
    "thunderbird_fx_charge_pst",
}
local SORYUHA_WAVE_FX_SCALE = {3, 2.5, 2, 1.5, 1,}

local function SpawnSoryuhaCrackFx(inst, stage, scale)
    local x, y, z = inst.Transform:GetWorldPosition()
    local theta = math.random() * TWOPI
    local dtheta = TWOPI / SORYUHA_CRACK_RING_COUNT

    local center = SpawnPrefab("sinkhole_spawn_fx_" .. tostring(math.random(3)))
    if center ~= nil then
        center.Transform:SetPosition(x, y, z)
    end

    for i = 1, SORYUHA_CRACK_RING_COUNT do
        local dust = SpawnPrefab("sinkhole_spawn_fx_" .. tostring(math.random(3)))
        if dust ~= nil then
            local r = SORYUHA_CRACK_RING_RADIUS * (1 + math.random() * .1)
            local px = x + math.cos(theta) * r
            local pz = z - math.sin(theta) * r
            dust.Transform:SetPosition(px, 0, pz)
            local s = scale + math.random() * .2
            dust.Transform:SetScale(i % 2 == 0 and -s or s, s, s)
        end
        theta = theta + dtheta
    end

    inst.SoundEmitter:PlaySoundWithParams(
        "dontstarve/creatures/together/antlion/sfx/ground_break",
        { size = math.pow(stage / SORYUHA_CRACK_STAGES, 2) }
    )
end

local function SpawnSoryuhaSinkholeVisual(inst)
    local sinkhole = SpawnPrefab("antlion_sinkhole")
    if sinkhole == nil then
        return nil
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    sinkhole.Transform:SetPosition(x, y, z)
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

local function UpdateSoryuhaSinkholeStage(sinkhole, stage)
    if sinkhole == nil or not sinkhole:IsValid() then
        return
    end

    if stage >= SORYUHA_CRACK_STAGES then
        sinkhole.AnimState:ClearOverrideSymbol("cracks1")
    else
        sinkhole.AnimState:OverrideSymbol("cracks1", "antlion_sinkhole", "cracks_pre" .. tostring(stage))
    end
end

local function StartSoryuhaCrackSequence(inst)
    inst.sg.statemem.soryuha_crack_stage = 0
    inst.sg.statemem.soryuha_sinkhole = SpawnSoryuhaSinkholeVisual(inst)

    local function DoCrackStage(inst_)
        if not inst_:IsValid() then
            return
        end

        local stage = math.min((inst_.sg.statemem.soryuha_crack_stage or 0) + 1, SORYUHA_CRACK_STAGES)
        inst_.sg.statemem.soryuha_crack_stage = stage
        UpdateSoryuhaSinkholeStage(inst_.sg.statemem.soryuha_sinkhole, stage)
        local scale = 0.45 + (stage / SORYUHA_CRACK_STAGES) * 0.35
        SpawnSoryuhaCrackFx(inst_, stage, scale)

        if stage >= SORYUHA_CRACK_STAGES and inst_.sg.statemem.soryuha_crack_task ~= nil then
            inst_.sg.statemem.soryuha_crack_task:Cancel()
            inst_.sg.statemem.soryuha_crack_task = nil
        end
    end

    DoCrackStage(inst)
    inst.sg.statemem.soryuha_crack_task = inst:DoPeriodicTask(SORYUHA_CRACK_STAGE_PERIOD, DoCrackStage)
end

local function SpawnSoryuhaTargetFx(inst, target)
    if target ~= nil and target:IsValid() then
        local base_x, base_y, base_z = target.Transform:GetWorldPosition()
        if target.components.health and not target.components.health:IsDead() then
            local steps = 6
            for i = 0, steps - 1 do
                inst:DoTaskInTime(i * 0.1, function()
                    local angle = math.random() * 2 * math.pi
                    local radius = math.random() * 2
                    local x = base_x + radius * math.cos(angle)
                    local z = base_z - radius * math.sin(angle)
                    local fx = SpawnPrefab(GetRandomItem(SORYUHA_TARGET_FX))
                    if fx ~= nil then
                        fx.Transform:SetPosition(x, base_y + i * 0.8, z)
                        fx.Transform:SetScale(2, 2, 2)
                    end
                end)
            end
        end
    end
end

local function ApplySoryuhaKnockback(inst, target)
    if target == nil or not target:IsValid() or target.Physics == nil then
        return
    end

    local ix, _, iz = inst.Transform:GetWorldPosition()
    local tx, _, tz = target.Transform:GetWorldPosition()
    local dx, dz = tx - ix, tz - iz
    local len = math.sqrt(dx * dx + dz * dz)
    if len <= 0 then
        return
    end

    dx, dz = dx / len, dz / len
    local push = 5
    target.Physics:Teleport(tx + dx * 0.3, 0, tz + dz * 0.3)
    target.Physics:SetVel(dx * push, 0, dz * push)
end

local function GetSoryuhaDamage(inst, weapon)
    local level = 1
    if inst.components.kenjutsuka ~= nil and inst.components.kenjutsuka.GetLevel ~= nil then
        level = math.max(1, inst.components.kenjutsuka:GetLevel() or 1)
    end

    local weapon_damage = 1
    if weapon ~= nil and weapon.components.weapon ~= nil then
        weapon_damage = math.max(0, weapon.components.weapon.damage or 0)
    end

    return SORYUHA_BASE_DAMAGE * weapon_damage * level
end

local function SpawnSoryuhaWaveFx(inst, x, y, z, rot)
    local lane_step = SORYUHA_WAVE_LANES > 1 and (SORYUHA_WAVE_HALF_ARC * 2) / (SORYUHA_WAVE_LANES - 1) or 0

    local task = nil
    local data = {
        count = 0,
        next_sfx = 0,
        x = x,
        y = y,
        z = z,
        rot = rot,
    }

    task = inst:DoPeriodicTask(SORYUHA_WAVE_SPAWN_PERIOD, function(inst_, d)
        if not inst_:IsValid() then
            if task ~= nil then
                task:Cancel()
            end
            return
        end

        local dist = d.count * SORYUHA_WAVE_SPACING
        local any_passable = false

        for lane = 1, SORYUHA_WAVE_LANES do
            local lane_offset = -SORYUHA_WAVE_HALF_ARC + (lane - 1) * lane_step
            local lane_jitter = (math.random() * 2 - 1) * SORYUHA_WAVE_JITTER
            local ang = d.rot + lane_offset + lane_jitter
            local px = d.x + dist * math.cos(ang)
            local pz = d.z - dist * math.sin(ang)

            if TheWorld.Map:IsPassableAtPoint(px, 0, pz) then
                any_passable = true
                local fx = SpawnPrefab(GetRandomItem(SORYUHA_WAVE_FX))
                if fx ~= nil then
                    local scale = GetRandomItem(SORYUHA_WAVE_FX_SCALE)
                    fx.Transform:SetPosition(px, 0, pz)
                    fx.Transform:SetRotation(ang / DEGREES)
                    fx.Transform:SetScale(scale, scale, scale)
                end
            end
        end

        if d.next_sfx > 0 then
            d.next_sfx = d.next_sfx - 1
        else
            d.next_sfx = SORYUHA_WAVE_SFX_PERIOD
        end

        d.count = d.count + 1
        if d.count >= SORYUHA_WAVE_MAX_COUNT or not any_passable then
            if task ~= nil then
                task:Cancel()
            end
        end
    end, 0, data)
end

local function IsInSoryuhaArc(inst, target, x, y, z, rot)
    local x1, _, z1 = target.Transform:GetWorldPosition()
    local dx = x1 - x
    local dz = z1 - z
    local range = SORYUHA_RANGE + target:GetPhysicsRadius(0)
    local dist_sq = dx * dx + dz * dz
    if dist_sq > range * range then
        return false
    end

    if dist_sq <= 0.0001 then
        return true
    end

    local inv_len = 1 / math.sqrt(dist_sq)
    local tx = dx * inv_len
    local tz = dz * inv_len

    -- DST forward in XZ plane (z is inverted in world-space formulas).
    local fx = math.cos(rot)
    local fz = -math.sin(rot)
    local dot = fx * tx + fz * tz

    return dot >= math.cos(SORYUHA_HALF_ARC)
end

local function DoSoryuhaPulse(inst)
    if inst.components.combat == nil then
        return
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    local rot = inst.Transform:GetRotation() * DEGREES
    local weapon = inst.components.inventory ~= nil and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
    local damage = GetSoryuhaDamage(inst, weapon)
    SpawnSoryuhaWaveFx(inst, x, y, z, rot)
    inst.SoundEmitter:PlaySound("turnoftides/common/together/moon_glass/mine")

    for _, target in ipairs(TheSim:FindEntities(x, y, z, SORYUHA_RANGE + 3, SORYUHA_TARGET_MUST_TAGS, SORYUHA_TARGET_CANT_TAGS)) do
        if target ~= inst
            and target:IsValid()
            and not target:IsInLimbo()
            and target.components.health ~= nil
            and not target.components.health:IsDead()
            and inst.components.combat:CanTarget(target)
            and IsInSoryuhaArc(inst, target, x, y, z, rot)
        then
            target.components.combat:GetAttacked(inst, damage, weapon)
            SpawnSoryuhaTargetFx(inst, target)
            ApplySoryuhaKnockback(inst, target)
        end
    end
end

return {
    events = {
        EventHandler("soryuha", function(inst, data)
            inst.sg:GoToState("soryuha", data ~= nil and (data.target or data) or nil)
        end),
    },
    states = {
        State{
            name = "soryuha",
            tags = {"busy", "nopredict", "nointerrupt", "nomorph", "doing", "notalking", "skilling", "mdodgeing"},

            onenter = function(inst, target)
                inst.components.locomotor:Stop()
                inst.components.combat:SetRange(SORYUHA_RANGE)
                inst.inspskill = true
                inst.components.health:SetInvincible(true)
                inst.AnimState:SetDeltaTimeMultiplier(1)
                inst.AnimState:PlayAnimation("parry_pre")
                inst.AnimState:PushAnimation("parry_loop", true)
                inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")

                if target ~= nil and target:IsValid() then
                    inst.sg.statemem.target = target
                    inst:ForceFacePoint(target.Transform:GetWorldPosition())
                end

                StartSoryuhaCrackSequence(inst)
                DoSoryuhaPulse(inst)
                inst.sg.statemem.soryuha_task = inst:DoPeriodicTask(SORYUHA_TICK_PERIOD, DoSoryuhaPulse)
                inst.sg:SetTimeout(SORYUHA_DURATION)
            end,

            timeline = {
                TimeEvent(6 * FRAMES, function(inst)
                    SkillUtil.AddFollowerFx(inst, "electricchargedfx", 1.5)
                end),
                TimeEvent(12 * FRAMES, function(inst)
                    SkillUtil.GroundPoundFx(inst, .9)
                end),
            },

            ontimeout = function(inst)
                inst.AnimState:PlayAnimation("parry_pst")
                inst.sg.statemem.soryuha_done = true
            end,

            events = {
                EventHandler("animqueueover", function(inst)
                    if inst.sg.statemem.soryuha_done then
                        inst.sg:GoToState("idle")
                    end
                end),
            },

            onexit = function(inst)
                if inst.sg.statemem.soryuha_task ~= nil then
                    inst.sg.statemem.soryuha_task:Cancel()
                    inst.sg.statemem.soryuha_task = nil
                end
                if inst.sg.statemem.soryuha_crack_task ~= nil then
                    inst.sg.statemem.soryuha_crack_task:Cancel()
                    inst.sg.statemem.soryuha_crack_task = nil
                end
                if inst.sg.statemem.soryuha_sinkhole ~= nil and inst.sg.statemem.soryuha_sinkhole:IsValid() then
                    inst.sg.statemem.soryuha_sinkhole:Remove()
                    inst.sg.statemem.soryuha_sinkhole = nil
                end
                if inst.components.combat ~= nil then
                    inst.components.combat:SetTarget(nil)
                    inst.components.combat:SetRange(TUNING.DEFAULT_ATTACK_RANGE)
                end
                inst.AnimState:SetDeltaTimeMultiplier(1)
                inst.inspskill = nil
                inst.components.health:SetInvincible(false)
            end,
        },
    },
}
