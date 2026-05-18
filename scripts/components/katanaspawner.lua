--------------------------------------------------------------------------
--[[ Katana Spawner class definition ]]
--------------------------------------------------------------------------

return Class(function(self, inst)

    assert(TheWorld.ismastersim, "Katana Spawner should not exist on client")

    --------------------------------------------------------------------------
    --[[ Dependencies ]]
    --------------------------------------------------------------------------

    local RPCUtil = require("utils/rpcutil")

    --------------------------------------------------------------------------
    --[[ Member variables ]]
    --------------------------------------------------------------------------

    self.inst = inst

    local _world = TheWorld
    local _ismastersim = _world.ismastersim
    local LouisManutsawee, SyncKatanaSpawnerData = "LouisManutsawee", "SyncKatanaSpawnerData"

    -- Store katana instances: {[name] = {inst = entity, shardid = string}}
    local katanas = {}

    --------------------------------------------------------------------------
    --[[ Private member functions ]]
    --------------------------------------------------------------------------

    local function SyncToAllShards(active, name)
        if _ismastersim then
            RPCUtil.SendModRPCToAllShards(
                GetShardModRPC(LouisManutsawee, SyncKatanaSpawnerData),
                active,
                name
            )
        end
    end

    --------------------------------------------------------------------------
    --[[ Private event handlers ]]
    --------------------------------------------------------------------------

    local TrackKatana = _ismastersim and function(inst, data)
        local name = data.name
        local katana_inst = data.inst

        if katanas[name] ~= nil then
            -- Katana already exists, prevent duplicate
            if katana_inst ~= nil and katana_inst:IsValid() then
                print(string.format("[KatanaSpawner] Warning: Duplicate katana '%s' detected, removing duplicate", name))
                katana_inst:Remove()
            end
            return
        end

        -- Track the katana
        katanas[name] = {
            inst = katana_inst,
            shardid = TheShard:GetShardId(),
            tracked_time = GetTime()
        }

        print(string.format("[KatanaSpawner] Tracking katana '%s' on shard %s", name, TheShard:GetShardId()))

        -- Sync to all shards
        SyncToAllShards(true, name)
    end or nil

    local ForgetKatana = _ismastersim and function(inst, data)
        local name = data.name

        if katanas[name] == nil then
            return
        end

        print(string.format("[KatanaSpawner] Forgetting katana '%s' from shard %s", name, TheShard:GetShardId()))

        katanas[name] = nil

        -- Sync to all shards
        SyncToAllShards(false, name)
    end or nil

    --------------------------------------------------------------------------
    --[[ Initialization ]]
    --------------------------------------------------------------------------

    if _ismastersim then
        inst:ListenForEvent("ms_trackkatana", TrackKatana, _world)
        inst:ListenForEvent("ms_forgetkatana", ForgetKatana, _world)
    end

    --------------------------------------------------------------------------
    --[[ Public member functions ]]
    --------------------------------------------------------------------------

    function self:GetKatana(name)
        return katanas[name] ~= nil
    end

    function self:GetKatanaData(name)
        return katanas[name]
    end

    function self:IsKatanaTracked(name)
        return katanas[name] ~= nil
    end

    function self:GetAllTrackedKatanas()
        local tracked = {}
        for name, data in pairs(katanas) do
            table.insert(tracked, name)
        end
        return tracked
    end

    --------------------------------------------------------------------------
    --[[ Save/Load ]]
    --------------------------------------------------------------------------

    if _ismastersim then
        function self:OnSave()
            local data = {}
            local saved_katanas = {}

            -- Save katana names and shard IDs (not entity references)
            for name, katana_data in pairs(katanas) do
                saved_katanas[name] = {
                    shardid = katana_data.shardid,
                    tracked_time = katana_data.tracked_time
                }
            end

            data.katanas = saved_katanas

            return next(data.katanas) ~= nil and data or nil
        end

        function self:OnLoad(data)
            if data ~= nil and data.katanas ~= nil then
                -- Restore katana tracking data
                for name, katana_data in pairs(data.katanas) do
                    katanas[name] = {
                        inst = nil, -- Entity reference will be restored when katana spawns
                        shardid = katana_data.shardid,
                        tracked_time = katana_data.tracked_time
                    }
                    print(string.format("[KatanaSpawner] Loaded katana '%s' from shard %s", name, katana_data.shardid))
                end
            end
        end

        function self:OnPostLoad()
            -- Sync loaded data to all shards
            for name, _ in pairs(katanas) do
                SyncToAllShards(true, name)
            end
        end
    end

    --------------------------------------------------------------------------
    --[[ Debug ]]
    --------------------------------------------------------------------------

    function self:GetDebugString()
        local str = string.format("Tracked Katanas: %d\n", GetTableSize(katanas))
        for name, data in pairs(katanas) do
            local inst_status = data.inst ~= nil and data.inst:IsValid() and "Valid" or "Invalid/Nil"
            str = str .. string.format("  - %s: [Shard: %s, Inst: %s, Time: %.1f]\n",
                name,
                data.shardid or "unknown",
                inst_status,
                data.tracked_time or 0
            )
        end
        return str
    end

    --------------------------------------------------------------------------
    --[[ End ]]
    --------------------------------------------------------------------------

end)
