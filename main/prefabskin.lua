local Assets = Assets
GLOBAL.setfenv(1, GLOBAL)

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


-- GlassicAPI.SkinHandler.AddModSkin("maid", function(skin, userid)
--     CLOTHING.maid = {
--         type = "body",
-- 		skin_tags = { "CLOTHING_BODY", "CLOTHING", },
-- 		symbol_overrides = { "arm_lower", "arm_upper", "foot", "leg", "skirt", "torso", "torso_pelvis", },
-- 		symbol_hides = { "arm_upper_skin", },
-- 		rarity = "Spiffy",
--     }
--     return true
-- end)

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
    cane = {"lcane"},
    yari = {"mnaginata"},
})
