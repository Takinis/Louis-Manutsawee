local modimport = modimport
GLOBAL.setfenv(1, GLOBAL)

modimport("postinit/entityscript")
modimport("postinit/input")
modimport("postinit/screens/optionsscreen")

if PL_ENABLED then
    modimport("postinit/components/shopper")
end

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
        "wagboss_beam_fx",
        "slurper",
        "pig_ruins_entrance",
    },
    stategraphs = {
        "SGwilson",
        "SGwilson_client",
        "SGkiritzuka",
        "SGbat",
        "SGslurper",
    },
    components = {
        "eater",
        "sanity",
        "sanity_replica",
        "grogginess",
        "equippable",
        "equippable_replica",
        "mightydumbbell",
        "wisecracker",
        "combat",
        "combat_replica",
        "lunarsupernovaburning",
        "cursable",
        "trader",
        "curseditem",
        "stewer",
        "teacher",
        "playerlightningtarget",
        "skinner",
        "health",
        "porkland_undertile",
    },
    widgets = {
        "skinspuppet",
        "statusdisplays",
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
