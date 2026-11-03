local AddAction = AddAction
local Vector3 = GLOBAL.Vector3
local AddComponentAction = AddComponentAction
local modimport = modimport
GLOBAL.setfenv(1, GLOBAL)

local M_ACTIONS = {
    MDODGE = Action({priority = -5, distance = math.huge, instant = false}),
}

for name, ACTION in pairs(M_ACTIONS) do
    ACTION.id = name
    ACTION.str = STRINGS.ACTIONS[name] or "Unknown ACTION"
    AddAction(ACTION)
end


-- The native inventory action only offers lifting to strongmen.
AddComponentAction("INVENTORY", "mightydumbbell", function(inst, doer, actions)
    if doer.prefab == "kiritzuka" and inst.replica.equippable ~= nil and inst.replica.equippable:IsEquipped() then
        table.insert(actions, inst:HasTag("lifting") and ACTIONS.STOP_LIFT_DUMBBELL or ACTIONS.LIFT_DUMBBELL)
    end
end)

local _BAIT_fn = ACTIONS.BAIT.fn
ACTIONS.BAIT.fn = function(act)
    if act.target.components.trap then
        act.target.components.trap:SetBait(act.doer.components.inventory:RemoveItem(act.invobject), act.doer)
        return true
    end
    return _BAIT_fn(act)
end
