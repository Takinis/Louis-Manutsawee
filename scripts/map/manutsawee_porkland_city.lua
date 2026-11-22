local UpvalueUtil = require("utils/upvalueutil")

local ROAD_LENGTH = 6
local SUBURB_BORDER = 4
local HEDGE_PARKS = {
    city_park_1 = true,
    city_park_2 = true,
    city_park_8 = true,
}
local HEDGE_PREFABS = { "hedge_block", "hedge_cone", "hedge_layered" }
local DISTRICT_CLUTTER = {
    grass = true,
    rocks = true,
    twigs = true,
    spoiled_food = true,
}
local DISTRICT_SITE_RADIUS = 2
local DISTRICT_HEDGE_CHANCE = 0.5
-- Share of building lots per city; shops stay sparse so the expanded city is mostly houses.
local SHOP_SHARE = 0.02
local TOWER_SHARE = 0.15
local EMPTY_SHARE = 0.1
-- One farm with pig farmhouses per this many farmland sites (vanilla always places 3).
local FARMLAND_PER_FARM = 3
-- Hedge rings snap to the wall grid (half-unit offsets) from an integer centre.
local HEDGE_GARDEN_HALF = 2.5
local installed = false
-- Tiles the cleanup folded into a city; streets may run over them even outside city sites.
local absorbed_tiles = {}

