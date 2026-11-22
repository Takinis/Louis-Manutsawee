-- Run from the mod directory: lua tests/stalker_inspect.lua
-- The NPC Fuelweaver only talks to players with stalkerinspectable, reading STRINGS.STALKER_NPC_INSPECT[PREFAB].
local CHARACTERS = { "manutsawee", "kiritzuka" }
local LOCALES = { "scripts/languages/chinese_s.po", "scripts/languages/chinese_t.po" }

local function ReadFile(path)
    local file = assert(io.open(path, "r"))
    local content = file:read("*a")
    file:close()
    return content
end

local common = dofile("strings/common.lua")
local inspect = assert(common.STALKER_NPC_INSPECT, "missing STALKER_NPC_INSPECT")

for _, prefab in ipairs(CHARACTERS) do
    local key = string.upper(prefab)
    local lines = inspect[key]
    assert(type(lines) == "table" and #lines > 0, key .. ": missing inspect lines")

    local source = ReadFile("scripts/prefabs/" .. prefab .. ".lua")
    assert(source:find('AddComponent%("stalkerinspectable"%)'), prefab .. ": missing stalkerinspectable")

    for i, line in ipairs(lines) do
        assert(line ~= "", key .. "." .. i .. ": blank line")
        local context = "STRINGS.STALKER_NPC_INSPECT." .. key .. "." .. i
        for _, path in ipairs(LOCALES) do
            local po = ReadFile(path)
            local _, finish = po:find('msgctxt "' .. context .. '"\n', 1, true)
            assert(finish, path .. ": missing " .. context)
            local msgid, msgstr = po:match('^msgid "(.-)"\nmsgstr "(.-)"\n', finish + 1)
            assert(msgid == line, path .. ": stale msgid for " .. context)
            assert(msgstr ~= nil and msgstr ~= "", path .. ": untranslated " .. context)
        end
    end
end

print("PASS: Fuelweaver NPC inspect lines registered for " .. table.concat(CHARACTERS, ", "))
