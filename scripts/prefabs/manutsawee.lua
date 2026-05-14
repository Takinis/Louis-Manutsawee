local MakePlayerCharacter = require "prefabs/player_common"
local SkillUtil = require("utils/skillutil")

local assets = {
    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),

    Asset("ANIM", "anim/hair_cut.zip"),
    Asset("ANIM", "anim/hair_short.zip"),
    Asset("ANIM", "anim/hair_medium.zip"),
    Asset("ANIM", "anim/hair_long.zip"),

    Asset("ANIM", "anim/hair_short_pony.zip"),
    Asset("ANIM", "anim/hair_medium_pony.zip"),
    Asset("ANIM", "anim/hair_long_pony.zip"),

    Asset("ANIM", "anim/hair_short_twin.zip"),
    Asset("ANIM", "anim/hair_medium_twin.zip"),
    Asset("ANIM", "anim/hair_long_twin.zip"),

    Asset("ANIM", "anim/hair_short_htwin.zip"),
    Asset("ANIM", "anim/hair_medium_htwin.zip"),
    Asset("ANIM", "anim/hair_long_htwin.zip"),

    Asset("ANIM", "anim/hair_short_yoto.zip"),
    Asset("ANIM", "anim/hair_medium_yoto.zip"),
    Asset("ANIM", "anim/hair_long_yoto.zip"),

    Asset("ANIM", "anim/hair_short_ronin.zip"),
    Asset("ANIM", "anim/hair_medium_ronin.zip"),
    Asset("ANIM", "anim/hair_long_ronin.zip"),

    Asset("ANIM", "anim/hair_short_ball.zip"),
    Asset("ANIM", "anim/hair_medium_ball.zip"),
    Asset("ANIM", "anim/hair_long_ball.zip"),

    Asset("ANIM", "anim/eyeglasses.zip"),
    Asset("ANIM", "anim/sunglasses.zip"),
    Asset("ANIM", "anim/starglasses.zip"),

    Asset("ANIM", "anim/face_controlled.zip"),

	Asset("ANIM", "anim/wendy_recall.zip"),
    Asset("ANIM", "anim/maid_hb.zip"),
    Asset("ANIM", "anim/m_sfoxmask_swap.zip"),
    Asset("ANIM", "anim/m_hb.zip"),
    Asset("ANIM", "anim/bocchi_ahoge.zip"),

    Asset("ANIM", "anim/wortox_actions_nabbag.zip"),
    Asset("ANIM", "anim/player_idles_wortox_nice.zip"),
    Asset("ANIM", "anim/player_idles_wortox_naughty.zip"),

    Asset("ANIM", "anim/player_idles_bocchi.zip"),
    Asset("ANIM", "anim/player_idles_walter.zip"),
    Asset("ANIM", "anim/player_idles_winona.zip"),
    Asset("ANIM", "anim/player_idles_wathgrithr.zip"),
    Asset("ANIM", "anim/player_idles_wanda.zip"),
    Asset("ANIM", "anim/player_idles_wendy.zip"),
    Asset("ANIM", "anim/player_idles_wilson.zip"),
    Asset("ANIM", "anim/player_idles_wortox.zip"),
    Asset("ANIM", "anim/player_idles_wes.zip"),
    Asset("ANIM", "anim/player_idles_willow.zip"),
}

local prefabs = {
    "battlesong_instant_attack_fx",
    "fx_book_light_upgraded",
    "abigail_rising_twinkles_fx",
    "lightningspike_fx",
    "electricchargedfx",
    "electrichitsparks",
    "thunderbird_fx_idle",
}

local Idle_Anim = {
    manutsawee = "idle_wilson",
    manutsawee_yukatalong = "idle_wendy",
    manutsawee_yukata = "idle_wendy",
    manutsawee_shinsengumi = "idle_wathgrithr",
    manutsawee_fuka = "idle_wathgrithr",
    manutsawee_sailor = "idle_walter",
    manutsawee_jinbei = "idle_wortox", -- "idle_naughty" "idle_nice"
    manutsawee_maid = "idle_wanda",
    manutsawee_lycoris = "idle_naughty",
    manutsawee_uniform_black = "idle_wanda",
    manutsawee_taohuu = "idle_winona",
    manutsawee_miko = "emote_impatient",
}

local Funny_Idle_Anim = {
    manutsawee_qipao = "wes_funnyidle",
    manutsawee_bocchi = "idle_bocchi",
}

local SkinsHeaddress = {
    manutsawee_maid = "maid_hb",
    manutsawee_shinsengumi = "m_hb",
    manutsawee_yukata = "m_sfoxmask_swap",
    manutsawee_yukatalong = "m_sfoxmask_swap",
    manutsawee_bocchi = "bocchi_ahoge",
}

local LouisManutsawee = "LouisManutsawee"

local start_inv = {}

for k, v in pairs(TUNING.GAMEMODE_STARTING_ITEMS) do
    start_inv[string.lower(k)] = v.MANUTSAWEE
