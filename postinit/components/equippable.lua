local Equippable = require("components/equippable")
GLOBAL.setfenv(1, GLOBAL)

-- Kiritzuka can hold a dumbbell without being a strongman, which would also open the gym and mightiness.
local _IsRestricted = Equippable.IsRestricted
function Equippable:IsRestricted(target, ...)
    if target.prefab == "kiritzuka" and self.inst:HasTag("dumbbell") then
        return false
    end
    return _IsRestricted(self, target, ...)
end

-- 帮Klei擦屁股
local _ToPocket = Equippable.ToPocket
function Equippable:ToPocket(owner, ...)
    _ToPocket(self, owner or self.inst.components.inventoryitem.owner, ...)
end