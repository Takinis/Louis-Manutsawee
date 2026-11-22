-- Run from the mod root: lua tests/keybinds.lua [native scripts dir]
local native_scripts = arg[1] or "../../data/databundles/scripts/"
package.path = "scripts/?.lua;" .. native_scripts .. "?.lua;" .. package.path

require("class")
GLOBAL = _G
KEY_B, KEY_C, KEY_G, KEY_H, KEY_J, KEY_K, KEY_L, KEY_N, KEY_O, KEY_V, KEY_X, KEY_Z, KEY_ESCAPE =
    98, 99, 103, 104, 106, 107, 108, 110, 111, 118, 120, 122, 27

STRINGS = { UI = { CONTROLSSCREEN = { INPUTS = { [1] = { [KEY_V] = "V", [KEY_G] = "G", [KEY_B] = "B", [KEY_N] = "N" } } } } }

local stored = {}
TheSim = {
    GetPersistentString = function(_, name, cb) cb(stored[name] ~= nil, stored[name]) end,
    SetPersistentString = function(_, name, data) stored[name] = data end,
}
json = {
    -- Just enough for the flat { version, binds } table this file writes.
    encode = function(t)
        local parts = {}
        for k, v in pairs(t.binds) do parts[#parts + 1] = k .. "=" .. tostring(v) end
        return table.concat(parts, ";")
    end,
    decode = function(s)
        local binds = {}
        for k, v in s:gmatch("([%w_]+)=([%w]+)") do if v == "false" then binds[k] = false else binds[k] = tonumber(v) end end
        return { binds = binds }
    end,
}

local now = 0
GetTime = function() return now end
TheInput = { OnRawKey = function() end }
dofile("postinit/input.lua")

local Keybinds = require("utils/keybinds")

-- Defaults when nothing is saved, false for unbound, names resolve per group.
assert(Keybinds.Get("ichimonji") == KEY_V and Keybinds.Get("kiritzuka_slam") == KEY_V)
assert(Keybinds.GetGroup("ichimonji") == "manutsawee" and Keybinds.GetGroup("kiritzuka_dash") == "kiritzuka")
assert(Keybinds.GetKeyName(KEY_V) == "V" and Keybinds.GetKeyName(nil) == "" and Keybinds.GetKeyName(5) == "5")

-- Save round trip, including an unbound key.
local binds = Keybinds.GetAll()
binds.ichimonji = KEY_G
binds.level_check = false
local notified = 0
local function OnChanged() notified = notified + 1 end
Keybinds.AddListener(OnChanged)
Keybinds.SetAll(binds)
assert(notified == 1)
assert(Keybinds.Get("ichimonji") == KEY_G and Keybinds.Get("level_check") == nil)
assert(Keybinds.GetDefault("ichimonji") == KEY_V)
Keybinds.RemoveListener(OnChanged)

package.loaded["utils/keybinds"] = nil
local Reloaded = require("utils/keybinds")
assert(Reloaded.Get("ichimonji") == KEY_G and Reloaded.Get("level_check") == nil, "Saved binds load on the next session")
assert(Reloaded.Get("flip") == KEY_B, "Unsaved names keep their default")
package.loaded["utils/keybinds"] = Keybinds

-- Key listeners follow rebinding without re-creating the component.
local sent = {}
TheWorld = { ismastersim = true }
TheFrontEnd = { GetActiveScreen = function() return { name = "HUD" } end }
GetModRPCHandler = function(_, action)
    return function(_, ...) sent[#sent + 1] = { action, ... } end
end

package.loaded["components/playerkeyhandler"] = nil
local PlayerKeyHandler = require("components/playerkeyhandler")
local player = {}
function player:DoTaskInTime() return { Cancel = function() end } end
ThePlayer = player
local handler = PlayerKeyHandler(player)
handler:AddKeyListener("LouisManutsawee", "ichimonji", "SkillInput", "ICHIMONJI", "pressed")
handler:AddHoldKeyListener("LouisManutsawee", "flip", "SkillInput", 0.5, "FLIP")
local raw = {}
handler:AddRawKeyListener("kiritzuka_homerun", function(down) raw[#raw + 1] = down end)

TheInput:OnRawKey(KEY_G, true)
TheInput:OnRawKey(KEY_G, false)
assert(#sent == 1 and sent[1][1] == "SkillInput" and sent[1][2] == "ICHIMONJI")

TheInput:OnRawKey(KEY_V, true)
assert(#sent == 1, "The old key no longer fires")
TheInput:OnRawKey(KEY_V, false)

-- Holding the home run key across a rebind still reports its release.
TheInput:OnRawKey(KEY_J, true)
TheInput:OnRawKey(KEY_B, true)
assert(#sent == 2 and sent[2][3] == "pressed")

binds = Keybinds.GetAll()
binds.ichimonji = KEY_V
binds.flip = KEY_N
binds.kiritzuka_homerun = KEY_H
Keybinds.SetAll(binds)
assert(raw[1] == true and raw[2] == false, "A held raw key is released on rebind")
assert(#sent == 3 and sent[3][3] == "released", "A held hold-route key is released on rebind")

TheInput:OnRawKey(KEY_B, false)
TheInput:OnRawKey(KEY_V, true)
TheInput:OnRawKey(KEY_V, false)
assert(#sent == 4 and sent[4][2] == "ICHIMONJI", "The new key fires")
TheInput:OnRawKey(KEY_H, true)
assert(raw[3] == true)
TheInput:OnRawKey(KEY_H, false)
assert(raw[4] == false)

-- Other characters' copies on this machine never act on local keys.
ThePlayer = { DoTaskInTime = player.DoTaskInTime }
TheInput:OnRawKey(KEY_V, true)
TheInput:OnRawKey(KEY_V, false)
assert(#sent == 4, "Only the local player's handler fires")
ThePlayer = player

-- Unbinding removes the listener; removal unsubscribes from changes.
binds.ichimonji = false
Keybinds.SetAll(binds)
TheInput:OnRawKey(KEY_V, true)
TheInput:OnRawKey(KEY_V, false)
assert(#sent == 4)

handler:OnRemoveEntity()
binds.ichimonji = KEY_V
Keybinds.SetAll(binds)
TheInput:OnRawKey(KEY_V, true)
TheInput:OnRawKey(KEY_V, false)
TheInput:OnRawKey(KEY_H, true)
assert(#sent == 4 and #raw == 4, "Removed handlers stay removed")

-- Combo hints follow the working binds and the control mode.
local hints = {}
for _, hint in ipairs(Keybinds.GROUPS[1].hints) do hints[hint.name] = hint end
local hint_binds = Keybinds.GetDefaults()
assert(Keybinds.FormatHint(hints.isshin, hint_binds, "combo") == "B → V")
assert(Keybinds.FormatHint(hints.heavenlystrike, hint_binds, "sequence") == "B ×3")
assert(Keybinds.FormatHint(hints.ryusen, hint_binds, "hold") == "Hold V")
assert(Keybinds.FormatHint(hints.heavenlystrike, hint_binds, "hold") == "—", "No hold route")
hint_binds.flip = KEY_G
assert(Keybinds.FormatHint(hints.susanoo, hint_binds, "combo") == "N → G")
hint_binds.flip = false
assert(Keybinds.FormatHint(hints.isshin, hint_binds, "combo") == "—", "Unbound keys have no route")

print("keybinds ok")
