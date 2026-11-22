local modimport = modimport
local AddRoom = AddRoom
local AddTask = AddTask
local AddLevelPreInitAny = AddLevelPreInitAny
local AddRoomPreInit = AddRoomPreInit
local AddTaskPreInit = AddTaskPreInit
local AddTaskSetPreInit = AddTaskSetPreInit
GLOBAL.setfenv(1, GLOBAL)

local IsTheFrontEnd = rawget(_G, "TheFrontEnd") and rawget(_G, "IsInFrontEnd") and IsInFrontEnd()
if IsTheFrontEnd then return end

modimport("main/config")
modimport("postinit/map/tasks/dst_tasks_forestworld")
modimport("scripts/map/m_layouts")
modimport("scripts/map/rooms/dev_cemetery")
modimport("postinit/screens/worldgenscreen")

local SHIPWRECKED_WORLD_SIZE = 800
local WORLD_SIZE_HOOK_FLAG = "manutsawee_shipwrecked_world_size_hook"

local function IsShipwreckedWorld()
    local dimensions = rawget(_G, "CONSTANT_DIMENSIONS")
    return dimensions ~= nil
        and rawget(_G, "IA_worldtype") == dimensions.SHIPWRECKED
end

local function InstallShipwreckedWorldSizeHook()
    if rawget(_G, WORLD_SIZE_HOOK_FLAG) then
        return
    end

    local worldsim = rawget(_G, "WorldSim")
    local metatable = worldsim ~= nil and getmetatable(worldsim) or nil
    local methods = metatable ~= nil and metatable.__index or nil
    if type(methods) ~= "table" then
        return
    end

    local SetWorldSize = methods.SetWorldSize
    local ConvertToTileMap = methods.ConvertToTileMap
    if type(SetWorldSize) ~= "function" or type(ConvertToTileMap) ~= "function" then
        return
    end

    methods.SetWorldSize = function(sim, width, height, ...)
        if IsShipwreckedWorld() then
            width = math.max(tonumber(width) or 0, SHIPWRECKED_WORLD_SIZE)
            height = math.max(tonumber(height) or 0, SHIPWRECKED_WORLD_SIZE)
        end
        return SetWorldSize(sim, width, height, ...)
    end

    methods.ConvertToTileMap = function(sim, size, ...)
        if IsShipwreckedWorld() then
            size = math.max(tonumber(size) or 0, SHIPWRECKED_WORLD_SIZE)
        end
        return ConvertToTileMap(sim, size, ...)
    end

    rawset(_G, WORLD_SIZE_HOOK_FLAG, true)
end

InstallShipwreckedWorldSizeHook()

if AddLevelPreInitAny ~= nil and KnownModIndex:IsModEnabledAny("workshop-3322803908") then
    local peak_room = "ManutsaweePorklandPeak"

    if AddRoomPreInit ~= nil then
        local function IncreaseTeaTreeSpawns(room)
            local contents = room.contents
            local weights = contents and contents.distributeprefabs
            if not (weights and weights.teatree and weights.teatree > 0 and contents.distributepercent) then
                return
            end

            local total = 0
            for _, weight in pairs(weights) do
                total = total + weight
            end
            -- Increase total density so other prefabs keep their original spawn probability.
            contents.distributepercent = math.min(1, contents.distributepercent * (total + weights.teatree) / total)
            weights.teatree = weights.teatree * 2

            local counts = contents.countprefabs
            if counts and counts.teatree_piko_nest_patch then
                counts.teatree_piko_nest_patch = counts.teatree_piko_nest_patch + 1
            end
        end

        for _, name in ipairs({ "BG_cultivated_base", "cultivated_base_1", "cultivated_base_2", "piko_land" }) do
            AddRoomPreInit(name, IncreaseTeaTreeSpawns)
        end
    end

    AddLevelPreInitAny(function(level)
        if level.location ~= "porkland" or level.overrides.task_set ~= "porkland" then
            return
        end

        local Layout = require("map/manutsawee_porkland_layout")
        require("map/manutsawee_porkland_city").Install()
        Layout.InstallBranching()
        Layout.AddTuberTask(level, AddTask)
        Layout.AddLilypondRoom(AddRoom)

        local rooms = require("map/rooms")
        if rooms.GetRoomByName(peak_room) == nil then
            local room = deepcopy(rooms.GetRoomByName("BG_pinacle_base"))
            -- Keep the scepter in the original peak room.
            room.contents.countprefabs.pig_scepter = nil
            AddRoom(peak_room, room)
        end

        level.overrides.world_size = "huge"

        local ApplyModsToTasks = level.ApplyModsToTasks
        function level:ApplyModsToTasks(tasklist)
            ApplyModsToTasks(self, tasklist)
            -- The copy keeps the scepter in the original peak room.
            Layout.EqualizeTasks(tasklist, { pincale = peak_room })
        end
    end)
