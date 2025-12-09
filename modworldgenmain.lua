local modimport = modimport
local TUNING = TUNING
GLOBAL.setfenv(1, GLOBAL)

local IsTheFrontEnd = rawget(_G, "TheFrontEnd") and rawget(_G, "IsInFrontEnd") and IsInFrontEnd()
if IsTheFrontEnd then return end

modimport("main/config")
modimport("postinit/map/tasks/dst_tasks_forestworld")
modimport("scripts/map/m_layouts")
modimport("scripts/map/rooms/dev_cemetery")
modimport("postinit/screens/worldgenscreen")
