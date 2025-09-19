local MakePlayerCharacter = require "prefabs/player_common"

--[[

“the art style of Don’t Starve Together, hand-drawn sketchy lines, gothic cartoon aesthetic, flat 2.5D perspective, no background, muted color palette, stylized shadows and highlights, item centered, illustrated with irregular lines and exaggerated proportions to match the Don’t Starve aesthetic”

]]

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
    manutsawee_maid_m = "idle_wanda",
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
    manutsawee_maid_m = "maid_hb",
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
    if mindpower >= 3 then
        inst.components.talker:Say("󰀈: ".. mindpower .."\n", 1, true)
    end
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

local function OnLevelUpSpawnFx(inst)
    OnDeath(inst)
end

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

local Skill = {
    {
        tag = "ichimonji",
        script = "",
        skill_range = 3.5,
        require_level = 1,
        require_mindpower = 3,
        cooldown_time = M_CONFIG.SKILL1_COOLDOWN,
        cooldown_effect = "ghostlyelixir_retaliation_dripfx",
        cb = function(inst, target)
            inst:PushEventInTime(.05, "ichimonji")
        end,
    },
}


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

local function OnKilled(inst, data)
    local target = data.victim
    local target_scale = (target:HasTag("smallcreature") and 1) or (target:HasTag("largecreature") and 4) or 2

    if target ~= nil and target_scale ~= nil then
        if not target:HasOneOfTags({"prey", "bird", "insect", "hostile"}) and inst.components.sanity:GetPercent() <= .8  then
            inst.components.sanity:DoDelta(target_scale)
        end
    end
end

local OnStartAttack = function(inst, target)
    inst.components.playerskillcontroller:ReleaseSkill(target)
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

    inst:AddComponent("playerkeyhandler")
    inst.components.playerkeyhandler:AddKeyListener(LouisManutsawee, M_CONFIG.LevelCheckKey, "LevelCheckKey")
    inst.components.playerkeyhandler:AddKeyListener(LouisManutsawee, M_CONFIG.PutGlassesKey, "PutGlassesKey")
    inst.components.playerkeyhandler:AddKeyListener(LouisManutsawee, M_CONFIG.ChangeHairStyleKey, "ChangeHairStyleKey")
    -- inst.components.playerkeyhandler:AddKeyListener(LouisManutsawee, M_CONFIG.QuickSheathKey, "QuickSheathKey")
    -- inst.components.playerkeyhandler:AddKeyListener(LouisManutsawee, M_CONFIG.SkillCancelKey, "SkillCancelKey")
    -- inst.components.playerkeyhandler:AddKeyListener(LouisManutsawee, M_CONFIG.CounterAttackKey, "CounterAttackKey")

    -- inst.components.playerkeyhandler:AddCombinationKeyListener(LouisManutsawee, M_CONFIG.PutGlassesKey, M_CONFIG.ChangeHairStyleKey, "PutGlassesKey")
    -- inst.components.playerkeyhandler:AddSequentialKeyHandler(LouisManutsawee, M_CONFIG.PutGlassesKey, M_CONFIG.ChangeHairStyleKey, "ChangeHairStyleKey")
    -- inst.components.playerkeyhandler:AddCombinationKeyListener(LouisManutsawee, M_CONFIG.PutGlassesKey, M_CONFIG.ChangeHairStyleKey, "ChangeHairStyleKey")

    -- inst.components.keyhandler:AddActionListener(LouisManutsawee, M_CONFIG.SKILL1_KEY, "Skill1")
    -- inst.components.keyhandler:AddActionListener(LouisManutsawee, M_CONFIG.SKILL2_KEY, "Skill2")
    -- inst.components.keyhandler:AddActionListener(LouisManutsawee, M_CONFIG.SKILL3_KEY, "Skill3")
    -- inst.components.keyhandler:AddActionListener(LouisManutsawee, M_CONFIG.SKILL4_KEY, "Skill4")
    -- inst.components.keyhandler:AddActionListener(LouisManutsawee, M_CONFIG.SKILL_COUNTER_ATK_KEY, "CounterAttack")
    -- inst.components.keyhandler:AddActionListener(LouisManutsawee, M_CONFIG.QUICK_SHEATH_KEY, "QuickSheath")
    -- inst.components.keyhandler:AddActionListener(LouisManutsawee, M_CONFIG.SKILL_CANCEL_KEY, "SkillCancel")
end

local master_postinit = function(inst)
    inst.starting_inventory = start_inv[TheNet:GetServerGameMode()] or start_inv.default

    inst.AnimState:SetScale(0.88, 0.9, 1)

    -- for test cmp
    inst:AddComponent("nilcmp")

    inst:SetComponent("dodger", M_CONFIG.EnableDodge)

    inst:AddComponent("hair")
    inst.components.hair:SetUpHair()

    inst:AddComponent("playerskillcontroller")
    for k, v in pairs(Skill) do
        inst.components.playerskillcontroller:AddSkill(k, v)
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

    inst:AddComponent("efficientuser")
    inst.components.efficientuser:AddMultiplier(ACTIONS.CHOP,   TUNING.WES_WORKEFFECTIVENESS_MODIFIER, inst)
    inst.components.efficientuser:AddMultiplier(ACTIONS.MINE,   TUNING.WES_WORKEFFECTIVENESS_MODIFIER, inst)
    inst.components.efficientuser:AddMultiplier(ACTIONS.HAMMER, TUNING.WES_WORKEFFECTIVENESS_MODIFIER, inst)
    inst.components.efficientuser:AddMultiplier(ACTIONS.ATTACK, TUNING.WES_WORKEFFECTIVENESS_MODIFIER, inst)

    inst.soundsname = "wortox"
    inst.skeleton_prefab = nil
    inst.Skill = Skill

    inst:ListenForEvent("killed", OnKilled)
    inst:ListenForEvent("death", OnDeath)
    inst:ListenForEvent("unequip", OnUnEquip)
    inst:ListenForEvent("equip", OnEquip)
    inst:ListenForEvent("dropitem", OnDroped)
    inst:ListenForEvent("itemlose", OnDroped)
end

return MakePlayerCharacter("manutsawee", prefabs, assets, common_postinit, master_postinit, start_inv)
