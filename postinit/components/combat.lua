local SkillUtil = require("utils/skillutil")
local AddComponentPostInit = AddComponentPostInit
local Combat = require("components/combat")
GLOBAL.setfenv(1, GLOBAL)

local blockcount = 0
local function BlockActive(inst)
    if inst.blockactive ~= nil then
        inst.blockactive:Cancel()
        inst.blockactive = nil
    end
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

        if weapon ~= nil and (not inst.sg:HasStateTag("mdodgeing")) then
            if blockcount > 0 then
                blockcount = 0
                BlockActive(inst)
                inst:PushEvent("heavenlystrike")
                if attacker.components.combat ~= nil then
                    --inst.components.combat:DoAttack(attacker)
                    SkillUtil.AoeAttack(inst, 2,3)
                    SkillUtil.GroundPoundFx(inst, .6)
                    SkillUtil.SlashFx(inst, attacker, "shadowstrike_slash_fx", 1.6)
                end
            else
                inst:PushEvent("blockparry")
                blockcount = blockcount + 1
                BlockActive(inst)
                inst.blockactive = inst:DoTaskInTime(3, function()
                    blockcount = 0
                end)
            end
        end

        if inst.sg:HasStateTag("mdodgeing") or inst.inspskill then
            SkillUtil.AddFollowerFx(inst, "electricchargedfx")
        elseif inst.sg:HasStateTag("counteractive") then

            inst.sg:GoToState("counter_attack", attacker)

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
