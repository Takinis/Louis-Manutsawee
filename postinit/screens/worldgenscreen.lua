local WorldGenScreen = require("screens/worldgenscreen")
GLOBAL.setfenv(1, GLOBAL)

local __ctor = WorldGenScreen._ctor
function WorldGenScreen:_ctor(profile, cb, world_gen_data, hidden, ...)
    for k, v in pairs(STRINGS.UI.WORLDGEN.M_NOUNS) do
        STRINGS.UI.WORLDGEN.NOUNS[#STRINGS.UI.WORLDGEN.NOUNS + 1] = v
    end

    -- 正在放置 百万呼噜币...
    if MOD_ENABLED.PL then
        for k, v in pairs(STRINGS.UI.WORLDGEN.PL_NOUNS) do
            STRINGS.UI.WORLDGEN.NOUNS[#STRINGS.UI.WORLDGEN.NOUNS + 1] = v
        end
    end

    __ctor(self, profile, cb, world_gen_data, hidden, ...)
    if hidden then return end
end
