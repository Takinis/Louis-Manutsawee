-- Tile cleanup that runs after Porkland's voronoi pass and before the cities are built:
-- - small patches of other terrain wedged into a city become suburb, so the city builder paves them;
-- - impassable holes enclosed by one island's land are filled with the surrounding terrain.

-- Largest terrain patch (in tiles) that can be folded into a city.
local ENCLAVE_MAX = 900
-- Share of a patch's land border that must touch city ground before it is folded in.
local ENCLAVE_CITY_SHARE = 0.7
-- Largest enclosed impassable hole (in tiles) that gets filled.
local HOLE_MAX = 1500

local CITY_TILES = {
    [WORLD_TILES.SUBURB] = true,
    [WORLD_TILES.FOUNDATION] = true,
    [WORLD_TILES.COBBLEROAD] = true,
    [WORLD_TILES.LAWN] = true,
}

-- Sparse vegetation for filled holes, as chance per tile; roughly the density of the base rooms.
local FILLERS = {
    [WORLD_TILES.RAINFOREST] = {
        { "rainforesttree", 0.12 }, { "sapling", 0.08 }, { "grass_tall", 0.08 }, { "flower_rainforest", 0.03 },
    },
    [WORLD_TILES.DEEPRAINFOREST] = {
        { "rainforesttree", 0.25 }, { "tree_pillar", 0.04 }, { "flower_rainforest", 0.1 }, { "lightrays_jungle", 0.08 },
    },
    [WORLD_TILES.GASJUNGLE] = {
        { "rainforesttree_rot", 0.2 }, { "poisonmist", 0.15 }, { "tree_pillar", 0.03 },
    },
    [WORLD_TILES.LILYPOND] = {
        { "reeds_water", 0.1 }, { "lotus", 0.07 },
    },
    [WORLD_TILES.PLAINS] = {
        { "grass_tall", 0.12 }, { "clawpalmtree", 0.06 }, { "sapling", 0.04 },
    },
    [WORLD_TILES.PAINTED] = {
        { "tubertree", 0.1 }, { "rocks", 0.02 },
    },
    [WORLD_TILES.FIELDS] = {
        { "teatree", 0.02 },
    },
}

local function GetRegionMapping()
    local SeparateRegion = require("map/separate_region")
    local index = 1
    while true do
        local name, value = debug.getupvalue(SeparateRegion, index)
        if name == nil then
            return nil
        elseif name == "task_region_mapping" then
            return value
        end
        index = index + 1
    end
end

