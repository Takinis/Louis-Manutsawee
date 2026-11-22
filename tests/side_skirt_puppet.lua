-- Run from the mod directory: lua tests/side_skirt_puppet.lua
hash = function(value) return value end
FACING_RIGHT, FACING_UP, FACING_LEFT, FACING_DOWN = 0, 1, 2, 3
FACING_UPRIGHT, FACING_UPLEFT, FACING_DOWNRIGHT, FACING_DOWNLEFT = 4, 5, 6, 7
SKIN_TYPES_THAT_RECEIVE_CLOTHING = { "normal_skin" }
CLOTHING = { kiritzuka_short_skirt = { symbol_overrides = { "skirt" } } }
table.contains = function(list, value)
    for _, v in pairs(list) do
        if v == value then return true end
    end
    return false
end
GLOBAL = _G
GLOBAL.setfenv = function() end
env, modname = {}, "test"
package.path = "scripts/?.lua;" .. package.path
package.loaded["utils/assetutil"] = {}
GetSkinData = function(item)
    local build = item == "inoue_none" and "takina"
        or (item == "kiritzuka_maid" or item == "kiritzuka_shirt_tie") and item or "kiritzuka"
    return { skins = { normal_skin = build } }
end

local anim, anim_time, anim_frame = "idle_loop", 0, 0
local SkinsPuppet = {
    SetSkins = function(self) self.animstate.overrides.skirt = nil end, -- SetSkinsOnAnim
    EmoteUpdate = function() end,
    DoIdleEmote = function() end,
}
package.loaded["widgets/skinspuppet"] = SkinsPuppet
dofile("postinit/widgets/skinspuppet.lua")

local puppet = setmetatable({}, { __index = SkinsPuppet })
puppet.anim = { SetFacing = function(_, dir) puppet.ui_facing = dir end }
puppet.animstate = {
    overrides = {},
    bank = "wilson",
    GetBankHash = function(self) return self.bank end,
    SetBank = function(self, bank) self.bank = bank end,
    SetScale = function() error("UIAnim scaling must remain owned by the widget") end,
    GetCurrentAnimationLength = function() return #anim end,
    GetCurrentAnimationTime = function() return anim_time end,
    IsCurrentAnimation = function(_, name) return name == anim end,
    GetCurrentAnimationFrame = function() return 0 end,
    OverrideSkinSymbol = function(self, sym, b, src) self.overrides[sym] = b .. ":" .. src end,
    ClearOverrideSymbol = function(self, sym) self.overrides[sym] = nil end,
}
local skirt = function() return puppet.animstate.overrides.skirt end

-- Rotated while another skin is shown, then switched to the maid skin.
puppet:SetSkins("kiritzuka", "kiritzuka_none", {})
puppet.anim:SetFacing(FACING_RIGHT)
assert(puppet.ui_facing == FACING_RIGHT, "Original SetFacing still runs")
assert(skirt() == nil, "Other skins are untouched")
puppet:SetSkins("kiritzuka", "kiritzuka_maid", {})
assert(skirt() == "kiritzuka_maid:skirt_side", "Side skirt after switching while rotated")

puppet.anim:SetFacing(FACING_DOWN)
assert(skirt() == "kiritzuka_maid:skirt_front", "Front facing uses the front skirt")
puppet.anim:SetFacing(FACING_LEFT)
assert(skirt() == "kiritzuka_maid:skirt_side")

anim_time = 0.4
puppet:EmoteUpdate(0)
anim, anim_time = "emoteXL_waving1", 0
puppet:EmoteUpdate(0)
assert(skirt() == "kiritzuka_maid:skirt_front", "Front-only emote while rotated")
anim, anim_time = "idle_loop", 0
puppet:EmoteUpdate(0)
assert(skirt() == "kiritzuka_maid:skirt_side", "Back to idle")
puppet.anim:SetFacing(FACING_UP)
assert(skirt() == "kiritzuka_maid:skirt_back", "Rotated to the back")

puppet:SetSkins("kiritzuka", "kiritzuka_maid", { legs = "kiritzuka_short_skirt" })
puppet:EmoteUpdate(0)
assert(skirt() == nil and puppet._side_skirt_build == nil, "Worn skirt clothing is left alone")

puppet:SetSkins("kiritzuka", "kiritzuka_shirt_tie", {})
assert(skirt() == "kiritzuka_shirt_tie:skirt_back")
puppet.anim:SetFacing(FACING_RIGHT)
assert(skirt() == "kiritzuka_shirt_tie:skirt_side")
puppet.anim:SetFacing(FACING_DOWN)
assert(skirt() == "kiritzuka_shirt_tie:skirt_front")
puppet:SetSkins("kiritzuka", "kiritzuka_none", {})
assert(skirt() == nil and puppet._side_skirt_build == nil)

puppet:SetSkins("inoue", "inoue_none", {})
assert(puppet.animstate.bank == "takina_player")
assert(puppet.animstate.scale == nil)
assert(skirt() == "takina:skirt_front")
puppet.animstate.bank = "wilson"
puppet:EmoteUpdate(0)
assert(puppet.animstate.bank == "takina_player")
puppet:SetSkins("kiritzuka", "kiritzuka_none", {})
assert(puppet.animstate.bank == "wilson" and puppet.animstate.scale == nil)
assert(puppet._takina_visual_build == nil)

print("side skirt puppet ok")
