return {
    states = {
        State{
            name = "quicksheath",
            tags = {"busy", "nopredict", "nointerrupt", "nomorph", "doing", "notalking", "skilling"},

            onenter = function(inst)
                inst.components.locomotor:Stop()
                inst.AnimState:PlayAnimation("atk")
                inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")
                if inst.components.timer ~= nil and not inst.components.timer:TimerExists("quick_sheath_cd") then
                    inst.components.timer:StartTimer("quick_sheath_cd", .4)
                end
            end,

            timeline = {
                TimeEvent(3 * FRAMES, function(inst)
                    local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if weapon ~= nil and weapon.components.spellcaster ~= nil then
                        weapon.components.spellcaster:CastSpell(inst)
                    end
                end),
                TimeEvent(8 * FRAMES, function(inst)
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
