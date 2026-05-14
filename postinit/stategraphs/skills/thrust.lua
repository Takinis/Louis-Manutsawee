return {
    states = {
        State{
            name = "thrust",
            tags = {"busy", "nopredict", "nointerrupt", "nomorph", "doing", "notalking", "skilling"},

            onenter = function(inst, target)
                inst.components.locomotor:Stop()
                inst.components.combat:SetRange(6)
                inst.components.combat:EnableAreaDamage(true)
                inst.components.combat:SetAreaDamage(2, 1)
                inst.AnimState:SetDeltaTimeMultiplier(1.3)
                inst.inspskill = true
                inst.AnimState:PlayAnimation("multithrust")
                inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")
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

                TimeEvent(8 * FRAMES, function(inst)
                    inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_nightsword")
                end),

                TimeEvent(9 * FRAMES, function(inst)
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/spiderqueen/swipe")
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    inst:PerformBufferedAction()
                end),

                TimeEvent(10 * FRAMES, function(inst)
                    inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_nightsword")
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    inst:PerformBufferedAction()
                end),

                TimeEvent(12 * FRAMES, function(inst)
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/spiderqueen/swipe")
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    inst:PerformBufferedAction()
                end),

                TimeEvent(14 * FRAMES, function(inst)
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
                    inst.components.combat:EnableAreaDamage(false)
                end
                inst.inspskill = nil
            end,
        },
    },
}
