-- Run from the mod directory: lua tests/side_skirt.lua
hash = function(value) return value end
FACING_RIGHT, FACING_UP, FACING_LEFT, FACING_DOWN = 0, 1, 2, 3
FACING_UPRIGHT, FACING_UPLEFT, FACING_DOWNRIGHT, FACING_DOWNLEFT = 4, 5, 6, 7
SKIN_TYPES_THAT_RECEIVE_CLOTHING = { "normal_skin" }
CLOTHING = {
    kiritzuka_short_skirt = { symbol_overrides = { "skirt" } },
    some_top = { symbol_overrides = { "torso" } },
    kiritzuka_long_sleeved_top = { symbol_overrides = { "arm_upper" } },
}
table.contains = function(list, value)
    for _, v in pairs(list) do
        if v == value then return true end
    end
    return false
end

GLOBAL = _G
GLOBAL.setfenv = function() end
GlassicAPI = { SkinHandler = { DoesCharacterHaveSkin = function() return true end } }
ValidateItemsLocal, ValidatePreviewItems = function() end, function() end
package.loaded["widgets/redux/clothingexplorerpanel"] = {}

local Skinner = {
    SetClothing = function() end,
    SetSkinMode = function(self, skintype)
        self.skintype = skintype or self.skintype
        self.inst.AnimState.overrides.skirt = nil -- SetSkinsOnAnim clears clothing symbols
        self.inst.AnimState.overrides.arm_upper = nil
        self.inst.AnimState.overrides.torso = nil
        self.inst.AnimState.overrides.arm_upper_skin = nil
    end,
}
package.loaded["components/skinner"] = Skinner
package.path = "scripts/?.lua;" .. package.path
dofile("postinit/components/skinner.lua")

local facing = FACING_DOWN
local anim, anim_time, anim_frame = "idle_loop", 0, 0
local function MakePlayer(build)
    local inst = { prefab = "kiritzuka", tasks = {} }
    inst.AnimState = {
        overrides = {},
        bank = "wilson",
        GetBankHash = function(self) return self.bank end,
        SetBank = function(self, bank) self.bank = bank end,
        GetCurrentFacing = function() return facing end,
        GetCurrentAnimationLength = function() return #anim end,
        GetCurrentAnimationTime = function() return anim_time end,
        IsCurrentAnimation = function(_, name) return name == anim end,
        GetCurrentAnimationFrame = function() return anim_frame end,
        OverrideSkinSymbol = function(self, sym, b, src) self.overrides[sym] = b .. ":" .. src end,
        ClearOverrideSymbol = function(self, sym) self.overrides[sym] = nil end,
    }
    function inst:HasTag() return false end
    function inst:DoPeriodicTask(_, fn)
        local task = { fn = fn }
        function task.Cancel() task.cancelled = true end
        table.insert(self.tasks, task)
        return task
    end
    local self = setmetatable({ inst = inst, clothing = {}, skin_data = { normal_skin = build } }, { __index = Skinner })
    return self, inst
end
local function Tick(inst)
    for _, task in ipairs(inst.tasks) do
        if not task.cancelled then task.fn(inst) end
    end
end

local skinner, inst = MakePlayer("kiritzuka_maid")
skinner:SetSkinMode("normal_skin")
assert(inst.AnimState.overrides.skirt == "kiritzuka_maid:skirt_front", "Front facing uses the front skirt")
facing = FACING_RIGHT
Tick(inst)
assert(inst.AnimState.overrides.skirt == "kiritzuka_maid:skirt_side", "Side facing uses the profile skirt")
facing = FACING_LEFT
Tick(inst)
assert(inst.AnimState.overrides.skirt == "kiritzuka_maid:skirt_side")
anim_time = 0.3
Tick(inst)
anim, anim_time = "dial_loop", 0
Tick(inst)
assert(inst.AnimState.overrides.skirt == "kiritzuka_maid:skirt_front", "Talking draws front art while facing sideways")
anim_time = 0.5
Tick(inst)
assert(inst.AnimState.overrides.skirt == "kiritzuka_maid:skirt_front")
anim, anim_time = "idle_loop", 0.1
Tick(inst)
assert(inst.AnimState.overrides.skirt == "kiritzuka_maid:skirt_side", "Side skirt returns after talking")
facing = FACING_UP
Tick(inst)
assert(inst.AnimState.overrides.skirt == "kiritzuka_maid:skirt_back", "Back facing uses the back skirt")
-- chop_pre side variant turns to the front from frame 5.
facing, anim, anim_time, anim_frame = FACING_RIGHT, "chop_pre", 0, 0
Tick(inst)
assert(inst.AnimState.overrides.skirt == "kiritzuka_maid:skirt_side")
anim_frame, anim_time = 5, 0.2
Tick(inst)
assert(inst.AnimState.overrides.skirt == "kiritzuka_maid:skirt_front", "Pose follows the frame")
facing = FACING_UP
Tick(inst)
assert(inst.AnimState.overrides.skirt == "kiritzuka_maid:skirt_back", "Back variant of chop_pre")
anim, anim_time, anim_frame = "idle_loop", 0, 0

