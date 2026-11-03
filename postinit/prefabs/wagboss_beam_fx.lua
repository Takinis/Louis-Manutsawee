local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

-- The beam only hears where W.A.R.B.O.T. stood when it fired, and native code keeps no record of it.
AddPrefabPostInit("wagboss_beam_fx", function(inst)
    if inst.TrackTarget == nil then
        return
    end

    local _TrackTarget = inst.TrackTarget
    function inst:TrackTarget(target, x0, z0, ...)
        self.kiritzuka_source_x, self.kiritzuka_source_z = x0, z0
        return _TrackTarget(self, target, x0, z0, ...)
    end
end)
