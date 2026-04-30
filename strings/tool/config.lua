local mod_path = "~/Library/Application Support/Steam/steamapps/common/Don't Starve Together/dontstarve_steam.app/Contents/mods/Louis-Manutsawee/"
local output_path = "../"
local file_prefix = ""
local output_potpath = "../../scripts/languages/"
local output_popath = output_potpath .. file_prefix

require("fns")

-- This file is responsible for loading the initial string data for the mod.
-- It sets up package paths to find local and mod-specific lua files.

package.path = package.path .. ";../?.lua"
package.path = package.path .. ";".. mod_path .. "/strings" .. "/?.lua"

local string_cn = require "string_cn"
local string_en = require "string_en"

local data = {
    -- {
    --     string_cn, -- The table containing the strings to process.
    --     "zh-CN",          -- The source language of the strings (e.g., "en" for English).
    --     override = false, -- If true, these strings will overwrite any existing ones.
    -- },
    {
        string_en,  -- input string
        "en",
        override = false,
    },
    -- {
    --     string_cn,  -- input string
    --     "zh-CN",
    --     override = false,
    -- },
}


local keys = {  -- copy key = over key
    -- ["NAMES"] = "NAMES",
    -- ["CHARACTERS"] = "CHARACTERS",
}

for k, v in pairs(require("common")) do
    keys[string.upper(k)] = string.upper(k)
end

for k, v in pairs(require("manutsawee")) do
    keys[string.upper(k)] = string.upper(k)
end

for k, v in pairs(require("generic")) do
    keys[string.upper(k)] = string.upper(k)
end

local characters = {
    "generic",  -- wilson
    "willow",
    "wolfgang",
    "wendy",
    "wx78",
    "wickerbottom",
    "woodie",
    -- "wes",
    "waxwell",
    "wathgrithr",
    "webber",
    "wormwood",
    "warly",
    -- sw character
    "walani",
    -- "wilbur",  -- monkey,no speech
    "woodlegs",
    -- hamlet character
    "wheeler",
    "wilba",
    "wagstaff",
    -- "warbucks"  -- discard
    -- dst_new_character
    "winona",
    "wortox",
    "wurt",
    "walter",
    "wanda",

    -- mod characters can be added here
    "manutsawee"
}

local languages = {
    -- en = "strings.pot",
    -- de = "german",
    -- es = "spanish",
    -- fr = "french",
    -- it = "italian",
    -- ko = "korean",
    -- pt = "portuguese_br",
    -- pl = "polish",
    -- ru = "russian",
    ["zh-CN"] = "chinese_s",
    -- ["zh-TW"] = "chinese_t",
}

return {
    mod_path = mod_path,
    output_path = output_path,
    file_prefix = file_prefix,
    output_potpath = output_potpath,
    output_popath = output_popath,
    data = data,
    keys = keys,
    characters = characters,
    languages = languages,
}

