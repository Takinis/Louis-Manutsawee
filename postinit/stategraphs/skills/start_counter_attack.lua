return {
    events = {
        EventHandler("start_counter_attack", function(inst)
            inst.sg:GoToState("start_counter_attack")
        end),
    },
    states = {
        State{
            name = "start_counter_attack",
            tags = {"busy", "nomorph", "notalking", "nopredict", "doing"},

            onenter = function(inst)
                inst.AnimState:PlayAnimation("parry_pre")
                inst.AnimState:PushAnimation("parry_pst", false)
                inst.components.locomotor:Stop()
                inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/jump")
            end,

            timeline = {
                TimeEvent(.5 * FRAMES, function(inst)
                    inst.sg:AddStateTag("counteractive")
                end),
                TimeEvent(8 * FRAMES, function(inst)
                    inst.sg:RemoveStateTag("counteractive")
                    inst.sg:AddStateTag("startblockparry")
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
                inst.sg:RemoveStateTag("startblockparry")
            end,
        },
    },
}
