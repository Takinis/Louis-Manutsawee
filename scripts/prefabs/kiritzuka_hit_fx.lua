-- Native fx spawn their sounds from a private table, so these replay the same visuals silently.
local HIT_FX = {
    { name = "impact", bank = "impact", build = "impact", anim = "idle", offset = 3 },
    { name = "ice", bank = "fx_dock_crackleandpop", build = "fx_dock_crackleandpop", anim = "pop" },
    { name = "balloon", bank = "balloon_pop", build = "balloon_pop", anim = "pop_low", offset = 1 },
    { name = "puff", bank = "round_puff_fx", build = "round_puff_fx", anim = "puff_hi" },
}

local function MakeHitFx(def)
    local assets = {
        Asset("ANIM", "anim/" .. def.build .. ".zip"),
    }

    local function StartFx(proxy)
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
        inst.AnimState:PlayAnimation(def.anim)
        if def.offset ~= nil then
            inst.AnimState:SetFinalOffset(def.offset)
        end

        inst:ListenForEvent("animover", inst.Remove)
    end

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddNetwork()

        --Dedicated server does not need to spawn the local fx
        if not TheNet:IsDedicated() then
            --Delay one frame so that we are positioned properly before starting the effect
            inst:DoTaskInTime(0, StartFx)
        end

        inst.Transform:SetFourFaced()
        inst:AddTag("FX")

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.persists = false
        inst:DoTaskInTime(1, inst.Remove)

        return inst
    end

    return Prefab("kiritzuka_hit_fx_" .. def.name, fn, assets)
end

local prefs = {}
for _, def in ipairs(HIT_FX) do
    table.insert(prefs, MakeHitFx(def))
end

return unpack(prefs)
