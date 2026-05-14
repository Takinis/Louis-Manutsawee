local EQUIPSLOTS = GLOBAL.EQUIPSLOTS
local AddStategraphEvent = AddStategraphEvent
local AddStategraphState = AddStategraphState
local AddStategraphPostInit = AddStategraphPostInit
local AddStategraphActionHandler= AddStategraphActionHandler
local MODROOT = MODROOT
GLOBAL.setfenv(1, GLOBAL)

local SkillUtil = require("utils/skillutil")

----------------------------------------------------------------------------------------------
--------------------------------------function-----------------------------------------------
----------------------------------------------------------------------------------------------

local function DoMountSound(inst, mount, sound, ispredicted)
    if mount ~= nil and mount.sounds ~= nil then
        inst.SoundEmitter:PlaySound(mount.sounds[sound], nil, nil, ispredicted)
    end
end

local function SkillCollision(inst, enable)
    inst.Physics:ClearCollisionMask()
    if enable then
        inst.Physics:CollidesWith(COLLISION.WORLD)
        inst.Physics:CollidesWith(COLLISION.GROUND)
    else
        inst.Physics:CollidesWith(COLLISION.WORLD)
        inst.Physics:CollidesWith(COLLISION.OBSTACLES)
        inst.Physics:CollidesWith(COLLISION.SMALLOBSTACLES)
        inst.Physics:CollidesWith(COLLISION.CHARACTERS)
        inst.Physics:CollidesWith(COLLISION.GIANTS)
    end
end

local function SpawnShadowFx(inst, target, fxscale)
    local wanda_attack_shadowweapon_normal_fx = SpawnPrefab("wanda_attack_shadowweapon_normal_fx")
    wanda_attack_shadowweapon_normal_fx.Transform:SetScale(fxscale, fxscale, fxscale)
    wanda_attack_shadowweapon_normal_fx.Transform:SetPosition(target:GetPosition():Get())
    inst.SoundEmitter:PlaySound("turnoftides/common/together/moon_glass/mine")
    inst.SoundEmitter:PlaySound("dontstarve/creatures/spiderqueen/swipe")
end

local katanarnd = 1

local balloon_colors = {
    "blue",
    "green",
    "orange",
    "red",
    "purple",
    "yellow"
}

----------------------------------------------------------------------------------------------

local actionhandlers = {
    ActionHandler(ACTIONS.MDODGE, "mdodge"),
}

local events = {
    EventHandler("put_glasses", function(inst)
        inst.sg:GoToState("put_glasses")
    end),
    EventHandler("change_hair_style", function(inst)
        inst.sg:GoToState("change_hair_style")
    end),
}

