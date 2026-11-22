-- Run from the mod directory: lua tests/kiritzuka_shirt_tie.lua
-- Add --assets after installing the user-supplied dynamic package pair.
local skin_name = "kiritzuka_shirt_tie"
local function Exists(path, signature)
    local file = assert(io.open(path, "rb"), path)
    if signature then
        assert(file:read(#signature) == signature, "Invalid signature: " .. path)
    end
    file:close()
end

unpack = unpack or table.unpack
Asset = function(kind, path)
    return {type = kind, file = path}
end
CreatePrefabSkin = function(name, info)
    info.name = name
    return info
end

local skins = {dofile("scripts/prefabs/kiritzuka_none.lua")}
local found
local names = {}
for _, skin in ipairs(skins) do
    assert(not names[skin.name], "Duplicate skin: " .. skin.name)
    names[skin.name] = true
    if skin.name == skin_name then
        found = skin
    end
end
assert(found, "Missing shirt-and-tie skin")
assert(found.base_prefab == "kiritzuka")
assert(found.type == "base")
assert(found.build_name_override == skin_name)
assert(found.skins.normal_skin == skin_name)
assert(#found.assets == 3 and found.assets[1].type == "DYNAMIC_ANIM")
assert(found.assets[1].file == "anim/dynamic/" .. skin_name .. ".zip")
assert(found.assets[2].type == "PKGREF")
assert(found.assets[2].file == "anim/dynamic/" .. skin_name .. ".dyn")
assert(found.skins.ghost_skin == "ghost_kiritzuka_build")
assert(found.assets[3].type == "ANIM" and found.assets[3].file == "anim/ghost_kiritzuka_build.zip")
Exists(found.assets[3].file, "PK")
if arg and arg[1] == "--assets" then
    Exists(found.assets[1].file, "PK")
    Exists(found.assets[2].file)
else
    print("SKIP: dynamic package files; run with --assets after installing them")
end
Exists("bigportraits/" .. skin_name .. ".tex", "KTEX")
Exists("bigportraits/" .. skin_name .. ".xml")

local registered
GLOBAL = _G
GLOBAL.setfenv = function() end
GlassicAPI = {
    SkinHandler = {
        AddModSkin = function() end,
        SetCharacterExclusiveSkin = function() end,
        AddModSkins = function(list) registered = list end,
    },
}
dofile("main/prefabskin.lua")
local count = 0
for _, name in ipairs(registered.kiritzuka) do
    if name == skin_name then count = count + 1 end
end
assert(count == 1, "Skin must be registered once")
assert(names.kiritzuka_none and names.kiritzuka_cape_cardigan)

local strings = dofile("strings/common.lua")
assert(strings.SKIN_NAMES[skin_name] == "Shirt and Tie")
assert(strings.SKIN_DESCRIPTIONS[skin_name] and strings.SKIN_QUOTES[skin_name])
print("PASS: shirt-and-tie skin registration, asset declarations, portrait and strings")
