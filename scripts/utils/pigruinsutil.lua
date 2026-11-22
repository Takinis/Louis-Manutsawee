-- Porkland pig ruins: bigger mazes with more secret rooms, and a reset that tears a ruin down
-- and builds a fresh one behind the same entrance so it can be looted again.

local UpvalueUtil = require("utils/upvalueutil")

-- Ruin rooms grow by this much; the secret rooms are on top of that.
local ROOM_SCALE = 1.5
local EXTRA_SECRET_ROOMS = 10
-- Interior slots kept free for shops, houses, anthills and bat caves. Porkland places every
-- interior on a fixed grid, and rooms past its end are outside the interior region.
local RESERVED_SLOTS = 120
local MAX_SLOT_SCAN = 4000

-- Entrance prefab and the prefab of its second exit, if the ruin has one.
local ENTRANCES = {
    pig_ruins_entrance = "pig_ruins_exit",
    pig_ruins_entrance2 = "pig_ruins_exit2",
    pig_ruins_entrance3 = false,
    pig_ruins_entrance4 = "pig_ruins_exit4",
    pig_ruins_entrance5 = false,
    pig_ruins_entrance_small = false,
}

local entrances = setmetatable({}, { __mode = "k" })
local InitMaze = nil
local installed = false

local function FreeSlots(spawner)
    local free = GetTableSize(spawner.reuse_interior_ids)
    for id = spawner.next_interior_id + 1, spawner.next_interior_id + MAX_SLOT_SCAN do
        local pos = spawner:IndexToPosition(id)
        if not spawner:IsInInteriorRegion(pos.x, pos.z) then
            break
        end
        free = free + 1
    end
    return free
end

-- Adds the extra rooms to a maze definition, scaled down if the interior grid is nearly full.
local function GrowMaze(dungeondef)
    local spawner = TheWorld.components.interiorspawner
    local rooms = dungeondef.rooms or 0
    local secret_rooms = dungeondef.secretrooms or 0
    local extra_rooms = math.floor(rooms * ROOM_SCALE + 0.5) - rooms
    local extra_secret = EXTRA_SECRET_ROOMS
    local wanted = extra_rooms + extra_secret
    if wanted <= 0 then
        return
    end

    local budget = math.max(FreeSlots(spawner) - RESERVED_SLOTS - rooms - secret_rooms, 0)
    if budget < wanted then
        extra_rooms = math.floor(extra_rooms * budget / wanted + 0.5)
        extra_secret = budget - extra_rooms
        print(string.format("[Manutsawee] Interior grid is nearly full; %s only gets %d extra rooms.",
            tostring(dungeondef.name), extra_rooms + extra_secret))
    end
    dungeondef.rooms = rooms + extra_rooms
    dungeondef.secretrooms = secret_rooms + extra_secret
end

-- Only rooms this ruin built: every pig ruin room is saved with its ruin's dungeon name, while
-- anthills, shops, houses and caves use their own names.
local function IsRuinRoom(spawner, center, dungeon_name)
    local def = center ~= nil and center:IsValid() and center.interiorID ~= nil
        and spawner.interior_defs[center.interiorID] or nil
    return def ~= nil and def.dungeon_name == dungeon_name
end

