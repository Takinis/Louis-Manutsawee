local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

AddPrefabPostInit("gravestone", function(inst)
    if not TheWorld.ismastersim then
        return
    end
    local Develpers = {
        Sydney = function(inst)
            inst.components.lootdropper:SpawnLootPrefab("m_pantsu")
            inst.components.lootdropper:SpawnLootPrefab("tenseiga")
            inst.components.lootdropper:SpawnLootPrefab("bakusaiga")
        end,
    }

    local IsDevelper = function(setepitaph)
        return Develpers[setepitaph] ~= nil
    end

    -- fuck
    local mound = inst.mound
    inst:DoTaskInTime(0, function()
        if mound ~= nil then
            local _onfinish = mound.components.workable.onfinish
            function mound.components.workable.onfinish(inst, worker, ...)
                if Develpers[inst.dev_name] then
                    inst.AnimState:PlayAnimation("dug")
                    inst:RemoveComponent("workable")

                    if worker ~= nil then
                        local fn = Develpers[inst.dev_name]
                        fn(inst)
                        if worker.components.sanity ~= nil then
                            worker.components.sanity:DoDelta(-TUNING.SANITY_SMALL)
                        end
                    end
                else
                    _onfinish(inst, worker, ...)
                end
            end

            inst.mound.dev_name = inst.setepitaph
            inst.mound.Develpers = Develpers
            inst.mound.IsDevelper = IsDevelper
        end
    end)

end)
