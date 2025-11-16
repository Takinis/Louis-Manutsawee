
local Prioritizations = {
    "lower",
    "normal",
    "higher",
    "always",
}

local Momentum = Class(function(self, inst)
    self.inst = inst
    self.states = {}
    self.basedamage = 0

    self.player_health = nil
    self.priority = "normal"
    self.dangertype = "large"
end)

local IsInNightmareArea = function(inst)
    return inst.components.areaaware ~= nil and inst.components.areaaware:CurrentlyInTag("Nightmare")
end

function Momentum:GetTargetPriority()
    return self.targetpriority
end

function Momentum:OnUpdate(dt)

end

return Momentum
