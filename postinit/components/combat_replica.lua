local Combat = require("components/combat_replica")
local SmallAnimalUtil = require("utils/smallanimalutil")
GLOBAL.setfenv(1, GLOBAL)

-- Small animals are never offered as targets until hunger drives her to them. Blows can still catch them in passing.
local _CanTarget = Combat.CanTarget
function Combat:CanTarget(target, ...)
    if target ~= nil and SmallAnimalUtil.IsHunter(self.inst) and SmallAnimalUtil.IsSmallAnimal(target)
        and not SmallAnimalUtil.IsStarving(self.inst.replica.hunger) then
        return false
    end
    return _CanTarget(self, target, ...)
end
