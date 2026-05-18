local Assets = {
    Asset("ANIM", "anim/m_scarf.zip"),
    Asset("ANIM", "anim/mface_scarf.zip"),
}

local function OnEquip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_body", "m_scarf", "swap_body")

    if owner:HasTag("kenjutsuka") then
        owner.AnimState:OverrideSymbol("beard", "mface_scarf", "beard_short")
    end

    if inst.components.fueled ~= nil then
        inst.components.fueled:StartConsuming()
    end
end

local function OnUnequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_body")

    if owner:HasTag("kenjutsuka") then
        owner.AnimState:ClearOverrideSymbol("beard")
    end

    if inst.components.fueled ~= nil then
        inst.components.fueled:StopConsuming()
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.entity:AddMiniMapEntity()

    MakeInventoryPhysics(inst)

    inst.MiniMapEntity:SetIcon("m_scarf.tex")

    inst:AddTag("scarf")

    inst.AnimState:SetBank("m_scarf")
    inst.AnimState:SetBuild("m_scarf")
    inst.AnimState:PlayAnimation("anim")

    MakeInventoryFloatable(inst, "small", 0.2, 1.1)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")

    inst:AddComponent("insulator")
    inst.components.insulator:SetInsulation(TUNING.INSULATION_MED)

    inst:AddComponent("fuel")
    inst.components.fuel.fuelvalue = TUNING.LARGE_FUEL

    inst:AddComponent("waterproofer")
    inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)

    inst:AddComponent("fueled")
    inst.components.fueled.fueltype = FUELTYPE.USAGE
    inst.components.fueled:InitializeFuelLevel(TUNING.GOGGLES_PERISHTIME)
    inst.components.fueled:SetDepletedFn(inst.Remove)

    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.BODY
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)
    inst.components.equippable.dapperness = TUNING.DAPPERNESS_MED

    MakeHauntableLaunch(inst)

    return inst
end

table.insert(ALL_HAT_PREFAB_NAMES, "m_scarf")

return Prefab("m_scarf", fn, Assets)
