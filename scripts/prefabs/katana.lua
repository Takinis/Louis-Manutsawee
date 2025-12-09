local MakeKatana = require "prefabs/katana_def"

local data = {
    "hitokiri",
    "shirasaya",
    "raikiri",
    "koshirae",
}

local rets = {}
for _, v in pairs(data) do
    table.insert(rets, MakeKatana({
        name = v,
        build = v,
        damage = TUNING.KATANA.DAMAGE,
    }))
end

return unpack(rets)
