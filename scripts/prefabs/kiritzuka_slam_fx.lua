-- Bearger's ground pound art, kept silent because the slam spawns so many of these at once.
local function PlayFx(proxy, def)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst:AddTag("FX")
    --[[Non-networked entity]]
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.Transform:SetFromProxy(proxy.GUID)

    inst.AnimState:SetBank(def.bank)
    inst.AnimState:SetBuild(def.build)
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetFinalOffset(3)
    if def.onground then
        inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
        inst.AnimState:SetLayer(LAYER_BACKGROUND)
        inst.AnimState:SetSortOrder(3)
    end

    inst:ListenForEvent("animover", inst.Remove)
end

local function MakeSlamFx(name, def)
    local assets = {
        Asset("ANIM", "anim/" .. def.build .. ".zip"),
    }

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddNetwork()

        inst:AddTag("FX")

        --Dedicated server does not need to spawn the local fx
        if not TheNet:IsDedicated() then
            --Delay one frame so that we are positioned properly before starting the effect
            inst:DoTaskInTime(0, PlayFx, def)
        end

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.persists = false
        inst:DoTaskInTime(3, inst.Remove)

        return inst
    end

    return Prefab(name, fn, assets)
end

return MakeSlamFx("kiritzuka_slam_ring_fx", {
        bank = "bearger_ring_fx",
        build = "bearger_ring_fx",
        onground = true,
    }),
    MakeSlamFx("kiritzuka_slam_dust_fx", {
        bank = "bearger_ground_fx",
        build = "bearger_ground_fx",
    })
