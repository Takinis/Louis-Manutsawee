local LoadingWidget = require("widgets/redux/loadingwidget")
local AssetUtil = require("utils/assetutil")
GLOBAL.setfenv(1, GLOBAL)

local assets = {
    Asset("DYNAMIC_ATLAS", "images/bg_loading_loading_dev_cemetery.xml"),
	Asset("PKGREF", "images/bg_loading_loading_dev_cemetery.tex"),
}

local __ctor = LoadingWidget._ctor
function LoadingWidget:_ctor(...)
    AssetUtil.LoadAssets("loadingwidget", assets)
    __ctor(self, ...)
end

local _KeepAlive = LoadingWidget.KeepAlive
function LoadingWidget:KeepAlive(...)
    AssetUtil.LoadAssets("loadingwidget", assets)
    return _KeepAlive(self, ...)
end
