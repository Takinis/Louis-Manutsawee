-- Run from the mod directory: lua tests/manutsawee_speech_variants.lua /path/to/scripts
local scripts = arg[1] or "../../data/databundles/scripts"
dofile(scripts .. "/stringutil.lua")
GLOBAL = _G

local function CheckPairs(base, extra, path)
    if type(base) == "string" then
        assert(type(extra) == "table" and #extra == 2, path)
        assert(extra[1] ~= base and extra[2] ~= base and extra[1] ~= extra[2], path)
        return 1
    end
    local count = 0
    for k, v in pairs(base) do
        count = count + CheckPairs(v, extra[k] or {}, path .. "." .. k)
    end
    for k in pairs(extra) do assert(base[k] ~= nil, path .. "." .. k) end
    return count
end

local count = 0
for _, name in ipairs({ "manutsawee", "ia_manutsawee", "pl_manutsawee", "um_manutsawee" }) do
    count = count + CheckPairs(dofile("strings/" .. name .. ".lua"), dofile("strings/" .. name .. "_variants.lua"), name)
end

local speech = dofile("strings/manutsawee.lua")
local extra = dofile("strings/manutsawee_variants.lua")
STRINGS = { CHARACTERS = { MANUTSAWEE = speech, GENERIC = { DESCRIBE = { VETSITEM = "generic curse" } } }, MANUTSAWEE_SPEECH_VARIANTS = extra }
local common_postinit
package.loaded["prefabs/player_common"] = function(_, _, _, common) common_postinit = common end
for _, name in ipairs({ "skillutil", "afterimageutil", "smallanimalutil" }) do
    package.loaded["utils/" .. name] = {}
end
Asset = function() end
FlattenTree = function() return {} end
TUNING = { GAMEMODE_STARTING_ITEMS = {} }
M_CONFIG = {}
SKILL_RPC = {}
ACTIONS = { LOOKAT = { id = "LOOKAT" } }
local tick = 1
GetTick = function() return tick end
UM_ENABLED = true
speech.DESCRIBE.VETSITEM = "personal curse"
extra.DESCRIBE.VETSITEM = { "first curse", "second curse" }
local get_string, get_description, get_action_fail = GetString, GetDescription, GetActionFailString
dofile("scripts/prefabs/manutsawee.lua")

local noop = function() end
local callbacks, args = {}, {}
local viewer = {
    prefab = "manutsawee",
    MiniMapEntity = { SetIcon = noop },
    components = {
        playerkeyhandler = { AddKeyListener = noop },
        talker = { Say = function(_, line, ...) args = {...}; return line, "sent" end },
    },
    HasTag = function() return false end,
    SetTag = noop, AddTag = noop, SetComponent = noop, AddComponent = noop,
    ListenForEvent = function(_, key, fn) callbacks[key] = fn end,
}
common_postinit(viewer)
assert(GetString == get_string and GetDescription == get_description and GetActionFailString == get_action_fail)
local talker = viewer.components.talker

local function Item(prefab)
    return { prefab = prefab, components = { inspectable = { GetStatus = noop } }, HasTag = viewer.HasTag }
end
local function Inspect(item, modifier)
    callbacks.performaction(viewer, { action = { action = ACTIONS.LOOKAT, target = item } })
    return talker:Say(GetDescription(viewer, item, modifier))
end

local native_random = math.random
local roll = 1
math.random = function(limit) return limit == 3 and roll or 1 end
local function CheckThree(fn, base, pair)
    for i = 1, 3 do
        roll = i
        assert(fn() == (i == 1 and base or pair[i - 1]), base)
    end
end

-- LOOKAT is instant, so tests do not set viewer.bufferedaction.
assert(speech.DESCRIBE.RAIKIRI == speech.DESCRIBE.TRUE_RAIKIRI)
for _, key in ipairs({ "RAIKIRI", "TRUE_RAIKIRI" }) do
    CheckThree(function() return Inspect(Item(key:lower())) end, speech.DESCRIBE[key], extra.DESCRIBE[key])
end
CheckThree(function() return Inspect(Item("kage")) end, speech.DESCRIBE.KAGE, extra.DESCRIBE.KAGE)
CheckThree(function() return talker:Say(GetString(viewer, "announce_encumbered")) end,
    speech.ANNOUNCE_ENCUMBERED[1], extra.ANNOUNCE_ENCUMBERED[1])
CheckThree(function()
    callbacks.actionfailed(viewer, { action = { action = { id = "COOK" } }, reason = "INUSE" })
    return talker:Say(GetActionFailString(viewer, "COOK", "INUSE"))
end, speech.ACTIONFAIL.COOK.INUSE, extra.ACTIONFAIL.COOK.INUSE)

local table_item = Item("wood_table")
table_item.components.inspectable.GetStatus = function() return "HAS_ITEM" end
CheckThree(function() return Inspect(table_item, "HAS_ITEM") end, speech.DESCRIBE.WOOD_TABLE.HAS_ITEM, extra.DESCRIBE.WOOD_TABLE.HAS_ITEM)
local repair = Item("sword")
repair.components.inspectable.nameoverride = "raikiri"
repair.components.repairable = { NeedsRepairs = function() return true end }
roll = 2
assert(Inspect(repair) == extra.DESCRIBE.RAIKIRI[1] .. extra.ANNOUNCE_CANFIX[1])
local weight = GetDescription(viewer, Item("trophyscale_fish"), "HAS_ITEM_HEAVY")
local fields = { weight = "11", owner = "A%2" }
assert(talker:Say(subfmt(weight, fields)) == subfmt(extra.DESCRIBE.TROPHYSCALE_FISH.HAS_ITEM_HEAVY[1], fields))

callbacks.performaction(viewer, { action = { action = ACTIONS.LOOKAT, invobject = Item("wilson") } })
local name = "A%2"
assert(talker:Say(string.format(speech.DESCRIBE.WILSON.GENERIC, name)) == string.format(extra.DESCRIBE.WILSON.GENERIC[1], name))
callbacks.performaction(viewer, { action = { action = ACTIONS.LOOKAT, target = Item("raikiri") } })
assert(talker:Say(speech.DESCRIBE.RAIKIRI .. "\ngeneric curse") == extra.DESCRIBE.RAIKIRI[1] .. "\nfirst curse")
callbacks.performaction(viewer) -- Client notification from player_classified has no action data.
local original = speech.DESCRIBE.SHINAI
local echoed, sent = talker:Say(original, 2, true, true, true, "colour", nil, "author")
assert(echoed == original and sent == "sent" and args[1] == 2 and args[5] == "colour" and args[7] == "author")
assert(talker:Say(original, nil, nil, nil, nil, nil, "user text") == original)
local script = { { message = original } }
assert(talker:Say(script) == script)
assert(talker:Say("other dialogue") == "other dialogue")
math.random = native_random
print(string.format("PASS: %d speech entries, prefab talker, inspection contexts, formatted fields and broadcast handling", count))
