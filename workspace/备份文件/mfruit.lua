local assets = {
    Asset("ANIM", "anim/mfruit.zip"),
}

local function OnPutInInventory(inst, owner)
    if owner ~= nil and owner.components.inventory ~= nil then
        if not (owner:HasTag("kenjutsu") or not owner:HasTag("kenjutsuka")) then
            inst:DoTaskInTime(0, function()
                SpawnPrefab("electrichitsparks"):AlignToTarget(owner, inst, true)
                owner.components.combat:GetAttacked(inst, 10)
                owner.components.inventory:DropItem(inst)
            end)
        end
    end
end

local function OnEaten(inst, eater)
    if eater ~= nil and eater.components.kenjutsuka ~= nil and eater.components.kenjutsuka:GetLevel() < 10 then
        eater:PushEvent("levelup")
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("mfruit")
    inst.AnimState:SetBuild("mfruit")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("nosteal")
    inst:AddTag("mfruit")

    MakeInventoryFloatable(inst, "small", 0.1)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("tradable")

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

    inst:AddComponent("edible")
    inst.components.edible.foodtype = FOODTYPE.MFRUIT
    inst.components.edible.hungervalue = 1
    inst.components.edible:SetOnEatenFn(OnEaten)

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.keepondeath = true
    inst.components.inventoryitem.keepondrown = true
    inst.components.inventoryitem:SetOnPutInInventoryFn(OnPutInInventory)

    return inst
end

return Prefab("mfruit", fn, assets)