local function PopRandom(list)
    local index = math.random(#list)
    local value = list[index]
    list[index] = list[#list]
    list[#list] = nil
    return value
end

local function FindHouseQuota(quotas)
    for index, quota in ipairs(quotas or {}) do
        if quota.prefab == "pighouse_city" then
            return quota, index
        end
    end
end

local function AddStartingCityShops(starting_quotas, royal_quotas, insert_at)
    local existing = {}
    for _, quota in ipairs(royal_quotas) do
        existing[quota.prefab] = true
    end

    for _, quota in ipairs(starting_quotas) do
        local prefab = quota.prefab
        if prefab:match("^pig_shop_") and prefab ~= "pig_shop_cityhall" and not existing[prefab] then
            table.insert(royal_quotas, insert_at, { prefab = prefab, num = 1 })
            existing[prefab] = true
            insert_at = insert_at + 1
        end
    end
end

local function ScaleBuildingQuotas(quotas, base_nums, lots)
    local shops, tower, house = {}, nil, nil
    for _, quota in ipairs(quotas) do
        if quota.prefab:match("^pig_shop_") then
            shops[#shops + 1] = quota
        elseif quota.prefab == "pig_guard_tower" then
            tower = quota
        elseif quota.prefab == "pighouse_city" then
            house = quota
        end
    end

    -- Quotas are module state shared by retries, so always scale from the vanilla numbers.
    local used = 0
    local per_shop = #shops > 0 and math.floor(lots * SHOP_SHARE / #shops + 0.5) or 0
    for _, quota in ipairs(shops) do
        quota.num = math.max(base_nums[quota], per_shop)
        used = used + quota.num
    end
    if tower then
        tower.num = math.max(base_nums[tower], math.floor(lots * TOWER_SHARE))
        used = used + tower.num
    end
    if house then
        house.num = math.max(base_nums[house], lots - used - math.floor(lots * EMPTY_SHARE))
    end
end

local function BuildSuburbDistrict(entities, worldsim, width, height)
    local far, developed = {}, {}
    local urban_tiles = {
        [WORLD_TILES.COBBLEROAD] = true,
        [WORLD_TILES.FOUNDATION] = true,
        [WORLD_TILES.LAWN] = true,
    }

    local function ToTile(instance)
        local x = math.floor(instance.x / TILE_SCALE + width / 2 + 0.5)
        local z = math.floor(instance.z / TILE_SCALE + height / 2 + 0.5)
        if x >= 0 and x < width and z >= 0 and z < height then
            return z * width + x
        end
    end

    local suburb = {}
    for z = 0, height - 1 do
        for x = 0, width - 1 do
            local tile = worldsim:GetTile(x, z)
            local index = z * width + x
            if tile == WORLD_TILES.SUBURB then
                suburb[#suburb + 1] = index
            elseif urban_tiles[tile] then
                developed[index] = true
            end
        end
    end

    for _, instances in pairs(entities) do
        for _, instance in ipairs(instances) do
            local scenario = instance.scenario
            if scenario == "set_city_possession_1" or scenario == "set_city_possession_2" then
                local index = ToTile(instance)
                if index then
                    developed[index] = true
                end
            end
        end
    end

    local function IsNearCity(x, z)
        for dz = -SUBURB_BORDER, SUBURB_BORDER do
            local reach = SUBURB_BORDER - math.abs(dz)
            for nx = math.max(0, x - reach), math.min(width - 1, x + reach) do
                if developed[(z + dz) * width + nx] then
                    return true
                end
            end
        end
        return false
    end

    local count = 0
    for _, index in ipairs(suburb) do
        if not IsNearCity(index % width, math.floor(index / width)) then
            far[index] = true
            count = count + 1
        end
    end
    if count == 0 then
        return
    end

    -- Leftover pockets the streets could not reach become paved ground with hedge gardens.
    local occupied = {}
    for prefab, instances in pairs(entities) do
        local clutter = DISTRICT_CLUTTER[prefab]
        for i = #instances, 1, -1 do
            local index = ToTile(instances[i])
            if index and far[index] then
                if clutter then
                    table.remove(instances, i)
                else
                    occupied[index] = true
                end
            end
        end
    end

    for index in pairs(far) do
        worldsim:SetTile(index % width, math.floor(index / width), WORLD_TILES.FOUNDATION)
    end

    local function IsFreeSite(x, z)
        for dz = -DISTRICT_SITE_RADIUS, DISTRICT_SITE_RADIUS do
            for dx = -DISTRICT_SITE_RADIUS, DISTRICT_SITE_RADIUS do
                local nx, nz = x + dx, z + dz
                if nx < 0 or nx >= width or nz < 0 or nz >= height then
                    return false
                end
                local index = nz * width + nx
                if not far[index] or occupied[index] then
                    return false
                end
            end
        end
        return true
    end

    local function AddEntity(prefab, wx, wz)
        local list = entities[prefab] or {}
        entities[prefab] = list
        list[#list + 1] = { x = wx, z = wz }
    end

    local function AddHedgeGarden(wx, wz)
        local prefab = HEDGE_PREFABS[math.random(#HEDGE_PREFABS)]
        local gap_side = math.random(4)
        local half = HEDGE_GARDEN_HALF
        for side = 1, 4 do
            for step = -half, half do
                -- Leave a two-hedge gap in the middle of one side as the entrance.
                if side ~= gap_side or math.abs(step) > 1 then
                    local ox, oz
                    if side == 1 then ox, oz = step, -half
                    elseif side == 2 then ox, oz = half, step
                    elseif side == 3 then ox, oz = -step, half
                    else ox, oz = -half, -step end
                    -- Skip duplicate corners from the neighbouring side.
                    if not (math.abs(step) == half and side % 2 == 0) then
                        AddEntity(prefab, wx + ox, wz + oz)
                    end
                end
            end
        end
    end

    -- Gardens sit on the same 6-tile grid as city intersections.
    for z = ROAD_LENGTH, height - 1 - ROAD_LENGTH, ROAD_LENGTH do
        for x = ROAD_LENGTH, width - 1 - ROAD_LENGTH, ROAD_LENGTH do
            if far[z * width + x] and IsFreeSite(x, z) then
                local wx = (x - width / 2) * TILE_SCALE
                local wz = (z - height / 2) * TILE_SCALE
                if math.random() < DISTRICT_HEDGE_CHANCE then
                    AddHedgeGarden(wx, wz)
                end
            end
        end
    end
end

local function Install()
    if installed then
        return
    end

    local BuildPorkland = require("map/build_porkland")
    local MakeCities, build_owner, build_index = UpvalueUtil.GetUpvalue(BuildPorkland, "make_cities")
    if type(MakeCities) ~= "function" then
        print("[Manutsawee] Porkland world builder has changed; skipping city changes.")
        return
    end
    local CreateCity, owner, index = UpvalueUtil.GetUpvalue(MakeCities, "create_city")
    local SetBuildings, buildings_owner, buildings_index = UpvalueUtil.GetUpvalue(MakeCities, "set_buildings")
    local starting_quotas = UpvalueUtil.GetUpvalue(MakeCities, "set_buildings.BUILDING_QUOTAS")
    local royal_quotas = UpvalueUtil.GetUpvalue(MakeCities, "set_buildings.BUILDING_QUOTAS_2")
    local quota1 = FindHouseQuota(starting_quotas)
    local quota2, royal_house_index = FindHouseQuota(royal_quotas)
    local MakeRoad = CreateCity and UpvalueUtil.GetUpvalue(CreateCity, "make_road")
    local PlaceCityTile = CreateCity and UpvalueUtil.GetUpvalue(CreateCity, "place_tile_city")
    local TestTile = CreateCity and UpvalueUtil.GetUpvalue(CreateCity, "test_tile")
    local valid_tiles = CreateCity and UpvalueUtil.GetUpvalue(CreateCity, "VALID_TILES")
    local directions = MakeRoad and UpvalueUtil.GetUpvalue(MakeRoad, "DIR_STEP")
    local park_choices = UpvalueUtil.GetUpvalue(MakeCities, "make_parks.PARK_CHOICES")
    local MakeFarms = UpvalueUtil.GetUpvalue(MakeCities, "make_farms")
    local PlaceFarm, farm_owner, farm_index
    local farm_choices
    if type(MakeFarms) == "function" then
        PlaceFarm, farm_owner, farm_index = UpvalueUtil.GetUpvalue(MakeFarms, "place_farm")
        farm_choices = UpvalueUtil.GetUpvalue(MakeFarms, "FARM_CHOICES")
    end
    if not (quota1 and quota2 and SetBuildings and MakeRoad and PlaceCityTile and TestTile and valid_tiles and directions) then
        print("[Manutsawee] Porkland city builder has changed; using the original road and building limits.")
        return
    end

    local function CreateExpandedCity(entities, width, height, spawners, city)
        local grid, candidates = {}, {}
        -- Include every buildable intersection in the city sites, even far from the first street.
        for _, node in ipairs(city.citynodes) do
            local poly = node.poly
            if #poly.x > 0 and #poly.y > 0 then
                local min_x = math.max(ROAD_LENGTH, math.ceil(math.min(unpack(poly.x)) / ROAD_LENGTH) * ROAD_LENGTH)
                local min_z = math.max(ROAD_LENGTH, math.ceil(math.min(unpack(poly.y)) / ROAD_LENGTH) * ROAD_LENGTH)
                for x = min_x, math.min(width - 1 - ROAD_LENGTH, math.max(unpack(poly.x))), ROAD_LENGTH do
                    local column = grid[x] or {}
                    grid[x] = column
                    for z = min_z, math.min(height - 1 - ROAD_LENGTH, math.max(unpack(poly.y))), ROAD_LENGTH do
                        if column[z] == nil and (absorbed_tiles[z * width + x] or WorldSim:PointInSite(node.id, x, z)) then
                            local point = { x = x, y = 0, z = z }
                            if TestTile(point, valid_tiles) then
                                column[z] = point
                                candidates[#candidates + 1] = point
                            end
                        end
                    end
                end
            end
        end

        local frontier = {}
        local function CanBuildRoad(point, dir)
            local step = directions[dir]
            for i = 1, ROAD_LENGTH do
                if not TestTile({ x = point.x + step.x * i, z = point.z + step.z * i }, valid_tiles) then
                    return false
                end
            end
            return true
        end

        local function QueueRoads(point)
            local before = #frontier
            for dir, step in ipairs(directions) do
                local column = grid[point.x + step.x * ROAD_LENGTH]
                local neighbor = column and column[point.z + step.z * ROAD_LENGTH]
                if neighbor and not neighbor.visited and CanBuildRoad(point, dir) then
                    frontier[#frontier + 1] = { start = point, target = neighbor, dir = dir }
                end
            end
            return #frontier > before
        end

        -- No road limit: keep paving until every reachable intersection has streets.
        while #frontier > 0 or #candidates > 0 do
            if #frontier == 0 then
                local start = PopRandom(candidates)
                if not start.visited and QueueRoads(start) then
                    start.visited = true
                    PlaceCityTile(entities, width, height, start)
                end
            else
                local road = PopRandom(frontier)
                if not road.target.visited and CanBuildRoad(road.start, road.dir) then
                    MakeRoad(entities, width, height, spawners, road.start, road.dir, true, city)
                    road.target.visited = true
                    QueueRoads(road.target)
                end
            end
        end
    end

    AddStartingCityShops(starting_quotas, royal_quotas, royal_house_index)
    local base_nums = {}
    for _, quotas in ipairs({ starting_quotas, royal_quotas }) do
        for _, quota in ipairs(quotas) do
            base_nums[quota] = quota.num
        end
    end

    debug.setupvalue(owner, index, CreateExpandedCity)
    if type(PlaceFarm) == "function" and type(farm_choices) == "table" then
        debug.setupvalue(farm_owner, farm_index, function(entities, width, height, spawners, nodes, city, total, set, ...)
            if set == farm_choices then
                total = math.max(total, math.ceil(#nodes / FARMLAND_PER_FARM))
            end
            return PlaceFarm(entities, width, height, spawners, nodes, city, total, set, ...)
        end)
    else
        print("[Manutsawee] Porkland farm builder has changed; using the original farm count.")
    end
    debug.setupvalue(buildings_owner, buildings_index, function(spawners, city, ...)
        local lots = 0
        for _, spawn in ipairs(spawners) do
            if spawn.prefab == "pig_shop_spawner" and spawn.city == city.city_id then
                lots = lots + 1
            end
        end
        ScaleBuildingQuotas(city.city_id == 2 and royal_quotas or starting_quotas, base_nums, lots)
        return SetBuildings(spawners, city, ...)
    end)
    debug.setupvalue(build_owner, build_index, function(entities, topology, worldsim, width, height, ...)
        absorbed_tiles = require("map/manutsawee_porkland_cleanup").Run(entities, topology, worldsim, width, height)
        local built = MakeCities(entities, topology, worldsim, width, height, ...)
        BuildSuburbDistrict(built, worldsim, width, height)
        return built
    end)
    if type(park_choices) == "table" then
        for i = 1, #park_choices do
            local park = park_choices[i]
            if HEDGE_PARKS[park] then
                park_choices[#park_choices + 1] = park
                park_choices[#park_choices + 1] = park
            end
        end
    end
    installed = true
end

return { Install = Install }
