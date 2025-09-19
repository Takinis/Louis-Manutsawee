local skilltime = .05

local Skill_Settings = {
    Ichimonji = {
        tag = "ichimonji",
        time = M_CONFIG.SKILL1_COOLDOWN,
        mindpower = 3,
        cooldown_effect = "ghostlyelixir_retaliation_dripfx",
        fn = function(inst)
            inst:PushEventInTime(skilltime, "ichimonji")

            -- local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            -- local target = inst.components.combat.target
            -- inst.inspskill = true

            -- if weapon ~= nil and weapon.IsUnsheath ~= nil and weapon:IsUnsheath() then
            --     skilltime = .3
            --     if inst.components.kenjutsuka:GetMindpower() >= 5 then
            --         inst.components.kenjutsuka:SetMindpower(inst.components.kenjutsuka:GetMindpower() - 2)
            --         inst.doubleichimonjistart = true
            --     end
            -- end

            -- inst:DoTaskInTime(skilltime, function()
            --     inst.sg:GoToState("ichimonji", target)
            -- end)

            -- if inst.doubleichimonjistart then
            --     inst:DoTaskInTime(1, function()
            --         if weapon ~= nil then
            --             inst.sg:GoToState("ichimonji", target)
            --         end
            --     end)
            -- end
        end,
    },
    Flip = {
        tag = "flip",
        time = M_CONFIG.SKILL2_COOLDOWN,
        mindpower = 4,
        cooldown_effect = "ghostlyelixir_shield_dripfx",
        fn = function(inst)
            local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            local target = inst.components.combat.target
            skilltime = .1
            if weapon ~= nil and weapon.IsUnsheath ~= nil and weapon:IsUnsheath() then
                skilltime = .05
                inst:DoTaskInTime(skilltime, function()
                    if weapon ~= nil then
                        inst.sg:GoToState("habakiri", target)
                        GroundPoundFx(inst, .6)
                    end
                end)
            else
                inst:DoTaskInTime(skilltime, function()
                    inst.sg:GoToState("flip", target)
                    GroundPoundFx(inst, .6)
                end)
            end
        end
    },
    Thrust = {
        tag = "thrust",
        time = M_CONFIG.SKILL3_COOLDOWN,
        mindpower = 4,
        cooldown_effect = "ghostlyelixir_speed_dripfx",
        fn = function(inst)
            local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            local target = inst.components.combat.target
            skilltime = .1
            if weapon ~= nil and weapon.IsUnsheath ~= nil and weapon:IsUnsheath() then
                skilltime = .05
                inst:DoTaskInTime(skilltime, function()
                    if weapon ~= nil then
                        inst.sg:GoToState("thrust", target)
                        GroundPoundFx(inst, .6)

                        inst:DoTaskInTime(.7, function()
                            inst:PushEvent("heavenlystrike")
                            if weapon.components.spellcaster ~= nil then
                                weapon.components.spellcaster:CastSpell(inst)
                                local fx = SpawnPrefab("sparks")
                                fx.Transform:SetPosition(inst:GetPosition():Get())
                            end
                        end)

                        inst:DoTaskInTime(.9, function()
                            SlashFx(inst, inst, "shadowstrike_slash_fx", 3)
                            AoeAttack(inst, 1,6.5)
                            inst.components.combat:SetRange(TUNING.DEFAULT_ATTACK_RANGE)
                            inst.components.talker:Say(STRINGS.SKILL.SKILL3ATTACK, 2, true)
                            local fx = SpawnPrefab("groundpoundring_fx")
                            fx.Transform:SetScale(.8, .8, .8)
                            fx.Transform:SetPosition(inst:GetPosition():Get())
                        end)
                    end
                end)
            else
                inst:DoTaskInTime(skilltime, function()
                    inst.sg:GoToState("thrust", target)
                    GroundPoundFx(inst, .6)
                end)
            end
        end
    },
    Isshin = {
        tag = "isshin",
        time = M_CONFIG.SKILL2_COOLDOWN,
        mindpower = 7,
        cooldown_effect = "monkey_deform_pre_fx",
        fn = function(inst)
            local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            local target = inst.components.combat.target
            inst:DoTaskInTime(.1, function()
                inst.components.talker:Say(STRINGS.SKILL.SKILL4ATTACK, 2, true)
                GroundPoundFx(inst, 0.6)
                SlashFx(inst, target, "shadowstrike_slash_fx", 3)
                inst.inspskill = true
                inst.sg:GoToState("monemind", target)

                inst:DoTaskInTime(.6, function()
                    GroundPoundFx(inst, .8)
                    SlashFx(inst, target, "wanda_attack_shadowweapon_old_fx", 4)
                    AoeAttack(inst, 1, 6.5)
                end)

                inst:DoTaskInTime(.7, function()
                    SlashFx(inst, inst, "wanda_attack_shadowweapon_normal_fx", 3)
                end)

                inst:DoTaskInTime(.8, function()
                    GroundPoundFx(inst, .8)
                    SlashFx(inst, target, "wanda_attack_shadowweapon_old_fx", 3.5)
                    AoeAttack(inst, 1, 6.5)
                end)

                inst:DoTaskInTime(1, function()
                    GroundPoundFx(inst, .6)
                    SlashFx(inst, inst, "wanda_attack_shadowweapon_normal_fx", 4)
                end)

                inst:DoTaskInTime(1.1, function()
                    GroundPoundFx(inst, .8)
                    SlashFx(inst, inst, "wanda_attack_shadowweapon_old_fx", 4)
                    AoeAttack(inst, 1, 6.5)
                end)

                inst:DoTaskInTime(1.2, function()
                    SlashFx(inst, inst, "wanda_attack_shadowweapon_normal_fx", 3)
                    AoeAttack(inst, 1, 6.5)
                end)

                inst:DoTaskInTime(1.4, function()
                    GroundPoundFx(inst, .8)
                    SlashFx(inst, inst, "wanda_attack_shadowweapon_old_fx", 3.5)
                    AoeAttack(inst, 1, 6.5)
                end)

                inst:DoTaskInTime(1.5, function()
                    GroundPoundFx(inst, .6)
                    SlashFx(inst, inst, "wanda_attack_shadowweapon_normal_fx", 4)
                end)

                inst:DoTaskInTime(1.6, function()
                    GroundPoundFx(inst, .8)
                    SlashFx(inst, inst, "wanda_attack_shadowweapon_old_fx", 4)
                end)

                inst:DoTaskInTime(1.8, function()
                    SlashFx(inst, inst, "wanda_attack_shadowweapon_normal_fx", 3)
                    AoeAttack(inst, 1, 6.5)
                end)

                inst:DoTaskInTime(1.9, function()
                    GroundPoundFx(inst, .8)
                    SlashFx(inst, inst, "wanda_attack_shadowweapon_old_fx", 3.5)
                    AoeAttack(inst, 1,6)
                    inst.components.playercontroller:Enable(true)
                    inst.inspskill = nil
                    inst:PushEvent("heavenlystrike")
                    if weapon ~= nil and weapon.components.spellcaster ~= nil then
                        weapon.components.spellcaster:CastSpell(inst)
                        local fx = SpawnPrefab("sparks")
                        fx.Transform:SetPosition(inst:GetPosition():Get())
                    end
                end)

                inst:DoTaskInTime(2.1, function()
                    GroundPoundFx(inst, .6)
                    AoeAttack(inst, 1, 4)
                    inst.components.combat:SetRange(TUNING.DEFAULT_ATTACK_RANGE)
                end)
            end)
        end
    },
    HeavenlyStrike = {
        tag = "heavenlystrike",
        time = M_CONFIG.SKILL2_COOLDOWN - 30,
        mindpower = 5,
        cooldown_effect = "fx_book_birds",
        fn = function(inst)
            local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            inst:DoTaskInTime(.1, function()
                inst.components.talker:Say(STRINGS.SKILL.SKILL5ATTACK, 2, true)
            end)

            inst.sg:AddStateTag("skilling")

            inst:DoTaskInTime(.3, function()
                inst:PushEvent("heavenlystrike")

                AddFollowerFx(inst, "mossling_spin_fx")
                AddFollowerFx(inst, "electricchargedfx")

                GroundPoundFx(inst, .8)
                SlashFx(inst, inst, "shadowstrike_slash_fx", 3)
                AoeAttack(inst, 1, 6.5)

                inst:DoTaskInTime(.2, function()
                    AoeAttack(inst, 2.5, 6.5)
                    SlashFx(inst, inst, "shadowstrike_slash2_fx", 3)
                    GroundPoundFx(inst, .8)
                end)

                inst:DoTaskInTime(.3, function()
                    AoeAttack(inst, 4, 6.5)
                    SlashFx(inst, inst, "shadowstrike_slash_fx", 3)
                    GroundPoundFx(inst, .8)
                end)
            end)
        end
    },
    Ryusen = {
        tag = "ryusen",
        time = M_CONFIG.SKILL3_COOLDOWN - 60,
        mindpower = 8,
        cooldown_effect = "fx_book_birds",
        fn = function(inst)
            local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            local target = inst.components.combat.target
            inst:DoTaskInTime(.1, function()
                inst.components.talker:Say(STRINGS.SKILL.SKILL6ATTACK, 2, true)
                inst.sg:GoToState("ryusen", target)

                inst:DoTaskInTime(.2, function()
                    SlashFx(inst, target, "wanda_attack_shadowweapon_old_fx", 2)
                end)

                inst:DoTaskInTime(.4, function()
                    SlashFx(inst, target, "wanda_attack_shadowweapon_normal_fx", 2)
                end)

                inst:DoTaskInTime(.6, function()
                    SlashFx(inst, target, "wanda_attack_shadowweapon_old_fx", 2.5)
                end)

                inst:DoTaskInTime(.8, function()
                    SlashFx(inst, target, "wanda_attack_shadowweapon_normal_fx", 2.5)
                    GroundPoundFx(target, .7)
                end)

                inst:DoTaskInTime(1, function()
                    GroundPoundFx(inst, .6)
                end)

                inst:DoTaskInTime(1.5, function()
                    SlashFx(inst, target, "shadowstrike_slash_fx", 3)
                    GroundPoundFx(target, .7)
                end)
            end)
        end
    },
    Susanoo = {
        tag = "susanoo",
        time = M_CONFIG.SKILL3_COOLDOWN,
        mindpower = 10,
        cooldown_effect = "fx_book_birds",
        fn = function(inst)
            local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            local target = inst.components.combat.target
            inst:DoTaskInTime(.1, function()
                inst.components.talker:Say(STRINGS.SKILL.SKILL7ATTACK, 2, true)
                GroundPoundFx(inst, .6)

                SlashFx(inst, target, "shadowstrike_slash_fx", 3)
                inst.inspskill = true
                inst.sg:GoToState("monemind", target)

                inst:DoTaskInTime(.6, function()
                    GroundPoundFx(inst, .8)
                    SlashFx(inst, inst, "fence_rotator_fx", 4)
                    AoeAttack(inst, 1,6.5)
                end)

                inst:DoTaskInTime(.7, function()
                    SlashFx(inst, inst, "fence_rotator_fx", 3)
                end)

                inst:DoTaskInTime(.8, function()
                    GroundPoundFx(inst, .8)
                    SlashFx(inst, inst, "fence_rotator_fx", 3.5)
                    AoeAttack(inst, 2, 6.5)
                end)

                inst:DoTaskInTime(.9, function()
                    SlashFx(inst, inst, "fence_rotator_fx", 2.5)
                end)

                inst:DoTaskInTime(1, function()
                    GroundPoundFx(inst, .6)
                    SlashFx(inst, inst, "fence_rotator_fx", 4)
                end)

                inst:DoTaskInTime(1.1, function()
                    GroundPoundFx(inst, .8)
                    SlashFx(inst, inst, "fence_rotator_fx", 4)
                    AoeAttack(inst, 1, 6.5)
                end)

                inst:DoTaskInTime(1.2, function()
                    SlashFx(inst, inst, "fence_rotator_fx", 3)
                    AoeAttack(inst, 2, 6.5)
                end)

                inst:DoTaskInTime(1.3, function()
                    SlashFx(inst, inst, "fence_rotator_fx", 2.5)
                end)

                inst:DoTaskInTime(1.4, function()
                    GroundPoundFx(inst, .8)
                    SlashFx(inst, inst, "fence_rotator_fx", 3.5)
                    AoeAttack(inst, 1, 6.5)
                end)

                inst:DoTaskInTime(1.5, function()
                    GroundPoundFx(inst, .6)
                    SlashFx(inst, inst, "fence_rotator_fx", 4)
                end)

                inst:DoTaskInTime(1.6, function()
                    GroundPoundFx(inst, .8)
                    SlashFx(inst, inst, "fence_rotator_fx", 4)
                end)

                inst:DoTaskInTime(1.7, function()
                    SlashFx(inst, inst, "fence_rotator_fx", 2.5)
                end)

                inst:DoTaskInTime(1.8, function()
                    SlashFx(inst, inst, "fence_rotator_fx", 3)
                    AoeAttack(inst, 2, 6.5)
                end)

                inst:DoTaskInTime(1.9, function()
                    GroundPoundFx(inst, .8)
                    SlashFx(inst, inst, "fence_rotator_fx", 3.5)
                    AoeAttack(inst, 1, 6)
                    inst.components.playercontroller:Enable(true)
                    inst.inspskill = nil
                    inst:PushEvent("heavenlystrike")
                    if weapon ~= nil and weapon.components.spellcaster ~= nil then
                        weapon.components.spellcaster:CastSpell(inst)
                    end
                end)

                inst:DoTaskInTime(2.1, function()
                    SlashFx(inst, inst, "shadowstrike_slash_fx", 3)
                    AoeAttack(inst, 2,4)
                    inst.components.combat:SetRange(TUNING.DEFAULT_ATTACK_RANGE)
                end)
            end)
        end
    },

    -- ImmortalSlash = {
    --     tag = "immortalslash",
    --     time = M_CONFIG.SKILL4_COOLDOWN,
    --     mindpower = 20,
    --     fn = function(inst, weapon)
    --         inst.components.talker:Say(STRINGS.SKILL.SKILL8ATTACK, 2, true)

    --         if weapon ~= nil and weapon.components.spellcaster ~= nil and weapon.IsUnsheath ~= nil and weapon:IsUnsheath() then
    --             weapon.components.spellcaster:CastSpell(inst)
    --         end



    --     end
    -- },

    Soryuha = {
        tag = "soryuha",
        time = M_CONFIG.SKILL3_COOLDOWN,
        cooldown_effect = "thunderbird_fx_idle",
        mindpower = 20,
        fn = function(inst, weapon)

        end
    }
}

return {
    Skill_Settings = Skill_Settings,
}
