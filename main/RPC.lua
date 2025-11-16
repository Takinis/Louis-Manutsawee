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

local LouisManutsawee, Momo = "LouisManutsawee", "Momo"

local function SkillRemove(inst)
    inst.components.playerskillcontroller:DeactivateSkill()
end


local MUST_TAG = {"tool", "sharp", "weapon", "katana"}
local CANT_TAG = {"projectile", "whip", "rangedweapon"}
local function CanActivateSkill(inst)
    local inventory = inst.components.inventory
    local weapon = inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
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



AddModRPCHandler(LouisManutsawee, "Skill1Key", function(inst)
    local data = {

    }
    inst.components.playerskillcontronller:ToggleActiveSkill()
    inst.components.timer:StartTimer("skill1_key_cd", 1)
end)



AddModRPCHandler(LouisManutsawee, "Skill1", function(inst)
    if CanActivateSkill(inst) then
        if inst.components.timer:TimerExists("skill1_key_cd")then
            return
        end


        if inst.components.kenjutsuka:GetLevel() < nskill1 then
            inst.components.talker:Say(STRINGS.SKILL.UNLOCK_SKILL..nskill1, 1, true)
            return
        end

        inst.components.timer:StartTimer("skill1_key_cd", 1)

        local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)

        -- if inst.components.kenjutsuka:GetMindpower() >= 3 then
        --     if inst:HasTag("ichimonji") or inst:HasTag("isshin") or inst:HasTag("ryusen") then
        --         SkillRemove(inst)
        --         inst.components.talker:Say(STRINGS.SKILL.SKILL_LATER, 1, true)
        --         return
        --     elseif inst:HasTag("flip") and weapon ~= nil and weapon:HasTag("katana") then
        --         if inst.components.kenjutsuka:GetLevel() < nskill4 then
        --             inst.components.talker:Say(STRINGS.SKILL.UNLOCK_SKILL..nskill4, 1, true)
        --             SkillRemove(inst)
        --         elseif inst.components.kenjutsuka:GetMindpower() >= 7 then
        --             if inst.components.timer:TimerExists("isshin") then
        --                 inst.components.talker:Say(STRINGS.SKILL.TIER2_COOLDOWN, 1, true)
        --                 SkillRemove(inst)
        --                 return
        --             end
        --             SkillRemove(inst)
        --             inst:AddTag("isshin")
        --             inst.components.combat:SetRange(3)
        --             inst.components.talker:Say(STRINGS.SKILL.SKILL4START..inst.components.kenjutsuka:GetMindpower().."/7\n ", 1, true)
        --             return
        --         else
        --             inst.components.talker:Say(STRINGS.SKILL.MINDPOWER_NOT_ENOUGH..inst.components.kenjutsuka:GetMindpower().."/7\n ", 1, true)
        --             SkillRemove(inst)
        --             return
        --         end
        --     elseif not inst:HasTag("ichimonji") then
        --         if inst.components.timer:TimerExists("ichimonji") then
        --             inst.components.talker:Say(STRINGS.SKILL.COOLDOWN, 1, true)
        --             SkillRemove(inst)
        --             return
        --         end
        --         SkillRemove(inst)
        --         inst:AddTag("ichimonji")
        --         inst.components.combat:SetRange(3.5)
        --         inst.components.talker:Say(STRINGS.SKILL.SKILL1START..inst.components.kenjutsuka:GetMindpower().."/3\n ", 1, true)
        --     end
        -- else
        --     inst.components.talker:Say(STRINGS.SKILL.MINDPOWER_NOT_ENOUGH..inst.components.kenjutsuka:GetMindpower().."/3\n ", 1, true)
        --     SkillRemove(inst)
        -- end
        local function WarnMindpowerNotEnough(inst, requiredMindpower)
            inst.components.talker:Say(STRINGS.SKILL.MINDPOWER_NOT_ENOUGH..inst.components.kenjutsuka:GetMindpower().."/"..requiredMindpower.."\n ", 1, true)
            SkillRemove(inst)
        end

        local function CheckSkillCooldown(inst, timerName, cooldownMessage)
            if inst.components.timer:TimerExists(timerName) then
                inst.components.talker:Say(cooldownMessage, 1, true)
                SkillRemove(inst)
                return true
            end
            return false
        end

        -- 修改 ActivateSkill 函数，接受 cooldownTimerName 和 cooldownMessage 参数
        local function ActivateSkill(inst, skillName, requiredLevel, requiredMindpower, cooldownTimerName, cooldownMessage, combatRange, startMessage, skillTag, levelVariableName)
            local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if inst.components.kenjutsuka:GetLevel() < requiredLevel then
                inst.components.talker:Say(STRINGS.SKILL.UNLOCK_SKILL..requiredLevel, 1, true)
                SkillRemove(inst)
                return
            elseif inst.components.kenjutsuka:GetMindpower() >= requiredMindpower then
                if CheckSkillCooldown(inst, cooldownTimerName, cooldownMessage) then
                    return
                end
                SkillRemove(inst)
                inst:AddTag(skillTag)
                inst.components.combat:SetRange(combatRange)
                inst.components.talker:Say(startMessage..inst.components.kenjutsuka:GetMindpower().."/"..requiredMindpower.."\n ", 1, true)
                return
            else
                WarnMindpowerNotEnough(inst, requiredMindpower)
                return
            end
        end


        if inst.components.kenjutsuka:GetMindpower() >= 3 then
            if inst:HasTag("ichimonji") or inst:HasTag("isshin") or inst:HasTag("ryusen") then
                SkillRemove(inst)
                inst.components.talker:Say(STRINGS.SKILL.SKILL_LATER, 1, true)
                return
            end

            local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if inst:HasTag("flip") and weapon ~= nil and weapon:HasTag("katana") then
                ActivateSkill(inst, "flip", nskill4, 7, "isshin", STRINGS.SKILL.TIER2_COOLDOWN, 3, STRINGS.SKILL.SKILL4START, "isshin", "nskill4") -- Skill 4 (Flip -> Isshin)
            elseif not inst:HasTag("ichimonji") then
                ActivateSkill(inst, "ichimonji", nil, 3, "ichimonji", STRINGS.SKILL.COOLDOWN, 3.5, STRINGS.SKILL.SKILL1START, "ichimonji", nil) -- Skill 1 (Ichimonji) -  nskill level check is not present in original for skill 1, so set requiredLevel to nil or some default if needed.
            end
        else
            WarnMindpowerNotEnough(inst, 3)
        end
    end