end

if AddLevelPreInitAny ~= nil then
    AddLevelPreInitAny(function(level)
        InstallShipwreckedWorldSizeHook()

        local overrides = level ~= nil and level.overrides or nil
        if overrides ~= nil and overrides.task_set == "shipwrecked" then
            overrides.world_size = "huge"
        end
    end)
end

if AddTaskPreInit ~= nil then
    local function ScaleRoomChoices(room_choices, scale)
        for key, value in pairs(room_choices or {}) do
            if type(value) == "number" then
                room_choices[key] = value * scale
            elseif type(value) == "table" then
                ScaleRoomChoices(value, scale)
            end
        end
    end

    for _, task_name in ipairs({
        "IslandJungleBamboozled",
        "PiggyParadise",
        "IslandParadise"
    }) do
        AddTaskPreInit(task_name, function(task)
            ScaleRoomChoices(task ~= nil and task.room_choices or nil, 2)
        end)
    end

    AddTaskPreInit("IslandParadise", function(task)
        if task == nil then
            return
        end

        local outer_rooms = task.room_choices or {}
        ScaleRoomChoices(outer_rooms, 2)
        -- outer_rooms.Jungle = math.max(0, (outer_rooms.Jungle or 0) - 1)

        -- task.gen_method = "lagoon"
        -- task.room_choices = {
        --     {
        --         Jungle = 1,
        --     },
        --     outer_rooms,
        -- }
        -- task.hub_room = nil
        -- task.make_loop = nil
        -- task.crosslink_factor = nil
        -- task.room_bg = WORLD_TILES.BEACH
        -- task.background_room = nil
    end)

    AddTaskPreInit("BeachPalmForest", function(task)
        if task == nil then
            return
        end

        local room_choices = task.room_choices or {}
        local room_count = math.max(1, tonumber(room_choices.BeachPalmForest) or 1) * 2
        local inner_count = math.ceil(room_count / 2)

        task.gen_method = "lagoon"
        task.room_choices = {
            {
                BeachPalmForest = inner_count,
            },
            {
                BeachPalmForest = room_count - inner_count,
            },
        }
        task.room_bg = WORLD_TILES.BEACH
        task.background_room = "BeachPalmForest"
    end)

    AddTaskPreInit("Vert", function(task)
        local room_choices = task ~= nil and task.room_choices or nil
        local count = room_choices ~= nil and room_choices.MeadowCarroty or nil
        if type(count) == "number" and count > 0 then
            room_choices.MeadowCarroty = nil
            room_choices.NoOxMeadow = (room_choices.NoOxMeadow or 0) + count
        end
    end)
end

if AddRoomPreInit ~= nil then
    AddRoomPreInit("BeachPalmForest", function(room)
        local contents = room ~= nil and room.contents or nil
        if contents == nil then
            return
        end

        contents.distributepercent = 0.55
        contents.distributeprefabs = contents.distributeprefabs or {}
        contents.distributeprefabs.palmtree = 2
    end)
end

if AddTaskSetPreInit ~= nil then
    AddTaskSetPreInit("shipwrecked", function(taskset)
        if taskset == nil then
            return
        end

        taskset.tasks = taskset.tasks or {}

        local selected_tasks_to_keep = {
            BeachBothJungles = true,
            Cranium = true,
            BeachJingleS = true,
            GreentipA = true,
            GreentipB = true,
            HalfGreen = true,
            LotsaGrass = true,
            CrashZone = true,
            VerdantMost = true,
            PiggyParadise = true,
            BeachPalmForest = true,
            JungleSRockyland = true,
            Spiderland = true,
            IslandJungleBamboozled = true,
            JungleDRockyland = true,
            JungleDRockyMarsh = true,
            ThemeMarshCity = true,
            IslandJungleCritterCrunch = true,
            KelpForest = true,
            GreatShoal = true,
            BarrierReef = true,
            Rockyland = true,
            IslandJungleMonkeyHell = true,
            FullofBees = true,
            IslandJungleRockyDrop = true,
            IslandJungleEvilFlowers = true,
            ["NoGreen B"] = true,
            IslandRockyGold = true,
            IslandRockyTallBeach = true,
        }

        local exists = {}
        for _, task_name in ipairs(taskset.tasks) do
            exists[task_name] = true
        end

        if not exists.BeachPalmForest then
            table.insert(taskset.tasks, "BeachPalmForest")
            exists.BeachPalmForest = true
        end

        for _, selected in ipairs(taskset.selectedtasks or {}) do
            for _, task_name in ipairs(selected.task_choices or {}) do
                if selected_tasks_to_keep[task_name] and not exists[task_name] then
                    table.insert(taskset.tasks, task_name)
                    exists[task_name] = true
                end
            end
        end

        taskset.selectedtasks = {}
    end)
end
