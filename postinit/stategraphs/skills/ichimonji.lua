local SkillUtil = require("utils/skillutil")

return {
    events = {
        EventHandler("ichimonji", function(inst, data)
            inst.sg:GoToState("ichimonji", data ~= nil and (data.target or data) or nil)
        end),
    },
    states = {
        State{
            name = "ichimonji",
            tags = {"busy", "nopredict", "nointerrupt", "nomorph", "doing", "notalking", "skilling"},

            onenter = function(inst, target)
                inst.inspskill = true
                inst.components.locomotor:Stop()
                inst.AnimState:PlayAnimation("atk_prop_pre")
                inst.AnimState:PushAnimation("atk_prop_lag", false)
                inst.AnimState:PushAnimation("atk", false)
                inst.components.combat:EnableAreaDamage(true)
                inst.components.combat:SetAreaDamage(2, 1)
                inst.AnimState:SetDeltaTimeMultiplier(2.5)
                inst.components.combat:SetRange(6)
                if target ~= nil and target:IsValid() then
                    inst.sg.statemem.target = target
                    inst:ForceFacePoint(target.Transform:GetWorldPosition())
                end
            end,

            timeline = {
                TimeEvent(8 * FRAMES, function(inst)
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/spiderqueen/swipe")
                    SkillUtil.AddFollowerFx(inst, "electrichitsparks")
                    SkillUtil.GroundPoundFx(inst, 0.5)
                end),

                TimeEvent(9 * FRAMES, function(inst)
                    inst.AnimState:SetDeltaTimeMultiplier(1)
                    inst.Physics:SetMotorVelOverride(32, 0, 0)
                    if inst.sg.statemem.target ~= nil then
                        inst:ForceFacePoint(inst.sg.statemem.target.Transform:GetWorldPosition())
                    end
                end),

                TimeEvent(10 * FRAMES, function(inst)
                    inst.Physics:ClearMotorVelOverride()
                    local x, y, z = inst.Transform:GetWorldPosition()
                    local pufffx = SpawnPrefab("dirt_puff")
                    pufffx.Transform:SetScale(.6, .6, .6)
                    pufffx.Transform:SetPosition(x, y, z)
                end),

                TimeEvent(17 * FRAMES, function(inst)
                    inst.SoundEmitter:PlaySound("dontstarve/wilson/hit")
                    inst.SoundEmitter:PlaySound("turnoftides/common/together/moon_glass/mine")

                    if inst.sg.statemem.target ~= nil then
                        inst:ForceFacePoint(inst.sg.statemem.target.Transform:GetWorldPosition())
                        inst.components.combat:DoAttack(inst.sg.statemem.target)
                        inst.components.combat:DoAttack(inst.sg.statemem.target)
                        inst.components.combat:DoAttack(inst.sg.statemem.target)
                    end

                    inst:PerformBufferedAction()
                    inst.components.combat:SetRange(TUNING.DEFAULT_ATTACK_RANGE)
                    inst.components.combat:SetAreaDamage(1, 1)
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
                if inst.doubleichimonji ~= nil then
                    inst.doubleichimonji = nil
                    inst.components.talker:Say(STRINGS.SKILL.SKILL1ATTACK, 2, true)
                end
                if inst.doubleichimonjistart then
                    inst.doubleichimonjistart = nil
                    inst.doubleichimonji = true
                end
            end,
        },
    },
}
