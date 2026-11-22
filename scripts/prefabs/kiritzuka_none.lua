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

-- These builds carry "skirt_front" / "skirt_side" / "skirt_back" symbols, swapped in
-- by body pose (scripts/utils/sideskirtutil.lua).
table.insert(prefabs, CreatePrefabSkin("kiritzuka_maid", {
    base_prefab = "kiritzuka",
    build_name_override = "kiritzuka_maid",
    type = "base",
    rarity = "Elegant",
    skip_item_gen = true,
    skip_giftable_gen = true,
    skin_tags = {"BASE", "kiritzuka", },
    skins = {
        normal_skin = "kiritzuka_maid",
        ghost_skin = "ghost_kiritzuka_build",
    },
    assets = {
        Asset("DYNAMIC_ANIM", "anim/dynamic/kiritzuka_maid.zip"),
        Asset("PKGREF", "anim/dynamic/kiritzuka_maid.dyn"),
        Asset("ANIM", "anim/ghost_kiritzuka_build.zip"),
    },
}))

table.insert(prefabs, CreatePrefabSkin("kiritzuka_maid_kimono", {
    base_prefab = "kiritzuka",
    build_name_override = "kiritzuka_maid_kimono",
    type = "base",
    rarity = "Elegant",
    skip_item_gen = true,
    skip_giftable_gen = true,
    skin_tags = {"BASE", "kiritzuka", },
    skins = {
        normal_skin = "kiritzuka_maid_kimono",
        ghost_skin = "ghost_kiritzuka_build",
    },
    assets = {
        Asset("DYNAMIC_ANIM", "anim/dynamic/kiritzuka_maid_kimono.zip"),
        Asset("PKGREF", "anim/dynamic/kiritzuka_maid_kimono.dyn"),
        Asset("ANIM", "anim/ghost_kiritzuka_build.zip"),
    },
}))

table.insert(prefabs, CreatePrefabSkin("kiritzuka_maid_victorian", {
    base_prefab = "kiritzuka",
    build_name_override = "kiritzuka_maid_victorian",
    type = "base",
    rarity = "Elegant",
    skip_item_gen = true,
    skip_giftable_gen = true,
    skin_tags = {"BASE", "kiritzuka", },
    skins = {
        normal_skin = "kiritzuka_maid_victorian",
        ghost_skin = "ghost_kiritzuka_build",
    },
    assets = {
        Asset("DYNAMIC_ANIM", "anim/dynamic/kiritzuka_maid_victorian.zip"),
        Asset("PKGREF", "anim/dynamic/kiritzuka_maid_victorian.dyn"),
        Asset("ANIM", "anim/ghost_kiritzuka_build.zip"),
    },
}))

table.insert(prefabs, CreatePrefabSkin("kiritzuka_maid_classic", {
    base_prefab = "kiritzuka",
    build_name_override = "kiritzuka_maid_classic",
    type = "base",
    rarity = "Elegant",
    skip_item_gen = true,
    skip_giftable_gen = true,
    skin_tags = {"BASE", "kiritzuka", },
    skins = {
        normal_skin = "kiritzuka_maid_classic",
        ghost_skin = "ghost_kiritzuka_build",
    },
    assets = {
        Asset("DYNAMIC_ANIM", "anim/dynamic/kiritzuka_maid_classic.zip"),
        Asset("PKGREF", "anim/dynamic/kiritzuka_maid_classic.dyn"),
        Asset("ANIM", "anim/ghost_kiritzuka_build.zip"),
    },
}))

table.insert(prefabs, CreatePrefabSkin("kiritzuka_maid_highcollar", {
    base_prefab = "kiritzuka",
    build_name_override = "kiritzuka_maid_highcollar",
    type = "base",
    rarity = "Elegant",
    skip_item_gen = true,
    skip_giftable_gen = true,
    skin_tags = {"BASE", "kiritzuka", },
    skins = {
        normal_skin = "kiritzuka_maid_highcollar",
        ghost_skin = "ghost_kiritzuka_build",
    },
    assets = {
        Asset("DYNAMIC_ANIM", "anim/dynamic/kiritzuka_maid_highcollar.zip"),
        Asset("PKGREF", "anim/dynamic/kiritzuka_maid_highcollar.dyn"),
        Asset("ANIM", "anim/ghost_kiritzuka_build.zip"),
    },
}))

table.insert(prefabs, CreatePrefabSkin("kiritzuka_cape_cardigan", {
    base_prefab = "kiritzuka",
    build_name_override = "kiritzuka_cape_cardigan",
    type = "base",
    rarity = "Elegant",
    skip_item_gen = true,
    skip_giftable_gen = true,
    skin_tags = {"BASE", "kiritzuka", },
    skins = {
        normal_skin = "kiritzuka_cape_cardigan",
        ghost_skin = "ghost_kiritzuka_build",
    },
    assets = {
        Asset("DYNAMIC_ANIM", "anim/dynamic/kiritzuka_cape_cardigan.zip"),
        Asset("PKGREF", "anim/dynamic/kiritzuka_cape_cardigan.dyn"),
        Asset("ANIM", "anim/ghost_kiritzuka_build.zip"),
    },
}))

table.insert(prefabs, CreatePrefabSkin("kiritzuka_shirt_tie", {
    base_prefab = "kiritzuka",
    build_name_override = "kiritzuka_shirt_tie",
    type = "base",
    rarity = "Elegant",
    skip_item_gen = true,
    skip_giftable_gen = true,
    skin_tags = {"BASE", "kiritzuka", },
    skins = {
        normal_skin = "kiritzuka_shirt_tie",
        ghost_skin = "ghost_kiritzuka_build",
    },
    assets = {
        Asset("DYNAMIC_ANIM", "anim/dynamic/kiritzuka_shirt_tie.zip"),
        Asset("PKGREF", "anim/dynamic/kiritzuka_shirt_tie.dyn"),
        Asset("ANIM", "anim/ghost_kiritzuka_build.zip"),
    },
}))

return unpack(prefabs)
