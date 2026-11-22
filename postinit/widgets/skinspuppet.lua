local ENV = env
local SkinsPuppet = require("widgets/skinspuppet")
local modname = modname
local AssetUtil = require("utils/assetutil")
local SideSkirtUtil = require("utils/sideskirtutil")
GLOBAL.setfenv(1, GLOBAL)

local balloon_color = {
    "blue",
    "green",
    "orange",
    "red",
    "purple",
    "yellow"
}

local Idle_Anim = {
    ["manutsawee"] = "idle_wilson",
    ["manutsawee_shinsengumi"] = "idle_wathgrithr",
    ["manutsawee_fuka"] = "idle_wathgrithr",
    ["manutsawee_sailor"] = "idle_walter",
    ["manutsawee_taohuu"] = "idle_winona",
    ["manutsawee_miko"] = "emote_impatient",
    ["manutsawee_jinbei"] = "idle_nice",
    ["manutsawee_bocchi"] = "idle_bocchi_loop",
    ["manutsawee_yukatalong"] = {
        fn = function(self)
            self.override_build = "player_idles_wendy"
            self.animstate:AddOverrideBuild(self.override_build)
        end,
        anim = "idle_wendy"
    },
    ["manutsawee_yukata"] = {
        fn = function(self)
            self.override_build = "player_idles_wendy"
            self.animstate:AddOverrideBuild(self.override_build)
        end,
        anim = "idle_wendy"
    },
    ["manutsawee_qipao"] = {
        fn = function(self)
            self.override_build = "player_idles_wes"
            self.animstate:AddOverrideBuild(self.override_build)
            self.animstate:OverrideSymbol("balloon_red", "player_idles_wes", "balloon_" .. balloon_color[math.random(1, #balloon_color)])
        end,
        anim = "idle_wes"
    },
    ["manutsawee_maid"] = {
        fn = function(self)
            self.override_build = "player_idles_wanda"
            self.animstate:AddOverrideBuild(self.override_build)
        end,
        anim = "idle_wanda"
    },

    ["manutsawee_uniform_black"] = {
        fn = function(self)
            self.override_build = "player_idles_wanda"
            self.animstate:AddOverrideBuild(self.override_build)
        end,
        anim = "idle_wanda"
    },
    ["manutsawee_lycoris"] = {
        fn = function(self)
            self.override_build = "player_idles_wanda"
            self.animstate:AddOverrideBuild(self.override_build)
        end,
        anim = "idle_wanda"
    },
}

local _DoIdleEmote = SkinsPuppet.DoIdleEmote
function SkinsPuppet:DoIdleEmote(...)
    local r = math.random()
    if r > 0.3 then
        local skin = self.last_skins.base_skin
        local emote_anim = Idle_Anim[skin]
        if self.prefabname == "manutsawee" and emote_anim ~= nil then
            if checkentity(emote_anim) then
                local fn = emote_anim.fn
                emote_anim = emote_anim.anim
                fn(self)
            end

            self:DoEmote(emote_anim, false, true)
            return
        end
    end

    if _DoIdleEmote ~= nil then
        return _DoIdleEmote(self, ...)
    end
end

-- The puppet faces down unless something (e.g. a model rotation mod) calls
-- SetFacing on its UIAnim, so remember the facing from those calls.
local function TrackFacing(self)
    if self._side_skirt_facing ~= nil then
        return
    end
    self._side_skirt_facing = FACING_DOWN
    local anim = self.anim
    local set_facing = anim.SetFacing
    function anim.SetFacing(widget, dir, ...)
        self._side_skirt_facing = dir
        set_facing(widget, dir, ...)
        if self._side_skirt_build ~= nil then
            SideSkirtUtil.Update(self, self.animstate, dir)
        end
    end
end

local _SetSkins = SkinsPuppet.SetSkins
function SkinsPuppet:SetSkins(prefabname, base_item, clothing_names, ...)
    TrackFacing(self)
    local result = { _SetSkins(self, prefabname, base_item, clothing_names, ...) }

    local skinmode = self.current_skinmode or {}
    local skindata = GetSkinData(base_item or (prefabname .. "_none"))
    local base_build = skindata ~= nil and skindata.skins ~= nil and skindata.skins[skinmode.type or "normal_skin"] or nil
    local enabled = SideSkirtUtil.HasSideSkirt(base_build)
        and (skinmode.type == nil or table.contains(SKIN_TYPES_THAT_RECEIVE_CLOTHING, skinmode.type))
        and not SideSkirtUtil.IsSkirtClothed(clothing_names or {}, prefabname)

    -- SetSkinsOnAnim has just cleared the skirt override.
    if SideSkirtUtil.Reset(self, enabled and base_build or nil, clothing_names, prefabname) then
        SideSkirtUtil.Update(self, self.animstate, self._side_skirt_facing)
    end
    if prefabname == "inoue" or prefabname == "takina" or self._takina_visual_build ~= nil then
        require("utils/takinavisuals").ApplyPreview(self.animstate, base_build)
        self._takina_visual_build = base_build == "takina" and base_build or nil
    end

    return unpack(result)
end

local _EmoteUpdate = SkinsPuppet.EmoteUpdate
function SkinsPuppet:EmoteUpdate(...)
    _EmoteUpdate(self, ...)
    if self._side_skirt_build ~= nil then
        SideSkirtUtil.Update(self, self.animstate, self._side_skirt_facing)
    end
    if self._takina_visual_build ~= nil then
        require("utils/takinavisuals").Apply(self.animstate, self._takina_visual_build)
    end
end
