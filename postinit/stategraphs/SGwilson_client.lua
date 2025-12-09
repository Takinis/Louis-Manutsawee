local FRAMES = GLOBAL.FRAMES
local TimeEvent = GLOBAL.TimeEvent
local State = GLOBAL.State
local AddStategraphState = AddStategraphState
local AddStategraphPostInit = AddStategraphPostInit
local AddStategraphActionHandler = AddStategraphActionHandler
GLOBAL.setfenv(1, GLOBAL)

----------------------------------------------------------------------------------------------
--------------------------------------function-----------------------------------------------
----------------------------------------------------------------------------------------------

local function DoMountSoundClient(inst, mount, sound)
    if mount ~= nil and mount.sounds ~= nil then
        inst.SoundEmitter:PlaySound(mount.sounds[sound], nil, nil, true)
    end
end

----------------------------------------------------------------------------------------------

local katanarnd = 1

local actionhandlers = {
    ActionHandler(ACTIONS.MDODGE, "mdodge"),
}

local states = {

--------------------------------------katana-----------------------------------------------
    State{
        name = "mkatana",
        tags = { "attack", "notalking", "abouttoattack" },

        onenter = function(inst)
            local buffaction = inst:GetBufferedAction()
            local cooldown = 0
            if inst.replica.combat ~= nil then
                if inst.replica.combat:InCooldown() then
                    inst.sg:RemoveStateTag("abouttoattack")
                    inst:ClearBufferedAction()
                    inst.sg:GoToState("idle", true)
                    return
                end
                inst.replica.combat:StartAttack()
                cooldown = inst.replica.combat:MinAttackPeriod() + .5 * FRAMES
            end

            local equip = inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            local rider = inst.replica.rider

            inst.AnimState:OverrideSymbol("fx_lunge_streak", "player_lunge_blue", "fx_lunge_streak")
            inst.components.locomotor:Stop()

            if rider ~= nil and rider:IsRiding() then
                inst.AnimState:PlayAnimation("atk_pre")
                inst.AnimState:PushAnimation("atk", false)
                DoMountSoundClient(inst, rider:GetMount(), "angry")
                if cooldown > 0 then
                    cooldown = math.max(cooldown, 16 * FRAMES)
                end
            elseif equip ~= nil and equip:HasTag("mkatana") then
                inst.sg.statemem.iskatana = true
                inst.AnimState:SetDeltaTimeMultiplier(1.2)

                if katanarnd == 1 then
                    inst.AnimState:PlayAnimation("atk_prop_pre")
                    inst.AnimState:PushAnimation("atk", false)
                    katanarnd = math.random(2, 3)
                elseif katanarnd == 2 then
                    inst.AnimState:SetDeltaTimeMultiplier(1.3)
                    inst.sg:AddStateTag("mkatanaatk")
                    inst.AnimState:PlayAnimation("chop_pre")
                    katanarnd = 4
                elseif katanarnd == 3 then
                    inst.AnimState:SetDeltaTimeMultiplier(1.4)
                    inst.sg:AddStateTag("mkatanaatk")
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
                    katanarnd = 1
                end

                if cooldown > 0 then
                    cooldown = math.max(cooldown, 13 * FRAMES)
                end
            end

            if buffaction ~= nil then
                inst:PerformPreviewBufferedAction()

                if buffaction.target ~= nil and buffaction.target:IsValid() then
                    inst:FacePoint(buffaction.target:GetPosition())
                    inst.sg.statemem.attacktarget = buffaction.target
                    inst.sg.statemem.retarget = buffaction.target
                end
            end

            if cooldown > 0 then
                inst.sg:SetTimeout(cooldown)
            end
        end,

        timeline = {
            TimeEvent(5 * FRAMES, function(inst)
                inst.AnimState:SetDeltaTimeMultiplier(1)
                if inst.sg.statemem.iskatana and inst.sg:HasStateTag("mkatanaatk") then
                    inst.AnimState:PlayAnimation("lunge_pst")
                    inst.sg:RemoveStateTag("mkatanaatk")
                end
            end),

            TimeEvent(8 * FRAMES, function(inst)
                if inst.sg.statemem.iskatana then
                    inst:ClearBufferedAction()
                    inst.sg:RemoveStateTag("abouttoattack")
                end

                if inst.sg.statemem.scythe_anim then
                    local bearger_swipe_fx = SpawnPrefab("bearger_swipe_fx")
                    if bearger_swipe_fx ~= nil then
                        bearger_swipe_fx.AnimState:SetScale(0.88, 0.88, 0.88)
                        bearger_swipe_fx.entity:SetParent(inst.entity)
                        bearger_swipe_fx.Transform:SetPosition(1, 0, 0)
                        bearger_swipe_fx:Reverse()
                    end
                    inst.sg.statemem.bearger_swipe_fx = bearger_swipe_fx
                end
            end),

            TimeEvent(10 * FRAMES, function(inst)
                if not inst.sg.statemem.iskatana then
                    inst:ClearBufferedAction()
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end)
        },

        ontimeout = function(inst)
            inst.sg:RemoveStateTag("attack")
            inst.sg:AddStateTag("idle")
        end,

        events = {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                    inst.AnimState:SetDeltaTimeMultiplier(1)
                end
            end),
        },

        onexit = function(inst)
            if inst.sg:HasStateTag("abouttoattack") and inst.replica.combat ~= nil then
                inst.replica.combat:CancelAttack()
                inst.AnimState:SetDeltaTimeMultiplier(1)
                if inst.sg:HasStateTag("mkatanaatk") then
                    inst.sg:RemoveStateTag("mkatanaatk")
                end
            end

            local bearger_swipe_fx = inst.sg.statemem.bearger_swipe_fx
            if bearger_swipe_fx ~= nil and bearger_swipe_fx:IsValid() then
				bearger_swipe_fx:Remove()
			end
        end,
    },
