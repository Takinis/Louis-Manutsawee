local SkillUtil = require("utils/skillutil")
local AddComponentPostInit = AddComponentPostInit
local Combat = require("components/combat")
GLOBAL.setfenv(1, GLOBAL)

AddComponentPostInit("combat", function(self, inst)

    local _GetAttacked = self.GetAttacked
    function self:GetAttacked(attacker, damage, weapon, stimuli, spdamage, ...)
        if not inst:HasTag("kenjutsuka") then
            return _GetAttacked(self, attacker, damage, weapon, stimuli, spdamage, ...)
        end

        if inst.sg:HasStateTag("mdodgeing") or inst.inspskill then
            SkillUtil.AddFollowerFx(inst, "electricchargedfx")
            return true
        end

        local predictor = inst.components.counterpredictor
        if predictor ~= nil and predictor:ShouldBlockAttack(attacker, weapon) then
            SkillUtil.AddFollowerFx(inst, "electricchargedfx")
            return true
        end
        return _GetAttacked(self, attacker, damage, weapon, stimuli, spdamage, ...)
    end

end)

local _GetAttacked_Internal = Combat.GetAttacked_Internal
function Combat:GetAttacked_Internal(attacker, damage, weapon, stimuli, spdamage, ...)
    if self.inst.InterceptHit ~= nil and self.inst:InterceptHit(attacker, damage, weapon, stimuli, spdamage, ...) then
        return true
    end
    -- A redirected hit comes back through here on whichever target actually takes it.
    if attacker ~= nil and attacker.OffsetTargetDefense ~= nil and damage ~= nil
        and self.redirectdamagefn == nil and self.inst.components.health ~= nil then
        damage, spdamage = attacker:OffsetTargetDefense(self.inst, weapon, damage, spdamage)
    end
    return _GetAttacked_Internal(self, attacker, damage, weapon, stimuli, spdamage, ...)
end

local _StartAttack = Combat.StartAttack
function Combat:StartAttack(...)
    _StartAttack(self, ...)

    local target = self.target
    local predictor = target ~= nil and target:IsValid() and target.components.counterpredictor or nil
    if predictor ~= nil then
        predictor:WatchAttacker(self.inst)
    end

    if self.startattackfn ~= nil and self.forcefacing and self.target ~= nil and self.target:IsValid() then
        self.startattackfn(self.inst, self.target)
    end
end

function Combat:SetStartAttack(fn)
    self.startattackfn = fn
end
