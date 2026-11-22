local AddComponentPostInit = AddComponentPostInit
GLOBAL.setfenv(1, GLOBAL)

if not KnownModIndex:IsModEnabledAny("workshop-3322803908") then
    return
end

local TILES_PER_RPC = 512

local function NotifyUnderTileChanged(_, tiles, userid)
    local action = "update"
    if tiles.action == "update" or tiles.action == "remove" then
        action, tiles = tiles.action, tiles.data
    end

    local rpc = GetClientModRPC("Porkland", "update_undertile")
    local batch = {}
    local count = 0
    -- Each batch uses the existing RPC format and can be decoded independently.
    for index, tile in pairs(tiles) do
        batch[index] = tile
        count = count + 1
        if count == TILES_PER_RPC then
            SendModRPCToClient(rpc, userid, ZipAndEncodeString({ action = action, data = batch }))
            batch = {}
            count = 0
        end
    end
    if count > 0 then
        SendModRPCToClient(rpc, userid, ZipAndEncodeString({ action = action, data = batch }))
    end
end

AddComponentPostInit("undertile", function(self, inst)
    if inst:HasTag("porkland") and self.NotifyUnderTileChanged ~= nil then
        self.NotifyUnderTileChanged = NotifyUnderTileChanged
    end
end)

AddComponentPostInit("clientundertile", function(self, inst)
    if not inst:HasTag("porkland") then
        return
    end

    local OnUnderTilesChange = self.OnUnderTilesChange
    function self:OnUnderTilesChange(data)
        if type(data) == "table" and type(data.data) == "table" then
            OnUnderTilesChange(self, data)
        end
    end
end)
