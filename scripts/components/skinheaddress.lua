local function OnSkinsChanged(inst)
    local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
    if equip == nil then
        local build = inst.components.skinheaddress.headdresses[inst.AnimState:GetBuild()]
        if build ~= nil then
            inst.AnimState:Show("HAT")
            inst.AnimState:OverrideSymbol("swap_hat", build, "swap_hat")
        elseif not build then
            inst.AnimState:Hide("HAT")
            inst.AnimState:ClearOverrideBuild("swap_hat")
        end
    end
end

local function OnUnEquip(inst, data)
    local eslot = data.eslot
    if eslot ~= nil and eslot == EQUIPSLOTS.HEAD then
        OnSkinsChanged(inst)
    end
end

local function OnPlayerSpawned(world, data)
    if data ~= nil and data.player ~= nil then
        OnSkinsChanged(data.player)
    end
end

local function OnRespawnFromGhost(inst)
    inst:DoTaskInTime(3, OnSkinsChanged)
end

local function OnPlayerJoined(inst, player)
    OnSkinsChanged(player)
end

local SkinHeaddress = Class(function(self, inst)

    assert(inst:HasTag("player"), "SkinHeaddress must use for player.")

    self.inst = inst

    self.headdresses = {}

    self.inst:ListenForEvent("onskinschanged", OnSkinsChanged)
    self.inst:ListenForEvent("unequip", OnUnEquip)
    self.inst:ListenForEvent("ms_respawnedfromghost", OnRespawnFromGhost)
    self.inst:ListenForEvent("ms_newplayercharacterspawned", OnPlayerSpawned, TheWorld)
    self.inst:ListenForEvent("ms_playerjoined", OnPlayerJoined, TheWorld)
end)

function SkinHeaddress:SetHeaddress(skin, headdress)
    self.headdresses[skin] = headdress
end

function SkinHeaddress:GetHeaddreass()
    return self.headdresses
end

return SkinHeaddress
