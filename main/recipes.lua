-- TODO: Sort Recipes

local AddRecipe2 = AddRecipe2
GLOBAL.setfenv(1, GLOBAL)

local recipes = {
    mingot = {
        ingredients = {Ingredient("moonrocknugget", 8), Ingredient("moonglass", 8), Ingredient("thulecite", 4)},
        tech = TECH.SCIENCE_TWO,
        config = {builder_tag = "kenjutsuka"},
        filters = {"REFINE"},
    },
    maid_hb = {
        ingredients = {Ingredient("silk", 4)},
        tech = TECH.SCIENCE_ONE,
        config = {builder_tag = "kenjutsuka"},
        filters = {"CHARACTER", "CLOTHING"},
    },
    m_foxmask = {
        ingredients = {Ingredient("silk", 4)},
        tech = TECH.SCIENCE_ONE,
        config = {builder_tag = "kenjutsuka"},
        filters = {"CHARACTER", "CLOTHING"},
    },
    m_scarf = {
        ingredients = {Ingredient("silk", 4), Ingredient("beefalowool", 4)},
        tech = TECH.SCIENCE_TWO,
        config = {builder_tag = "kenjutsuka"},
        filters = {"CHARACTER", "CLOTHING", "WINTER"},
    },

    harakiri = {
        ingredients = {Ingredient("flint", 2), Ingredient("log", 2)},
        tech = TECH.SCIENCE_ONE,
        config = {builder_tag = "kenjutsuka"},
        filters = {"CHARACTER", "WEAPONS"},
    },
    mmiko_armor = {
        ingredients = {Ingredient("silk", 4), Ingredient("boards", 2), Ingredient("rope", 2)},
        tech = TECH.SCIENCE_TWO,
        config = {builder_tag = "kenjutsuka"},
        filters = {"CHARACTER", "ARMOUR", "CLOTHING"},
    },

    shinai = {
        ingredients = {Ingredient("rope", 1), Ingredient("boards", 1)},
        tech = TECH.SCIENCE_ONE,
        config = {builder_tag = "kenjutsuka"},
        filters = {"CHARACTER", "WEAPONS"},
    },

    yari = {
        ingredients = {Ingredient("spear", 1), Ingredient("goldnugget", 2)},
        tech = TECH.SCIENCE_TWO,
        config = {builder_tag = "kenjutsuka"},
        filters = {"CHARACTER", "WEAPONS"},
    },

    katanablade = {
        ingredients = {Ingredient("rope", 1), Ingredient("katanabody", 1), Ingredient("cutstone", 1)},
        tech = TECH.SCIENCE_TWO,
        config = {builder_tag = "kenjutsuka"},
        filters = {"CHARACTER", "WEAPONS"},
    },

    shirasaya = {
        ingredients = {Ingredient("cane", 1), Ingredient("katanablade", 1), Ingredient("rope", 2), Ingredient("goldnugget", 2)},
        tech = TECH.SCIENCE_TWO,
        config = {builder_tag = "kenjutsuka"},
        filters = {"CHARACTER", "WEAPONS"},
    },
    koshirae = {
        ingredients = {Ingredient("cane", 1), Ingredient("katanablade", 1), Ingredient("rope", 2), Ingredient("goldnugget", 2)},
        tech = TECH.SCIENCE_TWO,
        config = {builder_tag = "kenjutsuka"},
        filters = {"CHARACTER", "WEAPONS"},
    },
    hitokiri = {
        ingredients = {Ingredient("cane", 1), Ingredient("katanablade", 1), Ingredient("rope", 2), Ingredient("goldnugget", 2)},
        tech = TECH.SCIENCE_TWO,
        config = {builder_tag = "kenjutsuka"},
        filters = {"CHARACTER", "WEAPONS"},
    },
    raikiri = {
        ingredients = {Ingredient("cane", 1), Ingredient("katanablade", 1), Ingredient("rope", 2), Ingredient("goldnugget", 2)},
        tech = TECH.SCIENCE_TWO,
        config = {builder_tag = "kenjutsuka"},
        filters = {"CHARACTER", "WEAPONS"},
    },

    shusui = {
        ingredients = {Ingredient("katanablade", 1), Ingredient("cane", 1), Ingredient("thulecite", 20), Ingredient("nightmarefuel", 20)},
        tech = TECH.ANCIENT_FOUR,
        config = {builder_tag = "kenjutsuka"},
        filters = {"CHARACTER", "WEAPONS"},
    },

    --
    kage = {
        ingredients = {Ingredient("katanablade", 1), Ingredient("nightmarefuel", 40)},
        tech = TECH.LOST,
        config = {builder_tag = "kenjutsuka"},
        filters = {"CHARACTER", "WEAPONS"},
    },

    -- true_shirasaya = {
    --     ingredients = {Ingredient("thulecite", 40), Ingredient("nightmarefuel", 80), Ingredient("shadowheart", 6), Ingredient("shirasaya", 1)},
    --     tech = TECH.SCIENCE_TWO,
    --     config = {builder_tag = "katanakaji"},
    --     filters = {"CHARACTER", "WEAPONS"},
    -- },
    -- true_koshirae = {
    --     ingredients = {Ingredient("thulecite", 40), Ingredient("nightmarefuel", 80), Ingredient("opalpreciousgem", 6), Ingredient("koshirae", 1)},
    --     tech = TECH.SCIENCE_TWO,
    --     config = {builder_tag = "katanakaji"},
    --     filters = {"CHARACTER", "WEAPONS"},
    -- },
    -- true_hitokiri = {
    --     ingredients = {Ingredient("thulecite", 40), Ingredient("nightmarefuel", 80), Ingredient("minotaurhorn", 4), Ingredient("hitokiri", 1)},
    --     tech = TECH.SCIENCE_TWO,
    --     config = {builder_tag = "katanakaji"},
    --     filters = {"CHARACTER", "WEAPONS"},
    -- },
    -- true_raikiri = {
    --     ingredients = {Ingredient("thulecite", 40), Ingredient("nightmarefuel", 80), Ingredient("lightninggoathorn", 12), Ingredient("raikiri", 1)},
    --     tech = TECH.SCIENCE_TWO,
    --     config = {builder_tag = "katanakaji"},
    --     filters = {"CHARACTER", "WEAPONS"},
    -- },
}

for k, v in pairs(recipes) do
    AddRecipe2(k, v.ingredients, v.tech, v.config, v.filters)

    -- if v.sort ~= nil and v.sort.before then
    --     GlassicAPI.RecipeSortBefore(k, v.sort.before, v.filters[2])
    -- end
    -- if v.sort ~= nil and v.sort.after then
    --     GlassicAPI.RecipeSortAfter(k, v.sort.after, v.filters[2])
    -- end
end
