local BUILD = "swap_lycoris_backpack"
local BANK = "backpack1"

local assets = {
    Asset("ANIM", "anim/backpack.zip"),
    Asset("ANIM", "anim/" .. BUILD .. ".zip"),
    Asset("ANIM", "anim/ui_backpack_2x4.zip"),
}

local function OnEquip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_body", BUILD, "swap_body")
    inst.components.container:Open(owner)
end

local function CloseContainer(inst, owner)
    inst.components.container:Close(owner)
end

local function OnUnequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_body")
    CloseContainer(inst, owner)
end

local function OnBurnt(inst)
    inst.components.container:DropEverything()
    inst.components.container:Close()
    SpawnPrefab("ash").Transform:SetPosition(inst.Transform:GetWorldPosition())
    inst:Remove()
end

local function OnIgnite(inst)
    inst.components.container.canbeopened = false
end

local function OnExtinguish(inst)
    inst.components.container.canbeopened = true
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    inst.AnimState:SetBank(BANK)
    inst.AnimState:SetBuild(BUILD)
    inst.AnimState:PlayAnimation("anim")
    inst.MiniMapEntity:SetIcon("backpack.png")

    inst:AddTag("backpack")
    inst.foleysound = "dontstarve/movement/foley/backpack"
    MakeInventoryFloatable(inst, "small", 0.2, nil, nil, nil, {bank = BANK, anim = "anim"})
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.cangoincontainer = false

    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.BODY
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)
    inst.components.equippable:SetOnEquipToModel(CloseContainer)

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("lycoris_backpack")

    MakeSmallBurnable(inst)
    MakeSmallPropagator(inst)
    inst.components.burnable:SetOnBurntFn(OnBurnt)
    inst.components.burnable:SetOnIgniteFn(OnIgnite)
    inst.components.burnable:SetOnExtinguishFn(OnExtinguish)
    MakeHauntableLaunchAndDropFirstItem(inst)

    return inst
end

return Prefab("lycoris_backpack", fn, assets, {"ash"})
