local assets = {
    Asset("ANIM", "anim/shadowhand_fx.zip"),
}

local function Release(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local rot = inst.Transform:GetRotation()
    inst.entity:SetParent(nil)
    inst.Transform:SetPosition(x, y, z)
    inst.Transform:SetRotation(rot)
    inst.AnimState:PlayAnimation("idle")
    inst:ListenForEvent("animover", inst.Remove)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst:AddTag("NOCLICK")
    inst:AddTag("FX")
    inst:AddTag("CLASSIFIED") --unfortunately, in DST, "FX" still makes it mouseover when parented

    inst.Transform:SetFourFaced()

    inst.AnimState:SetBank("shadowhand_fx")
    inst.AnimState:SetBuild("shadowhand_fx")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetFinalOffset(1)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.AnimState:PushAnimation("idle", true)

    inst.persists = false

    inst.Release = Release

    return inst
end

return Prefab("m_shadowhand_fx", fn, assets)
