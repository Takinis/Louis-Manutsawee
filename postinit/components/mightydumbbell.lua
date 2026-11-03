local MightyDumbbell = require("components/mightydumbbell")
GLOBAL.setfenv(1, GLOBAL)

-- Native code assumes whoever lifts has mightiness; Kiritzuka lifts for show.
local _StopWorkout = MightyDumbbell.StopWorkout
function MightyDumbbell:StopWorkout(...)
    if self.strongman ~= nil and self.strongman.components.mightiness == nil then
        self.inst:RemoveTag("lifting")
        self.strongman = nil
        return
    end
    return _StopWorkout(self, ...)
end
