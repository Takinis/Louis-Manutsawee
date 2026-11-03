-- Run from the mod directory: lua tests/kiritzuka_food.lua
package.path = "scripts/?.lua;" .. package.path

TUNING = {
    GAMEMODE_STARTING_ITEMS = { DEFAULT = { KIRITZUKA = {} } },
    AFFINITY_15_CALORIES_TINY = 2.6,
    AFFINITY_15_CALORIES_SMALL = 2.2,
    AFFINITY_15_CALORIES_MED = 1.6,
    AFFINITY_15_CALORIES_LARGE = 1.4,
}
FlattenTree = function() return {} end
TheNet = { GetServerGameMode = function() return "default" end }
STRINGS = dofile("strings/common.lua")
Asset = function() end

package.loaded["components/spdamageutil"] = {}
local master_postinit
package.loaded["prefabs/player_common"] = function(_, _, _, _, postinit)
    master_postinit = postinit
end
dofile("scripts/prefabs/kiritzuka.lua")

local affinities = {}
local inst = {
    AddComponent = function() end,
    AnimState = { SetScale = function() end },
    components = {
        combat = {},
        foodaffinity = { AddPrefabAffinity = function(_, prefab, bonus) affinities[prefab] = bonus end },
        health = { SetMaxHealth = function() end },
        hunger = { SetMax = function() end },
        sanity = { SetMax = function() end },
    },
    ListenForEvent = function() end,
}
master_postinit(inst)

-- Each bonus is the tier for that food's own hunger value, so raw and crock pot favorites pay alike.
local expected = {
    justeggs = TUNING.AFFINITY_15_CALORIES_LARGE,
    icecream = TUNING.AFFINITY_15_CALORIES_MED,
    californiaroll = TUNING.AFFINITY_15_CALORIES_LARGE,
    unagi = TUNING.AFFINITY_15_CALORIES_LARGE,
    blue_cap = TUNING.AFFINITY_15_CALORIES_SMALL,
    berries = TUNING.AFFINITY_15_CALORIES_TINY,
    berries_juicy = TUNING.AFFINITY_15_CALORIES_SMALL,
}
for prefab, bonus in pairs(expected) do
    assert(affinities[prefab] == bonus, prefab)
end
for prefab in pairs(affinities) do
    assert(expected[prefab] ~= nil, "Not a favorite: " .. prefab)
end
print("kiritzuka_food: checks passed")
