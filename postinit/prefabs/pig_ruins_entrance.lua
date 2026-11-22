local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

if not PL_ENABLED then
    return
end

local PigRuinsUtil = require("utils/pigruinsutil")

for prefab in pairs(PigRuinsUtil.ENTRANCES) do
    AddPrefabPostInit(prefab, function(inst)
        if not TheWorld.ismastersim then
            return
        end

        -- Runs before the entrance's OnLoad, which is where the maze is built.
        PigRuinsUtil.Register(inst)
    end)
end
