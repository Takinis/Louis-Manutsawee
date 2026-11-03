local assets = {
    Asset("ANIM", "anim/antlion_sinkhole.zip"),
}

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("sinkhole")
    inst.AnimState:SetBuild("antlion_sinkhole")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(2)
    inst.AnimState:SetScale(.8, .8)
    inst.Transform:SetEightFaced()
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.persists = false

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:DoTaskInTime(TUNING.KIRITZUKA_BOSS_SLAM.CRATER_DURATION, ErodeAway)
    return inst
end

return Prefab("kiritzuka_crater_fx", fn, assets)
