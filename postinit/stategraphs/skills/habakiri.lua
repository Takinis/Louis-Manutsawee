local function SpawnShadowFx(inst, target, fxscale)
    local fx = SpawnPrefab("wanda_attack_shadowweapon_normal_fx")
    fx.Transform:SetScale(fxscale, fxscale, fxscale)
    fx.Transform:SetPosition(target:GetPosition():Get())
    inst.SoundEmitter:PlaySound("turnoftides/common/together/moon_glass/mine")
    inst.SoundEmitter:PlaySound("dontstarve/creatures/spiderqueen/swipe")
end

return {
    states = {
        State{
            name = "habakiri",
            tags = {"busy", "nopredict", "nointerrupt", "nomorph", "doing", "notalking", "skilling", "mdodgeing"},

            onenter = function(inst, target)
                inst.components.locomotor:Stop()
                inst.AnimState:OverrideSymbol("fx_lunge_streak", "player_lunge_blue", "fx_lunge_streak")
                inst.components.combat:SetRange(12)
                inst.components.combat:EnableAreaDamage(true)
                inst.components.combat:SetAreaDamage(2, 1)
                inst.inspskill = true
                inst.AnimState:PlayAnimation("atk")
                inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/jump")
                if target ~= nil and target:IsValid() then
                    inst.sg.statemem.target = target
                    inst:ForceFacePoint(target.Transform:GetWorldPosition())
                end
            end,

            timeline = {
                TimeEvent(1 * FRAMES, function(inst)
                    inst:ForceFacePoint(inst.sg.statemem.target.Transform:GetWorldPosition())
                    inst.Physics:SetMotorVelOverride(-.25, 0, 10)
                end),

                TimeEvent(3 * FRAMES, function(inst)
                    inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/jump")
                end),

                TimeEvent(4 * FRAMES, function(inst)
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    SpawnShadowFx(inst, inst.sg.statemem.target, 3)
                    inst.SoundEmitter:PlaySound("turnoftides/common/together/moon_glass/mine")
                    inst:PerformBufferedAction()
                    inst.Physics:ClearMotorVelOverride()
                end),

                TimeEvent(5 * FRAMES, function(inst)
                    inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/jump")
                    inst.AnimState:PlayAnimation("lunge_pst")
                    inst:ForceFacePoint(inst.sg.statemem.target.Transform:GetWorldPosition())
                    inst.Physics:SetMotorVelOverride(-.5, 0, -20)
                end),

                TimeEvent(8 * FRAMES, function(inst)
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    SpawnShadowFx(inst, inst.sg.statemem.target, 2)
                    inst.SoundEmitter:PlaySound("turnoftides/common/together/moon_glass/mine")
                    inst:PerformBufferedAction()
                    inst.Physics:ClearMotorVelOverride()
                end),

                TimeEvent(9 * FRAMES, function(inst)
                    inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/jump")
                    inst.AnimState:PlayAnimation("atk")
                    inst:ForceFacePoint(inst.sg.statemem.target.Transform:GetWorldPosition())
                    inst.Physics:SetMotorVelOverride(-.5, 0, 20)
                end),

                TimeEvent(12 * FRAMES, function(inst)
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    SpawnShadowFx(inst, inst.sg.statemem.target, 2)
                    inst:PerformBufferedAction()
                    inst.components.combat:SetRange(TUNING.DEFAULT_ATTACK_RANGE)
                    inst.components.combat:SetAreaDamage(1, 1)
                    inst.SoundEmitter:PlaySound("turnoftides/common/together/moon_glass/mine")
                    inst.Physics:ClearMotorVelOverride()
                    inst.Physics:SetMotorVelOverride(-.5, 0, -10)
                end),

                TimeEvent(15 * FRAMES, function(inst)
                    local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if weapon ~= nil and weapon.components.spellcaster ~= nil then
                        weapon.components.spellcaster:CastSpell(inst)
                    end
                    inst.Physics:ClearMotorVelOverride()
                    local sparks = SpawnPrefab("sparks")
                    sparks.Transform:SetPosition(inst:GetPosition():Get())
                end),

                TimeEvent(20 * FRAMES, function(inst)
                    inst.components.talker:Say(STRINGS.SKILL.SKILL2ATTACK, 2, true)
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
