-- Run from the mod directory: lua tests/kiritzuka_armor_break.lua
package.path = "scripts/?.lua;" .. package.path
TUNING = {
    GAMEMODE_STARTING_ITEMS = { DEFAULT = { KIRITZUKA = {} } },
    KIRITZUKA_ARMOR_BREAK = { STEP = 0.05, MAX_STACKS = 10, WINDOW = 5 },
    KIRITZUKA_CRIT = { CHANCE = { 0 }, MULTIPLIER = { 2 }, CHANCE_STEP = 0, MOMENTUM_GAIN = 5, FX_COUNT = 3, FX_TOWARD = 0.85 },
    KIRITZUKA_BOSS_SLAM = { RADIUS = 6, IMPACT_BURSTS = 0, HIT_BURSTS = 0 },
}
STRINGS = dofile("strings/common.lua")
EQUIPSLOTS = { HANDS = "hands", BODY = "body" }
CAMERASHAKE = { VERTICAL = 1 }
TheNet = { GetServerGameMode = function() return "default" end }
FlattenTree = function(tree) return tree[1] end
Asset = function() end
ShakeAllCameras = function() end
package.loaded["components/spdamageutil"] = {}
local now = 0
GetTime = function() return now end
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
TheWorld = { Map = { IsPassableAtPoint = function() return true end } }

local master
package.loaded["prefabs/player_common"] = function(_, _, _, _, master_fn) master = master_fn end
dofile("scripts/prefabs/kiritzuka.lua")
local real_random = math.random
math.random = function(a) return a or 1 end -- never crits

local function Near(a, b)
    return math.abs(a - b) < 0.0001
end

local function Player()
    local listeners = {}
    local inst = { weapon = { prefab = "baseballbat" }, listeners = listeners }
    inst.AddComponent = function() end
    inst.HasTag = function() return false end
    inst.ListenForEvent = function(_, event, fn)
        listeners[event] = listeners[event] or {}
        table.insert(listeners[event], fn)
    end
    inst.DoTaskInTime = function(self, _, fn, ...) fn(self, ...) end
    inst.Transform = { GetWorldPosition = function() return 0, 0, 0 end }
    inst.AnimState = { SetScale = function() end }
    inst.SoundEmitter = { PlaySound = function() end }
    inst.components = {
        hunger = { SetMax = function() end },
        sanity = { SetMax = function() end },
        health = { SetMaxHealth = function() end },
        talker = { Say = function() end },
        combat = {
            GetWeapon = function() return inst.weapon end,
            CanTarget = function() return true end,
            IsAlly = function() return false end,
        },
    }
    master(inst)
    return inst
end

local function Target()
    local target = { taken = {} }
    target.IsValid = function() return true end
    target.IsInLimbo = function() return false end
    target.HasTag = function() return false end
    target.HasAnyTag = function() return false end
    target.Transform = { GetWorldPosition = function() return 4, 0, 0 end }
    target.components = {
        health = { IsDead = function() return false end },
        combat = { GetAttacked = function(_, _, damage) table.insert(target.taken, damage) end },
    }
    return target
end

local function Land(player, target, resolved)
    for _, fn in ipairs(player.listeners.onhitother) do
        fn(player, { target = target, damageresolved = resolved or 10 })
    end
end

local function Mult(player, target)
    return player.components.combat.customdamagemultfn(player, target)
end

-- Each landed hit adds five percent on the next one, and planar damage follows.
local player = Player()
local target = Target()
assert(Mult(player, target) == 1, "The first hit has nothing to build on")
Land(player, target)
assert(Near(Mult(player, target), 1.05))
assert(Near(player.components.combat.customspdamagemultfn(player), 1.05), "Planar damage follows")
Land(player, target)
assert(Near(Mult(player, target), 1.1))

-- It tops out at ten stacks, and marks that moment once on the target.
spawned = {}
for _ = 1, 7 do Land(player, target) end
assert(#spawned == 0, "Not full yet")
Land(player, target)
assert(Near(Mult(player, target), 1.5))
assert(#spawned == 1 and spawned[1].name == "kiritzuka_hit_fx_impact" and spawned[1].x == 4)
Land(player, target)
assert(Near(Mult(player, target), 1.5), "Capped")
assert(#spawned == 1, "Marked once")

-- Stacks belong to one target: hitting another starts over.
local other = Target()
assert(Mult(player, other) == 1, "Others take no bonus")
Land(player, other)
assert(Near(Mult(player, other), 1.05))
assert(Mult(player, target) == 1, "The old target has lost it")

-- A pause drops the stacks, and each hit refreshes the clock.
player = Player()
target = Target()
now = 100
Land(player, target)
now = 104.9
assert(Near(Mult(player, target), 1.05))
Land(player, target)
now = 109.8
assert(Near(Mult(player, target), 1.1), "The hit refreshed the window")
now = 115
assert(Mult(player, target) == 1, "Too long without a hit")
Land(player, target)
assert(Near(Mult(player, target), 1.05), "Starts again from one")

-- A hit that did no damage adds nothing.
player = Player()
target = Target()
Land(player, target, 0)
assert(Mult(player, target) == 1)

-- Only the exclusive weapons build stacks.
for _, prefab in ipairs({ "pickaxe", "spear" }) do
    player = Player()
    player.weapon.prefab = prefab
    target = Target()
    Land(player, target)
    assert(Mult(player, target) == 1, prefab)
end
player = Player()
player.weapon = nil
target = Target()
Land(player, target)
assert(Mult(player, target) == 1, "Unarmed")

-- Changing weapons clears them; other slots do not.
player = Player()
target = Target()
Land(player, target)
for _, fn in ipairs(player.listeners.unequip) do fn(player, { eslot = EQUIPSLOTS.BODY }) end
assert(Near(Mult(player, target), 1.05))
for _, fn in ipairs(player.listeners.unequip) do fn(player, { eslot = EQUIPSLOTS.HANDS }) end
assert(Mult(player, target) == 1)

-- It multiplies with a crit, and a crit still reads as a crit.
player = Player()
target = Target()
Land(player, target)
TUNING.KIRITZUKA_CRIT.CHANCE = { 2 }
assert(Near(Mult(player, target), 2.1))
assert(player.kiritzuka_crit_hit == true)
assert(Near(player.components.combat.customspdamagemultfn(player), 2.1))
TUNING.KIRITZUKA_CRIT.CHANCE = { 0 }

-- The slam cashes in the stacks without adding any of its own.
player = Player()
target = Target()
local bystander = Target()
Land(player, target)
Land(player, target)
entities = { target, bystander }
player:DoSlamHit({ x = 0, y = 0, z = 0 }, 100)
assert(Near(target.taken[1], 110) and bystander.taken[1] == 100, "Only the worked-over target")
assert(Near(Mult(player, target), 1.1), "No stack from the slam")

math.random = real_random
print("kiritzuka_armor_break: checks passed")
