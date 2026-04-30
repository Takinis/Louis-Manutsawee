local strings = {
    NAMES = {
        OINC1000000 = "Millionpiece Oinc",
    },
    CHARACTERS = {
        MANUTSAWEE = require("manutsawee"),
        GENERIC = require("generic"),
    },
}

merge_table(strings, require("common"))

return strings
