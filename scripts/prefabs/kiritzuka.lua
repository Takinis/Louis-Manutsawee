local MakePlayerCharacter = require "prefabs/player_common"

local assets ={

}

local prefabs = {

}

local start_inv = {

}

local bosses = {
    bearger = "high",
}

local common_postinit = function(inst)
    -- Minimap icon
    inst.MiniMapEntity:SetIcon("kiritzuka.tex")

end

local master_postinit = function(inst)

end

return MakePlayerCharacter("kiritzuka", prefabs, assets, common_postinit, master_postinit, start_inv)
