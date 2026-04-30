local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

local eater_prefabs = {
    "phlegm",
    "rottenegg",
    "humanmeat",
    "humanmeat_cooked",
    "humanmeat_dried",
    "spoiled_food",
    "spoiled_fish",
    "spoiled_fish_small",
    "deerclops_eyeball",
    "glommerfuel",
    "minotaurhorn",
}

for _, v in ipairs(eater_prefabs) do
    AddPrefabPostInit(v, function(inst)
        inst:AddTag("terriblefood")

        if not TheWorld.ismastersim then
            return
        end
    end)
end
