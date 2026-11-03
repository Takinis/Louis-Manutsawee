-- Run from the mod directory: lua tests/momentum.lua
local native_scripts = arg[1] or "../../data/databundles/scripts/"
package.path = "scripts/?.lua;" .. native_scripts .. "?.lua;" .. package.path
require("class")
require("util/sourcemodifierlist")
EntityScript = { is_instance = function(value) return value.listeners ~= nil end }

GLOBAL = _G
env = { is_mim_enabled = true }
ALL_KATANA = {}
M_CONFIG = {}
TUNING = { TOTAL_DAY_TIME = 480, GAMEMODE_STARTING_ITEMS = { DEFAULT = {} } }
dofile("main/tuning.lua")
local tuning = TUNING.MOMENTUM
local EnemyTracker = require("components/enemytracker")
local Momentum = require("components/momentum")
local now = 0
GetTime = function() return now end
math.clamp = function(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local tasks = {}
local entities = {}
local function NewEntity(prefab, tags, x)
    local inst = {
        prefab = prefab, tags = tags or {}, x = x or 0, components = {},
        listeners = {}, visible = true, valid = true,
    }
    inst.Transform = { GetWorldPosition = function() return inst.x, 0, 0 end }
    inst.entity = { IsVisible = function() return inst.visible end }
    function inst:IsValid() return self.valid end
    function inst:HasTag(tag) return self.tags[tag] == true end
    function inst:GetDistanceSqToInst(other) return (self.x - other.x) ^ 2 end
    function inst:ListenForEvent(event, fn, source)
        source = source or self
        source.listeners[event] = source.listeners[event] or {}
        table.insert(source.listeners[event], { owner = self, fn = fn })
    end
    function inst:RemoveEventCallback(event, fn, source)
        local listeners = (source or self).listeners[event] or {}
        for i = #listeners, 1, -1 do
            if listeners[i].owner == self and listeners[i].fn == fn then
                table.remove(listeners, i)
            end
        end
    end
    function inst:PushEvent(event, data)
        local listeners = {}
        for _, listener in ipairs(self.listeners[event] or {}) do
            table.insert(listeners, listener)
        end
        for _, listener in ipairs(listeners) do
            listener.fn(listener.owner, data)
        end
    end
    function inst:DoTaskInTime(delay, fn)
        local task = { inst = self, time = now + delay, fn = fn }
        function task:Cancel() self.cancelled = true end
        table.insert(tasks, task)
        return task
    end
    function inst:DoPeriodicTask(period, fn, delay)
        local task = self:DoTaskInTime(delay or period, fn)
        task.period = period
        return task
    end
    inst.components.health = {
        currenthealth = 100, maxhealth = 100,
        GetMaxWithPenalty = function(self) return self.maxhealth end,
        GetPercent = function(self) return self.currenthealth / self.maxhealth end,
        IsDead = function(self) return self.currenthealth <= 0 end,
    }
    inst.components.combat = {
        defaultdamage = 20,
        externaldamagemultipliers = SourceModifierList(inst),
    }
    table.insert(entities, inst)
    return inst
end

TheSim = {
    FindEntities = function(_, x, y, z, radius, must, cant)
        local found = {}
        for _, inst in ipairs(entities) do
            local include = inst.valid and math.abs(inst.x - x) <= radius
            for _, tag in ipairs(must) do include = include and inst:HasTag(tag) end
            for _, tag in ipairs(cant) do include = include and not inst:HasTag(tag) end
            if include then table.insert(found, inst) end
        end
        return found
    end,
}

local function Advance(dt)
    local finish = now + dt
    while true do
        local next_task
        for _, task in ipairs(tasks) do
            if not task.cancelled and task.time <= finish
                and (next_task == nil or task.time < next_task.time) then
                next_task = task
            end
        end
        if next_task == nil then break end
        now = next_task.time
        if next_task.period ~= nil then
            next_task.time = now + next_task.period
        else
            next_task.cancelled = true
        end
        next_task.fn(next_task.inst)
    end
    now = finish
end

local function NewPlayer(x)
    local inst = NewEntity("kiritzuka", { player = true, _combat = true }, x)
    inst.components.sanity = { percent = 1, GetPercent = function(self) return self.percent end }
    inst.components.hunger = { percent = 1, GetPercent = function(self) return self.percent end }
    inst.components.areaaware = { GetCurrentArea = function() return inst.area end }
    inst.components.locomotor = {
        speed = {},
        SetExternalSpeedMultiplier = function(self, _, key, value) self.speed[key] = value end,
        RemoveExternalSpeedMultiplier = function(self, _, key) self.speed[key] = nil end,
    }
    inst.net_momentum_value = { set = function(self, v) self.v = v end }
    inst.net_momentum_stage = { set = function(self, v) self.v = v end }
    inst.components.enemytracker = EnemyTracker(inst)
    inst.components.momentum = Momentum(inst)
    return inst
end

local function Near(actual, expected)
    assert(math.abs(actual - expected) < 0.000001, tostring(actual) .. " ~= " .. tostring(expected))
end

local function SetHealth(inst, percent)
    inst.components.health.currenthealth = inst.components.health.maxhealth * percent
    inst:PushEvent("healthdelta")
end

local function Copy(data)
    if type(data) ~= "table" then return data end
    local copy = {}
    for key, value in pairs(data) do copy[key] = Copy(value) end
    return copy
end

local player = NewPlayer()
local tracker = player.components.enemytracker
local momentum = player.components.momentum
local modifiers = player.components.combat.externaldamagemultipliers
local MAX = tuning.MAX

local function Stage(name)
    assert(momentum:GetStageName() == name, momentum:GetStageName() .. " ~= " .. name)
end

-- Idle: nothing tracked, no ticking, no modifiers.
Advance(0)
assert(not momentum:IsActive() and momentum.task == nil)
Near(modifiers:Get(), 1)
Stage("calm")

-- Neutral targeters are tracked but their weight stays under the first stage.
local neutral = NewEntity("pigman", { _combat = true })
neutral.components.combat.target = player
Advance(0.5)
assert(tracker:GetMarks()[neutral] ~= nil)
assert(tracker:GetThreat() > 0)
neutral.components.combat.target = nil
Advance(0.5)
assert(tracker:GetThreat() == 0)
assert(not momentum:IsActive() and momentum.task == nil, "Ticker stops when nothing is left to move")

local ally = NewEntity("spider", { _combat = true, monster = true })
ally.components.follower = { leader = player }
local hidden = NewEntity("hound", { _combat = true, hostile = true })
hidden.visible = false
Advance(0.5)
assert(next(tracker:GetMarks()) == nil and tracker:GetThreat() == 0, "Allies and hidden entities are ignored")

-- Threat distance falloff.
local frog = NewEntity("frog", { _combat = true }, 0)
Advance(0.5)
local near_threat = tracker:GetThreat()
frog.x = tuning.SCAN_RADIUS - 1
Advance(0.5)
assert(tracker:GetThreat() < near_threat)
Near(tracker:GetThreat(), tuning.THREAT_WEIGHTS.normal * (1 - 0.5 * (tuning.SCAN_RADIUS - 1) / tuning.SCAN_RADIUS))
frog.x = 31
Advance(0.5)
assert(tracker:GetMarks()[frog] == nil and #frog.listeners.healthdelta == 0, "Out-of-range marks detach listeners")
frog.x = 0

-- Passive gain climbs to, and stops at, the threat ceiling.
Advance(0.5)
local ceiling = momentum:GetCeiling()
Near(ceiling, tuning.CEILING_BASE + tracker:GetThreat() * tuning.CEILING_SLOPE)
Advance(60)
Near(momentum.value, ceiling)
Stage("rise")
Near(modifiers:Get(), tuning.STAGES[2].effects.damage)
assert(player.components.locomotor.speed.momentum == nil, "Rise has no speed effect")
assert(player.net_momentum_value.v == math.floor(ceiling + 0.5) and player.net_momentum_stage.v == 2)

-- Hits add gauge by priority; a boss in range lifts the ceiling to the next stage.
local boss = NewEntity("bearger", { _combat = true, epic = true })
Advance(0.5)
assert(momentum:GetCeiling() > ceiling)
local before = momentum.value
player:PushEvent("onhitother", { target = boss, damageresolved = 10 })
Near(momentum.value, before + tuning.HIT_GAIN.high)
player:PushEvent("onhitother", { target = boss, damageresolved = 0 })
Near(momentum.value, before + tuning.HIT_GAIN.high)
Advance(60)
Near(momentum.value, momentum:GetCeiling())
assert(momentum:GetStage() >= 3)
assert(player.components.locomotor.speed.momentum ~= nil)

-- Hysteresis: dipping below enter but above exit keeps the stage.
momentum.value = tuning.STAGES[3].enter - 1
momentum:Recompute()
Stage("surge")
momentum.value = tuning.STAGES[3].exit - 1
momentum:Recompute()
Stage("rise")
momentum.value = tuning.STAGES[3].enter
momentum:Recompute()
Stage("surge")

-- Damage taken is the main source and is capped per hit.
momentum.value = 0
momentum:Recompute()
SetHealth(player, 1)
player:PushEvent("attacked", { attacker = boss, damageresolved = 10 })
Near(momentum.value, 10 / 100 * tuning.DAMAGED_SCALE)
momentum.value = 0
player:PushEvent("attacked", { attacker = boss, damageresolved = 90 })
Near(momentum.value, tuning.DAMAGED_MAX)
local value = momentum.value
player:PushEvent("attacked", { attacker = player, damageresolved = 50 })
player:PushEvent("attacked", { attacker = boss, damageresolved = 50, redirected = true })
player:PushEvent("attacked", { attacker = boss, damageresolved = 0 })
Near(momentum.value, value)

-- Kills add gauge by victim priority, and the gauge never exceeds MAX.
momentum.value = 0
player:PushEvent("killed", { victim = boss })
Near(momentum.value, tuning.KILL_GAIN.high)
for _ = 1, 20 do player:PushEvent("killed", { victim = boss }) end
Near(momentum.value, MAX)
Stage("zenith")

-- Last stand: deterministic by health band and gauge, stage-based when critical.
SetHealth(player, 0.5)
local expected_band
for _, band in ipairs(tuning.HEALTH_BANDS) do
    if 0.5 <= band[1] then expected_band = band break end
end
Near(momentum:GetLastStand(), expected_band[3])
momentum.value = 0
assert(momentum:GetLastStand() == nil, "An empty gauge has no last stand")
momentum.value = MAX / 2
Near(momentum:GetLastStand(), expected_band[2] + (expected_band[3] - expected_band[2]) / 2)
SetHealth(player, 0.01)
momentum.value = MAX
momentum:Recompute()
Near(momentum:GetLastStand(), tuning.CRITICAL_MULTIPLIERS[4])
Near(modifiers:Get(), math.min(tuning.DAMAGE_CAP, tuning.CRITICAL_MULTIPLIERS[4] * tuning.STAGES[4].effects.damage))
SetHealth(player, 1)

-- Sources multiply, are capped, and unrelated modifiers survive.
modifiers:SetModifier(player, 1.2, "unrelated")
momentum:SetSource("low_health", { damage = 1.75 })
Near(modifiers:Get(), 1.2 * momentum:GetEffect("damage"))
assert(momentum:GetEffect("damage") <= tuning.DAMAGE_CAP)
momentum:SetSource("big", { damage = 100 })
Near(momentum:GetEffect("damage"), tuning.DAMAGE_CAP)
momentum:SetSource("big", nil)
momentum:SetSource("low_health", nil)
modifiers:RemoveModifier(player, "unrelated")

-- Spending: refuses without side effects, then pays and demotes the stage.
momentum.value = 20
momentum:Recompute()
assert(not momentum:Spend(30) and momentum.value == 20)
momentum.value = MAX
momentum:Recompute()
local spent
player:ListenForEvent("momentumspent", function(_, data) spent = data end)
assert(momentum:Spend(30) and spent.amount == 30)
Near(momentum.value, MAX - 30)
Stage("surge")

-- Decay: nothing while recent activity, then drains toward the ceiling.
for _, enemy in ipairs({ boss, frog }) do enemy.x = 100 end
Advance(0.5)
assert(tracker:GetThreat() == 0)
momentum.value = 50
momentum.last_activity = GetTime()
momentum:Recompute()
Advance(tuning.DECAY_DELAY - 1)
Near(momentum.value, 50)
Advance(tuning.DECAY_DELAY)
assert(momentum.value < 50)
Advance(60)
assert(momentum.value == 0 and not momentum:IsActive())
assert(momentum.task == nil, "Ticker stops once drained")
Near(modifiers:Get(), 1)
assert(player.components.locomotor.speed.momentum == nil)

-- Soft decay toward a nonzero ceiling while a small threat remains.
frog.x = 0
Advance(0.5)
momentum.value = MAX
momentum.last_activity = GetTime() - tuning.DECAY_DELAY
local soft_start = momentum.value
momentum:Wake()
Advance(1)
Near(momentum.value, soft_start - tuning.SOFT_DECAY_RATE * 1)
Advance(60)
Near(momentum.value, momentum:GetCeiling())

-- Area danger lifts the threat floor.
player.area = { tags = { "Atrium" } }
player:PushEvent("changearea")
assert(tracker:GetThreat() >= tuning.AREA_THREAT)
player.area = nil
player:PushEvent("changearea")

-- Persistence and long updates.
frog.x = 100
Advance(0.5)
momentum.value = 80
momentum:Recompute()
local data = Copy(momentum:OnSave())
momentum.value = 0
momentum:OnLoad(data)
Near(momentum.value, 80)
Stage("surge")
momentum:LongUpdate(1000)
assert(momentum.value == 0, "Long skips drain the gauge")
Near(modifiers:Get(), 1)

-- Death and revival.
momentum.value = 90
momentum:Recompute()
SetHealth(player, 0)
player:PushEvent("death")
assert(momentum.value == 0 and momentum.task == nil)
Near(modifiers:Get(), 1)
player:PushEvent("onhitother", { target = boss, damageresolved = 10 })
assert(momentum.value == 0, "A dead player gains nothing")
SetHealth(player, 0.5)
player:PushEvent("ms_respawnedfromghost")
Stage("calm")

-- A second player owns an independent tracker and gauge.
local other = NewPlayer(1000)
local near_other = NewEntity("hound", { _combat = true, hostile = true }, 1000)
Advance(0.5)
assert(other.components.enemytracker:GetMarks()[near_other] ~= nil)
assert(tracker:GetMarks()[near_other] == nil)
other.components.enemytracker:OnRemoveFromEntity()
other.components.momentum:OnRemoveFromEntity()
Near(other.components.combat.externaldamagemultipliers:Get(), 1)

-- Cleanup.
momentum:SetSource("low_health", { damage = 1.5 })
tracker:OnRemoveFromEntity()
momentum:OnRemoveFromEntity()
tracker:OnRemoveFromEntity()
momentum:OnRemoveFromEntity()
assert(#player.listeners.attacked == 0 and #player.listeners.changearea == 0)
assert(#player.listeners.killed == 0 and #player.listeners.kiritzuka_dangerchanged == 0)
Near(modifiers:Get(), 1)
print("PASS: threat, sources, stages, hysteresis, last stand, effect bus, spending, decay, persistence and cleanup")
