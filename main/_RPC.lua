-- use for manutsawee

local AddModRPCHandler = AddModRPCHandler
local AddShardModRPCHandler = AddShardModRPCHandler
local LouisManutsawee = "LouisManutsawee"
GLOBAL.setfenv(1, GLOBAL)

local LouisManutsawee_RPC_HANDLERS = {
    RPC_Handlers = {
        Skill_1 = function(inst)
            if inst.components.playerskillcontroller:CanActivateSkill(inst) then

            end
        end,
        Skill_2 = function()

        end,
        Skill_3 = function()

        end,
    },
    Client_RPC_Handlers = {

    },
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

for k, v in pairs(LouisManutsawee_RPC_HANDLERS.RPC_Handlers) do
    AddModRPCHandler(LouisManutsawee, k, v)
end

for k, v in pairs(LouisManutsawee_RPC_HANDLERS.Shard_RPC_Handlers) do
    AddShardModRPCHandler(LouisManutsawee, k, v)
end
