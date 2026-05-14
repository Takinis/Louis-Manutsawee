local modimport = modimport
local TUNING = TUNING
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

-- print("Loading ScaleRoomChoices")

-- -- Worldgen tweak: scale all shipwrecked island tasks to ~2x size.
-- if AddTaskPreInit ~= nil then
--     local function ScaleRoomChoices(room_choices, scale)
--         if type(room_choices) ~= "table" then
--             return
--         end
--         for key, value in pairs(room_choices) do
--             if type(value) == "number" then
--                 if value > 0 then
--                     room_choices[key] = math.max(1, math.floor(value * scale + 0.5))
--                 else
--                     room_choices[key] = 0
--                 end
--             elseif type(value) == "table" then
--                 ScaleRoomChoices(value, scale)
--             end
--         end
--     end

--     local SW_TASKS_TO_SCALE = {
--         "HomeIslandVerySmall",
--         "HomeIslandSmall",
--         "HomeIslandSmallBoon",
--         "HomeIslandMed",
--         "HomeIslandLarge",
--         "HomeIslandLargeBoon",
--         "DesertIsland",
--         "JungleMarsh",
--         "BeachJingleS",
--         "BeachBothJungles",
--         "BeachJungleD",
--         "BeachSavanna",
--         "GreentipA",
--         "GreentipB",
--         "HalfGreen",
--         "BeachRockyland",
--         "LotsaGrass",
--         "AllBeige",
--         "BeachMarsh",
--         "Verdant",
--         "VerdantMost",
--         "Vert",
--         "Florida Timeshare",
--         "JungleSRockyland",
--         "JungleSSavanna",
--         "JungleBeige",
--         "FullofBees",
--         "JungleDense",
--         "JungleDMarsh",
--         "JungleDRockyland",
--         "JungleDRockyMarsh",
--         "JungleDSavanna",
--         "JungleDSavRock",
--         "HotNSticky",
--         "Marshy",
--         "NoGreen A",
--         "NoGreen B",
--         "Savanna",
--         "DoydoyIslandGirl",
--         "DoydoyIslandBoy",
--         "IslandCasino",
--         "KelpForest",
--         "GreatShoal",
--         "IslandMeadowBeeQueen",
--         "BeachPalmForest",
--         "ThemeMarshCity",
--         "Spiderland",
--         "IslandJungleMonkeyHell",
--         "IslandJungleCritterCrunch",
--         "IslandJungleShroomin",
--         "IslandJungleRockyDrop",
--         "IslandJungleNoBerry",
--         "IslandJungleNoRock",
--         "IslandJungleNoMushroom",
--         "IslandJungleNoFlowers",
--         "IslandJungleEvilFlowers",
--         "IslandJungleSkeleton",
--         "IslandBeachCrabTown",
--         "IslandBeachDunes",
--         "IslandBeachGrassy",
--         "IslandBeachSappy",
--         "IslandBeachRocky",
--         "IslandBeachLimpety",
--         "IslandBeachForest",
--         "IslandBeachSpider",
--         "IslandBeachNoFlowers",
--         "IslandBeachNoLimpets",
--         "IslandBeachNoCrabbits",
--         "IslandMangroveOxBoon",
--         "IslandMeadowBees",
--         "IslandMeadowCarroty",
--         "IslandRockyTallBeach",
--         "IslandRockyTallJungle",
--         "PirateBounty",
--         "IslandOasis",
--         "ShellingOut",
--         "Cranium",
--         "CrashZone",
--         "SharkHome",
--         -- Coral cluster island.
--         "BarrierReef",
--     }

--     local e = {
--         -- Ore-rich islands.
--         "IslandRockyGold",
--         "Rockyland",
--         -- Bamboo-dense island.
--         -- High-resource islands only:
--         "IslandJungleBamboozled",
--     }

--     AddTaskPreInit("IslandParadise", function(task)
--         if task ~= nil and task.room_choices ~= nil then
--             ScaleRoomChoices(task.room_choices, 4)
--         end
--     end)