end

prefabs = FlattenTree({prefabs, start_inv}, true)

local function OnRegenMindPower(inst, mindpower)
    inst:FollwerFx("battlesong_instant_attack_fx"):SetScale(.7)
    -- mtfc
    -- if mindpower >= 3 then
    --     inst.components.talker:Say("󰀈: ".. mindpower .."\n", 1, true)
    -- end
end

local function OnDeath(inst)
    local fx_book_light_upgraded = SpawnPrefab("fx_book_light_upgraded")
    fx_book_light_upgraded.entity:SetParent(inst.entity)
    fx_book_light_upgraded.Transform:SetScale(.9, 2.5, 1)
end

local function OnEquip(inst, data)
    local item = data.item
    if item ~= nil and (item.prefab == "onemanband" or item.prefab == "armorsnurtleshell") then
        if not inst:HasTag("notshowscabbard") then
            inst:AddTag("notshowscabbard")
        end
    end
end

local function OnUnEquip(inst, data)
    local item = data.item
    if item ~= nil and (item.prefab == "onemanband" or item.prefab == "armorsnurtleshell") then
        if inst:HasTag("notshowscabbard") then
            inst:RemoveTag("notshowscabbard")
        end
    end
end

local function OnDroped(inst, data)
    local item = data ~= nil and (data.prev_item or data.item)
    if item ~= nil and item:HasTag("katana") and not item:HasTag("woodensword") then
        if not inst:HasTag("notshowscabbard") then
            inst.AnimState:ClearOverrideSymbol("swap_body_tall")
        end
    end
end

local OnLevelUpSpawnFx = OnDeath

local OnLevelUp = {
    Level1 = {
        require_exp = 250,
    },
    Level2 = {
        require_exp = 500,
        fn = function(inst)
            if not inst:HasTag("kenjutsu") then
                inst:AddTag("kenjutsu")
            end
        end
    },
    Level3 = {
        require_exp = 750,
    },
    Level4 = {
        require_exp = 1000,
        fn = function(inst)
            inst.components.kenjutsuka:SetRegenMindPower(true)
        end
    },
    Level5 = {
        require_exp = 1250,
    },
    Level6 = {
        require_exp = 1500,
        fn = function(inst, level)
            inst:AddTag("ghostlyfriend")
            inst.components.sanity:SetPlayerGhostImmunity(true)
            inst.components.sanity.neg_aura_mult = 1 - ((level / 2) / 10)
            inst.components.sanity:AddSanityAuraImmunity("ghost")
        end
    },
    Level7 = {
        require_exp = 1750,
        fn = function(inst)
            inst.components.workmultiplier:AddMultiplier(ACTIONS.CHOP,   1, inst)
            inst.components.workmultiplier:AddMultiplier(ACTIONS.MINE,   1, inst)
            inst.components.workmultiplier:AddMultiplier(ACTIONS.HAMMER, 1, inst)
            inst.components.efficientuser:AddMultiplier(ACTIONS.CHOP,   1, inst)
            inst.components.efficientuser:AddMultiplier(ACTIONS.MINE,   1, inst)
            inst.components.efficientuser:AddMultiplier(ACTIONS.HAMMER, 1, inst)
            inst.components.efficientuser:AddMultiplier(ACTIONS.ATTACK, 1, inst)
        end
    },
    Level8 = {
        require_exp = 2000,
    },
    Level9 = {
        require_exp = 2250,
    },
    Level10 = {
        require_exp = 2500,
    },
}

local function OnKilled(inst, data)
    local target = data.victim
    local target_scale = (target:HasTag("smallcreature") and 1) or (target:HasTag("largecreature") and 4) or 2

    if target ~= nil and target_scale ~= nil then
        if not target:HasOneOfTags({"prey", "bird", "insect", "hostile"}) and inst.components.sanity:GetPercent() <= .8  then
            inst.components.sanity:DoDelta(target_scale)
        end
    end
end

local Critical_Fx = {
    "round_puff_attack_fx",
    "fx_attack_pop",
    "slingshotammo_hitfx_stinger",
    "balloon_attack_pop",
    "purebrilliance_mark_attack_fx",
    "chester_transform_attack_fx",
}

