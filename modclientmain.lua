local modimport = modimport
local ENV = env

if not GLOBAL.IsInFrontEnd() then return end

local AssetUtil = require("utils/assetutil")

PrefabFiles = {
	"manutsawee_none",
}

Assets = {
    Asset("IMAGE", "bigportraits/manutsawee.tex"),
    Asset("ATLAS", "bigportraits/manutsawee.xml"),
    Asset("IMAGE", "bigportraits/manutsawee_none.tex"),
    Asset("ATLAS", "bigportraits/manutsawee_none.xml"),

    -- inventoryimages
    Asset("IMAGE", "images/hud/m_inventoryimages.tex"),
    Asset("ATLAS", "images/hud/m_inventoryimages.xml"),
    Asset("ATLAS_BUILD", "images/hud/m_inventoryimages.xml", 256),  -- for minisign

    Asset("IMAGE", "images/saveslot_portraits/manutsawee.tex"),
    Asset("ATLAS", "images/saveslot_portraits/manutsawee.xml"),

    Asset("IMAGE", "images/names_gold_manutsawee.tex"),
    Asset("ATLAS", "images/names_gold_manutsawee.xml"),
    Asset("IMAGE", "images/names_gold_cn_manutsawee.tex"),
    Asset("ATLAS", "images/names_gold_cn_manutsawee.xml"),

    Asset("DYNAMIC_ATLAS", "images/bg_loading_loading_dev_cemetery.xml"),
	Asset("PKGREF", "images/bg_loading_loading_dev_cemetery.tex"),
}

PreloadAssets = {}

modimport("main/constants")
modimport("main/config")
modimport("main/strings")
modimport("main/tuning")
modimport("main/characters")
modimport("main/prefabskin")

AssetUtil.RegisterImageAtlas("images/hud/m_inventoryimages.xml")
AssetUtil.LoadAssets(ENV.modname, {
    Asset("ANIM", "anim/player_idles_wortox_nice.zip"), -- fuck
    Asset("ANIM", "anim/player_idles_bocchi.zip"),

    Asset("DYNAMIC_ANIM", "anim/dynamic/loading_dev_cemetery.zip"),
	Asset("PKGREF", "anim/dynamic/loading_dev_cemetery.dyn"),
})

if ENV.is_mim_enabled then
    modimport("postinit/widgets/skinspuppet")
    modimport("postinit/widgets/loadingwidget")
end
