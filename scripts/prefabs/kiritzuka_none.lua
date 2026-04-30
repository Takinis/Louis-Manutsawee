local prefabs = {}

table.insert(prefabs, CreatePrefabSkin("kiritzuka_none", {
    base_prefab = "kiritzuka",
    build_name_override = "kiritzuka",
    type = "base",
    rarity = "Elegant",
    skip_item_gen = true,
    skip_giftable_gen = true,
    skin_tags = {"BASE", "kiritzuka", },
    skins = {
        normal_skin = "kiritzuka",
        ghost_skin = "ghost_kiritzuka_build",
    },
    assets = {
        Asset("ANIM", "anim/kiritzuka.zip"),
        Asset("ANIM", "anim/ghost_kiritzuka_build.zip"),
    },
}))

return unpack(prefabs)
