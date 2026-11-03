local ex_fns = require "prefabs/player_common_extensions"

local LIFETIME = 0.25
local PEAK_ALPHA = 0.8
-- The same dark silhouette the dash leaves behind.
local COLOUR = { 0.1, 0.03, 0.15 }
local ANIM_SPEED = 3

local function SetAlpha(inst, a)
    -- The add colour fades with the alpha, or the silhouette would stay bright until it is removed.
    inst.AnimState:SetMultColour(0, 0, 0, a)
    inst.AnimState:SetAddColour(COLOUR[1] * a, COLOUR[2] * a, COLOUR[3] * a, 0)
end

local function Fade(inst)
    local a = math.max(0, 1 - (GetTime() - inst._start_time) / LIFETIME)
    SetAlpha(inst, a * a * PEAK_ALPHA)
end

local function Setup(inst, owner, weapon, anim)
    inst.AnimState:SetBuild(owner.AnimState:GetBuild())
    local symbol = "swap_" .. weapon.prefab
    local skin_build = weapon:GetSkinBuild()
    if skin_build ~= nil then
        inst.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, symbol, weapon.GUID, symbol)
    else
        inst.AnimState:OverrideSymbol("swap_object", symbol, symbol)
    end
    inst.AnimState:SetDeltaTimeMultiplier(ANIM_SPEED)
    inst.AnimState:PlayAnimation(anim)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst.Transform:SetFourFaced()

    inst.AnimState:SetBank("wilson")
    inst.AnimState:SetBuild("wilson")
    inst.AnimState:SetScale(0.88, 0.9, 1)
    ex_fns.SetupBaseSymbolVisibility(inst)
    inst.AnimState:Show("ARM_carry")
    inst.AnimState:Hide("ARM_normal")

    --Dedicated server has nothing to fade
    if not TheNet:IsDedicated() then
        inst._start_time = GetTime()
        SetAlpha(inst, PEAK_ALPHA)
        inst:DoPeriodicTask(0, Fade)
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false
    inst.Setup = Setup
    inst:DoTaskInTime(LIFETIME, inst.Remove)

    return inst
end

return Prefab("kiritzuka_flurry_image", fn)
