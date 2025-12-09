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

    Asset("DYNAMIC_ATLAS", "images/bg_loading_loading_dev_cemetery.xml"),
	Asset("PKGREF", "images/bg_loading_loading_dev_cemetery.tex"),

    Asset("DYNAMIC_ATLAS", "images/bg_loading_loading_night_for_four.xml"),
	Asset("PKGREF", "images/bg_loading_loading_night_for_four.tex"),
})

if ENV.is_mim_enabled then
    modimport("postinit/widgets/redux/loadersexplorerpanel")
    modimport("postinit/widgets/skinspuppet")
    modimport("postinit/widgets/redux/loadingwidget")
end