end)

AddModRPCHandler(LouisManutsawee, "Skill2", function(inst)
    if CanActivateSkill(inst) then
        if inst.components.timer:TimerExists("skill2_key_cd") then
            return
        end

        if inst.components.kenjutsuka:GetLevel() < nskill2 then
            inst.components.talker:Say(STRINGS.SKILL.UNLOCK_SKILL..nskill2, 1, true)
            return
        end

        inst.components.timer:StartTimer("skill2_key_cd",1)

    --     if inst.components.kenjutsuka:GetMindpower() >= 4 then
    --         local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    --         if inst:HasTag("flip") or inst:HasTag("ryusen") or inst:HasTag("susanoo") then
    --             SkillRemove(inst)
    --             inst.components.talker:Say(STRINGS.SKILL.SKILL_LATER, 1, true)
    --             return
    --         elseif inst:HasTag("ichimonji") and weapon ~= nil and weapon:HasTag("katana") then
    --             if inst.components.kenjutsuka:GetLevel() < nskill6 then
    --                 inst.components.talker:Say(STRINGS.SKILL.UNLOCK_SKILL..nskill6, 1, true)
    --                 SkillRemove(inst)
    --             elseif inst.components.kenjutsuka:GetMindpower() >= 8 then
    --                 if inst.components.timer:TimerExists("ryusen") then
    --                     inst.components.talker:Say(STRINGS.SKILL.TIER3_COOLDOWN, 1, true)
    --                     SkillRemove(inst)
    --                     return
    --                 end
    --                 SkillRemove(inst)
    --                 inst:AddTag("ryusen")
    --                 inst.components.combat:SetRange(10)
    --                 inst.components.talker:Say(STRINGS.SKILL.SKILL6START..inst.components.kenjutsuka:GetMindpower().."/8\n ", 1, true)
    --                 return
    --             else
    --                 inst.components.talker:Say(STRINGS.SKILL.MINDPOWER_NOT_ENOUGH..inst.components.kenjutsuka:GetMindpower().."/8\n ", 1, true)
    --                 SkillRemove(inst)
    --                 return
    --             end
    --         elseif inst:HasTag("thrust") and weapon ~= nil and weapon:HasTag("katana") then
    --             if inst.components.kenjutsuka:GetLevel() < nskill7 then
    --                 inst.components.talker:Say(STRINGS.SKILL.UNLOCK_SKILL..nskill7, 1, true)
    --                 SkillRemove(inst)
    --             elseif inst.components.kenjutsuka:GetMindpower() >= 10 then
    --                 if inst.components.timer:TimerExists("ryusen") then
    --                     inst.components.talker:Say(STRINGS.SKILL.TIER3_COOLDOWN, 1, true)
    --                     SkillRemove(inst)
    --                     return
    --                 end
    --                 SkillRemove(inst)
    --                 inst:AddTag("susanoo")
    --                 inst.components.combat:SetRange(3)
    --                 inst.components.talker:Say(STRINGS.SKILL.SKILL7START..inst.components.kenjutsuka:GetMindpower().."/10\n ", 1, true)
    --                 return
    --             else
    --                 inst.components.talker:Say(STRINGS.SKILL.MINDPOWER_NOT_ENOUGH..inst.components.kenjutsuka:GetMindpower().."/10\n ", 1, true)
    --                 SkillRemove(inst)
    --                 return
    --             end
    --         elseif not inst:HasTag("flip") then
    --             if inst.components.timer:TimerExists("flip") then
    --                 inst.components.talker:Say(STRINGS.SKILL.COOLDOWN, 1, true)
    --                 SkillRemove(inst)
    --                 return
    --             end
    --             SkillRemove(inst)
    --             inst:AddTag("flip")
    --             inst.components.combat:SetRange(3.5)
    --             inst.components.talker:Say(STRINGS.SKILL.SKILL2START..inst.components.kenjutsuka:GetMindpower().."/4\n ", 1, true)
    --         end
    --     else
    --         inst.components.talker:Say(STRINGS.SKILL.MINDPOWER_NOT_ENOUGH..inst.components.kenjutsuka:GetMindpower().."/4\n ", 1, true)
    --         SkillRemove(inst)
    --     end

        local function WarnMindpowerNotEnough(inst, requiredMindpower)
            inst.components.talker:Say(STRINGS.SKILL.MINDPOWER_NOT_ENOUGH..inst.components.kenjutsuka:GetMindpower().."/"..requiredMindpower.."\n ", 1, true)
            SkillRemove(inst)
        end

        local function CheckSkillCooldown(inst, timerName, cooldownMessage)
            if inst.components.timer:TimerExists(timerName) then
                inst.components.talker:Say(cooldownMessage, 1, true)
                SkillRemove(inst)
                return true -- 返回 true 表示有冷却，需要退出
            end
            return false -- 返回 false 表示没有冷却
        end

        local function ActivateSkill(inst, skillName, requiredLevel, requiredMindpower, cooldownTimerName, combatRange, startMessage, skillTag, levelVariableName)
            local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if inst.components.kenjutsuka:GetLevel() < requiredLevel then
                inst.components.talker:Say(STRINGS.SKILL.UNLOCK_SKILL..requiredLevel, 1, true)
                SkillRemove(inst)
                return
            elseif inst.components.kenjutsuka:GetMindpower() >= requiredMindpower then
                if CheckSkillCooldown(inst, cooldownTimerName, STRINGS.SKILL.TIER3_COOLDOWN) then -- 假设 Skill 6/7 共用 TIER3_COOLDOWN
                    return
                end
                SkillRemove(inst) -- 移除之前的技能状态
                inst:AddTag(skillTag)
                inst.components.combat:SetRange(combatRange)
                inst.components.talker:Say(startMessage..inst.components.kenjutsuka:GetMindpower().."/"..requiredMindpower.."\n ", 1, true)
                return
            else
                WarnMindpowerNotEnough(inst, requiredMindpower)
                return
            end
        end


        if inst.components.kenjutsuka:GetMindpower() >= 4 then
            if inst:HasTag("flip") or inst:HasTag("ryusen") or inst:HasTag("susanoo") then
                SkillRemove(inst)
                inst.components.talker:Say(STRINGS.SKILL.SKILL_LATER, 1, true)
                return
            end

            local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if inst:HasTag("ichimonji") and weapon ~= nil and weapon:HasTag("katana") then
                ActivateSkill(inst, "ichimonji", nskill6, 8, "ryusen", 10, STRINGS.SKILL.SKILL6START, "ryusen", "nskill6")
            elseif inst:HasTag("thrust") and weapon ~= nil and weapon:HasTag("katana") then
                ActivateSkill(inst, "thrust", nskill7, 10, "ryusen", 3, STRINGS.SKILL.SKILL7START, "susanoo", "nskill7")
            elseif not inst:HasTag("flip") then
                if CheckSkillCooldown(inst, "flip", STRINGS.SKILL.COOLDOWN) then
                    return
                end
                SkillRemove(inst) -- 移除之前的技能状态
                inst:AddTag("flip")
                inst.components.combat:SetRange(3.5)
                inst.components.talker:Say(STRINGS.SKILL.SKILL2START..inst.components.kenjutsuka:GetMindpower().."/4\n ", 1, true)
            end
        else
            WarnMindpowerNotEnough(inst, 4)
        end
    end
end)