local OnAttackOther = function(inst, data)
    local target = data.target
    local weapon = data.weapon
    local kenjutsuka = inst.components.kenjutsuka
    local CANT_TAG = {"prey", "bird", "insect", "wall"}

    if target ~= nil and weapon ~= nil and kenjutsuka ~= nil and not weapon:HasTag("projectile") and not weapon:HasTag("rangedweapon") and not inst.sg:HasStateTag("skilling") then
        if not target:HasOneOfTags(CANT_TAG) then
            if not inst.components.timer:TimerExists("critical_cd") then
                if math.random(1, 100) <= 5 + kenjutsuka:GetLevel() then
                    local crit_cd_time = 15 - (kenjutsuka:GetLevel() / 2)
                    inst.components.timer:StartTimer("critical_cd", crit_cd_time > 1 and crit_cd_time or 1)
                    if target.components.health and not target.components.health:IsDead() then
                        target:SpawnPrefabInPos(GetRandomItem(Critical_Fx))
                    end
                    inst.components.combat.damagemultiplier = (inst.components.combat.damagemultiplier + (0.1 * kenjutsuka:GetLevel()))
                    inst:DoTaskInTime(1, function(inst)
                        inst.components.combat.damagemultiplier = 1
                    end)
                end
            end

            if not inst.components.timer:TimerExists("heart_cd") then
                inst.components.timer:StartTimer("heart_cd", .3)
                kenjutsuka.hitcount = kenjutsuka.hitcount + 1
                if kenjutsuka.hitcount >= (M_CONFIG.RegenMindPowerCount or 10) then
                    inst:PushEvent("ms_regenmindpower")
                    if inst.components.sanity then
                        inst.components.sanity:DoDelta(1)
                    end
                    kenjutsuka.hitcount = 0
                end
            end
        end
    end
end

local OnStartAttack = function(inst, target)
    if inst.components.playerskillcontroller ~= nil then
        inst.components.playerskillcontroller:ReleaseSkill(target)
    end
end

local function IsSheathedKatana(weapon)
    return weapon ~= nil and weapon.IsUnsheath ~= nil and not weapon:IsUnsheath()
end

local function CastEquippedWeapon(inst)
    local weapon = inst.components.inventory ~= nil and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
    if weapon ~= nil and weapon.components.spellcaster ~= nil then
        weapon.components.spellcaster:CastSpell(inst)
        local fx = SpawnPrefab("sparks")
        fx.Transform:SetPosition(inst:GetPosition():Get())
    end
end

local function GoToSkillState(inst, state, target, delay)
    inst:DoTaskInTime(delay or .1, function(inst)
        if inst:IsValid() then
            inst.sg:GoToState(state, target)
            SkillUtil.GroundPoundFx(inst, .6)
        end
    end)
end

local function GoToStateLater(inst, state, target, delay)
    inst:DoTaskInTime(delay or 0, function(inst)
        if inst:IsValid() then
            inst.sg:GoToState(state, target)
        end
    end)
end

local function GetSoryuhaWarningDay()
    return TheWorld ~= nil and TheWorld.state ~= nil and TheWorld.state.cycles or 0
end

local function IsSoryuhaCarrier(weapon)
    return weapon ~= nil and (weapon:HasTag("onikiba") or weapon:HasTag("tokijin") or weapon.prefab == "tokijin")
end

local function ShouldInterruptSoryuha(inst, weapon)
    if weapon == nil or not weapon:HasTag("katana") or IsSoryuhaCarrier(weapon) then
        return false
    end

    local day = GetSoryuhaWarningDay()
    if inst._soryuha_fragile_warning_day ~= day then
        inst._soryuha_fragile_warning_day = day
        if inst.components.talker ~= nil then
            inst.components.talker:Say(STRINGS.SKILL.SORYUHA_FRAGILE, 2, true)
        end
        inst:ClearBufferedAction()
        inst.sg:GoToState("idle")
        return true
    end

    return false
end

local function IsSoryuhaLevelReady(inst)
    local kenjutsuka = inst.components.kenjutsuka
    if kenjutsuka == nil then
        return false
    end
    return kenjutsuka:IsMaxLevel()
end

