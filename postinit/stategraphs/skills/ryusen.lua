return {
    states = {
        State{
            name = "ryusen",
            tags = {"busy", "nopredict", "nointerrupt", "nomorph", "doing", "notalking", "skilling", "mdodgeing"},

            onenter = function(inst, target)
                inst.components.locomotor:Stop()
                inst.components.combat:SetRange(10)
                inst.AnimState:PlayAnimation("atk")
                inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")
                if target ~= nil and target:IsValid() then
                    inst.sg.statemem.target = target
                    inst:ForceFacePoint(target.Transform:GetWorldPosition())
                end
            end,

            timeline = {
                TimeEvent(2 * FRAMES, function(inst)
                    local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if equip ~= nil and equip.components.spellcaster ~= nil then
                        equip.components.spellcaster:CastSpell(inst)
                    end
                    local sparks = SpawnPrefab("sparks")
                    sparks.Transform:SetPosition(inst:GetPosition():Get())
                end),

                TimeEvent(3 * FRAMES, function(inst)
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/spiderqueen/swipe")
                    local fx = SpawnPrefab("wanda_attack_shadowweapon_old_fx")
                    fx.entity:AddFollower()
                    fx.Follower:FollowSymbol(inst.GUID, "swap_body", 0, 0, 0)
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    inst:PerformBufferedAction()

                    local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if equip ~= nil and equip.components.spellcaster ~= nil then
                        equip.components.spellcaster:CastSpell(inst)
                    end
                end),

                TimeEvent(6 * FRAMES, function(inst)
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/spiderqueen/swipe")
                    local fx = SpawnPrefab("wanda_attack_shadowweapon_normal_fx")
                    fx.entity:AddFollower()
                    fx.Follower:FollowSymbol(inst.GUID, "swap_body", 0, 0, 0)
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    inst:PerformBufferedAction()

                    local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if equip ~= nil and equip.components.spellcaster ~= nil then
                        equip.components.spellcaster:CastSpell(inst)
                    end
                end),

                TimeEvent(9 * FRAMES, function(inst)
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/spiderqueen/swipe")
                    local fx = SpawnPrefab("wanda_attack_shadowweapon_old_fx")
                    fx.entity:AddFollower()
                    fx.Follower:FollowSymbol(inst.GUID, "swap_body", 0, 0, 0)
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    inst:PerformBufferedAction()

                    local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if equip ~= nil and equip.components.spellcaster ~= nil then
                        equip.components.spellcaster:CastSpell(inst)
                    end
                end),

                TimeEvent(12 * FRAMES, function(inst)
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/spiderqueen/swipe")
                    local fx = SpawnPrefab("wanda_attack_shadowweapon_normal_fx")
                    fx.entity:AddFollower()
                    fx.Follower:FollowSymbol(inst.GUID, "swap_body", 0, 0, 0)
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    inst:PerformBufferedAction()

                    local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if equip ~= nil and equip.components.spellcaster ~= nil then
                        equip.components.spellcaster:CastSpell(inst)
                    end
                end),

                TimeEvent(13 * FRAMES, function(inst)
                    inst.AnimState:PlayAnimation("atk")
                    inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")
                end),

                TimeEvent(14 * FRAMES, function(inst)
                    inst.Physics:SetMotorVelOverride(32, 0, 0)
                    inst:ForceFacePoint(inst.sg.statemem.target.Transform:GetWorldPosition())
                end),

                TimeEvent(16 * FRAMES, function(inst)
                    inst.Physics:ClearMotorVelOverride()
                    local x, y, z = inst.Transform:GetWorldPosition()
                    local fx = SpawnPrefab("groundpoundring_fx")
                    fx.Transform:SetScale(.6, .6, .6)
                    fx.Transform:SetPosition(x, y, z)
                end),

                TimeEvent(17 * FRAMES, function(inst)
                    inst.SoundEmitter:PlaySound("turnoftides/common/together/moon_glass/mine")
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    inst:PerformBufferedAction()
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
            end,
        },
    },
}
