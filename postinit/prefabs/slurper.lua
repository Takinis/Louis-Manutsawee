local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

-- A failed test is the only way to keep it off the head: passing it knocks her hat off and latches on.
-- The attack also asks from out of reach, where it should still leap; the leap asks again up close.
AddPrefabPostInit("slurper", function(inst)
    if inst.HatTest == nil then
        return
    end

    local _HatTest = inst.HatTest
    function inst:HatTest(target, ...)
        if target.RepelPounce ~= nil and self:IsNear(target, 2) and target:RepelPounce(self) then
            return false
        end
        return _HatTest(self, target, ...)
    end
end)
