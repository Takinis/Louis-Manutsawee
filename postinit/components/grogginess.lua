local Grogginess = require("components/grogginess")
GLOBAL.setfenv(1, GLOBAL)

-- Beams grog whatever they touch right after their damage, blocked or not.
local _MaximizeGrogginess = Grogginess.MaximizeGrogginess
function Grogginess:MaximizeGrogginess(...)
    if self.inst.kiritzuka_guard_tick ~= nil and self.inst.kiritzuka_guard_tick == GetTick() then
        return
    end
    return _MaximizeGrogginess(self, ...)
end

local _SetEnableSpeedMod = Grogginess.SetEnableSpeedMod
function Grogginess:SetEnableSpeedMod(enabled)
    _SetEnableSpeedMod(self, enabled)

    if enabled and self.enablespeedmod and self.inst:HasTag("controlled") then
        self.inst:AddTag("groggy")
    end
end

local _OnUpdate = Grogginess.OnUpdate
function Grogginess:OnUpdate(dt)
    _OnUpdate(self, dt)

    if self.grog_amount <= 0 and self.inst:HasTag("controlled") then
        self.inst:AddTag("groggy")
    end
end