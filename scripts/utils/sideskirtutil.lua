-- Base builds that carry "skirt_front" / "skirt_side" / "skirt_back" symbols.
-- Vanilla player animations pick skirt frames without regard to the body pose
-- (back views use frames 0/2/3, side views share frame 0 with the front), so the
-- skin swaps in the symbol for the pose the body is actually drawn in.
-- Builds with "arm_upper_cape_<n>" also get the cape drawn over the near arm while
-- it hangs in side poses (pose "C<n>", n = arm angle bucket), since the near arm
-- draws in front of the torso.
-- They also carry "arm_upper_skin_cape_<F|B|S>": the sleeve with its part of the
-- cape on it, so an arm that swings or lifts out keeps the cape over it.
-- Builds with "torso_flare_<n>" get the cape billowing: poses with suffix "f<n>"
-- (flare level n, from how fast the torso moves in that frame) swap it in for torso.
-- Shared by the Skinner component (in game) and SkinsPuppet (menus).
local ANIM_POSES = require("utils/animposes")

local POSE_SKIRT_BUILDS = {
    inoue = {},
    takina = {},
    kiritzuka_maid = {},
    kiritzuka_maid_kimono = {},
    kiritzuka_maid_victorian = {},
    kiritzuka_maid_classic = {},
    kiritzuka_maid_highcollar = {},
    kiritzuka_shirt_tie = {},
    kiritzuka_cape_cardigan = { arm_cape = true, flare = true },
}

-- Pose of animations not listed in ANIM_POSES: the facing's own.
local FACING_POSE = {
    [FACING_RIGHT] = "S",
    [FACING_UP] = "B",
    [FACING_LEFT] = "S",
    [FACING_DOWN] = "F",
    [FACING_UPRIGHT] = "B",
    [FACING_UPLEFT] = "B",
    [FACING_DOWNRIGHT] = "F",
    [FACING_DOWNLEFT] = "F",
}

local POSE_SYMBOL = {
    F = "skirt_front",
    S = "skirt_side",
    C = "skirt_side",
    B = "skirt_back",
}

local SideSkirtUtil = {}

function SideSkirtUtil.HasSideSkirt(build)
    return build ~= nil and POSE_SKIRT_BUILDS[build] ~= nil
end

local function IsSymbolClothed(clothing, prefab, symbol)
    for _, name in pairs(clothing) do
        local data = CLOTHING[name]
        if data ~= nil then
            if data.symbol_overrides ~= nil and table.contains(data.symbol_overrides, symbol) then
                return true
            end
            local by_character = data.symbol_overrides_by_character
            local alt = by_character ~= nil and (by_character[prefab] or by_character.default) or nil
            if alt ~= nil and alt[symbol] ~= nil then
                return true
            end
        end
    end
    return false
end

function SideSkirtUtil.IsSkirtClothed(clothing, prefab)
    return IsSymbolClothed(clothing, prefab, "skirt")
end

-- AnimState has no getter for the animation name, so find it in ANIM_POSES,
-- rescanning only when the animation changed: new length, or time jumped back.
local function GetAnimPoses(state, anim_state)
    local length, time = anim_state:GetCurrentAnimationLength(), anim_state:GetCurrentAnimationTime()
    if length ~= state._side_skirt_anim_length or time < state._side_skirt_anim_time then
        state._side_skirt_anim_poses = false
        for name, variants in pairs(ANIM_POSES) do
            if anim_state:IsCurrentAnimation(name) then
                state._side_skirt_anim_poses = variants
                break
            end
        end
    end
    state._side_skirt_anim_length, state._side_skirt_anim_time = length, time
    return state._side_skirt_anim_poses
end

local function GetPose(state, anim_state, facing)
    local variants = GetAnimPoses(state, anim_state)
    if not variants then
        return FACING_POSE[facing] or "F"
    end

    -- The facing variant the engine plays: its mask has the 1 << facing bit.
    local bit = 2 ^ (facing or FACING_DOWN)
    local runs = variants[1][2]
    for _, variant in ipairs(variants) do
        if math.floor(variant[1] / bit) % 2 == 1 then
            runs = variant[2]
            break
        end
    end

    local frame = anim_state:GetCurrentAnimationFrame()
    local pose = runs[2]
    for i = 3, #runs, 2 do
        if runs[i] > frame then
            break
        end
        pose = runs[i + 1]
    end
    return pose
end

-- state: table holding the swap state (the entity or the puppet widget).
function SideSkirtUtil.Update(state, anim_state, facing)
    local pose = GetPose(state, anim_state, facing)
    if pose ~= state._side_skirt_pose then
        state._side_skirt_pose = pose
        local kind = pose:sub(1, 1)
        anim_state:OverrideSkinSymbol("skirt", state._side_skirt_build, POSE_SYMBOL[kind])
        if state._side_skirt_arm_cape then
            anim_state:OverrideSkinSymbol("arm_upper", state._side_skirt_build, kind == "C" and "arm_upper_cape_" .. pose:sub(2) or "arm_upper")
            anim_state:OverrideSkinSymbol("arm_upper_skin", state._side_skirt_build, kind == "C" and "arm_upper_skin" or "arm_upper_skin_cape_" .. kind)
        end
        if state._side_skirt_flare then
            local level = pose:match("f(%d+)$")
            if level ~= state._side_skirt_flare_level then
                state._side_skirt_flare_level = level
                anim_state:OverrideSkinSymbol("torso", state._side_skirt_build, level ~= nil and "torso_flare_" .. level or "torso")
            end
        end
    end
end

-- Call right after SetSkinsOnAnim, which clears every clothing symbol override.
-- Returns whether the swap is active and Update must keep running.
function SideSkirtUtil.Reset(state, build, clothing, prefab)
    local config = build ~= nil and POSE_SKIRT_BUILDS[build] or nil
    state._side_skirt_pose = nil
    state._side_skirt_anim_length = nil
    state._side_skirt_build = build
    -- Worn sleeves replace arm_upper; leave them alone.
    state._side_skirt_arm_cape = config ~= nil and config.arm_cape
        and not IsSymbolClothed(clothing or {}, prefab, "arm_upper")
        and not IsSymbolClothed(clothing or {}, prefab, "arm_upper_skin") or nil
    -- Worn tops replace torso, and SetSkinsOnAnim has just restored it.
    state._side_skirt_flare = config ~= nil and config.flare
        and not IsSymbolClothed(clothing or {}, prefab, "torso") or nil
    state._side_skirt_flare_level = nil
    return build ~= nil
end

return SideSkirtUtil
