-- Run from the mod directory: lua tests/kiritzuka_destruction.lua
package.path = "scripts/?.lua;" .. package.path
TUNING = {
    GAMEMODE_STARTING_ITEMS = { DEFAULT = { KIRITZUKA = {} } },
    KIRITZUKA_DASH = { WIDTH = 2.5, DAMAGE_MULT = { 1, 1, 2 } },
    KIRITZUKA_CRIT = { CHANCE = { 0 }, MULTIPLIER = { 2 }, CHANCE_STEP = 0, MOMENTUM_GAIN = 5, FX_COUNT = 3, FX_TOWARD = 0.85 },
    KIRITZUKA_ARMOR_BREAK = { STEP = 0.05, MAX_STACKS = 10, WINDOW = 5 },
    KIRITZUKA_BOSS_SLAM = { RADIUS = 6, IMPACT_BURSTS = 0, HIT_BURSTS = 0 },
}
STRINGS = dofile("strings/common.lua")
CAMERASHAKE = { VERTICAL = 1 }
TheNet = { GetServerGameMode = function() return "default" end }
FlattenTree = function(tree) return tree[1] end
Asset = function() end
ShakeAllCameras = function() end
GetTime = function() return 0 end
math.clamp = math.clamp or function(value, low, high) return math.min(math.max(value, low), high) end
package.loaded["components/spdamageutil"] = {}
SpawnPrefab = function()
    local fx = {}
    fx.Transform = { SetPosition = function() end, SetScale = function() end, SetRotation = function() end }
    return fx
end
TheWorld = { Map = {
    IsPassableAtPoint = function() return true end,
    IsOceanTileAtPoint = function() return false end,
    GetPlatformAtPoint = function() return nil end,
} }