-- Every room behind an entrance, found through the doors between rooms.
local function GetRooms(spawner, entrance)
    local dungeon_name = entrance.dungeon_name
    local start = entrance.interiorID ~= nil and spawner.interiors[entrance.interiorID] or nil
    local rooms, queue = {}, { start }
    while #queue > 0 do
        local center = table.remove(queue)
        if IsRuinRoom(spawner, center, dungeon_name) and not rooms[center] then
            rooms[center] = true
            local x, _, z = center.Transform:GetWorldPosition()
            for _, door in ipairs(TheSim:FindEntities(x, 0, z, TUNING.ROOM_FINDENTITIES_RADIUS, { "interior_door" })) do
                local target = door.components.door ~= nil and door.components.door.target_interior or nil
                if type(target) == "number" then
                    queue[#queue + 1] = spawner.interiors[target]
                end
            end
        end
    end
    return rooms
end

-- Loot a build spawns on the floor or on its shelves. Whatever is still unclaimed at the next
-- reset is removed with the ruin; picked-up items stop being tracked, so anything players drop
-- or leave behind is moved out instead.
local function Untrack(item)
    local entrance = item.manutsawee_ruin_entrance
    if entrance ~= nil and entrance.manutsawee_ruin_loot ~= nil then
        entrance.manutsawee_ruin_loot[item] = nil
    end
    item.manutsawee_ruin_entrance = nil
    item:RemoveEventCallback("onputininventory", Untrack)
    item:RemoveEventCallback("onremove", Untrack)
end

local function Track(entrance, item)
    entrance.manutsawee_ruin_loot = entrance.manutsawee_ruin_loot or {}
    entrance.manutsawee_ruin_loot[item] = true
    item.manutsawee_ruin_entrance = entrance
    item:ListenForEvent("onputininventory", Untrack)
    item:ListenForEvent("onremove", Untrack)
end

local function IsRuinLoot(entrance, item)
    return entrance.manutsawee_ruin_loot ~= nil and entrance.manutsawee_ruin_loot[item] == true
end

local function TrackBuiltLoot(entrance)
    entrance.manutsawee_ruin_loot = {}
    local spawner = TheWorld.components.interiorspawner
    for center in pairs(GetRooms(spawner, entrance)) do
        local x, _, z = center.Transform:GetWorldPosition()
        for _, ent in ipairs(TheSim:FindEntities(x, 0, z, TUNING.ROOM_FINDENTITIES_RADIUS, nil, { "INLIMBO" })) do
            if ent.components.inventoryitem ~= nil then
                Track(entrance, ent)
            elseif ent.components.container ~= nil then
                for _, item in ipairs(ent.components.container:GetAllItems()) do
                    Track(entrance, item)
                end
            end
        end
    end
end

local function WrapSaveLoad(entrance)
    local OnSave = entrance.OnSave
    entrance.OnSave = function(inst, data, ...)
        local refs = OnSave ~= nil and OnSave(inst, data, ...) or nil
        if inst.manutsawee_ruin_loot ~= nil then
            local loot = {}
            for item in pairs(inst.manutsawee_ruin_loot) do
                if item:IsValid() and item.persists ~= false then
                    loot[#loot + 1] = item.GUID
                end
            end
            if #loot > 0 then
                data.manutsawee_ruin_loot = loot
                refs = refs or {}
                for _, guid in ipairs(loot) do
                    table.insert(refs, guid)
                end
            end
        end
        return refs
    end

    local OnLoadPostPass = entrance.OnLoadPostPass
    entrance.OnLoadPostPass = function(inst, newents, data, ...)
        if OnLoadPostPass ~= nil then
            OnLoadPostPass(inst, newents, data, ...)
        end
        if data ~= nil and data.manutsawee_ruin_loot ~= nil then
            inst.manutsawee_ruin_loot = {}
            for _, guid in ipairs(data.manutsawee_ruin_loot) do
                local record = newents[guid]
                if record ~= nil and record.entity ~= nil then
                    Track(inst, record.entity)
                end
            end
        end
    end
end

local function Install(entrance)
    if installed then
        return InitMaze ~= nil
    end
    installed = true

    local init_maze = UpvalueUtil.GetUpvalue(entrance.OnLoad, "InitMaze")
    local build_maze, scope, index = nil, nil, nil
    if type(init_maze) == "function" then
        build_maze, scope, index = UpvalueUtil.GetUpvalue(init_maze, "BuildMaze")
    end
    if type(build_maze) ~= "function" then
        print("[Manutsawee] Porkland pig ruins have changed; ruins keep their size and cannot be reset.")
        return false
    end

    debug.setupvalue(scope, index, function(inst, dungeondef, ...)
        GrowMaze(dungeondef)
        local exit_room = build_maze(inst, dungeondef, ...)
        TrackBuiltLoot(inst)
        return exit_room
    end)
    InitMaze = init_maze
    return true
end

local function Register(entrance)
    if Install(entrance) then
        entrances[entrance] = true
        WrapSaveLoad(entrance)
    end
end

local function Teleport(ent, pos)
    if ent.Physics ~= nil then
        ent.Physics:Teleport(pos:Get())
    else
        ent.Transform:SetPosition(pos:Get())
    end
end

-- A spot in front of the entrance; items are scattered a little so they don't stack up.
local function GetDropPoint(entrance, radius)
    local pos = entrance:GetPosition()
    local offset = FindWalkableOffset(pos, math.random() * TWOPI, radius, 8, false, true)
    return offset ~= nil and pos + offset or pos
end

local function IsPlayerFollower(ent)
    local leader = ent.components.follower ~= nil and ent.components.follower:GetLeader() or nil
    return leader ~= nil and leader:HasTag("player")
end

local function MoveOut(item, entrance)
    Teleport(item, GetDropPoint(entrance, 2 + math.random() * 2))
end

-- Players, their followers and items that aren't the ruin's own loot leave the room;
-- everything else is removed. Ids of the removed doors go into removed_doors.
local function ClearRoom(center, entrance, removed_doors)
    local x, _, z = center.Transform:GetWorldPosition()
    local radius = TUNING.ROOM_FINDENTITIES_RADIUS

    for _, player in ipairs(TheSim:FindEntities(x, 0, z, radius, { "player" })) do
        local pos = GetDropPoint(entrance, 3)
        player:PushEvent("pl_clearfrominterior", { exterior_pos = pos })
        Teleport(player, pos)
        if player.SnapCamera ~= nil then
            player:SnapCamera()
        end
    end

    -- Player-built structures break so their contents and materials drop.
    local destroyer = TheWorld.components.interiorspawner.destroyer
    for _, ent in ipairs(TheSim:FindEntities(x, 0, z, radius, { "structure" }, { "INLIMBO" })) do
        local workable = ent.components.workable
        if workable ~= nil and workable:CanBeWorked() and workable:GetWorkAction() == ACTIONS.HAMMER then
            workable:Destroy(destroyer)
        end
    end

    for _, ent in ipairs(TheSim:FindEntities(x, 0, z, radius, nil, { "player", "INLIMBO", "pl_interiorcenter" })) do
        if ent:IsValid() then
            if ent.components.inventoryitem ~= nil then
                if IsRuinLoot(entrance, ent) then
                    ent:Remove()
                else
                    MoveOut(ent, entrance)
                end
            elseif IsPlayerFollower(ent) then
                Teleport(ent, GetDropPoint(entrance, 3))
            else
                -- Items players put on ruin shelves come out; the shelf's own loot goes with it.
                local door = ent.components.door
                if door ~= nil and door.door_id ~= nil then
                    removed_doors[door.door_id] = true
                end
                local container = ent.components.container
                if container ~= nil then
                    for _, item in ipairs(container:GetAllItems()) do
                        if not IsRuinLoot(entrance, item) then
                            MoveOut(container:RemoveItem(item, true), entrance)
                        end
                    end
                end
                ent:Remove()
            end
        end
    end

    local id = center.interiorID
    center:Remove()
    if id ~= nil then
        -- Drops the room from every player's interior minimap.
        TheWorld:PushEvent("room_removed", { id = id })
    end
end

local function DetachExterior(spawner, ent)
    if ent.interiorspawner_exterior_on_remove_listener ~= nil then
        ent:RemoveEventCallback("onremove", ent.interiorspawner_exterior_on_remove_listener)
        ent.interiorspawner_exterior_on_remove_listener = nil
    end
    if ent.interiorID ~= nil and spawner.exteriors[ent.interiorID] == ent then
        spawner.exteriors[ent.interiorID] = nil
    end
end

-- The second exit is linked to whichever room the new maze picks as its exit room.
local function RelinkExit(spawner, exit, dungeon_name)
    local exit_door = spawner.doors[dungeon_name .. "_EXIT2"]
    local room_id = exit_door ~= nil and exit_door.inst:IsValid() and exit_door.my_interior_name or nil
    DetachExterior(spawner, exit)
    if room_id == nil then
        print("[Manutsawee] Rebuilt " .. dungeon_name .. " has no exit room; its second exit stays closed.")
        exit.interiorID = nil
        exit.components.door:SetDoorDisabled(true, "manutsawee_reset")
        return
    end

    exit.interiorID = room_id
    exit.components.door:SetDoorDisabled(false, "manutsawee_reset")
    spawner:AddDoor(exit, {
        my_door_id = dungeon_name .. "_ENTRANCE2",
        target_door_id = dungeon_name .. "_EXIT2",
        target_interior = room_id,
    })
    spawner:AddExterior(exit)
end

local function Reset(entrance)
    local spawner = TheWorld.components.interiorspawner
    local dungeon_name = entrance.dungeon_name
    if InitMaze == nil or spawner == nil or dungeon_name == nil or entrance.interiorID == nil then
        return false
    end

    local exit_prefab = ENTRANCES[entrance.prefab]
    local exit = exit_prefab and TheSim:FindFirstEntityWithTag(dungeon_name .. "_EXIT_TARGET") or nil

    local rooms = GetRooms(spawner, entrance)
    if next(rooms) == nil then
        print("[Manutsawee] " .. dungeon_name .. " has no ruin rooms behind its entrance; skipping its reset.")
        return false
    end

    local removed_doors = {}
    for center in pairs(rooms) do
        ClearRoom(center, entrance, removed_doors)
    end
    -- Drop the records of this ruin's removed doors; the new rooms register their own.
    for door_id in pairs(removed_doors) do
        local door = spawner.doors[door_id]
        if door ~= nil and (door.inst == nil or not door.inst:IsValid()) then
            spawner.doors[door_id] = nil
        end
    end

    DetachExterior(spawner, entrance)
    entrance.interiorID = nil
    InitMaze(entrance, dungeon_name)
    -- An entrance whose vines were already hacked stays open.
    if entrance.stage == 0 then
        entrance.components.door:SetDoorDisabled(false, "vines")
    end

    if exit ~= nil then
        RelinkExit(spawner, exit, dungeon_name)
    end
    return true
end

local reset_task = nil

-- Resets every registered ruin, one per `delay` seconds so the mazes are not all built in one frame.
-- Returns how many ruins were queued, or nil if a reset is already running.
local function ResetAll(delay)
    if reset_task ~= nil then
        return nil
    end

    local queue = {}
    for entrance in pairs(entrances) do
        if entrance:IsValid() then
            queue[#queue + 1] = entrance
        end
    end

    local count = #queue
    local function Step()
        reset_task = nil
        local entrance = table.remove(queue, 1)
        if entrance ~= nil and entrance:IsValid() then
            Reset(entrance)
        end
        if #queue > 0 then
            reset_task = TheWorld:DoTaskInTime(delay or 1, Step)
        end
    end
    if count > 0 then
        Step()
    end
    return count
end

local function GetEntrances()
    local list = {}
    for entrance in pairs(entrances) do
        if entrance:IsValid() then
            list[#list + 1] = entrance
        end
    end
    return list
end

return {
    ENTRANCES = ENTRANCES,
    Register = Register,
    Reset = Reset,
    ResetAll = ResetAll,
    GetEntrances = GetEntrances,
}
