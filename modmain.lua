local modimport = modimport

local modules = {
    "config",
    "constants",
    "recipes",
    "assets",
    "strings",
    "fx",
    "tuning",
    "actions",
    "postinit",
    "containers",
    "RPC",
    "characters",
    "prefabskin",
    "commands",
    "loadingtips",
}

for i = 1, #modules do
    modimport("main/" .. modules[i])
end

GLOBAL.setfenv(1, GLOBAL)

if IsRail() then
    error("Ban WeGame");
end