--     AddTaskPreInit("PiggyParadise", function(task)
--         if task ~= nil and task.room_choices ~= nil then
--             ScaleRoomChoices(task.room_choices, 3)
--         end
--     end)

--     for _, task_name in ipairs(e) do
--         AddTaskPreInit(task_name, function(task)
--             if task ~= nil and task.room_choices ~= nil then
--                 ScaleRoomChoices(task.room_choices, 2)
--             end
--         end)
--     end

--     for _, task_name in ipairs(SW_TASKS_TO_SCALE) do
--         AddTaskPreInit(task_name, function(task)
--             if task ~= nil and task.room_choices ~= nil then
--                 ScaleRoomChoices(task.room_choices, 2)
--             end
--         end)
--     end
-- end

-- require("map/storygen")
-- require("map/network")

-- -- Worldgen tweak: scale ocean spacing/area between islands to ~2x.
-- -- This is separate from island task scaling above.
-- if Story ~= nil and Story.SeperateIslandsByOcean ~= nil then
--     local _SeperateIslandsByOcean = Story.SeperateIslandsByOcean
--     Story.SeperateIslandsByOcean = function(story, startnode, endnode, links)
--         print("Scaling ocean links for separate islands by ocean...")
--         local ocean_links = tonumber(links) or 0
--         if ocean_links > 0 then
--             ocean_links = math.max(1, math.floor(ocean_links * 2 + 0.5))
--         end
--         return _SeperateIslandsByOcean(story, startnode, endnode, ocean_links)
--     end
-- end

-- -- Worldgen tweak: merge selectedtasks into tasks, then clear selectedtasks.
-- -- Implemented via hook (AddTaskSetPreInit), not by directly editing taskset logic.
-- AddTaskSetPreInit("shipwrecked", function(taskset)
--     if taskset == nil then
--         return
--     end

--     taskset.tasks = taskset.tasks or {}
--     taskset.selectedtasks = taskset.selectedtasks or {}

--     -- High-resource tasks picked from selectedtasks:
--     -- pig houses, five-biome rich island, ore-rich, dense bamboo, coral/ocean resource clusters.
--     local PROMOTE_TASKS = {
--         PiggyParadise = true,
--         IslandParadise = true,
--         IslandRockyGold = true,
--         Rockyland = true,
--         IslandJungleBamboozled = true,
--         BarrierReef = true,
--         GreatShoal = true,
--         KelpForest = true,
--     }

--     local exists = {}
--     for _, task_name in ipairs(taskset.tasks) do
--         exists[task_name] = true
--     end

--     -- Promote selected high-resource tasks into fixed tasks.
--     for _, selected in ipairs(taskset.selectedtasks) do
--         local choices = selected and selected.task_choices
--         if type(choices) == "table" then
--             for _, task_name in ipairs(choices) do
--                 if type(task_name) == "string" and PROMOTE_TASKS[task_name] and not exists[task_name] then
--                     table.insert(taskset.tasks, task_name)
--                     exists[task_name] = true
--                 end
--             end
--         end
--     end

--     -- Remove promoted tasks from selected choices, keep the rest randomized.
--     for _, selected in ipairs(taskset.selectedtasks) do
--         local choices = selected and selected.task_choices
--         if type(choices) == "table" then
--             local filtered = {}
--             for _, task_name in ipairs(choices) do
--                 if not PROMOTE_TASKS[task_name] then
--                     table.insert(filtered, task_name)
--                 end
--             end
--             selected.task_choices = filtered

--             -- Clamp min/max against new choice count to avoid invalid sampling.
--             local n = #filtered
--             if n == 0 then
--                 selected.min = 0
--                 selected.max = 0
--             else
--                 selected.min = math.max(0, math.min(selected.min or 0, n))
--                 selected.max = math.max(selected.min, math.min(selected.max or n, n))
--             end
--         end
--     end
-- end)
