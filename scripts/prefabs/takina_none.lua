local prefabs = {}

table.insert(prefabs, CreatePrefabSkin("takina_none", {
    base_prefab = "takina",
    build_name_override = "takina",
    type = "base",
    rarity = "Elegant",
    skip_item_gen = true,
    skip_giftable_gen = true,
    skin_tags = {"BASE", "TAKINA", },
    skins = {
        normal_skin = "takina",
        ghost_skin = "ghost_takina_build",
    },
    assets = {
        Asset("ANIM", "anim/takina.zip"),
        Asset("ANIM", "anim/ghost_takina_build.zip"),
    },
}))

return unpack(prefabs)
