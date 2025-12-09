local AssetUtil = require("utils/assetutil")
local LoadersExplorerPanel = require "widgets/redux/loadersexplorerpanel"
GLOBAL.setfenv(1, GLOBAL)

local assets = {
    Asset("DYNAMIC_ANIM", "anim/dynamic/loading_dev_cemetery.zip"),
	Asset("PKGREF", "anim/dynamic/loading_dev_cemetery.dyn"),

    Asset("DYNAMIC_ANIM", "anim/dynamic/loading_night_for_four.zip"),
	Asset("PKGREF", "anim/dynamic/loading_night_for_four.dyn"),
}

local __ctor = LoadersExplorerPanel._ctor
function LoadersExplorerPanel:_ctor(...)
    AssetUtil.LoadAssets("loadersexplorerpanel", assets)
    __ctor(self, ...)
end
