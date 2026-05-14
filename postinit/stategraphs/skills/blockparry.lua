return {
    events = {
        EventHandler("blockparry", function(inst)
            inst.sg:GoToState("blockparry")
        end),
    },
    states = {
        State{
            name = "blockparry",
            tags = {"busy", "nopredict", "nointerrupt", "nomorph"},

            onenter = function(inst)
                inst.components.locomotor:Stop()
                inst.AnimState:PlayAnimation("atk")
                inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/jump")
            end,

            timeline = {
                TimeEvent(0.5 * FRAMES, function(inst)
                    inst.SoundEmitter:PlaySound("dontstarve/wilson/hit")
                    inst.Physics:SetMotorVelOverride(-0.1, 0, 0)
                end),

                TimeEvent(1 * FRAMES, function(inst)
                    local sparks = SpawnPrefab("sparks")
                    inst.SoundEmitter:PlaySound("turnoftides/common/together/moon_glass/mine")
                    sparks.Transform:SetPosition(inst:GetPosition():Get())
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
                inst.Physics:ClearMotorVelOverride()
            end,
        },
    },
}
