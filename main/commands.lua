GLOBAL.setfenv(1, GLOBAL)

-- Rebuilds every Porkland pig ruin now so it can be looted again. Players, their followers and
-- items they left inside are moved to the ruin's entrance; unclaimed ruin loot is removed.
-- This is the only way to reset the ruins.
function c_resetpigruins()
    if TheWorld == nil or not TheWorld.ismastersim then
        print("c_resetpigruins: run this on the server.")
        return
    end
    if not PL_ENABLED or TheWorld.components.interiorspawner == nil then
        print("c_resetpigruins: this world has no Porkland pig ruins.")
        return
    end

    local count = require("utils/pigruinsutil").ResetAll(1)
    if count == nil then
        print("c_resetpigruins: a reset is already running.")
    else
        print(string.format("c_resetpigruins: resetting %d pig ruins, one per second.", count))
    end
end

function c_getkatana()
    d_spawnlist(ALL_KATANA)
end

function c_setmindpower(num)
    local player = ConsoleCommandPlayer()
    if player ~= nil and player.components.kenjutsuka ~= nil then
        player.components.kenjutsuka:SetMindpower(num or 30)
    end
end

function c_setexp(num)
    local player = ConsoleCommandPlayer()
    if player ~= nil and player.components.kenjutsuka ~= nil then
        player.components.kenjutsuka:SetExp(num or 1)
    end
end

if not rawget(_G, "c_revealmap") then
    function c_revealmap()
        local size = 2 * TheWorld.Map:GetSize()
        local player = ConsoleCommandPlayer()
        for x = -size, size, 32 do
            for z = -size, size, 32 do
                player.player_classified.MapExplorer:RevealArea(x, 0, z)
            end
        end
    end
end

function c_debug()
    local player = ConsoleCommandPlayer()
    c_supergodmode(player)
    c_select(player)
    c_freecrafting(player)
end

function c_mgive(t)
    for k,v in pairs(t) do
        c_give(v)
    end
end
