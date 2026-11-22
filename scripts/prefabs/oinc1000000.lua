local FACE_VALUE = 1000000
local assets = {
    Asset("ANIM", "anim/oinc1000000.zip"),
    Asset("ANIM", "anim/oinc1000000_engraved.zip"),
}

local function GetDisplayName(inst)
    return string.format("%s (%d)", STRINGS.NAMES.OINC1000000, inst._balance:value())
end

local function OnSave(inst, data)
    data.balance = inst._balance:value()
end

local function OnLoad(inst, data)
    if data and data.balance then
        inst._balance:set(data.balance)
    end
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("oinc1000000")
    inst.AnimState:SetBuild("oinc1000000")
    inst.AnimState:PlayAnimation("idle")
    inst.pickupsound = "paper"
    MakeInventoryFloatable(inst, "med", nil, 0.75)

    inst._balance = net_uint(inst.GUID, "oinc1000000.balance")
    inst.displaynamefn = GetDisplayName

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst._balance:set(FACE_VALUE)

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")

    local build = math.random(2) == 2 and "oinc1000000_engraved" or "oinc1000000"
    inst.AnimState:SetBuild(build)
    inst.components.inventoryitem:ChangeImageName(build)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    MakeHauntableLaunch(inst)
    return inst
end

return Prefab("oinc1000000", fn, assets)
