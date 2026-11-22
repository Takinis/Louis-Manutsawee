-- Porkland layout rework: every task gets about the same number of rooms, and new tasks
-- attach to any unlocked parent so islands do not grow as long chains.

-- Rooms per task. Each room also spawns several background rooms, so equal room counts
-- give each terrain roughly the same area. Cities stay smaller so houses do not take over.
local TASK_ROOMS = 12
local CITY_TASK_ROOMS = 8
-- Feature rooms grow at most this much; the rest of a task is filled with its background room.
-- Scaling feature rooms further interleaves their tiles with the background into a checkerboard.
local FEATURE_MAX_SCALE = 1.5
local FEATURE_SCALE_OVERRIDES = {
    -- Lily ponds break the rainforest into patches; keep the vanilla count.
    rainforest_lillypond = 1,
}
-- The main island's lily pond tasks become whole lakes that hang off the deep rainforest.
-- Their vanilla lily pond rooms stay as the lake centres; the rest is filled with a lighter
-- lily pond background so the lake is one patch instead of ponds dotted through rainforest.
local LILYPOND_BG_ROOM = "ManutsaweeLilypondBG"
-- Lakes stay about half the size of the other terrains.
local LILYPOND_TASK_ROOMS = 6
-- The background copy is thinned, since the lake spreads it over many more tiles.
local LILYPOND_BG_DENSITY = 0.5
local LILYPOND_TASKS = {
    Lilypond_land = true,
    Lilypond_land_2 = true,
}
local CITY_TASKS = {
    Pigtopia = true,
    Pigtopia_capital = true,
    Other_pigtopia = true,
    Other_pigtopia_capital = true,
}

-- Tuber trees only grow in painted rooms; gather the main island's painted rooms into one terrain.
local TUBER_TASK = "Manutsawee_tuber_sands"
local PAINTED_ROOM = "BG_painted_base"
local PAINTED_SOURCE_TASKS = {
    painted_sands = "BG_battleground_base",
    Edge_of_the_unknown_2 = false,
}

-- The key that unlocks the next island's divider (a band of blank, impassable rooms) is
-- given by the last city task, so the blanks wrap around the city and leave only a narrow
-- forced path into it. Hand that key to a leaf jungle task so the divider sits at the edge.
local ISLAND_EXITS = {
    { key = "ISLAND_2", from = "Pigtopia_capital", to = "Lost_Ruins_1" },
    { key = "ISLAND_3", from = "Other_pigtopia_capital", to = "Deep_rainforest_mandrake" },
}

-- One-off rooms that hold unique prefabs, bosses or linked ruins; never duplicated.
local UNIQUE_ROOMS = {
    BG_pinacle_base = true,
    battleground_head = true,
    battleground_claw = true,
    battleground_leg = true,
    battleground_ribs = true,
    deeprainforest_anthill = true,
    deeprainforest_anthill_exit = true,
    deeprainforest_ruins_entrance = true,
    deeprainforest_ruins_exit = true,
    deeprainforest_mandrakeman = true,
    rainforest_pugalisk = true,
}

-- Surface ruin set pieces that can safely appear more than once.
local SCALABLE_SET_PIECES = {
    PigRuinsHead = true,
    PigRuinsArtichoke = true,
    pig_ruins_nocanopy = true,
    pig_ruins_nocanopy_2 = true,
    pig_ruins_nocanopy_3 = true,
    pig_ruins_nocanopy_4 = true,
    nettlegrove = true,
}

local function IsDivider(task)
    local choices = task.room_choices
    return choices == nil or choices.ForceDisconnectedRoom ~= nil
end

local function ScaleSetPieces(task, factor)
    factor = math.min(factor, FEATURE_MAX_SCALE)
    if factor <= 1 then
        return
    end

    local counts = {}
    for _, set_piece in ipairs(task.set_pieces or {}) do
        local name = set_piece.name
        if SCALABLE_SET_PIECES[name] then
            counts[name] = (counts[name] or 0) + 1
        end
    end
    for name, count in pairs(counts) do
        for _ = count + 1, math.floor(count * factor + 0.5) do
            table.insert(task.set_pieces, { name = name })
        end
    end
end

