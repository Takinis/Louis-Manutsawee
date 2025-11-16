local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

AddPrefabPostInit("gravestone", function(inst)
    if not TheWorld.ismastersim then
        return
    end

    local Develpers = {
        ffffff = function(inst)

        end,
        Sydney = function(inst)
            inst.components.lootdropper:SpawnLootPrefab("m_pantsu")
            inst.components.lootdropper:SpawnLootPrefab("tenseiga")
        end,
    }

    local IsDevelper = function(_epitaph)
        return Develpers[_epitaph] ~= nil
    end

    local mound = inst.mound
    if mound ~= nil and mound ~= nil then
        local _onfinish = mound.components.workable.onfinish
        local function OnFinishCallback(inst, worker, ...)
            if IsDevelper(inst._epitaph) then
                inst.AnimState:PlayAnimation("dug")
                inst:RemoveComponent("workable")

                Develpers[inst._epitaph](inst)

                if worker ~= nil then
                    if worker.components.sanity ~= nil then
                        worker.components.sanity:DoDelta(-TUNING.SANITY_SMALL)
                    end
                end
            else
                _onfinish(inst, worker, ...)
            end
        end
        mound.components.workable:SetOnFinishCallback(OnFinishCallback)

        inst.mound.Develpers = Develpers
        inst.mound.IsDevelper = IsDevelper
    end

end)
