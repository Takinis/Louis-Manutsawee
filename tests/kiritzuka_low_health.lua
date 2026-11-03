-- Run from the mod directory: lua tests/kiritzuka_low_health.lua
package.path = "scripts/?.lua;" .. package.path

TUNING = { KIRITZUKA_LOW_HEALTH_DAMAGE = 0.75 }
TUNING.GAMEMODE_STARTING_ITEMS = { DEFAULT = { KIRITZUKA = {} } }
FlattenTree = function() return {} end
TheNet = { GetServerGameMode = function() return "default" end }
STRINGS = dofile("strings/common.lua")
Asset = function() end
math.clamp = function(value, min, max)
    return math.max(min, math.min(max, value))
end

package.loaded["components/spdamageutil"] = {}
local master_postinit
package.loaded["prefabs/player_common"] = function(_, _, _, _, postinit)
    master_postinit = postinit
end
dofile("scripts/prefabs/kiritzuka.lua")

-- Without a skill tree, low health damage is simply always on.
local percent = 1
local ghost = false
local dead = false
local sources = {}
local listeners = {}
local inst = {
    AddComponent = function() end,
    AnimState = { SetScale = function() end },
    components = {
        momentum = { SetSource = function(_, name, effects) sources[name] = effects end },
        combat = {},
        health = {
            SetMaxHealth = function() end,
            GetPercent = function() return percent end,
            IsDead = function() return dead end,
        },
        hunger = { SetMax = function() end },
        sanity = { SetMax = function() end },
    },
    HasTag = function(_, tag) return tag == "playerghost" and ghost end,
    ListenForEvent = function(_, event, fn)
        listeners[event] = listeners[event] or {}
        table.insert(listeners[event], fn)
    end,
}
master_postinit(inst)
assert(listeners.onactivateskill_server == nil, "Nothing listens for skill changes any more")

local function Check(event, expected)
    for _, fn in ipairs(listeners[event]) do fn(inst) end
    local actual = sources.low_health and sources.low_health.damage or 1
    assert(math.abs(actual - expected) < 0.000001, event .. ": " .. actual)
end

percent = 1
Check("healthdelta", 1)
percent = 0.5
Check("healthdelta", 1.375)
percent = 0.01
Check("healthdelta", 1 + 0.99 * 0.75)
percent = 0.5
ghost = true
for _, fn in ipairs(listeners.ms_becameghost) do pcall(fn, inst) end
assert(sources.low_health == nil)
ghost = false
Check("ms_respawnedfromghost", 1.375)
dead = true
Check("healthdelta", 1)
assert(sources.low_health == nil)
print("PASS: low health damage, death and revival, no skill tree")