local function CreateSkillData()
    local skills = {
        {
            id = SKILL_ID.ICHIMONJI,
            tag = SKILL_ID.ICHIMONJI,
            state = SG_STATE.ICHIMONJI,
            level = 0,
            mindpower = 3,
            cooldown_name = SKILL_ID.ICHIMONJI,
            cooldown_time = M_CONFIG.IchimonjiCooldown,
            cooldown_effect = "ghostlyelixir_retaliation_dripfx",
            range = 3.5,
            start_message = STRINGS.SKILL.SKILL1START,
            release = function(inst, target)
                GoToStateLater(inst, SG_STATE.ICHIMONJI, target, .05)
            end,
        },

        {
            id = SKILL_ID.FLIP,
            tag = SKILL_ID.FLIP,
            state = SG_STATE.FLIP,
            states = {SG_STATE.FLIP, SG_STATE.HABAKIRI},
            level = 0,
            mindpower = 4,
            cooldown_name = SKILL_ID.FLIP,
            cooldown_time = M_CONFIG.FlipCooldown,
            cooldown_effect = "ghostlyelixir_shield_dripfx",
            range = 3.5,
            start_message = STRINGS.SKILL.SKILL2START,
            release = function(inst, target)
                local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                local sheathed = IsSheathedKatana(weapon)
                local state = sheathed and SG_STATE.HABAKIRI or SG_STATE.FLIP
                GoToSkillState(inst, state, target, sheathed and .05 or .1)
            end,
        },

        {
            id = SKILL_ID.THRUST,
            tag = SKILL_ID.THRUST,
            state = SG_STATE.THRUST,
            states = {SG_STATE.THRUST, SG_STATE.HEAVENLYSTRIKE},
            level = 0,
            mindpower = 4,
            cooldown_name = SKILL_ID.THRUST,
            cooldown_time = M_CONFIG.ThrustCooldown,
            cooldown_effect = "ghostlyelixir_speed_dripfx",
            range = 3,
            start_message = STRINGS.SKILL.SKILL3START,
            release = function(inst, target)
                local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                local sheathed = IsSheathedKatana(weapon)
                GoToSkillState(inst, SG_STATE.THRUST, target, sheathed and .05 or .1)

                if sheathed then
                    inst:DoTaskInTime(.7, function(inst)
                        inst:PushEvent(SG_STATE.HEAVENLYSTRIKE)
                        CastEquippedWeapon(inst)
                    end)

                    inst:DoTaskInTime(.9, function(inst)
                        SkillUtil.SlashFx(inst, inst, "shadowstrike_slash_fx", 3)
                        SkillUtil.AoeAttack(inst, 1, 6.5)
                        inst.components.combat:SetRange(TUNING.DEFAULT_ATTACK_RANGE)
                        inst.components.talker:Say(STRINGS.SKILL.SKILL3ATTACK, 2, true)
                        SkillUtil.GroundPoundFx(inst, .8)
                    end)
                end
            end,
        },

        {
            id = SKILL_ID.ISSHIN,
            tag = SKILL_ID.ISSHIN,
            state = SG_STATE.MONEMIND,
            level = UNLOCK_LEVEL.ISSHIN,
            mindpower = 7,
            cooldown_name = SKILL_ID.ISSHIN,
            cooldown_time = M_CONFIG.IsshinCooldown,
            cooldown_message = STRINGS.SKILL.TIER2_COOLDOWN,
            cooldown_effect = "monkey_deform_pre_fx",
            range = 3,
            start_message = STRINGS.SKILL.SKILL4START,
            release = function(inst, target)
                inst:DoTaskInTime(.1, function(inst)
                    inst.components.talker:Say(STRINGS.SKILL.SKILL4ATTACK, 2, true)
                    SkillUtil.GroundPoundFx(inst, .6)
                    SkillUtil.SlashFx(inst, target, "shadowstrike_slash_fx", 3)
                    inst.inspskill = true
                    inst.sg:GoToState(SG_STATE.MONEMIND, target)

                    for i, t in ipairs({.6, .8, 1.1, 1.4, 1.8, 1.9}) do
                        inst:DoTaskInTime(t, function(inst)
                            SkillUtil.GroundPoundFx(inst, i % 2 == 0 and .6 or .8)
                            SkillUtil.SlashFx(inst, i % 2 == 0 and inst or target, i % 2 == 0 and "wanda_attack_shadowweapon_normal_fx" or "wanda_attack_shadowweapon_old_fx", 3 + (i % 2))
                            SkillUtil.AoeAttack(inst, 1, 6.5)
                        end)
                    end

                    inst:DoTaskInTime(1.9, function(inst)
                        if inst.components.playercontroller ~= nil then
                            inst.components.playercontroller:Enable(true)
                        end
                        inst.inspskill = nil
                        inst:PushEvent(SG_STATE.HEAVENLYSTRIKE)
                        CastEquippedWeapon(inst)
                    end)

                    inst:DoTaskInTime(2.1, function(inst)
                        SkillUtil.GroundPoundFx(inst, .6)
                        SkillUtil.AoeAttack(inst, 1, 4)
                        inst.components.combat:SetRange(TUNING.DEFAULT_ATTACK_RANGE)
                    end)
                end)
            end,
        },

        {
            id = SKILL_ID.HEAVENLYSTRIKE,
            tag = SKILL_ID.HEAVENLYSTRIKE,
            state = SG_STATE.HEAVENLYSTRIKE,
            level = UNLOCK_LEVEL.HEAVENLYSTRIKE,
            mindpower = 5,
            cooldown_name = SKILL_ID.ISSHIN,
            cooldown_time = M_CONFIG.IsshinCooldown,
            cooldown_message = STRINGS.SKILL.TIER2_COOLDOWN,
            cooldown_effect = "fx_book_birds",
            range = 3,
            start_message = STRINGS.SKILL.SKILL5START,
            release = function(inst, target)
                inst:DoTaskInTime(.1, function(inst)
                    inst.components.talker:Say(STRINGS.SKILL.SKILL5ATTACK, 2, true)
                end)

                inst.sg:AddStateTag("skilling")
                inst:DoTaskInTime(.3, function(inst)
                    inst:PushEvent(SG_STATE.HEAVENLYSTRIKE)
                    SkillUtil.AddFollowerFx(inst, "mossling_spin_fx")
                    SkillUtil.AddFollowerFx(inst, "electricchargedfx")
                    SkillUtil.GroundPoundFx(inst, .8)
                    SkillUtil.SlashFx(inst, inst, "shadowstrike_slash_fx", 3)
                    SkillUtil.AoeAttack(inst, 1, 6.5)

                    inst:DoTaskInTime(.2, function(inst)
                        SkillUtil.AoeAttack(inst, 2.5, 6.5)
                        SkillUtil.SlashFx(inst, inst, "shadowstrike_slash2_fx", 3)
                        SkillUtil.GroundPoundFx(inst, .8)
                    end)

                    inst:DoTaskInTime(.3, function(inst)
                        SkillUtil.AoeAttack(inst, 4, 6.5)
                        SkillUtil.SlashFx(inst, inst, "shadowstrike_slash_fx", 3)
                        SkillUtil.GroundPoundFx(inst, .8)
                    end)
                end)
            end,
        },

        {
            id = SKILL_ID.RYUSEN,
            tag = SKILL_ID.RYUSEN,
            state = SG_STATE.RYUSEN,
            level = UNLOCK_LEVEL.RYUSEN,
            mindpower = 8,
            cooldown_name = SKILL_ID.RYUSEN,
            cooldown_time = M_CONFIG.RyusenSusanooCooldown,
            cooldown_message = STRINGS.SKILL.TIER3_COOLDOWN,
            cooldown_effect = "fx_book_birds",
            range = 10,
            start_message = STRINGS.SKILL.SKILL6START,
            release = function(inst, target)
                inst:DoTaskInTime(.1, function(inst)
                    inst.components.talker:Say(STRINGS.SKILL.SKILL6ATTACK, 2, true)
                    inst.sg:GoToState(SG_STATE.RYUSEN, target)
                    inst:DoTaskInTime(.2, function(inst) SkillUtil.SlashFx(inst, target, "wanda_attack_shadowweapon_old_fx", 2) end)
                    inst:DoTaskInTime(.4, function(inst) SkillUtil.SlashFx(inst, target, "wanda_attack_shadowweapon_normal_fx", 2) end)
                    inst:DoTaskInTime(.6, function(inst) SkillUtil.SlashFx(inst, target, "wanda_attack_shadowweapon_old_fx", 2.5) end)
                    inst:DoTaskInTime(.8, function(inst)
                        SkillUtil.SlashFx(inst, target, "wanda_attack_shadowweapon_normal_fx", 2.5)
                        SkillUtil.GroundPoundFx(target, .7)
                    end)
                    inst:DoTaskInTime(1, function(inst) SkillUtil.GroundPoundFx(inst, .6) end)
                    inst:DoTaskInTime(1.5, function(inst)
                        SkillUtil.SlashFx(inst, target, "shadowstrike_slash_fx", 3)
                        SkillUtil.GroundPoundFx(target, .7)
                    end)
                end)
            end,
        },

        {
            id = SKILL_ID.SUSANOO,
            tag = SKILL_ID.SUSANOO,
            state = SG_STATE.MONEMIND,
            level = UNLOCK_LEVEL.SUSANOO,
            mindpower = 10,
            cooldown_name = SKILL_ID.RYUSEN,
            cooldown_time = M_CONFIG.RyusenSusanooCooldown,
            cooldown_message = STRINGS.SKILL.TIER3_COOLDOWN,
            cooldown_effect = "fx_book_birds",
            range = 3,
            start_message = STRINGS.SKILL.SKILL7START,
            release = function(inst, target)
                inst:DoTaskInTime(.1, function(inst)
                    inst.components.talker:Say(STRINGS.SKILL.SKILL7ATTACK, 2, true)
                    SkillUtil.GroundPoundFx(inst, .6)
                    SkillUtil.SlashFx(inst, target, "shadowstrike_slash_fx", 3)
                    inst.inspskill = true
                    inst.sg:GoToState(SG_STATE.MONEMIND, target)

                    for _, t in ipairs({.6, .8, 1.1, 1.2, 1.4, 1.8, 1.9}) do
                        inst:DoTaskInTime(t, function(inst)
                            SkillUtil.GroundPoundFx(inst, .8)
                            SkillUtil.SlashFx(inst, inst, "fence_rotator_fx", 3.5)
                            SkillUtil.AoeAttack(inst, 1, 6.5)
                        end)
                    end

                    inst:DoTaskInTime(1.9, function(inst)
                        if inst.components.playercontroller ~= nil then
                            inst.components.playercontroller:Enable(true)
                        end
                        inst.inspskill = nil
                        inst:PushEvent(SG_STATE.HEAVENLYSTRIKE)
                        CastEquippedWeapon(inst)
                    end)

                    inst:DoTaskInTime(2.1, function(inst)
                        SkillUtil.SlashFx(inst, inst, "shadowstrike_slash_fx", 3)
                        SkillUtil.AoeAttack(inst, 2, 4)
                        inst.components.combat:SetRange(TUNING.DEFAULT_ATTACK_RANGE)
                    end)
                end)
            end,
        },

        {
            id = SKILL_ID.SORYUHA,
            tag = SKILL_ID.SORYUHA,
            state = SKILL_ID.SORYUHA,
            level = UNLOCK_LEVEL.SORYUHA,
            mindpower = 50,
            display_mindpower = 50,
            cooldown_name = SKILL_ID.SORYUHA,
            cooldown_time = M_CONFIG.SoryuhaCooldown,
            cooldown_effect = "thunderbird_fx_idle",
            range = 12,
            start_message = STRINGS.SKILL.SKILL9START,
            release = function(inst, target)
                if not IsSoryuhaLevelReady(inst) then
                    if inst.components.talker ~= nil then
                        inst.components.talker:Say("需要满级才能释放苍龙破。", 2, true)
                    end
                    return false
                end

                local weapon = inst.components.inventory ~= nil and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
                if ShouldInterruptSoryuha(inst, weapon) then
                    return false
                end

                inst:DoTaskInTime(.1, function(inst)
                    if inst:IsValid() then
                        if inst.components.talker ~= nil then
                            if weapon ~= nil and weapon:HasTag("katana") and not IsSoryuhaCarrier(weapon) then
                                inst.components.talker:Say("奥义·苍龙破！！！", 2, true)
                            else
                                inst.components.talker:Say(STRINGS.SKILL.SKILL9ATTACK, 2, true)
                            end
                        end
                        inst.sg:GoToState(SG_STATE.SORYUHA, target)
                    end
                end)
                return true
            end,
        },
    }

    return {
        skills = skills,
        inputs = {
            [SKILL_INPUT.ICHIMONJI] = {
                {
                    skill = SKILL_ID.ISSHIN,
                    key_cooldown = INPUT_COOLDOWN.ICHIMONJI,
                    input_level = UNLOCK_LEVEL.ICHIMONJI_INPUT,
                    base_mindpower = 3,
                    blocked_tags = {SKILL_ID.ICHIMONJI, SKILL_ID.ISSHIN, SKILL_ID.RYUSEN},
                    requires_tags = {SKILL_ID.FLIP},
                    weapon_tags = {"katana"},
                },
                {
                    skill = SKILL_ID.ICHIMONJI,
                    key_cooldown = INPUT_COOLDOWN.ICHIMONJI,
                    input_level = UNLOCK_LEVEL.ICHIMONJI_INPUT,
                    base_mindpower = 3,
                    blocked_tags = {SKILL_ID.ICHIMONJI, SKILL_ID.ISSHIN, SKILL_ID.RYUSEN},
                },
            },
            [SKILL_INPUT.FLIP] = {
                {
                    skill = SKILL_ID.RYUSEN,
                    key_cooldown = INPUT_COOLDOWN.FLIP,
                    input_level = UNLOCK_LEVEL.FLIP_INPUT,
                    base_mindpower = 4,
                    blocked_tags = {SKILL_ID.FLIP, SKILL_ID.RYUSEN, SKILL_ID.SUSANOO},
                    requires_tags = {SKILL_ID.ICHIMONJI},
                    weapon_tags = {"katana"},
                },
                {
                    skill = SKILL_ID.SUSANOO,
                    key_cooldown = INPUT_COOLDOWN.FLIP,
                    input_level = UNLOCK_LEVEL.FLIP_INPUT,
                    base_mindpower = 4,
                    blocked_tags = {SKILL_ID.FLIP, SKILL_ID.RYUSEN, SKILL_ID.SUSANOO},
                    requires_tags = {SKILL_ID.THRUST},
                    weapon_tags = {"katana"},
                },
                {
                    skill = SKILL_ID.FLIP,
                    key_cooldown = INPUT_COOLDOWN.FLIP,
                    input_level = UNLOCK_LEVEL.FLIP_INPUT,
                    base_mindpower = 4,
                    blocked_tags = {SKILL_ID.FLIP, SKILL_ID.RYUSEN, SKILL_ID.SUSANOO},
                },
            },
            [SKILL_INPUT.THRUST] = {
                {
                    skill = SKILL_ID.HEAVENLYSTRIKE,
                    key_cooldown = INPUT_COOLDOWN.THRUST,
                    input_level = UNLOCK_LEVEL.THRUST_INPUT,
                    base_mindpower = 4,
                    blocked_tags = {SKILL_ID.HEAVENLYSTRIKE, SKILL_ID.THRUST, SKILL_ID.SUSANOO},
                    requires_tags = {SKILL_ID.FLIP},
                    weapon_tags = {"katana"},
                },
                {
                    skill = SKILL_ID.THRUST,
                    key_cooldown = INPUT_COOLDOWN.THRUST,
                    input_level = UNLOCK_LEVEL.THRUST_INPUT,
                    base_mindpower = 4,
                    blocked_tags = {SKILL_ID.HEAVENLYSTRIKE, SKILL_ID.THRUST, SKILL_ID.SUSANOO},
                },
            },
            [SKILL_INPUT.SORYUHA] = {
                {
                    skill = SKILL_ID.SORYUHA,
                    key_cooldown = INPUT_COOLDOWN.SORYUHA,
                    input_level = UNLOCK_LEVEL.SORYUHA,
                    base_mindpower = 50,
                    blocked_tags = {SKILL_ID.SORYUHA},
                    weapon_tags = {"katana"},
                },
            },
        },
    }
