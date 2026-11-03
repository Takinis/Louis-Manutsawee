local prefabs = {}

-- Placeholder: borrows existing builds until anim/inoue.zip and anim/ghost_inoue_build.zip exist.
table.insert(prefabs, CreatePrefabSkin("inoue_none", {
    base_prefab = "inoue",
    build_name_override = "kiritzuka",
    type = "base",
    rarity = "Elegant",
    skip_item_gen = true,
    skip_giftable_gen = true,
    skin_tags = {"BASE", "INOUE", },
    skins = {
        normal_skin = "kiritzuka",
        ghost_skin = "ghost_manutsawee_build",
    },
    assets = {
        Asset("ANIM", "anim/kiritzuka.zip"),
        Asset("ANIM", "anim/ghost_manutsawee_build.zip"),
    },
}))

return unpack(prefabs)
