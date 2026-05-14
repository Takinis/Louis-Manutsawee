local AddComponentPostInit = AddComponentPostInit
GLOBAL.setfenv(1, GLOBAL)

AddComponentPostInit("wisecracker", function(self, inst)
    -- local _fn = self.inst:GetEventCallbacks("lightningdamageavoided")
    -- self.inst:ListenForEvent("lightningdamageavoided", function(inst, hasraikiri)
    --     if hasraikiri then
    --         inst.components.talker:Say(GetString(inst, "ANNOUNCE_HASRAIKIRI"))
    --     else
    --         _fn(inst)
    --     end
    -- end)
end)
