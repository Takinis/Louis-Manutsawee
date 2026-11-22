-- Run from the mod directory: lua tests/player_summary.lua
GLOBAL = _G
GLOBAL.setfenv = function() end
MOVE_UP, MOVE_DOWN = 1, 2
STRINGS = { UI = { PLAYERSUMMARYSCREEN = {
    M_MOD_CHARACTERS_ONLY = "Mods", M_SHOW_ALL_CHARACTERS = "All",
} } }
Asset = function(kind, file) return { type = kind, file = file } end
Prefabs = {}
CreatePrefabSkin = function(name, data)
    data.name = name
    Prefabs[name] = data
    return data
end
package.preload["utils/deathsickleskin"] = function()
    return { Init = function() end, Clear = function() end }
end
dofile("scripts/prefabs/manutsawee_none.lua")
dofile("scripts/prefabs/kiritzuka_none.lua")
dofile("scripts/prefabs/inoue_none.lua")

local loaded, batches = {}, 0
TheSim = { LoadPrefabs = function(_, names)
    batches = batches + 1
    local seen = {}
    for _, name in ipairs(names) do
        assert(not seen[name], "Duplicate load: " .. name)
        seen[name] = true
        local prefab = assert(Prefabs[name])
        for _, asset in ipairs(prefab.assets) do
            local file = assert(io.open(asset.file, "rb"), asset.file)
            file:close()
        end
        loaded[name] = true
    end
end }
local hook, button
AddClassPostConstruct = function(name, fn)
    assert(name == "screens/redux/playersummaryscreen")
    hook = fn
end
local function Widget()
    return {
        SetPosition = function() end, SetScale = function() end,
        MoveToBack = function() end, Kill = function() end,
        SetFocusChangeDir = function() end,
        AddChild = function(_, child) return child end,
    }
end
package.preload["widgets/redux/templates"] = function()
    return { StandardButton = function()
        button = Widget()
        button.SetOnClick = function(self, fn) self.click = fn end
        button.SetText = function(self, text) self.text = text end
        return button
    end }
end
dofile("postinit/screens/playersummaryscreen.lua")

MODCHARACTERLIST = { "manutsawee", "kiritzuka", "inoue", "inoue" }
local selected = { manutsawee = "manutsawee_yukata", kiritzuka = "kiritzuka_none" }
local screen = {
    character_list = { "wilson", "manutsawee", "kiritzuka", "inoue" },
    user_profile = { GetSkinsForCharacter = function(_, character)
        return { base = selected[character] }
    end },
    root = Widget(), menu = Widget(), bg = Widget(),
}
local refreshes = 0
function screen:_RefreshPuppets(marker)
    refreshes = refreshes + 1
    for _, name in ipairs({ "manutsawee", "kiritzuka", "inoue" }) do
        assert(loaded[name .. "_none"], "Default must load before refresh: " .. name)
        if selected[name] ~= nil and Prefabs[selected[name]] ~= nil
            and Prefabs[selected[name]].base_prefab == name then
            assert(loaded[selected[name]], "Selected skin must load before refresh")
        end
    end
    return marker
end
function screen:_BuildPosse()
    self.posse_root = Widget()
    self.posse = {}
    for _ in ipairs(self.character_list) do table.insert(self.posse, Widget()) end
end
screen:_BuildPosse()
local all_characters = screen.character_list
hook(screen)
assert(refreshes == 1 and loaded.manutsawee_yukata)
button.click()
assert(#screen.character_list == 3 and button.text == "All")
selected.kiritzuka = "kiritzuka_maid"
assert(screen:_RefreshPuppets("preserved") == "preserved")
assert(loaded.kiritzuka_maid)
loaded = {}
button.click()
assert(screen.character_list == all_characters and button.text == "Mods")
assert(loaded.inoue_none and loaded.kiritzuka_maid)
selected.inoue = "missing_skin"
screen:_RefreshPuppets()
assert(not loaded.missing_skin)
selected.inoue = "kiritzuka_shirt_tie"
screen:_RefreshPuppets()
assert(not loaded.kiritzuka_shirt_tie, "Do not load another character's stale saved skin")
MODCHARACTERLIST = {}
local before = batches
hook({})
assert(batches == before)
print("player summary: default/selected assets, reload, filtering and empty list passed")
