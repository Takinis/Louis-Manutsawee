local function GetLastDodgeTime(self, inst)
    self.last_dodge_time = GetTime()
end

local Dodger = Class(function(self, inst)
    self.inst = inst

    self.dodge_time = net_bool(inst.GUID, "dodge_time", "dodgetimedirty")
    self.dodge_cooldown_time = TUNING.DEFAULT_DODGE_COOLDOWN_TIME
    self.last_dodge_time = GetTime()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("dodgetimedirty", GetLastDodgeTime, self)
    end
end)

function Dodger:SetCooldownTime(time)
    if not TheWorld.ismastersim then
        self.dodge_cooldown_time = time
    end
end

function Dodger:OnRemoveFromEntity()
    if not TheWorld.ismastersim then
        self.inst:RemoveEventCallback("dodgetimedirty", GetLastDodgeTime)
    end
end

return Dodger
