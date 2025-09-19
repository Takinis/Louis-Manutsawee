local prefabs = {}

table.insert(prefabs, CreatePrefabSkin("manutsawee_none", {
    base_prefab = "manutsawee",
    build_name_override = "manutsawee",
    type = "base",
    rarity = "Elegant",
    skip_item_gen = true,
    skip_giftable_gen = true,
    skin_tags = {"BASE", "MANUTSAWEE", },
    skins = {
        normal_skin = "manutsawee",
        ghost_skin = "ghost_manutsawee_build",
    },
    assets = {
        Asset("ANIM", "anim/manutsawee.zip"),
        Asset("ANIM", "anim/ghost_manutsawee_build.zip"),
    },
}))

for _, v in ipairs({
    "sailor",
    "yukata",
    "yukatalong",
    "miko",
    "qipao",
    "fuka",
    "maid",
    "jinbei",
    "shinsengumi",
    "taohuu",
    "uniform_black",
    "bocchi",
    "lycoris",
    "maid_m",
}) do
    table.insert(prefabs, CreatePrefabSkin("manutsawee_" .. v, {
        base_prefab = "manutsawee",
        build_name_override = "manutsawee_" .. v,
        type = "base",
        rarity = "Elegant",
        skip_item_gen = true,
        skip_giftable_gen = true,
        skin_tags = {"BASE", "MANUTSAWEE", "SURVIVOR"},
        skins = {
            normal_skin = "manutsawee_" .. v,
            ghost_skin = "ghost_manutsawee_build",
        },

        assets = {
            Asset("ANIM", "anim/manutsawee_" .. v .. ".zip"),
            Asset("ANIM", "anim/ghost_manutsawee_build.zip"),
        },
    }))
end

table.insert(prefabs, CreatePrefabSkin("lcane", {
    base_prefab = "cane",
    type = "item",
    rarity = "Glassic",
    assets = {
        Asset("DYNAMIC_ANIM", "anim/dynamic/lcane.zip"),
        Asset("PKGREF", "anim/dynamic/lcane.dyn"),
    },
    init_fn = function(inst)
        cane_init_fn(inst, "lcane")
        GlassicAPI.UpdateFloaterAnim(inst)
    end,
    skin_tags = { "CANE", "Glassic" },
}))

table.insert(prefabs, CreatePrefabSkin("mnaginata", {
    base_prefab = "yari",
    type = "item",
    rarity = "Glassic",
    assets = {
        Asset("DYNAMIC_ANIM", "anim/dynamic/mnaginata.zip"),
        Asset("PKGREF", "anim/dynamic/mnaginata.dyn"),
    },
    init_fn = function(inst)
        yari_init_fn(inst, "mnaginata")
        GlassicAPI.UpdateFloaterAnim(inst)
    end,
    skin_tags = { "MNAGINATA", "Glassic" },
}))

return unpack(prefabs)
