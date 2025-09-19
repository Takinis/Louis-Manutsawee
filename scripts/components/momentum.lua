local Momentum = Class(function(self, inst)

    self.targetpriority = ""
end)

local Prioritizations = {
    "lower",
    "normal",
    "higher",
    "always",
}

local IsInNightmare = function()

end

function Momentum:GetTargetPriority()
    return self.targetpriority
end

return Momentum