----------------------------------------------------------------------------------------------

--------------------------------------iai-----------------------------------------------
    State{
        name = "iai",
        tags = { "attack", "notalking", "abouttoattack" },

        onenter = function(inst)
            local buffaction = inst:GetBufferedAction()
            local cooldown = 0

            if inst.replica.combat ~= nil then
                if inst.replica.combat:InCooldown() then
                    inst.sg:RemoveStateTag("abouttoattack")
                    inst:ClearBufferedAction()
                    inst.sg:GoToState("idle", true)
                    return
                end
                inst.replica.combat:StartAttack()
                cooldown = inst.replica.combat:MinAttackPeriod() + .5 * FRAMES
            end

            inst.AnimState:OverrideSymbol("fx_lunge_streak", "player_lunge_blue", "fx_lunge_streak")
            inst.components.locomotor:Stop()

            local equip = inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            local rider = inst.replica.rider

            if rider ~= nil and rider:IsRiding() then
                inst.AnimState:PlayAnimation("atk_pre")
                inst.AnimState:PushAnimation("atk", false)
                DoMountSoundClient(inst, rider:GetMount(), "angry")
                if cooldown > 0 then
                    cooldown = math.max(cooldown, 16 * FRAMES)
                end
            elseif equip ~= nil and equip:HasTag("iai") then
                inst.AnimState:PlayAnimation("spearjab_pre")
                inst.AnimState:PushAnimation("lunge_pst", false)
                inst.sg.statemem.iskatana = true
                if cooldown > 0 then
                    cooldown = math.max(cooldown, 9 * FRAMES)
                end
            end

            if buffaction ~= nil then
                inst:PerformPreviewBufferedAction()
                if buffaction.target ~= nil and buffaction.target:IsValid() then
                    inst:FacePoint(buffaction.target:GetPosition())
                    inst.sg.statemem.attacktarget = buffaction.target
                    inst.sg.statemem.retarget = buffaction.target
                end
            end

            if cooldown > 0 then
                inst.sg:SetTimeout(cooldown)
            end
        end,

        timeline = {
            TimeEvent(7.5 * FRAMES, function(inst)
                if inst.sg.statemem.iskatana then
                    inst:ClearBufferedAction()
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
            TimeEvent(10 * FRAMES, function(inst)
                if not inst.sg.statemem.iskatana then
                    inst:ClearBufferedAction()
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
        },

        ontimeout = function(inst)
            inst.sg:RemoveStateTag("attack")
            inst.sg:AddStateTag("idle")
        end,

        events = {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            if inst.sg:HasStateTag("abouttoattack") and inst.replica.combat ~= nil then
                inst.replica.combat:CancelAttack()
            end
        end,
    },
----------------------------------------------------------------------------------------------

--------------------------------------yari-----------------------------------------------
    State {
        name = "yari",
        tags = { "attack", "notalking", "abouttoattack" },

        onenter = function(inst)
            local buffaction = inst:GetBufferedAction()
            local cooldown = 0

            if inst.replica.combat ~= nil then
                if inst.replica.combat:InCooldown() then
                    inst.sg:RemoveStateTag("abouttoattack")
                    inst:ClearBufferedAction()
                    inst.sg:GoToState("idle", true)
                    return
                end
                inst.replica.combat:StartAttack()
                cooldown = inst.replica.combat:MinAttackPeriod() + .5 * FRAMES
            end

			inst.AnimState:OverrideSymbol("fx_lunge_streak", "player_lunge_blue", "fx_lunge_streak")
            inst.components.locomotor:Stop()

            local equip = inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            local rider = inst.replica.rider

            if rider ~= nil and rider:IsRiding() then
                inst.AnimState:PlayAnimation("atk_pre")
                inst.AnimState:PushAnimation("atk", false)
                DoMountSoundClient(inst, rider:GetMount(), "angry")
                if cooldown > 0 then
                    cooldown = math.max(cooldown, 16 * FRAMES)
                end
            elseif equip ~= nil and equip:HasTag("yari") then
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

                if cooldown > 0 then
                    cooldown = math.max(cooldown, 13 * FRAMES)
                end
            end

            if buffaction ~= nil then
                inst:PerformPreviewBufferedAction()
                if buffaction.target ~= nil and buffaction.target:IsValid() then
                    inst:FacePoint(buffaction.target:GetPosition())
                    inst.sg.statemem.attacktarget = buffaction.target
                    inst.sg.statemem.retarget = buffaction.target
                end
            end

            if cooldown > 0 then
                inst.sg:SetTimeout(cooldown)
            end
        end,

        timeline = {
            TimeEvent(8 * FRAMES, function(inst)
                if inst.sg.statemem.isyari then
                    inst:ClearBufferedAction()
                    inst.sg:RemoveStateTag("abouttoattack")
				end
			end),

			TimeEvent(10 * FRAMES, function(inst)
                if not inst.sg.statemem.isyari then
                    inst:ClearBufferedAction()
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
        },

        ontimeout = function(inst)
            inst.sg:RemoveStateTag("attack")
            inst.sg:AddStateTag("idle")
        end,

        events = {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            if inst.sg:HasStateTag("abouttoattack") and inst.replica.combat ~= nil then
                inst.replica.combat:CancelAttack()
            end
        end,
	},
----------------------------------------------------------------------------------------------

    State{
        name = "mdodge",
        tags = {"busy", "nopredict", "nointerrupt", "nomorph" },

        onenter = function(inst, data)
            local action = inst:GetBufferedAction()
            if action then
                local pos = action:GetActionPoint()
                inst:ForceFacePoint(pos)
            end

            local equip = inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            local is_katana_equip = equip ~= nil and equip:HasTag("katana")
            local x, y, z = inst.Transform:GetWorldPosition()
            local pufffx = SpawnPrefab("dirt_puff")
            pufffx.Transform:SetScale(.3, .3, .3)
            pufffx.Transform:SetPosition(x, y, z)

            -- inst.sg:SetTimeout(0.25)

            inst.components.locomotor:Stop()
            local motor_speed = 20
			inst.components.locomotor:Stop()
            if is_katana_equip then
                inst.AnimState:PlayAnimation("atk_leap_pre")
                motor_speed = 30
            else
                inst.AnimState:PlayAnimation("slide_pre")
                inst.AnimState:PushAnimation("slide_loop")
            end
			inst.Physics:SetMotorVelOverride(motor_speed, 0, 0)
            inst.components.locomotor:EnableGroundSpeedMultiplier(false)

            inst.components.dodger.last_dodge_time = GetTime()
            inst.components.dodger.dodge_time:set(inst.components.dodger.dodge_time:value() == false and true or false)

            inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/jump")

            inst.sg.statemem.is_katana_equip = is_katana_equip

            inst:PerformPreviewBufferedAction()
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

        onenter = function(inst)
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
    }
}

for _, state in ipairs(states) do
    AddStategraphState("wilson_client", state)
end

for _, actionhandler in ipairs(actionhandlers) do
    AddStategraphActionHandler("wilson_client", actionhandler)
end

local function fn(sg)
    local attack_actionhandler = sg.actionhandlers[ACTIONS.ATTACK].deststate
    sg.actionhandlers[ACTIONS.ATTACK].deststate = function(inst, action, ...)
        if not (inst.sg:HasStateTag("attack") and action.target == inst.sg.statemem.attacktarget or IsEntityDead(inst)) then
            local weapon = inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            local inventoryitem = weapon.replica.inventoryitem
            if (inventoryitem ~= nil and inventoryitem:IsWeapon()) then
                if weapon:HasTag("mkatana") then
                    return "mkatana"
                elseif weapon:HasTag("iai") then
                    return "iai"
                elseif weapon:HasTag("yari") then
                    return "yari"
                end
            end
        end

        if attack_actionhandler ~= nil then
            return attack_actionhandler(inst, action, ...)
        end
    end
end

AddStategraphPostInit("wilson_client", fn)
