local AddStategraphPostInit = AddStategraphPostInit
GLOBAL.setfenv(1, GLOBAL)

local function ReadDuring(state)
    local _onupdate = state.onupdate
    state.onupdate = function(inst, ...)
        local target = inst.components.combat.target
        if target ~= nil and target.ReadPounce ~= nil and target:IsValid() then
            target:ReadPounce(inst)
        end
        if _onupdate ~= nil then
            return _onupdate(inst, ...)
        end
    end
end

AddStategraphPostInit("slurper", function(sg)
    -- Every attack starts unseen, so a pounce read earlier says nothing about this one.
    local _onenter = sg.states.attack.onenter
    sg.states.attack.onenter = function(inst, ...)
        inst.sg.mem.kiritzuka_pounce_reader = nil
        return _onenter(inst, ...)
    end
    ReadDuring(sg.states.attack)
    ReadDuring(sg.states.headslurp)
end)