AddModRPCHandler(LouisManutsawee, "Skill3", function(inst)
    if CanActivateSkill(inst) then

        if inst.components.timer:TimerExists("skill3_key_cd") then
            return
        end


        if inst.components.kenjutsuka:GetLevel() < nskill3 then
            inst.components.talker:Say(STRINGS.SKILL.UNLOCK_SKILL..nskill3, 1, true)
            return
        end

        inst.components.timer:StartTimer("skill3_key_cd",1)

        -- if inst.components.kenjutsuka:GetMindpower() >= 4 then
        --     local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        --     if inst:HasTag("heavenlystrike") or inst:HasTag("thrust") or inst:HasTag("susanoo") then
        --         SkillRemove(inst)
        --         inst.components.talker:Say(STRINGS.SKILL.SKILL_LATER, 1, true)
        --         return
        --     elseif inst:HasTag("flip") and weapon ~= nil and weapon:HasTag("katana") then
        --         if inst.components.kenjutsuka:GetLevel() < nskill5 then
        --             inst.components.talker:Say(STRINGS.SKILL.UNLOCK_SKILL..nskill5, 1, true)
        --             SkillRemove(inst)
        --         elseif inst.components.kenjutsuka:GetMindpower() >= 5 then
        --             if inst.components.timer:TimerExists("isshin") then
        --                 inst.components.talker:Say(STRINGS.SKILL.TIER2_COOLDOWN, 1, true)
        --                 SkillRemove(inst)
        --                 return
        --             end

        --             SkillRemove(inst)
        --             inst:AddTag("heavenlystrike")
        --             inst.components.combat:SetRange(3)
        --             inst.components.talker:Say(STRINGS.SKILL.SKILL5START..inst.components.kenjutsuka:GetMindpower().."/5\n ", 1, true)
        --             return
        --         else
        --             inst.components.talker:Say(STRINGS.SKILL.MINDPOWER_NOT_ENOUGH..inst.components.kenjutsuka:GetMindpower().."/5\n ", 1, true)
        --             SkillRemove(inst)
        --             return
        --         end
        --     elseif not inst:HasTag("thrust") then
        --         if inst.components.timer:TimerExists("thrust") then
        --             inst.components.talker:Say(STRINGS.SKILL.COOLDOWN, 1, true)
        --             SkillRemove(inst)
        --             return
        --         end
        --         SkillRemove(inst)
        --         inst:AddTag("thrust")
        --         inst.components.combat:SetRange(3)
        --         inst.components.talker:Say(STRINGS.SKILL.SKILL3START..inst.components.kenjutsuka:GetMindpower().."/4\n ", 1, true)
        --     end
        -- else
        --     inst.components.talker:Say(STRINGS.SKILL.MINDPOWER_NOT_ENOUGH..inst.components.kenjutsuka:GetMindpower().."/4\n ", 1, true)
        --     SkillRemove(inst)
        -- end
        local function WarnMindpowerNotEnough(inst, requiredMindpower)
            inst.components.talker:Say(STRINGS.SKILL.MINDPOWER_NOT_ENOUGH..inst.components.kenjutsuka:GetMindpower().."/"..requiredMindpower.."\n ", 1, true)
            SkillRemove(inst)
        end

        local function CheckSkillCooldown(inst, timerName, cooldownMessage)
            if inst.components.timer:TimerExists(timerName) then
                inst.components.talker:Say(cooldownMessage, 1, true)
                SkillRemove(inst)
                return true
            end
            return false
        end

        local function ActivateSkill(inst, skillName, requiredLevel, requiredMindpower, cooldownTimerName, cooldownMessage, combatRange, startMessage, skillTag, levelVariableName)
            local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if inst.components.kenjutsuka:GetLevel() < requiredLevel then
                inst.components.talker:Say(STRINGS.SKILL.UNLOCK_SKILL..requiredLevel, 1, true)
                SkillRemove(inst)
                return
            elseif inst.components.kenjutsuka:GetMindpower() >= requiredMindpower then
                if CheckSkillCooldown(inst, cooldownTimerName, cooldownMessage) then
                    return
                end
                SkillRemove(inst)
                inst:AddTag(skillTag)
                inst.components.combat:SetRange(combatRange)
                inst.components.talker:Say(startMessage..inst.components.kenjutsuka:GetMindpower().."/"..requiredMindpower.."\n ", 1, true)
                return
            else
                WarnMindpowerNotEnough(inst, requiredMindpower)
                return
            end
        end


        if inst.components.kenjutsuka:GetMindpower() >= 4 then
            if inst:HasTag("heavenlystrike") or inst:HasTag("thrust") or inst:HasTag("susanoo") then
                SkillRemove(inst)
                inst.components.talker:Say(STRINGS.SKILL.SKILL_LATER, 1, true)
                return
            end

            local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if inst:HasTag("flip") and weapon ~= nil and weapon:HasTag("katana") then
                ActivateSkill(inst, "flip", nskill5, 5, "isshin", STRINGS.SKILL.TIER2_COOLDOWN, 3, STRINGS.SKILL.SKILL5START, "heavenlystrike", "nskill5") -- Skill 5 (Flip -> Heavenly Strike)
            elseif not inst:HasTag("thrust") then
                ActivateSkill(inst, "thrust", nil, 4, "thrust", STRINGS.SKILL.COOLDOWN, 3, STRINGS.SKILL.SKILL3START, "thrust", nil) -- Skill 3 (Thrust) - no level check in original
            end
        else
            WarnMindpowerNotEnough(inst, 4)
        end
    end
end)