-- The search returns what is in the radius and asked for by tag, like the real one.
local world, searches = {}, {}
TheSim = {
    FindEntities = function(_, x, _, z, radius, must, cant, oneof)
        searches[#searches + 1] = { cant = cant, oneof = oneof }
        local found = {}
        for _, entity in ipairs(world) do
            if oneof ~= nil and (entity.x - x) ^ 2 + (entity.z - z) ^ 2 <= radius * radius then
                found[#found + 1] = entity
            end
        end
        return found
    end,
}

local master
package.loaded["prefabs/player_common"] = function(_, _, _, _, master_fn) master = master_fn end
dofile("scripts/prefabs/kiritzuka.lua")

local function Player()
    local inst = {}
    inst.AddComponent = function() end
    inst.HasTag = function() return false end
    inst.ListenForEvent = function() end
    inst.DoTaskInTime = function(self, _, fn, ...) fn(self, ...) end
    inst.Transform = { GetWorldPosition = function() return 0, 0, 0 end, GetRotation = function() return 0 end }
    inst.AnimState = { SetScale = function() end }
    inst.SoundEmitter = { PlaySound = function() end }
    inst.components = {
        hunger = { SetMax = function() end },
        sanity = { SetMax = function() end },
        health = { SetMaxHealth = function() end },
        talker = { Say = function(_, line) inst.said = line end },
        combat = {
            GetWeapon = function() end,
            CanTarget = function() return true end,
            IsAlly = function() return false end,
        },
    }
    master(inst)
    return inst
end

local function Workable(x, z, action, tags, components)
    local thing = { x = x, z = z, tags = tags or {}, valid = true, components = components or {} }
    thing.IsValid = function(self) return self.valid end
    thing.HasTag = function(self, tag) return self.tags[tag] == true end
    thing.Remove = function(self) self.valid = false; self.removed = true end
    thing.GetPhysicsRadius = function() return 0.5 end
    thing.Transform = { GetWorldPosition = function() return thing.x, 0, thing.z end }
    thing.components.workable = {
        CanBeWorked = function() return not thing.spent end,
        GetWorkAction = function() return action and { id = action } or nil end,
        Destroy = function(_, destroyer)
            thing.destroyed_by = destroyer
            if thing.becomes_stump then
                thing.tags.stump = true
            end
        end,
    }
    return thing
end

-- Off until asked for, with a line each way.
local player = Player()
assert(not player.kiritzuka_destruction)
local tree = Workable(1, 0, "CHOP")
world = { tree }
player:DoSlamHit({ x = 0, y = 0, z = 0 }, 100)
assert(tree.destroyed_by == nil, "Nothing breaks while off")
assert(player:ToggleDestruction() and player.kiritzuka_destruction)
assert(player.said == STRINGS.SKILL.KIRITZUKA_DESTROY_ON)
assert(player:ToggleDestruction() and not player.kiritzuka_destruction)
assert(player.said == STRINGS.SKILL.KIRITZUKA_DESTROY_OFF)
assert(player:ToggleDestruction())

-- The slam levels what is in its radius, of every kind the list names, and asks by the right tags.
local rock = Workable(0, 3, "MINE")
local hut = Workable(-3, 0, "HAMMER", { structure = true })
local grave = Workable(2, 2, "DIG")
local wall = Workable(3, 3, "HAMMER", { wall = true }, { combat = {} })
local far = Workable(30, 0, "CHOP")
world = { tree, rock, hut, grave, wall, far }
searches = {}
player:DoSlamHit({ x = 0, y = 0, z = 0 }, 100)
for _, thing in ipairs({ tree, rock, hut, grave, wall }) do
    assert(thing.destroyed_by == player, "Levelled")
end
assert(far.destroyed_by == nil, "Outside the radius")
assert(searches[1].oneof ~= nil, "Finds by work tag")
local cant = {}
for _, tag in ipairs(searches[1].cant) do cant[tag] = true end
assert(cant.boat and cant.INLIMBO and cant.FX, "Never the boat underfoot")

-- Things it leaves alone.
local function Survives(thing, label)
    world = { thing }
    player:DoSlamHit({ x = 0, y = 0, z = 0 }, 100)
    assert(thing.destroyed_by == nil, label)
end
Survives(Workable(1, 0, "NET"), "Other work actions")
Survives(Workable(1, 0, nil), "No work action")
Survives(Workable(1, 0, "MINE", nil, { combat = {}, health = {} }), "Fighters that can be mined, like the Rock Master's boulder")
Survives(Workable(1, 0, "DIG", nil, { spawner = {} }), "A spawner dug up would be gone for good")
Survives(Workable(1, 0, "DIG", nil, { childspawner = {} }), "Same for its children")
local spent = Workable(1, 0, "CHOP")
spent.spent = true
Survives(spent, "Already spent")

-- A Poison Birchnut fights back but has no health to fight, so it falls like any other tree.
local poison_birchnut = Workable(1, 0, "CHOP", { monster = true }, { combat = {} })
world = { poison_birchnut }
player:DoSlamHit({ x = 0, y = 0, z = 0 }, 100)
assert(poison_birchnut.destroyed_by == player, "Felled")

-- A felled tree leaves its stump, and later hits leave the stump alone.
local felled = Workable(1, 0, "CHOP")
felled.becomes_stump = true
world = { felled }
player:DoSlamHit({ x = 0, y = 0, z = 0 }, 100)
assert(felled.destroyed_by == player and not felled.removed, "Felled, not uprooted")
Survives(Workable(1, 0, "DIG", { stump = true }), "Stumps stay")

-- The dash levels only the line it travels.
local on_line = Workable(5, 1, "CHOP")
local off_line = Workable(5, 6, "CHOP")
world = { on_line, off_line }
player:SweepDash({ x = 0, z = 0 }, { x = 10, z = 0 }, 1, {})
assert(on_line.destroyed_by == player)
assert(off_line.destroyed_by == nil)

player:ToggleDestruction()
local spared = Workable(5, 1, "CHOP")
world = { spared }
player:SweepDash({ x = 0, z = 0 }, { x = 10, z = 0 }, 1, {})
assert(spared.destroyed_by == nil, "Nothing breaks once switched off")

print("kiritzuka_destruction: checks passed")