end

local function GetCooldownTime(inst, dodger)
    return GetTime() - inst.components.dodger.last_dodge_time > inst.components.dodger.dodge_cooldown_time
end

local function GetPointSpecialActions(inst, pos, useitem, right)
    local rider = inst.replica.rider
    if inst:HasTag("dodger") and right and not rider:IsRiding() and GetCooldownTime(inst) and not inst:HasTag("sitting_on_chair") then
        return {ACTIONS.MDODGE}
    end
    return {}
end

local function OnSetOwner(inst)
    if inst.components.playeractionpicker ~= nil then
        inst.components.playeractionpicker.pointspecialactionsfn = GetPointSpecialActions
    end
end

local common_postinit = function(inst)
    inst.MiniMapEntity:SetIcon("manutsawee.tex")

    inst:AddTag("bearded")

    inst:AddTag("kenjutsuka")
    inst:AddTag("dodger")

    inst:AddTag("naughtychild")

    inst:AddTag("stronggrip")

    inst:AddTag("expertchef")
    inst:AddTag("pinetreepioneer")
    inst:AddTag("slingshot_sharpshooter")
    inst:AddTag("pebblemaker")

    inst:SetTag("surfer", IA_ENABLED)
    inst:SetTag("msurfer", IA_ENABLED)

    inst:SetComponent("dodger", M_CONFIG.EnableDodge)

    inst:AddComponent("playerkeyhandler")
    inst.components.playerkeyhandler:AddKeyListener(LouisManutsawee, M_CONFIG.LevelCheckKey, "LevelCheckKey")
    inst.components.playerkeyhandler:AddKeyListener(LouisManutsawee, M_CONFIG.PutGlassesKey, "PutGlassesKey")
    inst.components.playerkeyhandler:AddKeyListener(LouisManutsawee, M_CONFIG.ChangeHairStyleKey, "ChangeHairStyleKey")
    inst.components.playerkeyhandler:AddKeyListener(LouisManutsawee, M_CONFIG.QuickSheathKey, "QuickSheathKey")

    --[[
        V = ICHIMONJI
        B = FLIP
        N = THRUST

        B + V = ISSHIN
        B + N = HEAVENLYSTRIKE
        V + B = RYUSEN
        V + N = ?
        N + V = ?
        N + B = SUSANOO
    ]]
    if M_CONFIG.EnableSkill then
        inst.components.playerkeyhandler:AddKeyListener(LouisManutsawee, M_CONFIG.IchimonjiKey, SKILL_INPUT.ICHIMONJI)
        inst.components.playerkeyhandler:AddKeyListener(LouisManutsawee, M_CONFIG.FlipKey, SKILL_INPUT.FLIP)
        inst.components.playerkeyhandler:AddKeyListener(LouisManutsawee, M_CONFIG.ThrustKey, SKILL_INPUT.THRUST)
        inst.components.playerkeyhandler:AddKeyListener(LouisManutsawee, M_CONFIG.SoryuhaKey, SKILL_INPUT.SORYUHA)
        inst.components.playerkeyhandler:AddKeyListener(LouisManutsawee, M_CONFIG.SkillCancelKey, "SkillCancelKey")
        inst.components.playerkeyhandler:AddKeyListener(LouisManutsawee, M_CONFIG.CounterAttackKey, "CounterAttackKey")
    end

    inst:ListenForEvent("setowner", OnSetOwner)
