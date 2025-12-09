local AssetUtil = require("utils/assetutil")
local AddMinimapAtlas = AddMinimapAtlas

PrefabFiles = {
    "manutsawee",
    "manutsawee_none",
    "yari",
    "shinai",
    -- "maid_hb",
    -- "m_foxmask",
    -- "m_scarf",
    "m_pantsu",
    "harakiri",
    "katanablade",
    "katana",
    "true_katana",
    "mingot",
    "mmiko_armor",
    "special_katana",
    "tokijin",
    "vscode",
    "lightningspike",
}

-- local IslandAdventruePrefabFiles = {

-- }

-- local PorkLandPrefabFiles = {
--     "oinc1000000",
-- }

-- if MOD_ENABLED.IA then
--     for k, v in pairs(IslandAdventruePrefabFiles) do
--         table.insert(PrefabFiles, v)
--     end
-- end

-- if MOD_ENABLED.PL then
--     for k, v in pairs(PorkLandPrefabFiles) do
--         table.insert(PrefabFiles, v)
--     end
-- end

Assets = {
    -- player_lunge_blue.zip from The Combat Overhaul
    -- https://steamcommunity.com/sharedfiles/filedetails/?id=2317339651
    Asset("ANIM", "anim/player_lunge_blue.zip"),
    -- Load the player_actions_roll animation
    Asset("ANIM", "anim/player_actions_roll.zip"),

    Asset("ANIM", "anim/nightmare_crack_upper_tomb.zip"),

    Asset("IMAGE", "images/map_icons/m_minimaps.tex"),
    Asset("ATLAS", "images/map_icons/m_minimaps.xml"),

    -- inventoryimages
    Asset("IMAGE", "images/hud/m_inventoryimages.tex"),
    Asset("ATLAS", "images/hud/m_inventoryimages.xml"),
    Asset("ATLAS_BUILD", "images/hud/m_inventoryimages.xml", 256),  -- for minisign

    Asset("IMAGE", "images/saveslot_portraits/manutsawee.tex"),
    Asset("ATLAS", "images/saveslot_portraits/manutsawee.xml"),

    Asset("IMAGE", "images/selectscreen_portraits/manutsawee.tex"),
    Asset("ATLAS", "images/selectscreen_portraits/manutsawee.xml"),
    Asset("IMAGE", "images/selectscreen_portraits/manutsawee_silho.tex"),
    Asset("ATLAS", "images/selectscreen_portraits/manutsawee_silho.xml"),

    Asset("IMAGE", "images/avatars/avatar_manutsawee.tex"),
    Asset("ATLAS", "images/avatars/avatar_manutsawee.xml"),
    Asset("IMAGE", "images/avatars/avatar_ghost_manutsawee.tex"),
    Asset("ATLAS", "images/avatars/avatar_ghost_manutsawee.xml"),
    Asset("IMAGE", "images/avatars/self_inspect_manutsawee.tex"),
    Asset("ATLAS", "images/avatars/self_inspect_manutsawee.xml"),

    Asset("IMAGE", "images/names_manutsawee.tex"),
    Asset("ATLAS", "images/names_manutsawee.xml"),
    Asset("IMAGE", "images/names_gold_manutsawee.tex"),
    Asset("ATLAS", "images/names_gold_manutsawee.xml"),
    Asset("IMAGE", "images/names_gold_cn_manutsawee.tex"),
    Asset("ATLAS", "images/names_gold_cn_manutsawee.xml"),
    Asset("IMAGE", "images/emotes_manutsawee.tex"),
    Asset("ATLAS", "images/emotes_manutsawee.xml"),

    Asset("IMAGE", "bigportraits/manutsawee.tex"),
    Asset("ATLAS", "bigportraits/manutsawee.xml"),

    Asset("IMAGE", "bigportraits/manutsawee_none.tex"),
    Asset("ATLAS", "bigportraits/manutsawee_none.xml"),
    Asset("IMAGE", "bigportraits/manutsawee_sailor.tex"),
    Asset("ATLAS", "bigportraits/manutsawee_sailor.xml"),
    Asset("IMAGE", "bigportraits/manutsawee_yukata.tex"),
    Asset("ATLAS", "bigportraits/manutsawee_yukata.xml"),
    Asset("IMAGE", "bigportraits/manutsawee_yukatalong.tex"),
    Asset("ATLAS", "bigportraits/manutsawee_yukatalong.xml"),
    Asset("IMAGE", "bigportraits/manutsawee_miko.tex"),
    Asset("ATLAS", "bigportraits/manutsawee_miko.xml"),
    Asset("IMAGE", "bigportraits/manutsawee_qipao.tex"),
    Asset("ATLAS", "bigportraits/manutsawee_qipao.xml"),
    Asset("IMAGE", "bigportraits/manutsawee_fuka.tex"),
    Asset("ATLAS", "bigportraits/manutsawee_fuka.xml"),
    Asset("IMAGE", "bigportraits/manutsawee_maid.tex"),
    Asset("ATLAS", "bigportraits/manutsawee_maid.xml"),
    Asset("IMAGE", "bigportraits/manutsawee_jinbei.tex"),
    Asset("ATLAS", "bigportraits/manutsawee_jinbei.xml"),
    Asset("IMAGE", "bigportraits/manutsawee_shinsengumi.tex"),
    Asset("ATLAS", "bigportraits/manutsawee_shinsengumi.xml"),
    Asset("IMAGE", "bigportraits/manutsawee_taohuu.tex"),
    Asset("ATLAS", "bigportraits/manutsawee_taohuu.xml"),
    Asset("IMAGE", "bigportraits/manutsawee_uniform_black.tex"),
    Asset("ATLAS", "bigportraits/manutsawee_uniform_black.xml"),
    Asset("IMAGE", "bigportraits/manutsawee_bocchi.tex"),
    Asset("ATLAS", "bigportraits/manutsawee_bocchi.xml"),
    Asset("IMAGE", "bigportraits/manutsawee_lycoris.tex"),
    Asset("ATLAS", "bigportraits/manutsawee_lycoris.xml"),

    Asset("DYNAMIC_ATLAS", "images/bg_loading_loading_dev_cemetery.xml"),
	Asset("PKGREF", "images/bg_loading_loading_dev_cemetery.tex"),

    Asset("DYNAMIC_ATLAS", "images/bg_loading_loading_night_for_four.xml"),
	Asset("PKGREF", "images/bg_loading_loading_night_for_four.tex"),
}

GlassicAPI.InitMinimapAtlas("map_icons/m_minimaps")
AssetUtil.RegisterImageAtlas("images/hud/m_inventoryimages.xml")
