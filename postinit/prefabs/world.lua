local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

AddPrefabPostInit("world", function(inst)
    if not inst.ismastersim then
        return
    end

    inst:AddComponent("katanaspawner")
end)