AddModRPCHandler(LouisManutsawee, "Skill4", function(inst)
    if CanActivateSkill(inst) then
        if not inst.components.timer:TimerExists("skill4_key_cd")then
            inst.components.timer:StartTimer("skill4_key_cd",1)

            local kenjutsulevel = inst.components.kenjutsuka:GetLevel()
            local mindpower = inst.components.kenjutsuka:GetMindpower()

            local immortalslash = inst:HasTag("immortalslash")
            local soryuha = inst:HasTag("soryuha")

            if kenjutsulevel >= nskill8 then

                local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)

                if weapon ~= nil then
                    local is_mortalblade = weapon:HasTag("mortalblade")
                    local is_tokijin = weapon:HasTag("onikiba")

                    if mindpower >= 20 then
                        if immortalslash or soryuha then
                            SkillRemove(inst)
                            inst.components.talker:Say(STRINGS.SKILL.SKILL_LATER, 1, true)
                        -- elseif not is_mortalblade and not immortalslash then
                        --     if not inst.components.timer:TimerExists("immortalslash") then
                        --         inst.components.talker:Say(STRINGS.SKILL.COOLDOWN, 1, true)
                        --         SkillRemove(inst)
                        --     else
                        --         SkillRemove(inst)
                        --         inst:AddTag("immortalslash")
                        --         inst.components.combat:SetRange(3)
                        --         inst.components.talker:Say(STRINGS.SKILL.SKILL8START.. mindpower .."/4\n ", 1, true)
                        --     end
                        elseif is_tokijin and not soryuha then
                            if not inst.components.timer:TimerExists("soryuha") then
                                SkillRemove(inst)
                                inst:AddTag("soryuha")
                                inst.components.combat:SetRange(3)
                                inst.components.talker:Say(STRINGS.SKILL.SKILL9START.. mindpower .."/4\n ", 1, true)
                            else
                                inst.components.talker:Say(STRINGS.SKILL.COOLDOWN, 1, true)
                                SkillRemove(inst)
                            end
                        end
                    else
                        inst.components.talker:Say(STRINGS.SKILL.MINDPOWER_NOT_ENOUGH.. mindpower .."/4\n ", 1, true)
                        SkillRemove(inst)
                    end
                else
                    inst.components.talker:Say(STRINGS.SKILL.REJECTED, 1, true)
                    SkillRemove(inst)
                end
            else
                inst.components.talker:Say(STRINGS.SKILL.UNLOCK_SKILL..nskill8, 1, true)
            end
        end
    end
