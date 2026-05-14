local SkillUtil = require("utils/skillutil")

return {
    states = {
        State{
            name = "counter_attack",
            tags = {"attack", "doing", "busy", "nointerrupt", "nopredict", "nomorph"},

            onenter = function(inst, target)
                inst.components.locomotor:Stop()

                local sparks = SpawnPrefab("sparks")
                sparks.Transform:SetPosition(inst:GetPosition():Get())

                if math.random(1, 3) > 1 then
                    inst.AnimState:OverrideSymbol("fx_lunge_streak", "player_lunge_blue", "fx_lunge_streak")
                    inst.AnimState:PlayAnimation("lunge_pst")
                else
                    inst.AnimState:PlayAnimation("atk")
                end

                SkillUtil.GroundPoundFx(inst, .6)
                inst.SoundEmitter:PlaySound("turnoftides/common/together/moon_glass/mine")

                inst.inspskill = true
                inst.components.combat:SetRange(4)

                if target ~= nil and target:IsValid() then
                    inst.sg.statemem.target = target
                    inst:ForceFacePoint(target.Transform:GetWorldPosition())
                end
            end,

            timeline = {
                TimeEvent(3 * FRAMES, function(inst)
                    inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")
                    inst:PerformBufferedAction()
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                end),

                TimeEvent(4 * FRAMES, function(inst)
                    inst.components.combat:SetRange(TUNING.DEFAULT_ATTACK_RANGE)
                end),
            },

            ontimeout = function(inst)
                inst.sg:RemoveStateTag("attack")
                inst.sg:AddStateTag("idle")
            end,

            events = {
                EventHandler("animqueueover", function(inst)
                    if inst.AnimState:AnimDone()
                        and inst.components.health ~= nil
                        and not inst.components.health:IsDead()
                        and not inst.sg:HasStateTag("dead") then
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
                inst.components.timer:StartTimer("counter_attack", M_CONFIG.CounterAtkCooldown or .63)
            end,
        },
    },
}
