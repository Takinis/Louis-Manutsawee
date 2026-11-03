-- Run from the mod directory: lua tests/kiritzuka_damage.lua
package.path = "scripts/?.lua;" .. package.path
math.clamp = math.clamp or function(value, low, high)
    return math.min(math.max(value, low), high)
end

local planar_defense = {}
package.loaded["components/spdamageutil"] = {
    GetSpDefenseForType = function(ent) return planar_defense[ent] or 0 end,
}
TUNING = { GAMEMODE_STARTING_ITEMS = { DEFAULT = { KIRITZUKA = {} } } }
TheNet = { GetServerGameMode = function() return "default" end }
FlattenTree = function() return {} end
Asset = function() end
local master
package.loaded["prefabs/player_common"] = function(_, _, _, _, master_fn) master = master_fn end
dofile("scripts/prefabs/kiritzuka.lua")

local function Mult(value)
    return { Get = function() return value end }
end

local attacker = {
    prefab = "kiritzuka",
    HasTag = function(_, tag) return tag == "player" end,
    AddComponent = function() end,
    ListenForEvent = function() end,
    AnimState = { SetScale = function() end },
    components = {
        combat = {},
        health = { SetMaxHealth = function() end },
        hunger = { SetMax = function() end },
        sanity = { SetMax = function() end },
    },
}
master(attacker)

local function Target()
    return {
        components = {
            combat = { externaldamagetakenmultipliers = Mult(1) },
            health = { absorb = 0, playerabsorb = 0, externalabsorbmodifiers = Mult(0) },
        },
    }
end

local function Near(a, b)
    return math.abs(a - b) < 0.0001
end

-- Forward pass mirroring Combat:GetAttacked_Internal for the parts the offset reverses.
local function Resolve(target, damage, spdamage)
    local components = target.components
    local combat, health = components.combat, components.health
    local absorbed, equip_resist = 0, 1
    local sp = spdamage ~= nil and spdamage.planar or nil
    if components.inventory ~= nil then
        for _, equip in pairs(components.inventory.equipslots) do
            if equip.components.armor ~= nil then
                absorbed = math.max(absorbed, equip.components.armor:GetAbsorption() or 0)
            end
            if equip.components.damagetyperesist ~= nil then
                equip_resist = equip_resist * equip.components.damagetyperesist:GetResist()
            end
        end
    end
    damage = damage * equip_resist * (1 - absorbed)
    if sp ~= nil then
        sp = sp * equip_resist
        if components.inventory ~= nil then
            for _, equip in pairs(components.inventory.equipslots) do
                sp = sp - (planar_defense[equip] or 0)
            end
        end
    end
    local resist = components.damagetyperesist ~= nil and components.damagetyperesist:GetResist() or 1
    if combat.conditionexternaldamagetakenmultipliers ~= nil then
        damage = resist * combat:ApplyConditionExternalDamageTakenMultiplier(damage)
    end
    damage = damage * resist * combat.externaldamagetakenmultipliers:Get()
    if damage > 0 and components.planarentity ~= nil then
        damage = (math.sqrt(damage * 4 + 64) - 8) * 4
    end
    if sp ~= nil then
        damage = damage + resist * math.max(sp - (planar_defense[target] or 0), 0)
    end
    local absorb = health.absorb + (health.playerabsorb ~= 0 and health.playerabsorb or 0)
    return damage * math.clamp(1 - absorb, 0, 1) * math.max(1 - health.externalabsorbmodifiers:Get(), 0)
end

local function Check(target, label, physical, planar)
    local expected = physical + (planar or 0)
    local damage, spdamage = attacker:OffsetTargetDefense(target, nil, physical, planar and { planar = planar } or nil)
    assert(Near(Resolve(target, damage, spdamage), expected), label)
end

-- No defense: the numbers are untouched.
local target = Target()
local damage, spdamage = attacker:OffsetTargetDefense(target, nil, 34, { planar = 10 })
assert(damage == 34 and spdamage.planar == 10, "No defense means no offset")

target = Target()
target.components.health.absorb = .5
Check(target, "Health absorb", 34, 10)

target = Target()
target.components.health.playerabsorb = .25
Check(target, "Player absorb", 34)

target = Target()
target.components.health.externalabsorbmodifiers = Mult(.75)
Check(target, "External absorb", 34, 10)

target = Target()
target.components.combat.externaldamagetakenmultipliers = Mult(.5)
Check(target, "Damage taken multiplier", 34)

target = Target()
target.components.damagetyperesist = { GetResist = function() return .8 end }
Check(target, "Type resist", 34, 10)

target = Target()
target.components.damagetyperesist = { GetResist = function() return .8 end }
target.components.combat.conditionexternaldamagetakenmultipliers = {}
target.components.combat.ApplyConditionExternalDamageTakenMultiplier = function(_, value) return value * .5 end
Check(target, "Conditional multiplier", 34)

target = Target()
target.components.planarentity = {}
Check(target, "Planar entity dampening", 600)

target = Target()
planar_defense[target] = 15
Check(target, "Planar defense", 34, 10)

target = Target()
target.components.planarentity = {}
planar_defense[target] = 15
target.components.health.absorb = .25
Check(target, "Planar defense, dampening and absorb stack", 34, 10)

target = Target()
local armor = { components = {
    armor = { GetAbsorption = function() return .8 end },
    damagetyperesist = { GetResist = function() return .5 end },
} }
planar_defense[armor] = 5
target.components.inventory = { equipslots = { body = armor } }
Check(target, "Worn armor", 34, 10)

-- Vulnerability and immunity are not defense.
target = Target()
target.components.combat.externaldamagetakenmultipliers = Mult(2)
damage = attacker:OffsetTargetDefense(target, nil, 34)
assert(damage == 34, "Vulnerability stays a bonus")

target = Target()
target.components.combat.externaldamagetakenmultipliers = Mult(0)
damage = attacker:OffsetTargetDefense(target, nil, 34)
assert(damage == 34, "Immunity is not divided by zero")

target = Target()
target.components.health.absorb = 1
damage = attacker:OffsetTargetDefense(target, nil, 34)
assert(damage == 34, "Full absorb stays immune")

-- The combat hook only offsets Kiritzuka's hits, and leaves redirected ones to the final target.
GLOBAL = _G
GLOBAL.setfenv = function() end
AddComponentPostInit = function() end
package.loaded["utils/skillutil"] = {}
local received
local Combat = {
    StartAttack = function() end,
    GetAttacked_Internal = function(_, _, damage) received = damage end,
}
package.loaded["components/combat"] = Combat
dofile("postinit/components/combat.lua")

target = Target()
target.components.health.absorb = .5
local combat = setmetatable({ inst = target }, { __index = Combat })
for key, value in pairs(target.components.combat) do combat[key] = value end
target.components.combat = combat

combat:GetAttacked_Internal(attacker, 34)
assert(received == 68, "Kiritzuka's hits go through the offset")
combat:GetAttacked_Internal({ prefab = "wilson", HasTag = attacker.HasTag }, 34)
assert(received == 34, "Other attackers are untouched")
combat:GetAttacked_Internal(nil, 34)
assert(received == 34, "Attacks without an attacker are untouched")
combat:GetAttacked_Internal(attacker, nil)
assert(received == nil, "Attacks without damage are untouched")
combat.redirectdamagefn = function() end
combat:GetAttacked_Internal(attacker, 34)
assert(received == 34, "A redirecting target does not offset")

print("kiritzuka_damage: checks passed")
