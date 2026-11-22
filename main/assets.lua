local AssetUtil = require("utils/assetutil")
local AddMinimapAtlas = AddMinimapAtlas

PrefabFiles = {
    "manutsawee",
    "manutsawee_none",
    "yari",
    "shinai",
    "pantsu",
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
    "kiritzuka",
    "kiritzuka_none",
    "kiritzuka_crater_fx",
    "kiritzuka_flurry_image",
    "kiritzuka_hit_fx",
    "kiritzuka_slam_fx",
    "inoue",
    "inoue_none",
    "crowbar",
    "rebar",
    "baseballbat",
    "lycoris_backpack",
}

if PL_ENABLED then
    table.insert(PrefabFiles, "oinc1000000")
end

Assets = {
    -- player_lunge_blue.zip from The Combat Overhaul
    -- https://steamcommunity.com/sharedfiles/filedetails/?id=2317339651
    Asset("ANIM", "anim/player_lunge_blue.zip"),
    -- Load the player_actions_roll animation
    Asset("ANIM", "anim/player_actions_roll.zip"),

    Asset("ANIM", "anim/nightmare_crack_upper_tomb.zip"),

    Asset("IMAGE", "images/map_icons/m_minimaps.tex"),
    Asset("ATLAS", "images/map_icons/m_minimaps.xml"),
    Asset("IMAGE", "images/map_icons/kiritzuka.tex"),
    Asset("ATLAS", "images/map_icons/kiritzuka.xml"),
    Asset("IMAGE", "images/map_icons/inoue.tex"),
    Asset("ATLAS", "images/map_icons/inoue.xml"),

    -- inventoryimages
    Asset("IMAGE", "images/hud/m_inventoryimages.tex"),
    Asset("ATLAS", "images/hud/m_inventoryimages.xml"),
    Asset("ATLAS_BUILD", "images/hud/m_inventoryimages.xml", 256),  -- for minisign

    Asset("IMAGE", "images/hud/crowbar.tex"),
    Asset("ATLAS", "images/hud/crowbar.xml"),
    Asset("ATLAS_BUILD", "images/hud/crowbar.xml", 256),  -- for minisign

    Asset("IMAGE", "images/hud/rebar.tex"),
    Asset("ATLAS", "images/hud/rebar.xml"),
    Asset("ATLAS_BUILD", "images/hud/rebar.xml", 256),  -- for minisign

    Asset("IMAGE", "images/hud/baseballbat.tex"),
    Asset("ATLAS", "images/hud/baseballbat.xml"),
    Asset("ATLAS_BUILD", "images/hud/baseballbat.xml", 256),  -- for minisign

    Asset("IMAGE", "images/hud/lycoris_backpack.tex"),
    Asset("ATLAS", "images/hud/lycoris_backpack.xml"),
    Asset("ATLAS_BUILD", "images/hud/lycoris_backpack.xml", 64),
    Asset("IMAGE", "images/hud/oinc1000000.tex"),
    Asset("ATLAS", "images/hud/oinc1000000.xml"),
    Asset("ATLAS_BUILD", "images/hud/oinc1000000.xml", 64),
    Asset("IMAGE", "images/hud/oinc1000000_engraved.tex"),
    Asset("ATLAS", "images/hud/oinc1000000_engraved.xml"),
    Asset("ATLAS_BUILD", "images/hud/oinc1000000_engraved.xml", 64),
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

    Asset("IMAGE", "bigportraits/manutsawee.tex"),
    Asset("ATLAS", "bigportraits/manutsawee.xml"),

    Asset("IMAGE", "bigportraits/kiritzuka.tex"),
    Asset("ATLAS", "bigportraits/kiritzuka.xml"),
    Asset("IMAGE", "bigportraits/kiritzuka_none.tex"),
    Asset("ATLAS", "bigportraits/kiritzuka_none.xml"),
    Asset("IMAGE", "images/names_kiritzuka.tex"),
    Asset("ATLAS", "images/names_kiritzuka.xml"),
    Asset("IMAGE", "images/names_gold_kiritzuka.tex"),
    Asset("ATLAS", "images/names_gold_kiritzuka.xml"),

    Asset("IMAGE", "images/names_gold_cn_kiritzuka.tex"),
    Asset("ATLAS", "images/names_gold_cn_kiritzuka.xml"),

    Asset("IMAGE", "images/saveslot_portraits/kiritzuka.tex"),
    Asset("ATLAS", "images/saveslot_portraits/kiritzuka.xml"),

    Asset("IMAGE", "images/selectscreen_portraits/kiritzuka.tex"),
    Asset("ATLAS", "images/selectscreen_portraits/kiritzuka.xml"),
    Asset("IMAGE", "images/selectscreen_portraits/kiritzuka_silho.tex"),
    Asset("ATLAS", "images/selectscreen_portraits/kiritzuka_silho.xml"),

    Asset("IMAGE", "images/avatars/avatar_kiritzuka.tex"),
    Asset("ATLAS", "images/avatars/avatar_kiritzuka.xml"),
    Asset("IMAGE", "images/avatars/avatar_ghost_kiritzuka.tex"),
    Asset("ATLAS", "images/avatars/avatar_ghost_kiritzuka.xml"),
    Asset("IMAGE", "images/avatars/self_inspect_kiritzuka.tex"),
    Asset("ATLAS", "images/avatars/self_inspect_kiritzuka.xml"),

    Asset("IMAGE", "bigportraits/inoue.tex"),
    Asset("ATLAS", "bigportraits/inoue.xml"),
    Asset("IMAGE", "bigportraits/inoue_none.tex"),
    Asset("ATLAS", "bigportraits/inoue_none.xml"),
    Asset("IMAGE", "images/names_inoue.tex"),
    Asset("ATLAS", "images/names_inoue.xml"),
    Asset("IMAGE", "images/names_gold_inoue.tex"),
    Asset("ATLAS", "images/names_gold_inoue.xml"),
    Asset("IMAGE", "images/names_gold_cn_inoue.tex"),
    Asset("ATLAS", "images/names_gold_cn_inoue.xml"),

    Asset("IMAGE", "images/saveslot_portraits/inoue.tex"),
    Asset("ATLAS", "images/saveslot_portraits/inoue.xml"),

    Asset("IMAGE", "images/selectscreen_portraits/inoue.tex"),
    Asset("ATLAS", "images/selectscreen_portraits/inoue.xml"),
    Asset("IMAGE", "images/selectscreen_portraits/inoue_silho.tex"),
    Asset("ATLAS", "images/selectscreen_portraits/inoue_silho.xml"),

    Asset("IMAGE", "images/avatars/avatar_inoue.tex"),
    Asset("ATLAS", "images/avatars/avatar_inoue.xml"),
    Asset("IMAGE", "images/avatars/avatar_ghost_inoue.tex"),
    Asset("ATLAS", "images/avatars/avatar_ghost_inoue.xml"),
    Asset("IMAGE", "images/avatars/self_inspect_inoue.tex"),
    Asset("ATLAS", "images/avatars/self_inspect_inoue.xml"),

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

    Asset("DYNAMIC_ANIM", "anim/dynamic/kiritzuka_short_skirt.zip"),
	Asset("PKGREF", "anim/dynamic/kiritzuka_short_skirt.dyn"),

    Asset("DYNAMIC_ANIM", "anim/dynamic/kiritzuka_long_sleeved_top.zip"),
	Asset("PKGREF", "anim/dynamic/kiritzuka_long_sleeved_top.dyn"),
}

GlassicAPI.InitMinimapAtlas("map_icons/m_minimaps")
GlassicAPI.InitMinimapAtlas("map_icons/kiritzuka")
GlassicAPI.InitMinimapAtlas("map_icons/inoue")
AssetUtil.RegisterImageAtlas("images/hud/m_inventoryimages.xml")
AssetUtil.RegisterImageAtlas("images/hud/crowbar.xml")
AssetUtil.RegisterImageAtlas("images/hud/rebar.xml")
AssetUtil.RegisterImageAtlas("images/hud/baseballbat.xml")
AssetUtil.RegisterImageAtlas("images/hud/lycoris_backpack.xml")
AssetUtil.RegisterImageAtlas("images/hud/oinc1000000.xml")
AssetUtil.RegisterImageAtlas("images/hud/oinc1000000_engraved.xml")