-- Resizes one task to task_rooms rooms while keeping its mix of room types.
local function EqualizeTask(task, background_override, task_rooms)
    local choices = task.room_choices
    local unique_count, scalable, scalable_count = 0, {}, 0
    for room, count in pairs(choices) do
        if type(count) == "number" and count > 0 then
            if UNIQUE_ROOMS[room] then
                unique_count = unique_count + count
            else
                scalable[#scalable + 1] = room
                scalable_count = scalable_count + count
            end
        end
    end
    local old_total = unique_count + scalable_count
    local available = math.max(task_rooms - unique_count, 0)

    local background = background_override or task.background_room
    if type(background) ~= "string" or UNIQUE_ROOMS[background] then
        background = nil
    end

    if scalable_count == 0 then
        if background ~= nil and available > 0 then
            choices[background] = available
        end
    else
        -- Proportional resize, keeping at least one room of every type that was present.
        -- Feature rooms are capped when growing; the background room takes the remaining space.
        table.sort(scalable)
        local factor = available / scalable_count
        local total = 0
        for _, room in ipairs(scalable) do
            local count = choices[room]
            local new_count = math.max(1, math.floor(count * factor + 0.5))
            if room ~= background and background ~= nil then
                local max_scale = FEATURE_SCALE_OVERRIDES[room] or FEATURE_MAX_SCALE
                new_count = math.min(new_count, math.max(count, math.floor(count * max_scale + 0.5)))
            end
            choices[room] = new_count
            total = total + new_count
        end

        -- Settle rounding on the biggest room type so the task lands on the target.
        table.sort(scalable, function(a, b)
            return choices[a] > choices[b] or choices[a] == choices[b] and a < b
        end)
        local diff = available - total
        local index = 1
        while diff < 0 and index <= #scalable do
            local room = scalable[index]
            if choices[room] > 1 then
                choices[room] = choices[room] - 1
                diff = diff + 1
            else
                index = index + 1
            end
        end
        if diff > 0 then
            local room = background or scalable[1]
            choices[room] = (choices[room] or 0) + diff
        end
    end

    if old_total > 0 then
        local new_total = 0
        for _, count in pairs(choices) do
            if type(count) == "number" then
                new_total = new_total + count
            end
        end
        ScaleSetPieces(task, new_total / old_total)
    end
end

local function SplitPaintedRooms(tasklist)
    for _, task in ipairs(tasklist) do
        local background = PAINTED_SOURCE_TASKS[task.id]
        if background ~= nil and task.room_choices ~= nil then
            task.room_choices[PAINTED_ROOM] = nil
            if background then
                task.background_room = background
            end
        end
    end
end

local function RemoveValue(list, value)
    for i = #list, 1, -1 do
        if list[i] == value then
            table.remove(list, i)
        end
    end
end

local function MoveIslandExits(tasklist)
    local by_id = {}
    for _, task in ipairs(tasklist) do
        by_id[task.id] = task
    end

    for _, exit in ipairs(ISLAND_EXITS) do
        local key = KEYS[exit.key]
        local from, to = by_id[exit.from], by_id[exit.to]
        if key and from and to and type(from.keys_given) == "table" and table.contains(from.keys_given, key) then
            RemoveValue(from.keys_given, key)
            if #from.keys_given == 0 then
                from.keys_given = { KEYS.NONE }
            end
            to.keys_given = type(to.keys_given) == "table" and to.keys_given or {}
            RemoveValue(to.keys_given, KEYS.NONE)
            if not table.contains(to.keys_given, key) then
                table.insert(to.keys_given, key)
            end
        else
            print("[Manutsawee] Porkland island exit " .. exit.key .. " has changed; leaving it on " .. exit.from .. ".")
        end
    end
end

-- Lily pond tasks normally attach to the first plains/rainforest ring (JUNGLE_DEPTH_1).
-- Lock them on JUNGLE_DEPTH_2, which only the deep rainforest tasks give, so each lake is
-- grown from a deep rainforest task. They give no key, so the two lakes never chain together.
local function AttachLilyponds(tasklist)
    for _, task in ipairs(tasklist) do
        if LILYPOND_TASKS[task.id] then
            task.locks = { LOCKS.JUNGLE_DEPTH_2 }
            task.keys_given = { KEYS.NONE }
            task.room_bg = WORLD_TILES.LILYPOND
        end
    end
end

local function EqualizeTasks(tasklist, background_overrides)
    MoveIslandExits(tasklist)
    SplitPaintedRooms(tasklist)
    AttachLilyponds(tasklist)
    for _, task in ipairs(tasklist) do
        if not IsDivider(task) then
            local override = background_overrides and background_overrides[task.id]
                or LILYPOND_TASKS[task.id] and LILYPOND_BG_ROOM
            if override then
                task.background_room = override
            end
            local task_rooms = CITY_TASKS[task.id] and CITY_TASK_ROOMS
                or LILYPOND_TASKS[task.id] and LILYPOND_TASK_ROOMS
                or TASK_ROOMS
            EqualizeTask(task, override, task_rooms)
        end
    end
end

local function GetTuberTaskDef()
    return {
        locks = LOCKS.JUNGLE_DEPTH_1,
        keys_given = KEYS.JUNGLE_DEPTH_1,
        room_tags = { "island_accademy" },
        room_choices = {
            [PAINTED_ROOM] = TASK_ROOMS,
        },
        room_bg = WORLD_TILES.PAINTED,
        background_room = PAINTED_ROOM,
        colour = { r = 1, g = 0.6, b = 0.2, a = 0.3 },
    }
end

-- Registers the tuber task once and puts it on the main island.
local tuber_registered = false
local function AddTuberTask(level, add_task)
    if not tuber_registered then
        if require("map/tasks").GetTaskByName(TUBER_TASK) == nil then
            add_task(TUBER_TASK, GetTuberTaskDef())
        end

        -- PorkLand separates islands by task name; unknown tasks would get no island border.
        local SeparateRegion = require("map/separate_region")
        local index = 1
        while true do
            local name, mapping = debug.getupvalue(SeparateRegion, index)
            if name == nil then
                print("[Manutsawee] Porkland island regions have changed; tuber task has no region.")
                break
            elseif name == "task_region_mapping" then
                mapping[TUBER_TASK] = "A"
                break
            end
            index = index + 1
        end
        tuber_registered = true
    end

    if level.tasks ~= nil and not table.contains(level.tasks, TUBER_TASK) then
        table.insert(level.tasks, TUBER_TASK)
    end
end

-- Background copy of the lily pond room: same tile and plants, but no guaranteed hippo and
-- a single lily pad layout, since every background node spawns the room's contents again.
local function AddLilypondRoom(add_room)
    local rooms = require("map/rooms")
    if rooms.GetRoomByName(LILYPOND_BG_ROOM) ~= nil then
        return
    end
    local source = rooms.GetRoomByName("rainforest_lillypond")
    if source == nil then
        print("[Manutsawee] Porkland lily pond room is missing; lakes keep the rainforest background.")
        LILYPOND_TASKS = {}
        return
    end

    local room = deepcopy(source)
    room.tags = {}
    local contents = room.contents
    contents.countprefabs = nil
    contents.countstaticlayouts = { lilypad = 1 }
    if contents.distributepercent then
        contents.distributepercent = contents.distributepercent * LILYPOND_BG_DENSITY
    end
    local weights = contents.distributeprefabs
    if weights and weights.hippopotamoose then
        weights.hippopotamoose = weights.hippopotamoose * 0.25
    end
    add_room(LILYPOND_BG_ROOM, room)
end

local installed = false
local function InstallBranching()
    if installed then
        return
    end

    require("map/pl_storygen")
    local Story = rawget(_G, "Story")
    local GenerateNodes = Story and Story.PL_GenerateNodesFromTasks
    if type(GenerateNodes) ~= "function" then
        print("[Manutsawee] Porkland story generator has changed; keeping its branching.")
        return
    end

    function Story:PL_GenerateNodesFromTasks(link_fn, ...)
        return GenerateNodes(self, function(story, ...)
            -- PorkLand uses "least", which always attaches to the deepest task and grows long
            -- arms; "default" spreads new tasks over every unlocked parent.
            story.gen_params.branching = "default"
            return link_fn(story, ...)
        end, ...)
    end
    installed = true
end

return {
    TASK_ROOMS = TASK_ROOMS,
    AddTuberTask = AddTuberTask,
    AddLilypondRoom = AddLilypondRoom,
    EqualizeTasks = EqualizeTasks,
    InstallBranching = InstallBranching,
}
