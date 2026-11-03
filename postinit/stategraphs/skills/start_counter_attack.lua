return {
    events = {
        EventHandler("start_counter_attack", function(inst)
            local controller = inst.components.playerskillcontroller
            if controller ~= nil then
                controller:StartCounterAttack()
            end
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

            events = {
                EventHandler("animover", function(inst)
                    if inst.AnimState:AnimDone() then
                        inst.sg:GoToState("idle")
                    end
                end),
            },
        },
    },
}
