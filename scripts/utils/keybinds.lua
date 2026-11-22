-- Client-side key bindings for the mod characters, edited from Options > Controls.
-- Bindings are stored per machine like the native control mapping, not in the mod config.

local SAVE_NAME = "louis_manutsawee_keybinds"
local SAVE_VERSION = 1

local Keybinds = {}

Keybinds.GROUPS = {
    {
        id = "manutsawee",
        binds = {
            { name = "ichimonji", default = KEY_V },
            { name = "flip", default = KEY_B },
            { name = "thrust", default = KEY_N },
            { name = "immortalslash", default = KEY_H },
            { name = "counter_attack", default = KEY_Z },
            { name = "skill_cancel", default = KEY_C },
            { name = "quick_sheath", default = KEY_X },
            { name = "put_glasses", default = KEY_O },
            { name = "change_hair_style", default = KEY_L },
            { name = "level_check", default = KEY_K },
        },
        -- Read-only rows showing how chained skills are entered with the current keys.
        -- Mirrors the routes in prefabs/manutsawee.lua for each skill control mode.
        hints = {
            { name = "isshin", combo = { "flip", "ichimonji" }, sequence = { "flip", 2 }, hold = "flip" },
            { name = "heavenlystrike", combo = { "flip", "thrust" }, sequence = { "flip", 3 } },
            { name = "ryusen", combo = { "ichimonji", "flip" }, sequence = { "ichimonji", 2 }, hold = "ichimonji" },
            { name = "susanoo", combo = { "thrust", "flip" }, sequence = { "thrust", 2 }, hold = "thrust" },
            { name = "soryuha", combo = { "immortalslash", "immortalslash" }, sequence = { "immortalslash", 2 }, hold = "immortalslash" },
        },
    },
    {
        id = "kiritzuka",
        binds = {
            { name = "kiritzuka_slam", default = KEY_V },
            { name = "kiritzuka_dash", default = KEY_B },
            { name = "kiritzuka_counter", default = KEY_N },
            { name = "kiritzuka_flurry", default = KEY_L },
            { name = "kiritzuka_homerun", default = KEY_J },
            { name = "kiritzuka_destroy", default = KEY_K },
        },
    },
}

local DEFAULTS = {}
local GROUP_OF = {}
for _, group in ipairs(Keybinds.GROUPS) do
    for _, bind in ipairs(group.binds) do
        DEFAULTS[bind.name] = bind.default or false
        GROUP_OF[bind.name] = group.id
    end
end

-- false means unbound, so every known name always has a value.
local current = nil
local listeners = {}

local function CopyBinds(binds)
    local copied = {}
    for name in pairs(DEFAULTS) do
        copied[name] = binds[name]
        if copied[name] == nil then
            copied[name] = false
        end
    end
    return copied
end

local function NotifyListeners()
    for fn in pairs(listeners) do
        fn()
    end
end

local function ApplySaved(data)
    local ok, saved = pcall(json.decode, data)
    if not ok or type(saved) ~= "table" or type(saved.binds) ~= "table" then
        return
    end

    for name in pairs(DEFAULTS) do
        local key = saved.binds[name]
        if key == false then
            current[name] = false
        elseif type(key) == "number" then
            current[name] = key
        end
    end
end

local function Load()
    if current ~= nil then
        return
    end

    current = CopyBinds(DEFAULTS)
    if TheSim == nil or json == nil then
        return
    end

    TheSim:GetPersistentString(SAVE_NAME, function(success, data)
        if success and data ~= nil and data ~= "" then
            ApplySaved(data)
            NotifyListeners()
        end
    end)
end

function Keybinds.Get(name)
    Load()
    return current[name] or nil
end

function Keybinds.GetDefault(name)
    return DEFAULTS[name] or nil
end

function Keybinds.GetAll()
    Load()
    return CopyBinds(current)
end

function Keybinds.GetDefaults()
    return CopyBinds(DEFAULTS)
end

function Keybinds.GetGroup(name)
    return GROUP_OF[name]
end

function Keybinds.SetAll(binds)
    Load()
    current = CopyBinds(binds)

    if TheSim ~= nil and json ~= nil then
        TheSim:SetPersistentString(SAVE_NAME, json.encode({ version = SAVE_VERSION, binds = current }), false)
    end

    NotifyListeners()
end

function Keybinds.AddListener(fn)
    listeners[fn] = true
end

function Keybinds.RemoveListener(fn)
    listeners[fn] = nil
end

function Keybinds.GetKeyName(key)
    if not key then
        return ""
    end

    local inputs = STRINGS.UI.CONTROLSSCREEN.INPUTS[1]
    return inputs ~= nil and inputs[key] or tostring(key)
end

function Keybinds.GetLabel(name)
    local labels = STRINGS.UI.M_KEYBINDS
    return labels ~= nil and labels[string.upper(name)] or name
end

local NO_ROUTE = "—"

local function HintString(name, fallback)
    local labels = STRINGS.UI.M_KEYBINDS
    return labels ~= nil and labels[name] or fallback
end

-- Describes how a chained skill is entered, using binds (a name -> key table) and the skill control mode.
function Keybinds.FormatHint(hint, binds, control_mode)
    local function KeyName(name)
        local key = binds[name]
        return key and Keybinds.GetKeyName(key) or nil
    end

    if control_mode == "sequence" then
        local key = KeyName(hint.sequence[1])
        return key ~= nil and string.format(HintString("HINT_REPEAT", "%s ×%d"), key, hint.sequence[2]) or NO_ROUTE
    elseif control_mode == "hold" then
        local key = hint.hold ~= nil and KeyName(hint.hold) or nil
        return key ~= nil and string.format(HintString("HINT_HOLD", "Hold %s"), key) or NO_ROUTE
    end

    local first, second = KeyName(hint.combo[1]), KeyName(hint.combo[2])
    return first ~= nil and second ~= nil and string.format(HintString("HINT_COMBO", "%s → %s"), first, second) or NO_ROUTE
end

function Keybinds.GetGroupTitle(group_id)
    return STRINGS.CHARACTER_NAMES[group_id] or group_id
end

return Keybinds
