--------------------------------------------------------------------------
--[[ Katana Spawner Component (Closure Refactor) ]]
-- Tracks global/special katana existence across shards.
--------------------------------------------------------------------------

local RPCUtil = require("utils/rpcutil")

local UNIQUE_KATANAS = {
    mortalblade = true,
    tenseiga = true,
    bakusaiga = true,
    kage = true,
    shusui = true,
}

local CLEANUP_INTERVAL = 10

local function TableSize(t)
    local count = 0
    if t ~= nil then
        for _ in pairs(t) do
            count = count + 1
        end
    end
    return count
end

local function IsValidEntity(inst)
    return inst ~= nil and inst:IsValid()
end

local function IsPlayerHeld(inst)
    if not IsValidEntity(inst) or inst.components.inventoryitem == nil then
        return false
    end

    local owner = inst.components.inventoryitem:GetGrandOwner()
    return owner ~= nil and owner:HasTag("player")
end

local function GetShardId()
    return TheShard ~= nil and TheShard:GetShardId() or "master"
end

local function NormalizeName(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    return name
end

local function ResolveSpawnPosition(spawn_pos)
    if type(spawn_pos) == "table" then
        if spawn_pos.x ~= nil and spawn_pos.z ~= nil then
            return spawn_pos.x, spawn_pos.y or 0, spawn_pos.z
        end

        if spawn_pos.Transform ~= nil then
            return spawn_pos.Transform:GetWorldPosition()
        end
    end

    if AllPlayers ~= nil and #AllPlayers > 0 and AllPlayers[1] ~= nil and AllPlayers[1].Transform ~= nil then
        return AllPlayers[1].Transform:GetWorldPosition()
    end

    return 0, 0, 0
end

local KatanaSpawner = Class(function(self, inst)
    assert(TheWorld.ismastersim, "Katana Spawner should not exist on client")

    self.inst = inst

    ----------------------------------------------------------------------
    -- Closure state
    ----------------------------------------------------------------------

    local katanas = {}
    local cleanup_task = nil

    -- Backward compatibility: keep state accessible for external debug tools.
    self.katanas = katanas

    ----------------------------------------------------------------------
    -- Closure internals
    ----------------------------------------------------------------------

    local function IsTrackedActive(name)
        local entry = katanas[name]
        if entry == nil then
            return false
        end

        local current_shard = GetShardId()
        if entry.shardid == current_shard then
            return IsValidEntity(entry.inst)
        end

        return true
    end

    local function SyncToAllShards(active, name)
        if not TheWorld.ismastersim then
            return
        end

        RPCUtil.SendModRPCToAllShards(
            GetShardModRPC("LouisManutsawee", "SyncKatanaSpawnerData"),
            active,
            name
        )
    end

    local function TrackKatanaInternal(name, katana_inst, shardid, should_sync, tracked_time)
        local old_entry = katanas[name]
        katanas[name] = {
            inst = katana_inst,
            shardid = shardid,
            tracked_time = tracked_time
                or (old_entry ~= nil and old_entry.tracked_time)
                or GetTime(),
        }

        if should_sync then
            SyncToAllShards(true, name)
        end
    end

    local function UntrackKatanaInternal(name, should_sync)
        if katanas[name] == nil then
            return
        end

        katanas[name] = nil

        if should_sync then
            SyncToAllShards(false, name)
        end
    end

    local function ShouldKeepExistingForDuplicate(existing_inst, new_inst)
        if existing_inst == new_inst then
            return true
        end

        local existing_held = IsPlayerHeld(existing_inst)
        local new_held = IsPlayerHeld(new_inst)

        if existing_held ~= new_held then
            return existing_held
        end

        return true
    end

    local function HandleLocalTrack(name, katana_inst)
        local current_shard = GetShardId()

        if not IsValidEntity(katana_inst) then
            TrackKatanaInternal(name, nil, current_shard, true)
            return
        end

        local existing = katanas[name]
        if existing == nil then
            TrackKatanaInternal(name, katana_inst, current_shard, true)
            return
        end

        local existing_inst = existing.inst
        if not UNIQUE_KATANAS[name] then
            TrackKatanaInternal(name, katana_inst, current_shard, true)
            return
        end

        if not IsValidEntity(existing_inst) then
            TrackKatanaInternal(name, katana_inst, current_shard, true)
            return
        end

        if existing_inst == katana_inst then
            return
        end

        print(string.format("[KatanaSpawner] Duplicate unique katana '%s' detected on shard '%s'.", name, current_shard))

        local keep_existing = ShouldKeepExistingForDuplicate(existing_inst, katana_inst)
        if keep_existing then
            if IsValidEntity(katana_inst) then
                katana_inst:Remove()
            end
            return
        end

        if IsValidEntity(existing_inst) then
            existing_inst:Remove()
        end
        TrackKatanaInternal(name, katana_inst, current_shard, true)
    end

    local function HandleLocalForget(name, katana_inst)
        local existing = katanas[name]
        if existing == nil then
            return
        end

        if katana_inst ~= nil and existing.inst ~= nil and existing.inst ~= katana_inst then
            return
        end

        UntrackKatanaInternal(name, true)
    end

    local function CleanupInvalidEntriesInternal()
        local current_shard = GetShardId()
        local removed = {}

        for name, entry in pairs(katanas) do
            if entry.shardid == current_shard and not IsValidEntity(entry.inst) then
                table.insert(removed, name)
            end
        end

        for _, name in ipairs(removed) do
            print(string.format("[KatanaSpawner] Periodic cleanup removed stale local tracker '%s'.", name))
            UntrackKatanaInternal(name, true)
        end
    end

    local function StartCleanupTaskInternal()
        if cleanup_task ~= nil then
            cleanup_task:Cancel()
            cleanup_task = nil
        end

        cleanup_task = inst:DoPeriodicTask(CLEANUP_INTERVAL, CleanupInvalidEntriesInternal)
    end

    local function GetKatanaLocationInternal(name)
        local entry = katanas[name]
        if entry == nil then
            return nil, "untracked", nil, nil
        end

        local current_shard = GetShardId()
        if entry.shardid ~= current_shard then
            return nil, "other_shard", nil, entry.shardid
        end

        local katana_inst = entry.inst
        if not IsValidEntity(katana_inst) then
            return nil, "stale", nil, current_shard
        end

        local owner = katana_inst.components.inventoryitem ~= nil
            and katana_inst.components.inventoryitem:GetGrandOwner()
            or nil

        if owner ~= nil and owner.Transform ~= nil then
            local x, y, z = owner.Transform:GetWorldPosition()
            local loc_type = owner:HasTag("player") and "player" or "container"
            return { x = x, y = y, z = z }, loc_type, owner, current_shard
        end

        local x, y, z = katana_inst.Transform:GetWorldPosition()
        return { x = x, y = y, z = z }, "world", nil, current_shard
    end

    ----------------------------------------------------------------------
    -- Public API (closure methods)
    ----------------------------------------------------------------------

    self.SyncToAllShards = function(_, active, name)
        local n = NormalizeName(name)
        if n == nil then
            return
        end
        SyncToAllShards(active and true or false, n)
    end

    self.OnLocalTrack = function(_, data)
        if type(data) ~= "table" then
            return
        end

        local name = NormalizeName(data.name)
        if name == nil then
            return
        end

        HandleLocalTrack(name, data.inst)
    end

    self.OnLocalForget = function(_, data)
        if type(data) ~= "table" then
            return
        end

        local name = NormalizeName(data.name)
        if name == nil then
            return
        end

        HandleLocalForget(name, data.inst)
    end

    self.ReceiveShardSync = function(_, active, name, sender_shardid)
        if not TheWorld.ismastersim then
            return
        end

        local n = NormalizeName(name)
        if n == nil then
            return
        end

        local shardid = type(sender_shardid) == "string" and sender_shardid or tostring(sender_shardid or "unknown")

        if active then
            local existing = katanas[n]
            if UNIQUE_KATANAS[n]
                and existing ~= nil
                and existing.shardid == GetShardId()
                and IsValidEntity(existing.inst) then
                print(string.format(
                    "[KatanaSpawner] Cross-shard duplicate unique katana '%s' detected: local '%s' vs remote '%s'.",
                    n,
                    GetShardId(),
                    shardid
                ))
                return
            end

            TrackKatanaInternal(n, nil, shardid, false)
            return
        end

        local existing = katanas[n]
        if existing ~= nil and existing.shardid == shardid then
            UntrackKatanaInternal(n, false)
        end
    end

    self.TrackKatana = function(_, name, katana_inst, shardid, should_sync)
        local n = NormalizeName(name)
        if n == nil then
            return
        end

        local resolved_shard = shardid or GetShardId()
        TrackKatanaInternal(n, katana_inst, resolved_shard, should_sync == true)
    end

    self.UntrackKatana = function(_, name, should_sync)
        local n = NormalizeName(name)
        if n == nil then
            return
        end

        UntrackKatanaInternal(n, should_sync == true)
    end

    self.IsKatanaTracked = function(_, name)
        local n = NormalizeName(name)
        return n ~= nil and IsTrackedActive(n) or false
    end

    self.GetKatana = function(_, name)
        local n = NormalizeName(name)
        return n ~= nil and IsTrackedActive(n) or false
    end

    self.GetKatanaData = function(_, name)
        local n = NormalizeName(name)
        if n == nil then
            return nil
        end
        return katanas[n]
    end

    self.GetAllTrackedKatanas = function(_)
        local list = {}
        for name in pairs(katanas) do
            if IsTrackedActive(name) then
                table.insert(list, name)
            end
        end
        table.sort(list)
        return list
    end

    self.Count = function(_)
        local count = 0
        for name in pairs(katanas) do
            if IsTrackedActive(name) then
                count = count + 1
            end
        end
        return count
    end

    self.GetKatanaLocation = function(_, name)
        local n = NormalizeName(name)
        if n == nil then
            return nil, "untracked", nil, nil
        end
        return GetKatanaLocationInternal(n)
    end

    self.SpawnOrLocateKatana = function(_, name, spawn_pos)
        if not TheWorld.ismastersim then
            return nil
        end

        local n = NormalizeName(name)
        if n == nil then
            return nil
        end

        if IsTrackedActive(n) then
            local _, loc_type, _, shardid = GetKatanaLocationInternal(n)
            print(string.format("[KatanaSpawner] SpawnOrLocate: '%s' already exists. Location: %s, Shard: %s", n, loc_type, tostring(shardid)))

            local entry = katanas[n]
            if entry ~= nil and IsValidEntity(entry.inst) then
                return entry.inst
            end

            return nil
        end

        local katana_inst = SpawnPrefab(n)
        if katana_inst == nil then
            print(string.format("[KatanaSpawner] Error: Failed to spawn prefab '%s'", n))
            return nil
        end

        local x, y, z = ResolveSpawnPosition(spawn_pos)
        katana_inst.Transform:SetPosition(x, y, z)

        TrackKatanaInternal(n, katana_inst, GetShardId(), true)

        print(string.format(
            "[KatanaSpawner] SpawnOrLocate: Spawned '%s' at (%.1f, %.1f, %.1f) and registered.",
            n, x, y, z
        ))

        return katana_inst
    end

    self.CleanupInvalidEntries = function(_)
        CleanupInvalidEntriesInternal()
    end

    self.StartCleanupTask = function(_)
        StartCleanupTaskInternal()
    end

    self.OnSave = function(_)
        local saved = {}

        for name, entry in pairs(katanas) do
            saved[name] = {
                shardid = entry.shardid,
                tracked_time = entry.tracked_time,
            }
        end

        if next(saved) == nil then
            return nil
        end

        return { katanas = saved }
    end

    self.OnLoad = function(_, data)
        katanas = {}
        self.katanas = katanas

        if type(data) ~= "table" or type(data.katanas) ~= "table" then
            return
        end

        for name, entry_data in pairs(data.katanas) do
            local n = NormalizeName(name)
            if n ~= nil then
                katanas[n] = {
                    inst = nil,
                    shardid = entry_data ~= nil and entry_data.shardid or nil,
                    tracked_time = entry_data ~= nil and entry_data.tracked_time or GetTime(),
                }
            end
        end
    end

    self.OnPostLoad = function(_)
        local current_shard = GetShardId()

        for name, entry in pairs(katanas) do
            if entry.shardid == current_shard then
                SyncToAllShards(true, name)
            end
        end

        CleanupInvalidEntriesInternal()
    end

    self.OnRemoveFromEntity = function(_)
        if cleanup_task ~= nil then
            cleanup_task:Cancel()
            cleanup_task = nil
        end
    end

    self.GetDebugString = function(_)
        local count = self:Count()
        local lines = {
            string.format("Tracked Katanas: %d (Unique configured: %d)", count, TableSize(UNIQUE_KATANAS))
        }

        for name, entry in pairs(katanas) do
            local is_unique = UNIQUE_KATANAS[name] and "[Unique]" or "[Normal]"
            local inst_status = "Nil"
            local loc_desc = "Remote / Loaded (Waiting for bind)"

            if entry.inst ~= nil then
                if IsValidEntity(entry.inst) then
                    inst_status = "Valid"
                    local pos, loc_type, owner = GetKatanaLocationInternal(name)
                    if pos ~= nil then
                        loc_desc = string.format("%s at (%.1f, %.1f)", loc_type, pos.x, pos.z)
                        if owner ~= nil then
                            loc_desc = loc_desc .. string.format(" held by [%s]", tostring(owner.prefab or owner))
                        end
                    else
                        loc_desc = tostring(loc_type)
                    end
                else
                    inst_status = "Invalid"
                    loc_desc = "Stale local reference"
                end
            end

            table.insert(lines, string.format(
                "  - %s %s: [Shard: %s, Inst: %s, Loc: %s, Age: %.1fs]",
                name,
                is_unique,
                tostring(entry.shardid or "unknown"),
                inst_status,
                loc_desc,
                GetTime() - (entry.tracked_time or GetTime())
            ))
        end

        return table.concat(lines, "\n")
    end

    ----------------------------------------------------------------------
    -- Event registration and startup
    ----------------------------------------------------------------------

    local on_track_katana = function(_, data)
        self:OnLocalTrack(data)
    end

    local on_forget_katana = function(_, data)
        self:OnLocalForget(data)
    end

    self._on_track_katana = on_track_katana
    self._on_forget_katana = on_forget_katana

    inst:ListenForEvent("ms_trackkatana", on_track_katana, TheWorld)
    inst:ListenForEvent("ms_forgetkatana", on_forget_katana, TheWorld)

    StartCleanupTaskInternal()
end)

return KatanaSpawner
