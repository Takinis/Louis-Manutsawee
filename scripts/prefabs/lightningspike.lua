local RADIUS = 0.8
local SPAWN_PERIOD = 0
local MAX_COUNT = 20
local MAX_ICESPIKE_SFX = 10
local SFX_PERIOD = math.ceil(MAX_COUNT / (MAX_ICESPIKE_SFX / 2 - 1))
local SPACING = RADIUS * 2 + 0.05
local FAN_HALF_ARC = 25 * DEGREES
local FAN_LANES = 3
local FAN_JITTER = 6 * DEGREES

local spike_fx = {
    "electricchargedfx",
    "electrichitsparks",
    "thunderbird_fx_idle",
    "thunderbird_fx_shoot",
    "thunderbird_fx_charge_loop",
    "thunderbird_fx_charge_pre",
    "thunderbird_fx_charge_pst",
}

local spike_fx_scale = {
    3,
    2.5,
    2,
    1.5,
    1,
}

local function EndTask(inst, taskname)
    if inst[taskname] then
        inst[taskname]:Cancel()
        inst[taskname] = nil
    end

    if not inst.task_fan then
        inst:Remove()
    end
end

local function SpawnLaneSpike(inst, x, z, rot)
    local fx = SpawnPrefab(spike_fx[math.random(1, #spike_fx)])
    if fx ~= nil then
        local scale = spike_fx_scale[math.random(1, #spike_fx_scale)]
        fx.Transform:SetPosition(x, 0, z)
        fx.Transform:SetRotation(rot / DEGREES)
        fx.Transform:SetScale(scale, scale, scale)
    end
end

local function DoSpawnFanSpike(inst, data)
    local rot = inst.Transform:GetRotation() * DEGREES
    local x, y, z = inst.Transform:GetWorldPosition()
    local lane_step = FAN_LANES > 1 and (FAN_HALF_ARC * 2) / (FAN_LANES - 1) or 0
    local dist = data.count * SPACING

    local any_passable = false

    for lane = 1, FAN_LANES do
        local lane_offset = -FAN_HALF_ARC + (lane - 1) * lane_step
        local lane_jitter = (math.random() * 2 - 1) * FAN_JITTER
        local ang = rot + lane_offset + lane_jitter
        local px = x + dist * math.cos(ang)
        local pz = z - dist * math.sin(ang)

        if TheWorld.Map:IsPassableAtPoint(px, 0, pz) then
            any_passable = true
            SpawnLaneSpike(inst, px, pz, ang)
        end
    end

    if data.next_sfx > 0 then
        data.next_sfx = data.next_sfx - 1
    else
        data.next_sfx = SFX_PERIOD
    end

    data.count = data.count + 1
    if data.count >= MAX_COUNT or not any_passable then
        EndTask(inst, "task_fan")
    end
end

local function fn()
    local inst = CreateEntity()

    inst:AddTag("CLASSIFIED")
    inst.persists = false

    inst.entity:AddTransform()

    inst.task_fan = inst:DoPeriodicTask(SPAWN_PERIOD, DoSpawnFanSpike, 0, {
        count = 0,
        next_sfx = 0,
    })

    return inst
end

return Prefab("lightningspike_fx", fn, nil, spike_fx)
