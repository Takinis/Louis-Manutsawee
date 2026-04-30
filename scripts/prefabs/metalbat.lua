local assets = {
    Asset("ANIM", "anim/metalbat.zip"),
    Asset("ANIM", "anim/swap_metalbat.zip"),
    Asset("ANIM", "anim/sc_metalbat.zip"),
}

local prefabs = {
}

local function OnPutInInventory(inst, owner)
    if owner:HasTag("player") and not owner:HasTag("kenjutsuka") then
        owner.components.inventory:DropItem(inst)
        if owner.components.combat ~= nil then
            owner.components.combat:GetAttacked(inst, 50)
        end
    end
end

local function OnEquip(inst, owner)
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
    owner.AnimState:OverrideSymbol("swap_object", "swap_metalbat" , "swap_metalbat")

    if not owner:HasTag("notshowscabbard")  then
        owner.AnimState:ClearOverrideSymbol("swap_body_tall")
    end
end

local function OnUnequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")

    inst.components.weapon:SetDamage(TUNING.metalbat_DAMAGE)
end

local function OnPocket(inst, owner)
    if owner ~= nil and not owner:HasTag("notshowscabbard") and owner:HasTag("player") then
        owner.AnimState:OverrideSymbol("swap_body_tall", "sc_metalbat", "tail")
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("metalbat")
    inst.AnimState:SetBuild("metalbat")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("nosteal")
    inst:AddTag("blunt")
    inst:AddTag("waterproofer")
    inst:AddTag("metalbat")

    --weapon (from weapon component) added to pristine state for optimization
    inst:AddTag("weapon")

    local swap_data = {sym_build = "swap_metalbat", bank = "metalbat"}
    MakeInventoryFloatable(inst, "med", nil, {1.0, 0.5, 1.0}, true, -13, swap_data)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("waterproofer")
    inst.components.waterproofer:SetEffectiveness(0)

    inst:AddComponent("hauntable")
    inst.components.hauntable.cooldown = TUNING.HAUNT_COOLDOWN_SMALL

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(TUNING.METALBAT_DAMAGE)
    inst.components.weapon:SetRange(1, 1)
    -- inst.components.weapon:SetOnAttack(OnAttack)

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.nobounce = true

    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)
    inst.components.equippable:SetOnPocket(OnPocket)

    return inst
end

return Prefab("metalbat", fn, assets, prefabs)
