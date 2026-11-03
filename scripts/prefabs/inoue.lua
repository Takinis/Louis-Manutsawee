local MakePlayerCharacter = require "prefabs/player_common"

local assets = {
    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
}

local prefabs = {}
local start_inv = {}

for k, v in pairs(TUNING.GAMEMODE_STARTING_ITEMS) do
    start_inv[string.lower(k)] = v.INOUE
end

prefabs = FlattenTree({prefabs, start_inv}, true)

local common_postinit = function(inst)
    -- Minimap icon
    inst.MiniMapEntity:SetIcon("inoue.tex")
end

local master_postinit = function(inst)
    inst.starting_inventory = start_inv[TheNet:GetServerGameMode()] or start_inv.default
    inst.soundsname = "wortox"

    inst.components.health:SetMaxHealth(TUNING.INOUE_HEALTH)
    inst.components.hunger:SetMax(TUNING.INOUE_HUNGER)
    inst.components.sanity:SetMax(TUNING.INOUE_SANITY)

    inst.skeleton_prefab = nil
end

return MakePlayerCharacter("inoue", prefabs, assets, common_postinit, master_postinit, start_inv)
