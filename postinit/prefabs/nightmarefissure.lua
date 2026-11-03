local AddPrefabPostInit = AddPrefabPostInit
local UpvalueUtil = require("utils/upvalueutil")
GLOBAL.setfenv(1, GLOBAL)

local function GetStatus(inst, viewer)
    if not inst.AnimState:GetBuild() == "nightmare_crack_upper_tomb" then
        return "TOMB"
    end
end

AddPrefabPostInit("fissure", function(inst)
    if not TheWorld.ismastersim then
        return
    end

    if inst.components.inspectable ~= nil then
        inst.components.inspectable.getstatus = GetStatus
    end

    local katanaspawner = TheWorld.components.katanaspawner
    local _onfinish = inst.components.workable.onfinish
    local function OnFinishCallback(inst, worker, ...)
        _onfinish(inst, worker, ...)
        local pt = inst:GetPosition()
        if katanaspawner ~= nil and not katanaspawner:GetKatana("mortalblade") then
            local mortalblade = inst.components.lootdropper:SpawnLootPrefab("mortalblade", pt)
            TheWorld:PushEvent("ms_trackkatana", {name = mortalblade.prefab, inst = mortalblade})
        end
    end

    inst.components.workable:SetOnFinishCallback(OnFinishCallback)

    local _OnNightmarePhaseChanged = inst.OnNightmarePhaseChanged
    local _ShowPhaseState = UpvalueUtil.GetUpvalue(_OnNightmarePhaseChanged, "ShowPhaseState")
    local _states = UpvalueUtil.GetUpvalue(_ShowPhaseState, "states")
    local _controlled = _states.controlled
    function _states.controlled(inst, instant, oldstate, ...)
        _controlled(inst, instant, oldstate, ...)
        if katanaspawner ~= nil and not katanaspawner:GetKatana("mortalblade") and inst.AnimState:IsCurrentAnimation("idle_open_rift") then
            local fx = SpawnPrefab("dreadstone_spawn_fx")
            fx.entity:SetParent(inst.entity)
            inst:SetPrefabNameOverride("dreadstone_stack_tomb")
            inst.AnimState:SetBank("nightmare_crack_upper_tomb")
            inst.AnimState:SetBuild("nightmare_crack_upper_tomb")
            inst.AnimState:PushAnimation("idle_open_rift", true)
        end
    end
end)
