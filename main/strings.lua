local ENV = env
local GlassicAPI = ENV.GlassicAPI
local MODROOT = MODROOT
local AddSimPostInit = AddSimPostInit
GLOBAL.setfenv(1, GLOBAL)

local StringUtil = require("utils/stringutil")

local languages = {
    -- en = "strings.pot",
    -- de = "german",  -- german
    -- es = "spanish",  -- spanish
    -- fr = "french",  -- french
    -- it = "italian",  -- italian
    -- ko = "korean",  -- korean
    -- pt = "portuguese_br",  -- portuguese and brazilian portuguese
    -- br = "portuguese_br",  -- brazilian portuguese
    -- pl = "polish",  -- polish
    -- ru = "russian",  -- russian
    zh = "chinese_s",  -- chinese
    chs = "chinese_s", -- chinese mod
    sc = "chinese_s", -- simple chinese
    zhr = "chinese_s",
    zht = "chinese_t",
    tc = "chinese_t",
    cht = "chinese_t",
}

local strings = {
    CHARACTERS = {
        GENERIC = StringUtil.ImportStringsFile("generic", ENV),
        INOUE = StringUtil.ImportStringsFile("inoue", ENV),
        KIRITZUKA = StringUtil.ImportStringsFile("kiritzuka", ENV),
        MANUTSAWEE = StringUtil.ImportStringsFile("manutsawee", ENV),
    },
    KIRITZUKA_SPEECH_VARIANTS = StringUtil.ImportStringsFile("kiritzuka_variants", ENV),
    MANUTSAWEE_SPEECH_VARIANTS = StringUtil.ImportStringsFile("manutsawee_variants", ENV),
}

local survivors = {
    "walter", "wanda", "warly", "wathgrithr", "waxwell", "webber", "wendy", "wickerbottom",
    "willow", "winona", "wolfgang", "woodie", "wormwood", "wortox", "wurt", "wx78",
}
for _, name in ipairs(survivors) do
    strings.CHARACTERS[string.upper(name)] = StringUtil.ImportStringsFile(name, ENV)
end

local common = StringUtil.ImportStringsFile("common", ENV)

GlassicAPI.MergeStringsToGLOBAL(common)
GlassicAPI.MergeStringsToGLOBAL(strings)

local default_lang = LanguageTranslator.defaultlang
local lang = languages[M_CONFIG.Locale] ~= nil and M_CONFIG.Locale or default_lang
local folder = languages[lang]

local function LoadTranslationFile(file)
    local temp_lang = lang .. "_louis_manutsawee"
    LanguageTranslator:LoadPOFile(MODROOT .. "scripts/languages/" .. file .. ".po", temp_lang)
    local translations = LanguageTranslator.languages[temp_lang] or {}
    LanguageTranslator.languages[temp_lang] = nil
    LanguageTranslator.defaultlang = default_lang
    return translations
end

local function MergeTranslations(translations, characters)
    local target = LanguageTranslator.languages[lang] or {}
    LanguageTranslator.languages[lang] = target
    for context, value in pairs(translations) do
        if characters == nil or characters[context:match("^STRINGS%.CHARACTERS%.([^.]+)%.")] ~= nil then
            local path = context:match("^STRINGS%.(.+)$")
            local node, key = path ~= nil and STRINGS, nil
            for part in (path or ""):gmatch("[^%.]+") do
                if key ~= nil then
                    node = type(node[key]) == "table" and node[key] or nil
                    if node == nil then
                        break
                    end
                end
                -- Gettext contexts use dots for both named fields and array indices.
                key = tonumber(part) or part
            end
            if node and type(node[key]) == "string" then
                node[key] = value
                target[context] = value
            end
        end
    end
end

local translations = folder ~= nil and LoadTranslationFile(folder) or nil
if translations ~= nil then
    MergeTranslations(translations)
end

if IA_ENABLED or PL_ENABLED then
    -- The expansion can register its character speech after this mod.
    AddSimPostInit(function()
        local returning_survivors = {}
        for _, name in ipairs({ "wagstaff", "walani", "wheeler", "wilba", "woodlegs" }) do
            local character = string.upper(name)
            if STRINGS.CHARACTERS[character] ~= nil then
                returning_survivors[character] = StringUtil.ImportStringsFile(name, ENV)
            end
        end
        if next(returning_survivors) ~= nil then
            GlassicAPI.MergeStringsToGLOBAL({ CHARACTERS = returning_survivors })
            if translations ~= nil then
                MergeTranslations(translations, returning_survivors)
            end
        end
        translations = nil
    end)
end

local function LoadExpansionSpeech(expansion)
    for _, character in ipairs({ "kiritzuka", "manutsawee" }) do
        local key = string.upper(character)
        local name = expansion .. "_" .. character
        GlassicAPI.MergeStringsToGLOBAL({
            CHARACTERS = { [key] = StringUtil.ImportStringsFile(name, ENV) },
            [key .. "_SPEECH_VARIANTS"] = StringUtil.ImportStringsFile(name .. "_variants", ENV),
        })
        if folder ~= nil then
            MergeTranslations(LoadTranslationFile(folder .. "/" .. name))
        end
    end
end

if IA_ENABLED then
    LoadExpansionSpeech("ia")
end

if PL_ENABLED then
    LoadExpansionSpeech("pl")
end

if UM_ENABLED then
    LoadExpansionSpeech("um")
end
