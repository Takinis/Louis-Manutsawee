local assets= {
    Asset("ANIM", "anim/m_foxmask.zip"),
    Asset("ANIM", "anim/m_foxmask_swap.zip"),
    Asset("ANIM", "anim/m_foxmask2_swap.zip"),
    Asset("ANIM", "anim/m_sfoxmask_swap.zip"),
}

local function SwitchMode(inst, owner)
    if inst.maskstatus == 0 then
       owner.AnimState:OverrideSymbol("swap_hat", "m_foxmask_swap", "swap_hat")
    elseif inst.maskstatus == 1 then
        owner.AnimState:OverrideSymbol("swap_hat", "m_sfoxmask_swap", "swap_hat")
    else
        owner.AnimState:OverrideSymbol("swap_hat", "m_foxmask2_swap", "swap_hat")
    end
end

local function OnEquip(inst, owner)
    SwitchMode(inst, owner)
    owner.AnimState:Show("HAT")

    if inst.components.fueled ~= nil then
        inst.components.fueled:StartConsuming()
    end
end

local function OnUnequip(inst, owner)
    owner.AnimState:Hide("HAT")
    if inst.components.fueled ~= nil then
        inst.components.fueled:StopConsuming()
    end
end

local function CastFn(inst, target, position, doer)
    if inst.maskstatus >= 2 then
        inst.maskstatus = 0
    else
        inst.maskstatus = inst.maskstatus + 1
    end

    SwitchMode(inst, doer)
end

local function OnSave(inst, data)
    data.maskstatus = inst.maskstatus
end

local function OnLoad(inst, data)
    if data ~= nil then
        inst.maskstatus = data.maskstatus or false
    end
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst:AddTag("hat")
    inst:AddTag("quickcast")
    inst:AddTag("waterproofer")

    inst.spelltype = "SCIENCE"

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("m_foxmask")
    inst.AnimState:SetBuild("m_foxmask")
    inst.AnimState:PlayAnimation("idle")

    MakeInventoryFloatable(inst, "med", 0.1)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst:AddComponent("tradable")

    inst:AddComponent("spellcaster")
    inst.components.spellcaster:SetSpellFn(CastFn)
    inst.components.spellcaster.canusefrominventory = true
    inst.components.spellcaster.quickcast = true

    inst:AddComponent("fueled")
    inst.components.fueled.fueltype = FUELTYPE.USAGE
    inst.components.fueled:InitializeFuelLevel(TUNING.GOGGLES_PERISHTIME)
    inst.components.fueled:SetDepletedFn(inst.Remove)

    inst:AddComponent("fuel")
    inst.components.fuel.fuelvalue = TUNING.LARGE_FUEL

    inst:AddComponent("waterproofer")
    inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)

    inst:AddComponent("equippable")
    inst.components.equippable.dapperness = TUNING.DAPPERNESS_MED
    inst.components.equippable.equipslot = EQUIPSLOTS.HEAD
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)

    inst.maskstatus = 0
    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    MakeHauntableLaunch(inst)

    return inst
end

table.insert(ALL_HAT_PREFAB_NAMES, "m_foxmask")

return Prefab("m_foxmask", fn, assets)
