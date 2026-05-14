local AddModRPCHandler = AddModRPCHandler
local AddClientModRPCHandler = AddClientModRPCHandler
local AddShardModRPCHandler = AddShardModRPCHandler
GLOBAL.setfenv(1, GLOBAL)

local LouisManutsawee = "LouisManutsawee"

local function GetSkillController(inst)
    return inst ~= nil and inst.components ~= nil and inst.components.playerskillcontroller or nil
end

local function CanPerformIdleAction(inst)
    local controller = GetSkillController(inst)
    if controller ~= nil and controller.CanPerformIdleAction ~= nil then
        return controller:CanPerformIdleAction()
    end

    return inst.components.inventory ~= nil
        and not (inst.components.health ~= nil and inst.components.health:IsDead() and not inst:HasTag("playerghost"))
        -- and inst:HasTag("idle")
        and not (inst.sg:HasStateTag("doing") or inst.components.inventory:IsHeavyLifting())
        and not (inst.sg:HasStateTag("moving") or inst:HasTag("moving"))
end

local function HandleSkillInput(inst, input_name)
    local controller = GetSkillController(inst)
    if controller ~= nil then
        return controller:HandleSkillInput(input_name)
    end
    return true
end

local function HandleSkillCancel(inst)
    local controller = GetSkillController(inst)
    if controller ~= nil then
        return controller:CancelSkill()
    end
    return true
end

local function HandleCounterAttack(inst)
    local controller = GetSkillController(inst)
    if controller ~= nil then
        return controller:CounterAttack()
    end
    return true
end

local function HandleQuickSheath(inst)
    local controller = GetSkillController(inst)
    if controller ~= nil then
        return controller:QuickSheath()
    end
    return true
end

local LouisManutsawee_RPC_HANDLERS = {
    RPC_Handlers = {
        [SKILL_INPUT.ICHIMONJI] = function(inst)
            return HandleSkillInput(inst, SKILL_INPUT.ICHIMONJI)
        end,

        [SKILL_INPUT.FLIP] = function(inst)
            return HandleSkillInput(inst, SKILL_INPUT.FLIP)
        end,

        [SKILL_INPUT.THRUST] = function(inst)
            return HandleSkillInput(inst, SKILL_INPUT.THRUST)
        end,

        [SKILL_INPUT.SORYUHA] = function(inst)
            return HandleSkillInput(inst, SKILL_INPUT.SORYUHA)
        end,

        CounterAttackKey = HandleCounterAttack,
        SkillCancelKey = HandleSkillCancel,
        QuickSheathKey = HandleQuickSheath,

        LevelCheckKey = function(inst)
            local kenjutsuka = inst.components.kenjutsuka
            if kenjutsuka ~= nil and not inst.components.timer:TimerExists("levelcheck_cd") then
                inst.components.timer:StartTimer("levelcheck_cd", .8)
                if inst.components.talker.task == nil then
                    local level = "󰀍: " .. kenjutsuka:GetLevel()
                    local exp = "󰀏: " .. kenjutsuka:GetExp() .. "/" .. kenjutsuka:GetMaxExpForMaxLevel()
                    local mindpower = "󰀈: " .. kenjutsuka:GetMindpower() .. "/" .. kenjutsuka:GetMaxMindpower()
                    inst.components.talker:Say(level .. exp .. "\n" .. mindpower, 2, true)
                end
            end
            return true
        end,

        ChangeHairStyleKey = function(inst, skinname)
            local hair_length = inst.components.hair ~= nil and inst.components.hair:GetHairLength()
            if CanPerformIdleAction(inst) and not inst.components.timer:TimerExists("change_hair_cd") and hair_length ~= nil then
                inst.components.timer:StartTimer("change_hair_cd", 1)
                if hair_length == "cut" then
                    inst.components.talker:Say(GetString(inst, "ANNOUNCE_HAIR_TOO_SHORT"))
                else
                    inst:PushEventInTime(.1, "change_hair_style")
                end
            end
            return true
        end,

        PutGlassesKey = function(inst, skinname)
            if CanPerformIdleAction(inst) and not inst.components.timer:TimerExists("put_glasses_cd") then
                inst.components.timer:StartTimer("put_glasses_cd", 1)
                inst:PushEventInTime(.1, "put_glasses")
            end
            return true
        end,
    },

    Client_RPC_Handlers = {},

    Shard_RPC_Handlers = {
        SyncKatanaSpawnerData = function(shardid, active, name)
            if active then
                TheWorld:PushEvent("ms_trackkatana", {name = name})
            else
                TheWorld:PushEvent("ms_forgetkatana", {name = name})
            end
        end,

        SyncDatingManagerData = function(shardid, active, name)
            if active then
            end
        end,
    },
}

for name, handler in pairs(LouisManutsawee_RPC_HANDLERS.RPC_Handlers) do
    AddModRPCHandler(LouisManutsawee, name, handler)
end

for name, handler in pairs(LouisManutsawee_RPC_HANDLERS.Client_RPC_Handlers) do
    if AddClientModRPCHandler ~= nil then
        AddClientModRPCHandler(LouisManutsawee, name, handler)
    end
end

for name, handler in pairs(LouisManutsawee_RPC_HANDLERS.Shard_RPC_Handlers) do
    if AddShardModRPCHandler ~= nil then
        AddShardModRPCHandler(LouisManutsawee, name, handler)
    end
end
