local MakePlayerCharacter = require "prefabs/player_common"

local assets ={
    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),

}

local prefabs = {

}

local start_inv = {

}

TUNING.KIRITZUKA = {}
TUNING.KIRITZUKA.HEALTH = 101
TUNING.KIRITZUKA.SANITY = 201
TUNING.KIRITZUKA.HUNGER = 151

local bosses = {
    bearger = "high",
}

local common_postinit = function(inst)
    -- Minimap icon
    inst.MiniMapEntity:SetIcon("kiritzuka.tex")

    inst:AddTag("delinquent")
end

local master_postinit = function(inst)
    inst.AnimState:SetScale(0.88, 0.9, 1)

    inst.components.health:SetMaxHealth(TUNING.MANUTSAWEE.HEALTH)
    inst.components.hunger:SetMax(TUNING.MANUTSAWEE.HUNGER)
    inst.components.sanity:SetMax(TUNING.MANUTSAWEE.SANITY)

    if inst.components.eater ~= nil then
        inst.components.eater:SetRejectEatingTag("terriblefood")
    end

    inst.skeleton_prefab = nil
end

return MakePlayerCharacter("kiritzuka", prefabs, assets, common_postinit, master_postinit, start_inv)
