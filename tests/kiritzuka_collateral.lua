-- Run from the mod directory: lua tests/kiritzuka_collateral.lua
package.path = "scripts/?.lua;" .. package.path
TUNING = {
    GAMEMODE_STARTING_ITEMS = { DEFAULT = { KIRITZUKA = {} } },
    KIRITZUKA_ARMOR_BREAK = { STEP = 0.05, MAX_STACKS = 10, WINDOW = 5 },
    KIRITZUKA_CRIT = { CHANCE = { 0 }, MULTIPLIER = { 2 }, CHANCE_STEP = 0, MOMENTUM_GAIN = 5, FX_COUNT = 3, FX_TOWARD = 0.85 },
    KIRITZUKA_COLLATERAL = { RADIUS = 2, DAMAGE_MULT = 0.25 },
}
STRINGS = dofile("strings/common.lua")
EQUIPSLOTS = { HANDS = "hands", BODY = "body" }
TheNet = { GetServerGameMode = function() return "default" end }
FlattenTree = function(tree) return tree[1] end
Asset = function() end
GetTime = function() return 0 end
package.loaded["components/spdamageutil"] = {}
package.loaded["prefabs/player_common_extensions"] = {}
FRAMES = 1 / 30
SpawnPrefab = function() return { Transform = { SetPosition = function() end } } end
local search
local entities = {}
TheSim = {
    FindEntities = function(_, x, _, z, radius, must, cant)
        search = { x = x, z = z, radius = radius, must = must, cant = cant }
        return entities
    end,
}

local master
package.loaded["prefabs/player_common"] = function(_, _, _, _, master_fn) master = master_fn end
dofile("scripts/prefabs/kiritzuka.lua")

local function Player()
    local listeners = {}
    local inst = { listeners = listeners, untargetable = {} }
    inst.AddComponent = function() end
    inst.HasTag = function() return false end
    inst.ListenForEvent = function(_, event, fn)
        listeners[event] = listeners[event] or {}
        table.insert(listeners[event], fn)
    end
    inst.AnimState = { SetScale = function() end }
    inst.sg = { currentstate = { name = "kiritzuka_attack" }, statemem = {} }
    inst.components = {
        hunger = { SetMax = function() end },
        sanity = { SetMax = function() end },
        health = { SetMaxHealth = function() end },
        rider = { IsRiding = function() return inst.riding == true end },
        combat = {
            GetWeapon = function() return nil end,
            CanTarget = function(_, target) return not inst.untargetable[target] end,
        },
    }
    master(inst)
    return inst
end

local function Creature(x, dead)
    local creature = { taken = {} }
    creature.IsValid = function() return true end
    creature.Transform = { GetWorldPosition = function() return x, 0, 0 end }
    creature.components = {
        health = { IsDead = function() return dead == true end },
        combat = {
            GetAttacked = function(_, attacker, damage)
                table.insert(creature.taken, { attacker = attacker, damage = damage })
            end,
        },
    }
    return creature
end

local function Weapon(ranged, thrown)
    return {
        HasTag = function(_, tag) return ranged and tag == "rangedweapon" end,
        components = { projectile = thrown and {} or nil },
    }
end

local function Land(player, target, damage, weapon)
    for _, fn in ipairs(player.listeners.onhitother) do
        fn(player, { target = target, damage = damage, damageresolved = damage, weapon = weapon })
    end
end

local function Has(list, value)
    for _, item in ipairs(list) do
        if item == value then return true end
    end
    return false
end

-- A plain swing carries into whatever stands beside the target, for a quarter of the blow.
local player = Player()
local target = Creature(4)
local follower, dead, spared = Creature(5), Creature(5, true), Creature(5)
player.untargetable[spared] = true
entities = { target, player, follower, dead, spared }
Land(player, target, 40)
assert(search.x == 4 and search.z == 0 and search.radius == 2, "Centred on the target")
assert(Has(search.must, "_combat") and Has(search.must, "_health"))
for _, tag in ipairs({ "player", "companion", "structure", "wall", "INLIMBO", "notarget" }) do
    assert(Has(search.cant, tag), "Never " .. tag)
end
assert(#follower.taken == 1 and follower.taken[1].attacker == player and follower.taken[1].damage == 10)
assert(#target.taken == 0, "The target already took the blow itself")
assert(#dead.taken == 0 and #spared.taken == 0, "Nor the dead, nor what she can't target")

-- Unarmed, the punch carries too; native attack is where an unarmed swing goes.
player.sg.currentstate = { name = "attack" }
follower.taken = {}
Land(player, target, 20)
assert(#follower.taken == 1 and follower.taken[1].damage == 5)

-- Skills, shots, throws, the saddle and blows that did nothing leave the rest alone.
local function Untouched(setup, damage, weapon)
    local p = Player()
    setup(p)
    local bystander = Creature(5)
    entities = { bystander }
    Land(p, target, damage or 40, weapon)
    return #bystander.taken == 0
end
assert(Untouched(function(p) p.sg.currentstate = { name = "kiritzuka_flurry" } end), "Skills have their own reach")
assert(Untouched(function() end, nil, Weapon(true)), "Staffs")
assert(Untouched(function() end, nil, Weapon(false, true)), "Darts and boomerangs")
assert(Untouched(function(p) p.riding = true end), "Not her mount")
assert(Untouched(function() end, 0), "Nothing to carry")
assert(not Untouched(function() end, nil, Weapon(false, false)), "A melee weapon swings as usual")

-- Like native combat, each spill-over hit pushes onhitother on her again. In a crowd that must
-- not spill over once more: each bystander takes one share, and the frogs never hit each other.
do
    local p = Player()
    local main = Creature(4)
    local frogs = {}
    for i = 1, 6 do
        frogs[i] = Creature(4 + i * 0.1)
        local frog = frogs[i]
        frog.components.combat.GetAttacked = function(_, attacker, damage)
            table.insert(frog.taken, { attacker = attacker, damage = damage })
            Land(attacker, frog, damage)
        end
    end
    entities = { main, frogs[1], frogs[2], frogs[3], frogs[4], frogs[5], frogs[6] }
    Land(p, main, 40)
    for _, frog in ipairs(frogs) do
        assert(#frog.taken == 1 and frog.taken[1].damage == 10, "One share each, no chain")
    end
    assert(#main.taken == 0, "The spill-over never comes back to the target")
    assert(not p.kiritzuka_hitting_collateral, "Free for the next swing")
    Land(p, main, 40)
    assert(#frogs[1].taken == 2, "The next swing carries again")
end

print("kiritzuka_collateral: checks passed")