end

local master_postinit = function(inst)
    inst.starting_inventory = start_inv[TheNet:GetServerGameMode()] or start_inv.default

    inst.AnimState:SetScale(0.88, 0.9, 1)

    -- for test cmp
    inst:AddComponent("nilcmp")

    inst:AddComponent("hair")

    if M_CONFIG.EnableSkill then
        inst:AddComponent("playerskillcontroller")
        local Skill = CreateSkillData()
        for _, skill in ipairs(Skill.skills) do
            inst.components.playerskillcontroller:AddSkill(skill.id, skill)
        end
        for input_name, routes in pairs(Skill.inputs) do
            for _, route in ipairs(routes) do
                inst.components.playerskillcontroller:AddInputRoute(input_name, route)
            end
        end
    end

    inst:AddComponent("skinheaddress")
    for k, v in pairs(SkinsHeaddress) do
        inst.components.skinheaddress:SetHeaddress(k, v)
    end

    inst:AddComponent("customidleanim")
    inst.components.customidleanim:SetIdleAnim(Idle_Anim, Funny_Idle_Anim)

    inst:AddComponent("glasses")
    inst.components.glasses:AddGlass("manutsawee_bocchi", "starglasses")
    inst.components.glasses:AddGlass("manutsawee_uniform_black", "sunglasses")

    inst:AddComponent("efficientuser")
    inst.components.efficientuser:AddMultiplier(ACTIONS.CHOP,   TUNING.WES_WORKEFFECTIVENESS_MODIFIER, inst)
    inst.components.efficientuser:AddMultiplier(ACTIONS.MINE,   TUNING.WES_WORKEFFECTIVENESS_MODIFIER, inst)
    inst.components.efficientuser:AddMultiplier(ACTIONS.HAMMER, TUNING.WES_WORKEFFECTIVENESS_MODIFIER, inst)
    inst.components.efficientuser:AddMultiplier(ACTIONS.ATTACK, TUNING.WES_WORKEFFECTIVENESS_MODIFIER, inst)

    inst:AddComponent("kenjutsuka")
    inst.components.kenjutsuka:SetOnRegenMindPower(OnRegenMindPower)
    inst.components.kenjutsuka:AddOnLevelUp(OnLevelUp)
    inst.components.kenjutsuka:AddSpawnFx(OnLevelUpSpawnFx)
    inst.components.kenjutsuka:OnPostInit()

    inst:AddComponent("houndedtarget")
    inst.components.houndedtarget.target_weight_mult:SetModifier(inst, TUNING.WES_HOUND_TARGET_MULT, "misfortune")
    inst.components.houndedtarget.hound_thief = true

    inst.components.foodaffinity:AddPrefabAffinity("baconeggs", TUNING.AFFINITY_15_CALORIES_HUGE)
    inst.components.foodaffinity:AddPrefabAffinity("unagi", TUNING.AFFINITY_15_CALORIES_TINY)
    inst.components.foodaffinity:AddPrefabAffinity("kelp_cooked", TUNING.AFFINITY_15_CALORIES_SUPERHUGE)
    inst.components.foodaffinity:AddPrefabAffinity("justeggs", TUNING.AFFINITY_15_CALORIES_SUPERHUGE)
    inst.components.foodaffinity:AddPrefabAffinity("durian", TUNING.AFFINITY_15_CALORIES_SUPERHUGE)
    inst.components.foodaffinity:AddPrefabAffinity("durian_cooked", TUNING.AFFINITY_15_CALORIES_SUPERHUGE)
    inst.components.foodaffinity:AddPrefabAffinity("californiaroll", TUNING.AFFINITY_15_CALORIES_TINY)
    inst.components.foodaffinity:AddPrefabAffinity("caviar", TUNING.AFFINITY_15_CALORIES_TINY)
    inst.components.foodaffinity:AddPrefabAffinity("liceloaf", TUNING.AFFINITY_15_CALORIES_TINY)
    inst.components.foodaffinity:AddPrefabAffinity("blueberrypancakes", TUNING.AFFINITY_15_CALORIES_TINY)

    inst.components.health:SetMaxHealth(TUNING.MANUTSAWEE.HEALTH)
    inst.components.hunger:SetMax(TUNING.MANUTSAWEE.HUNGER)
    inst.components.sanity:SetMax(TUNING.MANUTSAWEE.SANITY)
    inst.components.hunger:SetRate(TUNING.WILSON_HUNGER_RATE * 1.3)

    inst.components.combat.damagemultiplier = 1
    inst.components.combat:SetStartAttack(OnStartAttack)
    inst.components.grogginess.decayrate = TUNING.WES_GROGGINESS_DECAY_RATE
    inst.components.temperature.inherentinsulation = -TUNING.INSULATION_TINY
    inst.components.temperature.inherentsummerinsulation = -TUNING.INSULATION_TINY

    if inst.components.eater ~= nil then
        inst.components.eater:SetRejectEatingTag("terriblefood")
    end

    inst.components.workmultiplier:AddMultiplier(ACTIONS.CHOP,   TUNING.WES_WORKEFFECTIVENESS_MODIFIER, inst)
    inst.components.workmultiplier:AddMultiplier(ACTIONS.MINE,   TUNING.WES_WORKEFFECTIVENESS_MODIFIER, inst)
    inst.components.workmultiplier:AddMultiplier(ACTIONS.HAMMER, TUNING.WES_WORKEFFECTIVENESS_MODIFIER, inst)

    inst.soundsname = "wortox"
    inst.skeleton_prefab = nil

    inst:ListenForEvent("onattackother", OnAttackOther)
    inst:ListenForEvent("killed", OnKilled)
    inst:ListenForEvent("death", OnDeath)
    inst:ListenForEvent("unequip", OnUnEquip)
    inst:ListenForEvent("equip", OnEquip)
    inst:ListenForEvent("dropitem", OnDroped)
    inst:ListenForEvent("itemlose", OnDroped)
end

return MakePlayerCharacter("manutsawee", prefabs, assets, common_postinit, master_postinit, start_inv)
