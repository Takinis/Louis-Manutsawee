local AddModRPCHandler = AddModRPCHandler
local AddShardModRPCHandler = AddShardModRPCHandler
local STRINGS = GLOBAL.STRINGS
GLOBAL.setfenv(1, GLOBAL)

local nskill1 = 1
local nskill2 = 3
local nskill3 = 4
local nskill4 = 6
local nskill5 = 5
local nskill6 = 7

local nskill7 = 8
local nskill8 = 10
local ncountskill = 2

local LouisManutsawee = "LouisManutsawee"

local function SkillRemove(inst)
    inst.components.playerskillcontroller:DeactivateSkill()
end

local MUST_TAG = {"tool", "sharp", "weapon", "katana"}
local CANT_TAG = {"projectile", "whip", "rangedweapon"}
local function CanActivateSkill(inst)
    local inventory = inst.components.inventory
    local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    local IsAsleep = inst.components.sleeper ~= nil and inst.components.sleeper:IsAsleep()
    local IsFrozen = inst.components.freezable:IsFrozen()
    local IsRiding = inst.components.rider:IsRiding()
    local IsHeavyLifting = inventory:IsHeavyLifting()

    if not weapon or IsAsleep or IsFrozen or IsRiding or IsHeavyLifting or inst:HasTag("playerghost") or weapon:HasOneOfTags(CANT_TAG) and not weapon:HasOneOfTags(MUST_TAG) then
        return false
    end

    return true
end

local function CanPerformIdleAction(inst)
    return not (inst.components.health ~= nil and inst.components.health:IsDead() and not inst:HasTag("playerghost")) and inst:HasTag("idle") and not (inst.sg:HasStateTag("doing") or inst.components.inventory:IsHeavyLifting()) and not (inst.sg:HasStateTag("moving") or inst:HasTag("moving"))
end

AddModRPCHandler(LouisManutsawee, "LevelCheckKey", function(inst)
    local kenjutsuka = inst.components.kenjutsuka
    if kenjutsuka ~= nil and not inst.components.timer:TimerExists("levelcheck_cd") then
        inst.components.timer:StartTimer("levelcheck_cd", .8)
        if inst.components.talker.task == nil then
            local level = "󰀍: " .. kenjutsuka:GetLevel()
            local exp = "󰀏: " .. kenjutsuka:GetExp() .. "/" .. kenjutsuka:GetMaxExpForMaxLevel()
            local mindpower = "󰀈: " .. kenjutsuka:GetMindpower() .. "/" .. kenjutsuka:GetMaxMindpower()
            local script = level .. exp .. "\n" .. mindpower
            inst.components.talker:Say(script, 2, true)
        end
    end
end)

AddModRPCHandler(LouisManutsawee, "QuickSheathKey", function(inst)
    if CanActivateSkill(inst) then
        if not (inst.components.kenjutsuka:GetLevel() < ncountskill) then
            if not inst.components.timer:TimerExists("quick_sheath_cd") then
                local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                if weapon ~= nil and weapon:HasTag("katana") and not weapon:HasTag("tokijin") then
                    inst.components.timer:StartTimer("quick_sheath_cd",.4)
                    inst.sg:GoToState("quicksheath")
                end
            end
        else
            inst.components.talker:Say(STRINGS.SKILL.UNLOCK_SKILL.. ncountskill , 1, true)
        end
    end
    return true
end)

AddModRPCHandler(LouisManutsawee, "ChangeHairStyleKey", function(inst, skinname)
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
end)

AddModRPCHandler(LouisManutsawee, "PutGlassesKey", function(inst, skinname)
    if CanPerformIdleAction(inst) and not inst.components.timer:TimerExists("put_glasses_cd") then
        inst.components.timer:StartTimer("put_glasses_cd", 1)
        inst:PushEventInTime(.1, "put_glasses")
    end
    return true
end)

AddShardModRPCHandler(LouisManutsawee, "SyncKatanaSpawnerData", function(shardid, active, name)
    if active then
        TheWorld:PushEvent("ms_trackkatana", {name = name})
    else
        TheWorld:PushEvent("ms_forgetkatana", {name = name})
    end
end)