facing = FACING_RIGHT
skinner:SetSkinMode("normal_skin")
assert(inst.AnimState.overrides.skirt == "kiritzuka_maid:skirt_side", "Reapplied after the skin is rebuilt")

skinner.clothing.legs = "kiritzuka_short_skirt"
skinner:SetSkinMode("normal_skin")
Tick(inst)
assert(inst.AnimState.overrides.skirt == nil, "Worn skirt clothing is left alone")
assert(inst._side_skirt_task == nil, "Watcher stops when not needed")

skinner.clothing.legs = nil
skinner.clothing.body = "some_top"
skinner:SetSkinMode("normal_skin")
assert(inst.AnimState.overrides.skirt == "kiritzuka_maid:skirt_side", "Other clothing keeps the swap")

skinner:SetSkinMode("ghost_skin")
assert(inst._side_skirt_task == nil, "Ghosts have no skirt swap")

local plain, plain_inst = MakePlayer("kiritzuka")
plain:SetSkinMode("normal_skin")
Tick(plain_inst)
assert(plain_inst.AnimState.overrides.skirt == nil and #plain_inst.tasks == 0, "Other builds are untouched")

-- Cape cardigan: the cape covers the near arm only while it hangs (pose C).
local cape, cape_inst = MakePlayer("kiritzuka_cape_cardigan")
facing, anim, anim_time, anim_frame = FACING_RIGHT, "idle_loop", 0, 0
cape:SetSkinMode("normal_skin")
assert(cape_inst.AnimState.overrides.arm_upper == "kiritzuka_cape_cardigan:arm_upper_cape_8", "Cape over the hanging arm")
assert(cape_inst.AnimState.overrides.arm_upper_skin == "kiritzuka_cape_cardigan:arm_upper_skin", "Hanging arm keeps the plain sleeve")
anim_frame, anim_time = 25, 0.4
Tick(cape_inst)
assert(cape_inst.AnimState.overrides.arm_upper == "kiritzuka_cape_cardigan:arm_upper_cape_12", "Piece follows the idle sway")
assert(cape_inst.AnimState.overrides.skirt == "kiritzuka_cape_cardigan:skirt_side")
anim_time = 0.5
Tick(cape_inst)
anim, anim_time, anim_frame = "run_loop", 0, 0
Tick(cape_inst)
assert(cape_inst.AnimState.overrides.arm_upper == "kiritzuka_cape_cardigan:arm_upper", "Swinging arm comes out from under the cape")
assert(cape_inst.AnimState.overrides.torso == "kiritzuka_cape_cardigan:torso_flare_2", "Running flares the cape")
assert(cape_inst.AnimState.overrides.arm_upper_skin == "kiritzuka_cape_cardigan:arm_upper_skin_cape_S", "Swinging arm carries its part of the cape")
anim_frame, anim_time = 2, 0.1
Tick(cape_inst)
assert(cape_inst.AnimState.overrides.torso == "kiritzuka_cape_cardigan:torso_flare_3", "Flare follows the run bob")
facing = FACING_DOWN
anim, anim_time, anim_frame = "idle_loop", 0, 0
Tick(cape_inst)
assert(cape_inst.AnimState.overrides.arm_upper == "kiritzuka_cape_cardigan:arm_upper", "Front view keeps the plain arm")
assert(cape_inst.AnimState.overrides.torso == "kiritzuka_cape_cardigan:torso", "Cape settles when standing")
assert(cape_inst.AnimState.overrides.arm_upper_skin == "kiritzuka_cape_cardigan:arm_upper_skin_cape_F", "Front view arm patch")
cape.clothing.body = "kiritzuka_long_sleeved_top"
facing = FACING_RIGHT
cape:SetSkinMode("normal_skin")
assert(cape_inst.AnimState.overrides.arm_upper == nil, "Worn sleeves are left alone")
assert(cape_inst.AnimState.overrides.arm_upper_skin == nil, "Worn sleeves get no arm patch")
cape.clothing.body = "some_top"
anim, anim_time, anim_frame = "run_loop", 0, 2
cape:SetSkinMode("normal_skin")
Tick(cape_inst)
assert(cape_inst.AnimState.overrides.torso == nil, "Worn tops are not flared")
assert(skinner.inst.AnimState.overrides.torso == nil, "Maid builds never touch torso")
assert(skinner.inst.AnimState.overrides.arm_upper_skin == nil, "Maid builds never touch arm_upper_skin")
assert(skinner.inst.AnimState.overrides.arm_upper == nil, "Maid builds never touch arm_upper")

local victorian, victorian_inst = MakePlayer("kiritzuka_maid_victorian")
facing = FACING_RIGHT
anim, anim_time, anim_frame = "idle_loop", 0, 0
victorian:SetSkinMode("normal_skin")
assert(victorian_inst.AnimState.overrides.skirt == "kiritzuka_maid_victorian:skirt_side", "Victorian maid gets the side skirt")
facing = FACING_UP
Tick(victorian_inst)
assert(victorian_inst.AnimState.overrides.skirt == "kiritzuka_maid_victorian:skirt_back", "Victorian maid gets the back skirt")
assert(victorian_inst.AnimState.overrides.torso == nil and victorian_inst.AnimState.overrides.arm_upper_skin == nil,
    "Victorian maid has no cape swaps")

local classic, classic_inst = MakePlayer("kiritzuka_maid_classic")
facing = FACING_RIGHT
anim, anim_time, anim_frame = "idle_loop", 0, 0
classic:SetSkinMode("normal_skin")
assert(classic_inst.AnimState.overrides.skirt == "kiritzuka_maid_classic:skirt_side", "Classic maid gets the side skirt")
facing = FACING_UP
Tick(classic_inst)
assert(classic_inst.AnimState.overrides.skirt == "kiritzuka_maid_classic:skirt_back", "Classic maid gets the back skirt")
assert(classic_inst.AnimState.overrides.torso == nil and classic_inst.AnimState.overrides.arm_upper_skin == nil,
    "Classic maid has no cape swaps")

local highcollar, highcollar_inst = MakePlayer("kiritzuka_maid_highcollar")
facing = FACING_RIGHT
anim, anim_time, anim_frame = "idle_loop", 0, 0
highcollar:SetSkinMode("normal_skin")
assert(highcollar_inst.AnimState.overrides.skirt == "kiritzuka_maid_highcollar:skirt_side", "High-collar maid gets the side skirt")
facing = FACING_UP
Tick(highcollar_inst)
assert(highcollar_inst.AnimState.overrides.skirt == "kiritzuka_maid_highcollar:skirt_back", "High-collar maid gets the back skirt")
assert(highcollar_inst.AnimState.overrides.torso == nil and highcollar_inst.AnimState.overrides.arm_upper_skin == nil,
    "High-collar maid has no cape swaps")

local shirt, shirt_inst = MakePlayer("kiritzuka_shirt_tie")
facing, anim, anim_time, anim_frame = FACING_DOWN, "idle_loop", 0, 0
shirt:SetSkinMode("normal_skin")
assert(shirt_inst.AnimState.overrides.skirt == "kiritzuka_shirt_tie:skirt_front")
facing = FACING_RIGHT
Tick(shirt_inst)
assert(shirt_inst.AnimState.overrides.skirt == "kiritzuka_shirt_tie:skirt_side")
facing = FACING_UP
Tick(shirt_inst)
assert(shirt_inst.AnimState.overrides.skirt == "kiritzuka_shirt_tie:skirt_back")
assert(shirt_inst.AnimState.overrides.torso == nil and shirt_inst.AnimState.overrides.arm_upper_skin == nil,
    "Shirt skin only overrides the skirt")
shirt.clothing.legs = "kiritzuka_short_skirt"
shirt:SetSkinMode("normal_skin")
assert(shirt_inst.AnimState.overrides.skirt == nil and shirt_inst._side_skirt_task == nil)
shirt.clothing.legs = nil
shirt.skin_data.normal_skin = "kiritzuka"
shirt:SetSkinMode("normal_skin")
assert(shirt_inst.AnimState.overrides.skirt == nil and shirt_inst._side_skirt_task == nil,
    "Changing back to the default clears the directional skirt")

local takina, takina_inst = MakePlayer("takina")
takina_inst.prefab = "takina"
facing, anim, anim_time, anim_frame = FACING_DOWN, "idle_loop", 0, 0
takina:SetSkinMode("normal_skin")
assert(takina_inst.AnimState.overrides.skirt == "takina:skirt_front")
facing = FACING_RIGHT
Tick(takina_inst)
assert(takina_inst.AnimState.overrides.skirt == "takina:skirt_side")
facing = FACING_UP
Tick(takina_inst)
assert(takina_inst.AnimState.overrides.skirt == "takina:skirt_back")
assert(takina_inst.AnimState.overrides.torso == nil, "Takina only swaps the directional skirt")
takina.clothing.legs = "kiritzuka_short_skirt"
takina:SetSkinMode("normal_skin")
assert(takina_inst.AnimState.overrides.skirt == nil and takina_inst._side_skirt_task == nil,
    "Worn skirt clothing takes precedence over Takina's base skirt")

print("side skirt ok")
