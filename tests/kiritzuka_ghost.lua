-- Run from the mod directory: lua tests/kiritzuka_ghost.lua
unpack = unpack or table.unpack
Asset = function(kind, file) return {type = kind, file = file} end
CreatePrefabSkin = function(name, info) info.name = name return info end

local skins = {dofile("scripts/prefabs/kiritzuka_none.lua")}
local count = 0
for _, skin in ipairs(skins) do
    assert(skin.base_prefab == "kiritzuka")
    assert(skin.skins.normal_skin == skin.build_name_override)
    assert(skin.skins.ghost_skin == "ghost_kiritzuka_build", skin.name)
    local references = 0
    for _, asset in ipairs(skin.assets) do
        if asset.file == "anim/ghost_kiritzuka_build.zip" then
            assert(asset.type == "ANIM")
            references = references + 1
        end
    end
    assert(references == 1, skin.name .. " must load the ghost build once")
    count = count + 1
end
assert(count == 8, "Expected default and seven character skins")
local file = assert(io.open("anim/ghost_kiritzuka_build.zip", "rb"))
assert(file:read(2) == "PK")
file:close()
print("PASS: all eight Kiritzuka skins share the registered ghost build")
