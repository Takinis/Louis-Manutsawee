local AddPrefabPostInit = AddPrefabPostInit
local UpvalueUtil = require("utils/upvalueutil")
GLOBAL.setfenv(1, GLOBAL)

local m_offering_recipe = {
    kage = {
        recipes = {"katanablade", "livinglog", "nightmarefuel", "nightmarefuel", "nightmarefuel", "nightmarefuel"},
        fn = function(inst)
            inst.components.inventoryitem.nobounce = false
            inst.components.inventoryitem.canonlygoinpocket = false
            inst:DoTaskInTime(3, function(inst)
                inst.components.inventoryitem.nobounce = true
                inst.components.inventoryitem.canonlygoinpocket = true
            end)
        end
    }
}

AddPrefabPostInit("sacred_chest", function(inst)
    if not TheWorld.ismastersim then
        return
    end

    local _onclosefn = inst.components.container.onclosefn
    local DoLocalOffering = UpvalueUtil.GetUpvalue(_onclosefn, "DoLocalOffering")
    local DoNetworkOffering = UpvalueUtil.GetUpvalue(_onclosefn, "DoNetworkOffering")
    local CheckOffering = UpvalueUtil.GetUpvalue(DoLocalOffering, "CheckOffering")
    local LockChest = UpvalueUtil.GetUpvalue(DoLocalOffering, "LockChest")
    local MIN_LOCK_TIME = 2.5

    local function MCheckOffering(items)
        for k, v in pairs(m_offering_recipe) do
            local valid = true
            for i, item in ipairs(items) do
                if v.recipes[i] ~= item.prefab then
                    valid = false
                    break
                end
            end
            if valid then
                return k
            end
        end

        return nil
    end

    local GetRewardItem = function()
        local rewarditem = MCheckOffering(inst.components.container.slots)
        if rewarditem == nil then
            rewarditem = CheckOffering(inst.components.container.slots)
        end
        return rewarditem
    end

    local function _DoLocalOffering(inst, doer)
        if inst.components.container:IsFull() then
            local rewarditem = GetRewardItem()
            if rewarditem then
                LockChest(inst)
                local reward = SpawnPrefab(rewarditem)
                local i = m_offering_recipe[reward.prefab]
                if i ~= nil and i.fn ~= nil then
                    i.fn(reward)
                end
                inst.components.container:DestroyContents()
                inst.components.container:GiveItem(reward)
                inst.components.timer:StartTimer("localoffering", MIN_LOCK_TIME)
                return true
            end
        end

        return false
    end

    function inst.components.container.onclosefn(inst, doer, ...)
        inst.AnimState:PlayAnimation("close")

        if not _DoLocalOffering(inst, doer) then
            DoNetworkOffering(inst, doer)
        end
    end
end)
