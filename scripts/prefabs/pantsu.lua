-- Don't be evil :P
local assets = {
    Asset("ANIM", "anim/m_pantsu.zip"),
}

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("m_pantsu")
    inst.AnimState:SetBuild("m_pantsu")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("nosteal")
	inst:AddTag("pantsu")

    MakeInventoryFloatable(inst, "small", 0.1)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("bait")
    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst:AddComponent("tradable")

    return inst
end

return Prefab("m_pantsu", fn, assets)