end)

local LevelCheckKey = function(inst, kenjutsuka)
    if inst.components.talker.task == nil then
        local level = "󰀍: " .. kenjutsuka:GetLevel()
        local exp = "󰀏: " .. kenjutsuka:GetExp() .. "/" .. kenjutsuka:GetMaxExpForMaxLevel()
        local mindpower = "󰀈: " .. kenjutsuka:GetMindpower() .. "/" .. kenjutsuka:GetMaxMindpower()
        local script = level .. exp .. "\n" .. mindpower
        inst.components.talker:Say(script, 2, true)
    end
end

AddModRPCHandler(LouisManutsawee, "LevelCheckKey", function(inst)
    local kenjutsuka = inst.components.kenjutsuka
    if kenjutsuka ~= nil and not inst.components.timer:TimerExists("levelcheck_cd") then
        inst.components.timer:StartTimer("levelcheck_cd", .8)
        LevelCheckKey(inst, kenjutsuka)
    end
end)

AddModRPCHandler(LouisManutsawee, "CounterAttackKey", function(inst)
    if CanActivateSkill(inst) then
        if not inst.components.timer:TimerExists("prepare_counter_attack") then
            local kenjutsuLevel = inst.components.kenjutsuka:GetLevel()
            if kenjutsuLevel >= ncountskill then
                inst.components.timer:StartTimer("prepare_counter_attack", .63)
                SkillRemove(inst)
                inst.sg:GoToState("start_counter_attack")
            else
                inst.components.talker:Say(STRINGS.SKILL.UNLOCK_SKILL..ncountskill, 1, true)
            end
        else
            inst.components.talker:Say(STRINGS.SKILL.COOLDOWN, 1, true)
            SkillRemove(inst)
        end
    end
    return true
end)