local states = {
    State{
        name = "kenjutsu",
        tags = { "attack", "notalking", "abouttoattack", "autopredict" },

        onenter = function(inst)
			if inst.components.combat:InCooldown() then
                inst.sg:RemoveStateTag("abouttoattack")
                inst:ClearBufferedAction()
                inst.sg:GoToState("idle", true)
                return
            end

            local buffaction = inst:GetBufferedAction()
            local target = buffaction ~= nil and buffaction.target or nil
            local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            local cooldown = inst.components.combat.min_attack_period + .5 * FRAMES

            inst.AnimState:OverrideSymbol("fx_lunge_streak", "player_lunge_blue", "fx_lunge_streak")
            inst.components.combat:SetTarget(target)
            inst.components.combat:StartAttack()
            inst.components.locomotor:Stop()

            if equip ~= nil then
                if equip:HasTag("iai") then
                    inst.sg.statemem.isiai = true
                    inst.AnimState:PlayAnimation("spearjab_pre")
                    inst.AnimState:PushAnimation("lunge_pst", false)

                    inst.SoundEmitter:PlaySound("dontstarve/creatures/spiderqueen/swipe")
                    cooldown = math.max(cooldown, 9 * FRAMES)
                elseif equip:HasTag("katana") then
                    inst.sg.statemem.iskatana = true
                    inst.AnimState:SetDeltaTimeMultiplier(1.2)

                    if katanarnd == 1 then
                        inst.AnimState:PlayAnimation("atk_prop_pre")
                        inst.AnimState:PushAnimation("atk", false)
                        katanarnd = math.random(2, 6)
                    elseif katanarnd == 2 then
                        inst.AnimState:SetDeltaTimeMultiplier(1.3)
                        inst.sg.statemem.lunge_pst = true
                        inst.AnimState:PlayAnimation("chop_pre")
                        katanarnd = 4
                    elseif katanarnd == 3 then
                        inst.AnimState:SetDeltaTimeMultiplier(1.4)
                        inst.sg.statemem.lunge_pst = true
                        inst.AnimState:PlayAnimation("pickaxe_pre")
                        katanarnd = 1
                    elseif katanarnd == 4 then
                        inst.AnimState:SetDeltaTimeMultiplier(1.4)
                        inst.AnimState:PlayAnimation("spearjab_pre")
                        inst.AnimState:PushAnimation("spearjab", false)
                        katanarnd = 5
                    elseif katanarnd == 5 then
                        inst.AnimState:SetDeltaTimeMultiplier(4)
                        inst.sg.statemem.scythe_anim = true
                        inst.AnimState:PlayAnimation("scythe_pre")
                        inst.AnimState:PushAnimation("scythe_loop", false)
                        katanarnd = 6
                    else
                        inst.AnimState:PlayAnimation("atk_pre")
                        inst.AnimState:PushAnimation("atk", false)
                        katanarnd = math.random(2, 6)
                    end

                    inst.SoundEmitter:PlaySound("dontstarve/creatures/spiderqueen/swipe")
                    cooldown = math.max(cooldown, 13 * FRAMES)
                elseif equip:HasTag("yari") then
                    inst.sg.statemem.isyari = true
                    if math.random(1, 3) == 1 then
                        inst.AnimState:PlayAnimation("spearjab_pre")
                        inst.AnimState:PushAnimation("lunge_pst", false)
                    elseif math.random(2, 3) == 2 then
                        inst.AnimState:PlayAnimation("atk_pre")
                        inst.AnimState:PushAnimation("atk", false)
                    else
                        inst.AnimState:PlayAnimation("spearjab_pre")
                        inst.AnimState:PushAnimation("spearjab", false)
                    end

                    inst.SoundEmitter:PlaySound("dontstarve/creatures/spiderqueen/swipe")
                    cooldown = math.max(cooldown, 13 * FRAMES)
                end
            end

            inst.sg:SetTimeout(cooldown)
            if target ~= nil then
                inst.components.combat:BattleCry()
                if target:IsValid() then
                    inst:FacePoint(target:GetPosition())
                    inst.sg.statemem.attacktarget = target
                    inst.sg.statemem.retarget = target
                end
            end
        end,

        timeline = {
			TimeEvent(1 * FRAMES, function(inst)
                if inst.sg.statemem.scythe_anim then
                    local sharkboi_swipe_fx = SpawnPrefab("sharkboi_swipe_fx")
                    sharkboi_swipe_fx.AnimState:SetScale(0.88, 0.88, 0.88)
                    sharkboi_swipe_fx.entity:SetParent(inst.entity)
                    sharkboi_swipe_fx.Transform:SetPosition(1, 0, 0)
                    sharkboi_swipe_fx.AnimState:SetMultColour(0, 0, 0, 1)
                    sharkboi_swipe_fx:Reverse()
                    inst.sg.statemem.sharkboi_swipe_fx = sharkboi_swipe_fx
                end
            end),

			TimeEvent(5 * FRAMES, function(inst)
				inst.AnimState:SetDeltaTimeMultiplier(1)
                if inst.sg.statemem.iskatana and inst.sg.statemem.lunge_pst then
                    inst.AnimState:PlayAnimation("lunge_pst")
                    inst.sg.statemem.lunge_pst = false
                end
            end),

			TimeEvent(8 * FRAMES, function(inst)
                if inst.sg.statemem.iskatana or inst.sg.statemem.isiai or inst.sg.statemem.isyari then
    				inst:PerformBufferedAction()
                    inst.sg:RemoveStateTag("abouttoattack")
				end
            end),

			TimeEvent(10 * FRAMES, function(inst)
                if not inst.sg.statemem.iskatana or not inst.sg.statemem.isiai or not inst.sg.statemem.isyari then
                    inst:PerformBufferedAction()
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end)
        },

        ontimeout = function(inst)
            inst.sg:RemoveStateTag("attack")
            inst.sg:AddStateTag("idle")
        end,

        events = {
            EventHandler("equip", function(inst)
                inst.sg:GoToState("idle")
            end),
            EventHandler("unequip", function(inst)
                inst.sg:GoToState("idle")
            end),
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
					inst.AnimState:SetDeltaTimeMultiplier(1)
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            inst.components.combat:SetTarget(nil)
            if inst.sg:HasStateTag("abouttoattack") then
                inst.components.combat:CancelAttack()
				inst.AnimState:SetDeltaTimeMultiplier(1)
                if inst.sg.statemem.scythe_anim then
                    inst.sg.statemem.scythe_anim = false
                end
				if inst.sg.statemem.lunge_pst then
                    inst.sg.statemem.lunge_pst = false
                end
            end
            local sharkboi_swipe_fx = inst.sg.statemem.sharkboi_swipe_fx
            if sharkboi_swipe_fx ~= nil and sharkboi_swipe_fx:IsValid() then
				sharkboi_swipe_fx:Remove()
			end
        end,
    },

    State{
        name = "put_glasses",
        tags = {"busy", "nopredict", "nointerrupt", "nomorph", "doing","notalking"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("give")
            inst.AnimState:PushAnimation("give_pst",false)
        end,

       timeline = {
            TimeEvent(13 * FRAMES, function(inst)
                inst:PerformBufferedAction()
            end),
        },

        events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            inst.components.glasses:UpdateGlass(not inst.components.glasses:IsPuted())
        end
    },

    State{
        name = "change_hair_style",
        tags = {"busy", "nopredict", "nointerrupt", "nomorph", "doing","notalking"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.SoundEmitter:PlaySound("dontstarve/wilson/make_trap", "make")
            inst.AnimState:PlayAnimation("build_pre")
            inst.AnimState:PushAnimation("build_loop", true)
            inst.sg:SetTimeout(1)
        end,

        ontimeout = function(inst)
            inst:PerformBufferedAction()
            inst.AnimState:PlayAnimation("build_pst")
            inst.sg:GoToState("idle", false)
        end,

        onexit = function(inst)
            inst.components.hair:ChangeHairStyle()
            inst.SoundEmitter:KillSound("make")
        end,
    },


    State{
        name = "mdodge",
        tags = {"busy", "nopredict", "nointerrupt", "nomorph" },

        onenter = function(inst, data)
            local action = inst:GetBufferedAction()
            if action then
                local pos = action:GetActionPoint()
                inst:ForceFacePoint(pos)
            end

            local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            local is_katana_equip = equip ~= nil and equip:HasTag("katana")
			local x, y, z = inst.Transform:GetWorldPosition()
			local pufffx = SpawnPrefab("dirt_puff")
			pufffx.Transform:SetScale(.3, .3, .3)
			pufffx.Transform:SetPosition(x, y, z)

            inst.sg:SetTimeout(TUNING.DEFAULT_DODGE_TIMEOUT)

            local motor_speed = 20
			inst.components.locomotor:Stop()
            if is_katana_equip and (equip:HasTag("tokijin") or equip.weaponstatus) then
                inst.AnimState:PlayAnimation("atk_leap_pre")
                motor_speed = 30
            else
                inst.AnimState:PlayAnimation("slide_pre")
                inst.AnimState:PushAnimation("slide_loop")
            end
			inst.Physics:SetMotorVelOverride(motor_speed, 0, 0)
			inst.components.locomotor:EnableGroundSpeedMultiplier(false)

			inst.components.dodger.last_dodge_time = GetTime()
            inst.components.dodger.dodge_time:set(not inst.components.dodger.dodge_time:value())
            inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/jump")

            inst.sg.statemem.is_katana_equip = is_katana_equip
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("mdodge_pst", inst.sg.statemem.is_katana_equip)
        end,

        onexit = function(inst)
            inst.Physics:ClearMotorVelOverride()
			inst.components.locomotor:EnableGroundSpeedMultiplier(true)
            inst.components.locomotor:Stop()
            inst.components.locomotor:SetBufferedAction(nil)
        end,
    },

    State{
        name = "mdodge_pst",
        tags = {"evade", "no_stun"},

        onenter = function(inst, is_katana_equip)
            if not is_katana_equip then
                inst.AnimState:PlayAnimation("slide_pst")
            end
        end,

        events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                    inst.sg.statemem.is_katana_equip = nil
                end
            end),
        }
    },

    State{
        name = "idle_bocchi",
        tags = { "idle", "canrotate" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("idle_bocchi_loop")
            inst.sg:SetTimeout(1)
        end,

        events = {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },
}

local skill_state_modules = {
    "heavenlystrike",
    "blockparry",
    "start_counter_attack",
    "counter_attack",
    "monemind",
    "quicksheath",
    "ryusen",
    "soryuha",
    "flip",
    "thrust",
    "ichimonji",
    "habakiri",
}

if package ~= nil and type(package.path) == "string" then
    local mod_lua_path = MODROOT .. "?.lua"
    if not string.find(package.path, mod_lua_path, 1, true) then
        package.path = package.path .. ";" .. mod_lua_path
    end
end

for _, module_name in ipairs(skill_state_modules) do
    local ok, skill_def = pcall(require, "postinit/stategraphs/skills/" .. module_name)
    if ok and type(skill_def) == "table" then
        if skill_def.events ~= nil then
            for _, event in ipairs(skill_def.events) do
                table.insert(events, event)
            end
        end
        if skill_def.states ~= nil then
            for _, state in ipairs(skill_def.states) do
                table.insert(states, state)
            end
        end
    else
        print("[Louis-Manutsawee][SGwilson] Failed loading skill module:", module_name, skill_def)
    end
end

for _, event in ipairs(events) do
    AddStategraphEvent("wilson", event)
end

for _, state in ipairs(states) do
    AddStategraphState("wilson", state)
end

for _, actionhandler in ipairs(actionhandlers) do
    AddStategraphActionHandler("wilson", actionhandler)
end

local function fn(sg)
    local attack_actionhandler = sg.actionhandlers[ACTIONS.ATTACK].deststate
    sg.actionhandlers[ACTIONS.ATTACK].deststate = function(inst, action, ...)
        inst.sg.mem.localchainattack = not action.forced or nil
        local playercontroller = inst.components.playercontroller
        local attack_tag =
            playercontroller ~= nil and
            playercontroller.remote_authority and
            playercontroller.remote_predicting and
            "abouttoattack" or
            "attack"
        local weapon = inst.components.combat ~= nil and inst.components.combat:GetWeapon() or nil
        if weapon ~= nil and (weapon:HasTag("katana") or weapon:HasTag("yari")) and inst:HasTag("kenjutsuka") and inst:HasTag("kenjutsu") and inst.components.rider ~= nil and not inst.components.rider:IsRiding() and not (inst.sg:HasStateTag(attack_tag) and action.target == inst.sg.statemem.attacktarget or inst.components.health:IsDead()) then
            return "kenjutsu"
        end

        if attack_actionhandler ~= nil then
            return attack_actionhandler(inst, action, ...)
        end
    end

    -- Why does Klei make it but not use it?????
    local _wes_funnyidle_onenter = sg.states["wes_funnyidle"].onenter
    sg.states["wes_funnyidle"].onenter = function(inst, ...)
        inst.AnimState:OverrideSymbol("balloon_red", "player_idles_wes", "balloon_" .. GetRandomItem(balloon_colors))

        if _wes_funnyidle_onenter ~= nil then
            _wes_funnyidle_onenter(inst, ...)
        end
    end

    sg.states["wes_funnyidle"].onexit = function(inst)
        inst.AnimState:ClearOverrideSymbol("balloon_red")
    end
end

AddStategraphPostInit("wilson", fn)