local function Run(entities, topology, worldsim, width, height)
    local absorbed = {}
    local mapping = GetRegionMapping()
    if mapping == nil then
        print("[Manutsawee] Porkland island regions have changed; skipping terrain cleanup.")
        return absorbed
    end

    local impassable = WORLD_TILES.IMPASSABLE
    local tiles = {}
    for z = 0, height - 1 do
        for x = 0, width - 1 do
            tiles[z * width + x] = worldsim:GetTile(x, z)
        end
    end

    -- Island of every tile, so holes on island borders are never filled.
    local regions = {}
    for _, node in pairs(topology.root:GetNodes(true)) do
        local task = node.id:match("^([^:]+)") or node.id
        local region = mapping[task]
        if region then
            local points_x, points_y = worldsim:GetPointsForSite(node.id)
            for i = 1, #(points_x or {}) do
                regions[points_y[i] * width + points_x[i]] = region
            end
        end
    end

    local function ToTile(instance)
        local x = math.floor(instance.x / TILE_SCALE + width / 2 + 0.5)
        local z = math.floor(instance.z / TILE_SCALE + height / 2 + 0.5)
        if x >= 0 and x < width and z >= 0 and z < height then
            return z * width + x
        end
    end

    local protected = {}
    for _, prefab in ipairs(rawget(_G, "PORKLAND_REQUIRED_PREFABS") or {}) do
        for _, instance in ipairs(entities[prefab] or {}) do
            local index = ToTile(instance)
            if index then
                protected[index] = true
            end
        end
    end

    -- Flood fill over 4-neighbours that satisfy `inside`; `visit_border` sees each outside neighbour.
    local visited = {}
    local function Collect(start, inside, visit_border)
        local cells, queue, head = {}, { start }, 1
        visited[start] = true
        local touches_edge = false
        while head <= #queue do
            local index = queue[head]
            head = head + 1
            cells[#cells + 1] = index
            local x, z = index % width, math.floor(index / width)
            if x == 0 or z == 0 or x == width - 1 or z == height - 1 then
                touches_edge = true
            end
            local around, count = {}, 0
            if x > 0 then count = count + 1 around[count] = index - 1 end
            if x < width - 1 then count = count + 1 around[count] = index + 1 end
            if z > 0 then count = count + 1 around[count] = index - width end
            if z < height - 1 then count = count + 1 around[count] = index + width end
            for i = 1, count do
                local n = around[i]
                if inside(n) then
                    if not visited[n] then
                        visited[n] = true
                        queue[#queue + 1] = n
                    end
                else
                    visit_border(n)
                end
            end
        end
        return cells, touches_edge
    end

    -- Terrain patches wedged into cities.
    local enclave_tiles = {}
    for index = 0, width * height - 1 do
        local tile = tiles[index]
        if not visited[index] and tile ~= impassable and tile > 1 and not CITY_TILES[tile] then
            local city_border, land_border = 0, 0
            local cells = Collect(index, function(n) return tiles[n] == tile end, function(n)
                local other = tiles[n]
                if other ~= impassable and other > 1 then
                    land_border = land_border + 1
                    if CITY_TILES[other] then
                        city_border = city_border + 1
                    end
                end
            end)

            local blocked = #cells > ENCLAVE_MAX or city_border == 0
                or city_border < land_border * ENCLAVE_CITY_SHARE
            for i = 1, #cells do
                if blocked then
                    break
                end
                blocked = protected[cells[i]] == true
            end
            if not blocked then
                for _, cell in ipairs(cells) do
                    tiles[cell] = WORLD_TILES.SUBURB
                    worldsim:SetTile(cell % width, math.floor(cell / width), WORLD_TILES.SUBURB)
                    absorbed[cell] = true
                    enclave_tiles[cell] = true
                end
            end
        end
    end

    -- Enclosed holes inside one island.
    local filled = {}
    for index = 0, width * height - 1 do
        if not visited[index] and tiles[index] == impassable then
            local neighbours, border_regions, region_count = {}, {}, 0
            local cells, touches_edge = Collect(index, function(n) return tiles[n] == impassable end, function(n)
                local other = tiles[n]
                if other > 1 then
                    neighbours[other] = (neighbours[other] or 0) + 1
                end
                local region = regions[n]
                if region and not border_regions[region] then
                    border_regions[region] = true
                    region_count = region_count + 1
                end
            end)

            if not touches_edge and #cells <= HOLE_MAX and region_count <= 1 then
                local fill, best = nil, 0
                for other, count in pairs(neighbours) do
                    if count > best or count == best and fill ~= nil and other < fill then
                        fill, best = other, count
                    end
                end
                if fill then
                    if CITY_TILES[fill] then
                        fill = WORLD_TILES.SUBURB
                    end
                    for _, cell in ipairs(cells) do
                        tiles[cell] = fill
                        worldsim:SetTile(cell % width, math.floor(cell / width), fill)
                        if fill == WORLD_TILES.SUBURB then
                            absorbed[cell] = true
                        else
                            filled[#filled + 1] = cell
                        end
                    end
                end
            end
        end
    end

    -- The folded-in patches lose their wild props; the city builder lays out its own.
    for _, instances in pairs(entities) do
        for i = #instances, 1, -1 do
            local cell = ToTile(instances[i])
            if cell and enclave_tiles[cell] then
                table.remove(instances, i)
            end
        end
    end

    for _, cell in ipairs(filled) do
        local choices = FILLERS[tiles[cell]]
        if choices then
            local roll = math.random()
            for _, choice in ipairs(choices) do
                roll = roll - choice[2]
                if roll < 0 then
                    local prefab = choice[1]
                    local list = entities[prefab] or {}
                    entities[prefab] = list
                    list[#list + 1] = {
                        x = (cell % width - width / 2 + (math.random() - 0.5)) * TILE_SCALE,
                        z = (math.floor(cell / width) - height / 2 + (math.random() - 0.5)) * TILE_SCALE,
                    }
                    break
                end
            end
        end
    end

    return absorbed
end

return { Run = Run }
