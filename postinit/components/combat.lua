local SkillUtil = require("utils/skillutil")
local AddComponentPostInit = AddComponentPostInit
local Combat = require("components/combat")
GLOBAL.setfenv(1, GLOBAL)

local function StopBlockWindow(inst)
    if inst._blockactive_task ~= nil then
        inst._blockactive_task:Cancel()
        inst._blockactive_task = nil
    end
    inst._blockcount = 0
end

AddComponentPostInit("combat", function(self, inst)

    local _GetAttacked = self.GetAttacked
    function self:GetAttacked(attacker, damage, weapon, stimuli, spdamage, ...)
        if not inst:HasTag("kenjutsuka") then
            return _GetAttacked(self, attacker, damage, weapon, stimuli, spdamage, ...)
        end

        if attacker ~= nil then
            inst:ForceFacePoint(attacker.Transform:GetWorldPosition())
        end

        -- Keep block count per-player to avoid cross-instance interference.
        inst._blockcount = inst._blockcount or 0

        if inst.sg:HasStateTag("mdodgeing") or inst.inspskill then
            SkillUtil.AddFollowerFx(inst, "electricchargedfx")
            return true
        end

        local counter_window = inst.sg:HasStateTag("counteractive") or inst.sg:HasStateTag("startblockparry")
        if not counter_window and inst._blockcount > 0 then
            StopBlockWindow(inst)
        end

        if counter_window and weapon ~= nil then
            if inst._blockcount > 0 then
                StopBlockWindow(inst)
                inst:PushEvent("heavenlystrike")
                if attacker ~= nil and attacker.components.combat ~= nil then
                    SkillUtil.AoeAttack(inst, 2, 3)
                    SkillUtil.GroundPoundFx(inst, .6)
                    SkillUtil.SlashFx(inst, attacker, "shadowstrike_slash_fx", 1.6)
                end
                return true
            else
                inst:PushEvent("blockparry")
                inst._blockcount = inst._blockcount + 1
                if inst._blockactive_task ~= nil then
                    inst._blockactive_task:Cancel()
                end
                inst._blockactive_task = inst:DoTaskInTime(3, function(inst_)
                    StopBlockWindow(inst_)
                end)
                return true
            end
        end

        if counter_window and inst.sg:HasStateTag("counteractive") then
            if attacker ~= nil and attacker:IsValid() then
                inst.sg:GoToState("counter_attack", attacker)
                return true
            end
            return _GetAttacked(self, attacker, damage, weapon, stimuli, spdamage, ...)
        else
            return _GetAttacked(self, attacker, damage, weapon, stimuli, spdamage, ...)
        end
    end

end)

local _StartAttack = Combat.StartAttack
function Combat:StartAttack(...)
    _StartAttack(self, ...)

    if self.startattackfn ~= nil and self.forcefacing and self.target ~= nil and self.target:IsValid() then
        self.startattackfn(self.inst, self.target)
    end
end

function Combat:SetStartAttack(fn)
    self.startattackfn = fn
end
