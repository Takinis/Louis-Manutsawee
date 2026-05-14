return {
    states = {
        State{
            name = "monemind",
            tags = {"busy", "nopredict", "nointerrupt", "nomorph", "doing", "notalking", "skilling"},

            onenter = function(inst, target)
                inst.components.locomotor:Stop()

                if inst.components.playercontroller ~= nil then
                    inst.components.playercontroller:Enable(false)
                end

                inst.AnimState:PlayAnimation("atk")
                inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")

                if target ~= nil and target:IsValid() then
                    inst.sg.statemem.target = target
                    inst:ForceFacePoint(target.Transform:GetWorldPosition())
                end
            end,

            timeline = {
                TimeEvent(3 * FRAMES, function(inst)
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if equip ~= nil and equip.components.spellcaster ~= nil then
                        equip.components.spellcaster:CastSpell(inst)
                    end
                    inst.Physics:SetMotorVelOverride(32, 0, 0)
                    if inst.sg.statemem.target then
                        inst:ForceFacePoint(inst.sg.statemem.target.Transform:GetWorldPosition())
                    end
                end),
                TimeEvent(4 * FRAMES, function(inst)
                    inst.Physics:ClearMotorVelOverride()
                end),
                TimeEvent(9 * FRAMES, function(inst)
                    inst.sg:GoToState("idle")
                end),
            },

            ontimeout = function(inst)
                inst.sg:AddStateTag("idle")
            end,

            events = {
                EventHandler("animqueueover", function(inst)
                    if inst.AnimState:AnimDone() then
                        inst.sg:GoToState("idle")
                    end
                end),
            },
        },
    },
}
