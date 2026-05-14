return {
    states = {
        State{
            name = "flip",
            tags = {"busy", "nopredict", "nointerrupt", "nomorph", "doing", "notalking", "skilling"},

            onenter = function(inst, target)
                inst.components.locomotor:Stop()
                inst.AnimState:OverrideSymbol("fx_lunge_streak", "player_lunge_blue", "fx_lunge_streak")
                inst.components.combat:SetRange(6)
                inst.components.combat:EnableAreaDamage(true)
                inst.components.combat:SetAreaDamage(2, 1)
                inst.AnimState:SetDeltaTimeMultiplier(1.3)
                inst.inspskill = true
                inst.AnimState:PlayAnimation("lunge_pre")
                inst.AnimState:PushAnimation("lunge_pst", false)
                inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/jump")
                if target ~= nil and target:IsValid() then
                    inst.sg.statemem.target = target
                    inst:ForceFacePoint(target.Transform:GetWorldPosition())
                end
            end,

            timeline = {
                TimeEvent(1 * FRAMES, function(inst)
                    inst.Physics:SetMotorVelOverride(32, 0, 0)
                    inst:ForceFacePoint(inst.sg.statemem.target.Transform:GetWorldPosition())
                end),

                TimeEvent(2 * FRAMES, function(inst)
                    inst.Physics:ClearMotorVelOverride()
                end),

                TimeEvent(3 * FRAMES, function(inst)
                    inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/jump")
                end),

                TimeEvent(4 * FRAMES, function(inst)
                    inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/jump")
                end),

                TimeEvent(5 * FRAMES, function(inst)
                    inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/jump")
                end),

                TimeEvent(6 * FRAMES, function(inst)
                    inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/jump")
                end),

                TimeEvent(7 * FRAMES, function(inst)
                    inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/jump")
                end),

                TimeEvent(8 * FRAMES, function(inst)
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    inst:PerformBufferedAction()
                    inst.components.combat:SetRange(TUNING.DEFAULT_ATTACK_RANGE)
                    inst.components.combat:SetAreaDamage(1, 1)
                    inst.SoundEmitter:PlaySound("turnoftides/common/together/moon_glass/mine")
                    inst.AnimState:SetDeltaTimeMultiplier(1)
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
                if inst.components.combat ~= nil then
                    inst.components.combat:SetTarget(nil)
                    inst.components.combat:SetRange(TUNING.DEFAULT_ATTACK_RANGE)
                end
                inst.inspskill = nil
                inst.components.combat:EnableAreaDamage(false)
            end,
        },
    },
}
