local modimport = modimport
local modname = modname

local modules = {
    "config",
    "util",
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

-- A local (non-workshop) copy is the dev build, same as the " - Dev" name in modinfo.
if not modname:find("^workshop%-") then
    require("utils/hangwatchdog").Start()
end

if IsRail() then
    error("Ban WeGame");
end
