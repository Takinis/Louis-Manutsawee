local Assets = Assets
GLOBAL.setfenv(1, GLOBAL)

if rawget(_G, "voidcloth_scythe_clear_fn") == nil then
    rawset(_G, "voidcloth_scythe_clear_fn", require("utils/deathsickleskin").Clear)
end

-- huh?
-- TheInventory:AddRestrictedBuildFromLua("loading_dev_cemetery", "loading_dev_cemetery", true)
-- TheInventory:AddRestrictedBuildFromLua("loading_night_for_four", "loading_night_for_four", true)

function yari_init_fn(inst, build_name)
    if not TheWorld.ismastersim then
        return
    end

    inst.displaynamefn = function()
        return STRINGS.SKIN_NAMES[build_name]
    end

    basic_init_fn(inst, build_name, "yari")
end

function yari_clear_fn(inst)
    inst.displaynamefn = nil
    basic_clear_fn(inst, "yari")
end

GlassicAPI.SkinHandler.AddModSkin("loading_dev_cemetery", function(skin, userid)
    MISC_ITEMS.loading_dev_cemetery = {
        type = "loading",
        skin_tags = { "LOADING"},
        rarity = "Classy",
        rarity_modifier = "Woven",
    }
    return true
end)

GlassicAPI.SkinHandler.AddModSkin("loading_night_for_four", function(skin, userid)
    MISC_ITEMS.loading_night_for_four = {
        type = "loading",
        skin_tags = { "LOADING"},
        rarity = "Classy",
        rarity_modifier = "Woven",
    }
    return true
end)

GlassicAPI.SkinHandler.AddModSkin("kiritzuka_short_skirt", function(skin, userid)
    CLOTHING.kiritzuka_short_skirt = {
        type = "legs",
		skin_tags = { "CLOTHING_LEGS", "CLOTHING", "BLACK", },
		symbol_overrides = { "skirt", },
        rarity = "Glassic",
        rarity_modifier = "Woven",
    }
    return true
end)

GlassicAPI.SkinHandler.AddModSkin("kiritzuka_long_sleeved_top", function(skin, userid)
    CLOTHING.kiritzuka_long_sleeved_top = {
        type = "body",
		skin_tags = { "CLOTHING_BODY", "CLOTHING", "BLACK", },
		symbol_overrides = { "arm_upper", },
        rarity = "Glassic",
        rarity_modifier = "Woven",
    }
    return true
end)

GlassicAPI.SkinHandler.SetCharacterExclusiveSkin("kiritzuka_short_skirt", "kiritzuka")
GlassicAPI.SkinHandler.SetCharacterExclusiveSkin("kiritzuka_long_sleeved_top", "kiritzuka")

GlassicAPI.SkinHandler.AddModSkins({
    manutsawee = {
        "manutsawee_none",
        "manutsawee_sailor",
        "manutsawee_yukata",
        "manutsawee_yukatalong",
        "manutsawee_miko",
        "manutsawee_qipao",
        "manutsawee_fuka",
        "manutsawee_maid",
        "manutsawee_jinbei",
        "manutsawee_shinsengumi",
        "manutsawee_taohuu",
        "manutsawee_uniform_black",
        "manutsawee_bocchi",
        "manutsawee_lycoris",

    },
    kiritzuka = {
        "kiritzuka_none",
        "kiritzuka_maid",
        "kiritzuka_maid_kimono",
        "kiritzuka_maid_victorian",
        "kiritzuka_maid_classic",
        "kiritzuka_maid_highcollar",
        "kiritzuka_cape_cardigan",
        "kiritzuka_shirt_tie",
    },
    inoue = {
        "inoue_none",
    },
    cane = {"lcane"},
    yari = {"mnaginata"},
    voidcloth_scythe = {"voidcloth_scythe_death"},
    ruinshat = {"ruinshat_dreadstone"},
})
