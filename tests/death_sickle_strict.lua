-- Run from the mod directory: lua tests/death_sickle_strict.lua
package.path = "scripts/?.lua;" .. package.path

local function LoadGameScript(path)
    local process = assert(io.popen("unzip -p ../../data/databundles/scripts.zip scripts/" .. path, "r"))
    local source = process:read("*a")
    process:close()
    assert(#source > 0, "Missing installed game script: " .. path)
    return assert(loadstring(source, "@installed_game/" .. path))()
end

Assets = {}
GLOBAL = _G
CAN_USE_DBUI = false
Asset = function(kind, file) return {type = kind, file = file} end
Prefab = function(name, fn, assets, deps)
    return {name = name, fn = fn, assets = assets, deps = deps}
end
local registered
GlassicAPI = {SkinHandler = {
    AddModSkin = function() end,
    SetCharacterExclusiveSkin = function() end,
    AddModSkins = function(skins) registered = skins end,
}}
package.loaded.class = true
package.loaded.prefabs = true

local function LoadDeathSickleSkin()
    for _, prefab in ipairs({dofile("scripts/prefabs/manutsawee_none.lua")}) do
        if prefab.name == "voidcloth_scythe_death" then
            return prefab
        end
    end
    error("Missing voidcloth_scythe_death prefab")
end

LoadGameScript("strict.lua")
assert(rawget(_G, "voidcloth_scythe_clear_fn") == nil)
local previous_code = assert(loadstring(
    "voidcloth_scythe_clear_fn = voidcloth_scythe_clear_fn or function() end"
))
local ok, err = pcall(previous_code)
assert(not ok and err:find("variable 'voidcloth_scythe_clear_fn' is not declared", 1, true), err)
print("death_sickle_strict: reproduced the logged undeclared-global crash")

dofile("main/prefabskin.lua")
local util = require("utils/deathsickleskin")
assert(rawget(_G, "voidcloth_scythe_clear_fn") == util.Clear)
assert(registered.voidcloth_scythe[1] == "voidcloth_scythe_death")
print("death_sickle_strict: main/prefabskin.lua loaded under the installed strict.lua")

LoadGameScript("prefabskin.lua")
local skin = LoadDeathSickleSkin()
assert(skin.is_skin and skin.base_prefab == "voidcloth_scythe")
assert(skin.init_fn == util.Init and skin.clear_fn == util.Clear)
print("death_sickle_strict: installed CreatePrefabSkin constructed the skin and captured its clear function")

local existing = function() end
rawset(_G, "voidcloth_scythe_clear_fn", existing)
dofile("main/prefabskin.lua")
assert(rawget(_G, "voidcloth_scythe_clear_fn") == existing)
local other_skin = CreatePrefabSkin("other_scythe", {base_prefab = "voidcloth_scythe", type = "item"})
assert(other_skin.clear_fn == existing)
skin = LoadDeathSickleSkin()
assert(skin.clear_fn == util.Clear)
print("death_sickle_strict: existing global clear function preserved; custom skin retained its own inverse")
