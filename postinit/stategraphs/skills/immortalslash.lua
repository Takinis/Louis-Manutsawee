local SkillUtil = require("utils/skillutil")

return {
    events = {
        EventHandler("immortalslash", function(inst, data)
            inst.sg:GoToState("immortalslash", data ~= nil and (data.target or data) or nil)
        end),
    },
    states = {
        State{
            name = "immortalslash",
            tags = {"busy", "nopredict", "nointerrupt", "nomorph", "doing", "notalking", "skilling"},

            onenter = function(inst, target)
                inst.inspskill = true
                inst.components.locomotor:Stop()
                inst.AnimState:PlayAnimation("scythe_pre")
                inst.AnimState:PushAnimation("scythe_loop", false)
                inst.components.combat:EnableAreaDamage(true)
                inst.components.combat:SetAreaDamage(2, 1)
                inst.AnimState:SetDeltaTimeMultiplier(2.5)

                if target ~= nil and target:IsValid() then
                    inst.sg.statemem.target = target
                    inst:ForceFacePoint(target.Transform:GetWorldPosition())
                end
            end,

            timeline = {
                TimeEvent(1 * FRAMES, function(inst)
                    if inst.sg.statemem.scythe_anim then
                        local sharkboi_swipe_fx = SpawnPrefab("sharkboi_swipe_fx")
                        sharkboi_swipe_fx.AnimState:SetDeltaTimeMultiplier(0.25)
                        sharkboi_swipe_fx.AnimState:SetScale(0.88, 0.88, 0.88)
                        sharkboi_swipe_fx.entity:SetParent(inst.entity)
                        sharkboi_swipe_fx.Transform:SetPosition(1, 0, 0)
                        sharkboi_swipe_fx.AnimState:SetMultColour(0, 0, 0, 1)
                        sharkboi_swipe_fx:Reverse()
                        inst.sg.statemem.sharkboi_swipe_fx = sharkboi_swipe_fx
                    end
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
            end,
        },
    },
}