AddModRPCHandler(LouisManutsawee, "QuickSheathKey", function(inst)
    if CanActivateSkill(inst) then
        if not (inst.components.kenjutsuka:GetLevel() < ncountskill) then
            if not inst.components.timer:TimerExists("quick_sheath_cd") then
                local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                if weapon ~= nil and weapon:HasTag("katana") then
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

AddModRPCHandler(LouisManutsawee, "SkillCancelKey", function(inst)
    if CanActivateSkill(inst) then
        if not inst.components.timer:TimerExists("skill_cancel_cd") then
            inst.components.timer:StartTimer("skill_cancel_cd",1)
            SkillRemove(inst)
            inst.components.talker:Say(STRINGS.SKILL.SKILL_CANCEL, 1, true)
        end
    end
    return true
end)

AddModRPCHandler(LouisManutsawee, "ChangeHairStyleKey", function(inst, skinname)
    local hair_length = inst.components.hair ~= nil and inst.components.hair:GetHairLength()
    if CanPerformIdleAction(inst) and not inst.components.timer:TimerExists("change_hair_cd") and hair_length ~= nil then
        inst.components.timer:StartTimer("change_hair_cd", 1)
        if hair_length == "cut" then
            inst.components.talker:Say(STRINGS.SKILL.HAIRTOOSHORT)
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

AddShardModRPCHandler(Momo, "SyncDatingManagerData", function()

end)
