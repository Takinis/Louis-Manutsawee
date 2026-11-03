-- Run from the mod directory: lua tests/kiritzuka_crit.lua
package.path = "scripts/?.lua;" .. package.path
TUNING = {
    GAMEMODE_STARTING_ITEMS = { DEFAULT = { KIRITZUKA = {} } },
    KIRITZUKA_CRIT = {
        CHANCE = { 0.1, 0.15, 0.2, 0.25 },
        CHANCE_STEP = 0.05,
        MULTIPLIER = { 1.5, 1.5, 1.5, 2 },
        MOMENTUM_GAIN = 5,
        FX_COUNT = 3,
        FX_TOWARD = 0.85,
    },
    KIRITZUKA_ARMOR_BREAK = { STEP = 0.05, MAX_STACKS = 10, WINDOW = 5 },
    KIRITZUKA_BOSS_SLAM = { DAMAGE = 600, HITS = 5, RADIUS = 6, IMPACT_BURSTS = 0, HIT_BURSTS = 0 },
}
CAMERASHAKE = { VERTICAL = 1 }
TheNet = { GetServerGameMode = function() return "default" end, IsDedicated = function() return false end }
FlattenTree = function(tree) return tree[1] end
Asset = function() end
package.loaded["components/spdamageutil"] = {}
GetTime = function() return 0 end
local shakes = 0
ShakeAllCameras = function() shakes = shakes + 1 end
local spawned = {}
SpawnPrefab = function(name)
    local fx = { name = name }
    fx.Transform = {
        SetPosition = function(_, x, y, z) fx.x, fx.y, fx.z = x, y, z end,
        SetScale = function() end,
    }
    spawned[#spawned + 1] = fx
    return fx
end
local entities = {}
TheSim = { FindEntities = function() return entities end }

local master
local dependencies
package.loaded["prefabs/player_common"] = function(_, prefabs, _, _, master_fn)
    dependencies, master = prefabs, master_fn
end
dofile("scripts/prefabs/kiritzuka.lua")

local roll = 1
math.random = function(low, high)
    if low ~= nil then
        return high or low
    end
    return roll
end

local listeners, stage, gained = {}, 1, 0
local player = {
    AddComponent = function() end,
    AnimState = { SetScale = function() end },
    SoundEmitter = { PlaySound = function() end },
    DoTaskInTime = function(self, _, fn, ...) fn(self, ...) end,
    Transform = { GetWorldPosition = function() return 0, 0, 0 end },
    sg = { statemem = {} },
    components = {
        combat = { GetWeapon = function() return nil end },
        health = { SetMaxHealth = function() end },
        hunger = { SetMax = function() end },
        sanity = { SetMax = function() end },
        momentum = {
            GetStage = function() return stage end,
            GetEffect = function() return 1 end,
            Spend = function() return true end,
            Gain = function(_, amount) gained = gained + amount end,
        },
    },
    ListenForEvent = function(_, event, fn)
        listeners[event] = listeners[event] or {}
        table.insert(listeners[event], fn)
    end,
}
master(player)
local combat = player.components.combat

local function Near(a, b)
    return math.abs(a - b) < 0.000001
end

-- Chance per stage, ten points above the plan's base table.
for index, chance in ipairs({ 0.1, 0.15, 0.2, 0.25 }) do
    stage = index
    player.kiritzuka_crit_bonus = 0
    roll = chance + 0.001
    assert(combat.customdamagemultfn(player) == 1, "Above the chance misses at stage " .. index)
    player.kiritzuka_crit_bonus = 0
    roll = chance - 0.001
    assert(combat.customdamagemultfn(player) == TUNING.KIRITZUKA_CRIT.MULTIPLIER[index], "Below the chance crits")
end
stage = 4
player.kiritzuka_crit_bonus = 0
roll = 0
assert(combat.customdamagemultfn(player) == 2, "Zenith crits harder")

-- Misses build toward the next crit, and a crit clears them.
stage, roll = 1, 0.195
player.kiritzuka_crit_bonus = 0
assert(combat.customdamagemultfn(player) == 1)
assert(Near(player.kiritzuka_crit_bonus, 0.05))
assert(combat.customdamagemultfn(player) == 1)
assert(combat.customdamagemultfn(player) == 1.5, "Two misses reach a 0.2 chance")
assert(player.kiritzuka_crit_bonus == 0, "A crit clears the build-up")

-- The combo's scythe always crits, and planar damage scales with the same roll.
roll = 1
player.sg.statemem.signature_crit = true
assert(combat.customdamagemultfn(player) == 1.5, "The scythe always crits")
assert(combat.customspdamagemultfn(player) == 1.5, "Planar damage follows the roll")
player.sg.statemem.signature_crit = nil
assert(combat.customdamagemultfn(player) == 1)
assert(combat.customspdamagemultfn(player) == 1, "Planar damage follows a miss too")

local target = {
    Transform = { GetWorldPosition = function() return 4, 0, 2 end },
    IsValid = function() return true end,
}
local function Hit(damage)
    for _, fn in ipairs(listeners.onhitother) do
        fn(player, { target = target, damageresolved = damage })
    end
end

-- Non-signature weapons only show fx when they crit.
spawned, gained, shakes = {}, 0, 0
combat.customdamagemultfn(player)
Hit(10)
assert(#spawned == 0 and gained == 0 and shakes == 0)

-- Signature hits show one fx halfway between the player and the target.
player.sg.statemem.signature_step = 1
combat.customdamagemultfn(player)
Hit(10)
assert(#spawned == 1 and spawned[1].x == 2 and spawned[1].z == 1, "Halfway to the target")
assert(spawned[1].name:find("kiritzuka_hit_fx_", 1, true) == 1, "Use the silent fx")
assert(gained == 0 and shakes == 0)

-- Crits show more fx, shake and feed the gauge once, then clear.
spawned = {}
roll = 0
combat.customdamagemultfn(player)
Hit(10)
assert(#spawned == 3 and gained == 5 and shakes == 1)
assert(Near(spawned[1].x, 3.4) and Near(spawned[1].z, 1.7), "Crit fx land close to the target")
assert(not player.kiritzuka_crit_hit, "The crit is consumed by its hit")
spawned = {}
roll = 1
combat.customdamagemultfn(player)
Hit(0)
assert(gained == 5, "A blocked hit feeds nothing")

-- Every listed fx is a dependency and exists in the silent set.
local real_prefab = {}
Prefab = function(name, fn)
    real_prefab[name] = fn
    return name
end
CreateEntity = function()
    local inst = { tags = {}, tasks = {} }
    local function noop() end
    inst.entity = {
        AddTransform = noop, AddAnimState = noop, AddNetwork = noop, SetPristine = noop, SetCanSleep = noop,
        AddSoundEmitter = function() error("Hit fx must stay silent") end,
    }
    inst.Transform = { SetFourFaced = noop, SetFromProxy = noop }
    inst.AnimState = setmetatable({}, { __index = function() return noop end })
    inst.AddTag = noop
    inst.ListenForEvent = noop
    inst.DoTaskInTime = function(self, _, fn) table.insert(self.tasks, fn) end
    return inst
end
TheWorld = { ismastersim = true, Map = { IsPassableAtPoint = function() return true end } }
dofile("scripts/prefabs/kiritzuka_hit_fx.lua")
local listed = 0
for _, name in ipairs(dependencies) do
    if name:find("kiritzuka_hit_fx_", 1, true) == 1 then
        listed = listed + 1
        local proxy = assert(real_prefab[name], name)()
        for _, task in ipairs(proxy.tasks) do
            if task ~= proxy.Remove then task(proxy) end
        end
    end
end
assert(listed == 4, "Four fx to pick from")

-- Each slam hit rolls once for everything it strikes.
local struck = {}
local function Victim()
    local victim = {
        Transform = target.Transform,
        IsValid = function() return true end,
        IsInLimbo = function() return false end,
        HasTag = function() return false end,
        HasAnyTag = function() return false end,
        components = {
            health = { IsDead = function() return false end },
            combat = { GetAttacked = function(_, _, damage) struck[#struck + 1] = damage end },
        },
    }
    return victim
end
combat.CanTarget = function() return true end
combat.IsAlly = function() return false end
entities = { Victim(), Victim() }
spawned, gained, struck = {}, 0, {}
roll = 0
stage = 1
player.kiritzuka_crit_bonus = 0
player:DoSlamHit({ x = 0, y = 0, z = 0 }, 120)
assert(struck[1] == 180 and struck[2] == 180, "A slam crit applies to the whole hit")
assert(gained == 5, "A slam crit feeds the gauge once")
struck = {}
roll = 1
player:DoSlamHit({ x = 0, y = 0, z = 0 }, 120)
assert(struck[1] == 120 and struck[2] == 120, "A slam miss keeps the base damage")

print("kiritzuka_crit: checks passed")
