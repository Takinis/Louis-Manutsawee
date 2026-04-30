local translator = python.eval("lua_translator")

require("fns")
local config = require("config")

local geted_strings = {}
local overed_indexs = {}
local invert_overed_indexs = {}
local translates = {}

-- Load existing translations for all configured languages.
local function load_existing_translations()
    for lang_code, file_name in pairs(config.languages) do
        translates[lang_code] = {}
        local po_file = config.output_popath .. file_name .. ".po"
        merge_table(translates[lang_code], load_pofile(po_file), true)
    end
end

-- Process and merge all source strings defined in the 'data' table from input.lua.
local function process_source_strings()
    for _, _data in ipairs(config.data) do
        local data_strings = _data[1]
        local lang_code = _data[2]
        local override = _data[3]

        -- If the source language is not English, translate it to English first.
        if config.languages[lang_code] then
            local _data_strings = deepcopy(data_strings)
            local data_index = table_index_to_str(_data_strings, "STRINGS")
            for msgctxt, msgstr in pairs(data_index) do
                data_index[msgctxt] = "msgstr " .. msgstr
            end
            merge_table(translates[lang_code], data_index, override)
            -- Translate the table content to English for processing.
            translate_table(data_strings, function(str) return translator(str, lang_code, "en") end)
        end

        -- Filter strings based on keys from config and handle remapping.
        for key, over_key in pairs(config.keys) do  -- get strings by key
            local key_strings = get_string(data_strings, key:upper(), over_key:upper())
            if key:upper() ~= over_key:upper() then
                local overed_strings = get_string(data_strings, key:upper())
                local overed_key_indexs = table_index_to_str(overed_strings, "STRINGS")
                local invert_overed_key_indexs = {}
                for msgctxt, msgstr in pairs(overed_key_indexs) do
                    local over_str = string.gsub(msgctxt, key:upper(), over_key:upper())
                    invert_overed_key_indexs[over_str] = msgctxt
                end
                merge_table(invert_overed_indexs, invert_overed_key_indexs, override)
                merge_table(overed_indexs, overed_key_indexs, override)
            end

            merge_table(geted_strings, key_strings, override)
        end
    end
end

-- Load translations from other miscellaneous .po files.
local function load_external_translations()
    local string_indexs = table_index_to_str(geted_strings, "STRINGS")
    for _, _data in ipairs(config.data) do
        local po_path = _data[2]
        local override = _data[3]

        if not config.languages[po_path] and po_path ~= "en" then
            for lang_code, file_name in pairs(config.languages) do
                local po_file = po_path .. file_name .. ".po"
                merge_table(translates[lang_code], load_pofile(po_file, string_indexs), override)
                merge_table(translates[lang_code], load_pofile(po_file, overed_indexs), override)
            end
        end
    end
end

function escape(str)
    return (str:gsub('\\', '\\\\')
               :gsub('"', '\\"')
               :gsub('\n', '\\n')
               :gsub('\r', '\\r'))
end

-- Generate and write .po and .pot files.
local function generate_localization_files()
    local string_indexs = table_index_to_str(geted_strings, "STRINGS")
    local all_languages = deepcopy(config.languages)
    all_languages["en"] = "strings" -- Add English for .pot file generation.

    for lang_code, file_name in pairs(all_languages) do
        local package = ""
        -- Header generation
        if lang_code == "en" then
            package = package .. "\"Application: Dont' Starve\\n\"" .. "\n"
            package = package .. "\"POT Version: 2.0\\n\"" .. "\n\n"
        else
            package = package .. "msgid \"\"" .. "\n"
            package = package .. "msgstr \"\"" .. "\n"
            package = package .. "\"Language: " .. lang_code .. "\\n\"" .. "\n"
            package = package .. "\"Content-Type: text/plain; charset=utf-8\\n\"" .. "\n"
            package = package .. "\"Content-Transfer-Encoding: 8bit\\n\"" .. "\n"
            package = package .. "\"POT Version: 2.0\"" .. "\n\n"
        end

        -- String entry generation
        for msgctxt, msgid in pairs_by_keys(string_indexs) do
            if lang_code ~= "en" and not translates[lang_code][msgctxt] and not translates[lang_code][invert_overed_indexs[msgctxt]] then
                print("Translating missing string for " .. lang_code .. ": " .. msgctxt)
                local source_lang = "en"
                local text_to_translate = msgid

                -- Use zh-CN as a source for zh-TW if available
                if lang_code == "zh-TW" and translates["zh-CN"] and translates["zh-CN"][msgctxt] then
                    source_lang = "zh-CN"
                    text_to_translate = translates["zh-CN"][msgctxt]:match("msgstr \"(.*)\"") or msgid
                end

                local translated_text = nil

                if text_to_translate == "" then
                    translated_text = ""
                else
                    translated_text = translator(text_to_translate, source_lang, lang_code)
                end

                translates[lang_code][msgctxt] = "msgstr \"" .. escape(tostring(translated_text)) .. "\""
            end

            local index_str = msgctxt:gsub('msgctxt "', ''):gsub('"', '')
            local translated_str = (lang_code == "en" and 'msgstr ""') or (translates[lang_code] and (translates[lang_code][msgctxt] or translates[lang_code][invert_overed_indexs[msgctxt]]))
            local content = translated_str:match('msgstr%s+"(.*)"') or ""

            package = package .. "#. " .. index_str .. "\n"
            package = package .. msgctxt .. "\n"
            package = package .. "msgid \"" .. escape(msgid) .. "\"\n"
            package = package .. translated_str .. "\n\n"
        end

        local po_file_name = (lang_code == "en") and (config.file_prefix .. "strings.pot") or (config.file_prefix .. file_name .. ".po")
        local po_file = io.open(config.output_potpath .. po_file_name, "w+")
        if po_file then
            po_file:write(package)
            po_file:close()
            print("Wrote localization file: " .. po_file_name)
        else
            print("Error writing localization file: " .. po_file_name)
        end
    end
end

-- Write the final processed strings into Lua files for the game.
local function write_output_lua_files()
    local CHARACTERS_table = geted_strings.CHARACTERS

    geted_strings.CHARACTERS = nil

    -- Write common strings file.
    write_lua_table(config.output_path .. "common.lua", geted_strings)

    -- Write character-specific string files.
    for _, character_name in pairs(config.characters) do
        local char_strings = CHARACTERS_table and CHARACTERS_table[string.upper(character_name)]
        if char_strings then
            write_lua_table(config.output_path .. character_name .. ".lua", char_strings)
        end
    end
end

-- Main execution flow
print("Starting string processing pipeline...")
load_existing_translations()
process_source_strings()
load_external_translations()
generate_localization_files()
write_output_lua_files()
print("String processing pipeline finished.")
