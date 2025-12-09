local modimport = modimport
GLOBAL.setfenv(1, GLOBAL)

modimport("postinit/entityscript")
modimport("postinit/input")

local postinit = {
    prefabs = {
        "nightmarefissure",
        "winter_tree",
        "world",
        "humanmeat",
        "sacred_chest",
        "world_network",
        "gravestone",
        "rainhat",
        "pighouse",
        "blueprint",
    },
    stategraphs = {
        "SGwilson",
        "SGwilson_client",
    },
    components = {
        "eater",
        "sanity",
        "sanity_replica",
        "grogginess",
        "equippable",
        "wisecracker",
        "combat",
        "cursable",
        "trader",
        "curseditem",
        "stewer",
        "teacher",
        "playerlightningtarget",
    },
    widgets = {
        "skinspuppet",
        "redux/loadingwidget",
    },
    multipleprefabs = {
        "tradable",
        "eater",
    },
}

for k, v in pairs(postinit) do
    for i = 1, #v do
        modimport("postinit/" .. k .. "/" .. postinit[k][i])
    end
end
