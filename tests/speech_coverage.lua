-- Run from the mod directory: lua tests/speech_coverage.lua /path/to/scripts
local native_scripts = arg[1] or "../../data/databundles/scripts"
local reference = dofile(native_scripts .. "/speech_wilson.lua")

local function IsShared(text)
    return type(text) == "string" and not text:find("only_used_by", 1, true)
end

local function HasSharedLines(node)
    if type(node) ~= "table" then
        return IsShared(node)
    end
    for _, value in pairs(node) do
        if HasSharedLines(value) then
            return true
        end
    end
    return false
end

local function CheckCoverage(template, speech, path)
    local count = 0
    for key, value in pairs(template) do
        local context = path .. "." .. key
        if HasSharedLines(value) then
            local actual = speech[key]
            if type(value) == "table" then
                assert(type(actual) == "table", context .. ": missing state table or random pool")
                count = count + CheckCoverage(value, actual, context)
            else
                -- A single native line may become a random pool, or lines per inspect status.
                assert(type(actual) == "string" or type(actual) == "table", context .. ": missing speech")
                assert(actual ~= "", context .. ": empty speech")
                if type(actual) == "table" then
                    assert(next(actual) ~= nil, context .. ": empty line table")
                    for index, line in pairs(actual) do
                        assert(type(line) == "string" and line ~= "", context .. "." .. index .. ": empty speech")
                    end
                end
                count = count + 1
            end
        end
    end
    return count
end

local function CheckLines(speech, path)
    for key, value in pairs(speech) do
        local context = path .. "." .. key
        if type(value) == "table" then
            CheckLines(value, context)
        else
            assert(type(value) == "string" and value:find("%S"), context .. ": blank or invalid speech")
            assert(not value:find("only_used_by", 1, true), context .. ": native placeholder")
        end
    end
end

for _, name in ipairs({ "manutsawee", "kiritzuka" }) do
    local speech = dofile("strings/" .. name .. ".lua")
    local count = CheckCoverage(reference, speech, name)
    CheckLines(speech, name)
    for _, prefab in ipairs({ "BAT", "ROCKY", "CHARLIE_NPC", "JUNK_PILE_BIG", "ROTTENEGG", "SPOILED_FISH", "SPOILED_FOOD" }) do
        assert(type(speech.DESCRIBE[prefab].GENERIC) == "string", name .. ": missing migrated GENERIC for " .. prefab)
    end
    assert(type(speech.DESCRIBE.RAIKIRI) == "string", name .. ": lost custom weapon speech")
    if name == "kiritzuka" then
        assert(type(speech.DESCRIBE.MANUTSAWEE) == "table", name .. ": lost custom character speech")
        assert(type(speech.BATTLECRY.GENERIC) == "table", "Preserve randomized battle cries")
        for _, severity in ipairs({ "LIGHT", "MEDIUM", "HEAVY" }) do
            assert(#speech.ANNOUNCE_HURT[severity] > 0, "Preserve hurt speech: " .. severity)
        end
    end
    print(string.format("PASS: %s covers %d shared speech contexts; no blank lines or native placeholders", name, count))
end
