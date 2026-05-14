local function SkillCollision(inst, enable)
    inst.Physics:ClearCollisionMask()
    if enable then
        inst.Physics:CollidesWith(COLLISION.WORLD)
        inst.Physics:CollidesWith(COLLISION.GROUND)
    else
        inst.Physics:CollidesWith(COLLISION.WORLD)
        inst.Physics:CollidesWith(COLLISION.OBSTACLES)
        inst.Physics:CollidesWith(COLLISION.SMALLOBSTACLES)
        inst.Physics:CollidesWith(COLLISION.CHARACTERS)
        inst.Physics:CollidesWith(COLLISION.GIANTS)
    end
end

return {
    events = {
        EventHandler("heavenlystrike", function(inst)
            inst.sg:GoToState("heavenlystrike")
        end),
    },
    states = {
        State{
            name = "heavenlystrike",
            tags = {"busy", "nopredict", "nointerrupt", "nomorph", "skilling", "notalking", "mdodgeing" },

            onenter = function(inst)
                local x, y, z = inst.Transform:GetWorldPosition()
                local pufffx = SpawnPrefab("dirt_puff")
                pufffx.Transform:SetScale(.3, .3, .3)
                pufffx.Transform:SetPosition(x, y, z)

                SkillCollision(inst, true)

                inst.components.locomotor:Stop()
                if inst.components.playercontroller ~= nil then
                    inst.components.playercontroller:Enable(false)
                end
                inst.components.combat:SetRange(TUNING.DEFAULT_ATTACK_RANGE)
                inst.AnimState:PlayAnimation("atk_leap_pre")
                inst.Physics:SetMotorVelOverride(30, 0, 0)
            end,

            timeline = {
                TimeEvent(0 * FRAMES, function(inst)
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/spiderqueen/swipe")
                end),
                TimeEvent(6 * FRAMES, function(inst)
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/spiderqueen/swipe")
                    SkillCollision(inst, false)
                end),
                TimeEvent(11 * FRAMES, function(inst)
                    inst.Physics:ClearMotorVelOverride()
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
                if inst.components.playercontroller ~= nil then
                    inst.components.playercontroller:Enable(true)
                end
            end,
        },
    },
}
