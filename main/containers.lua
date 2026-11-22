GLOBAL.setfenv(1, GLOBAL)
local params = require("containers").params

params.lycoris_backpack = params.backpack

local boat_msurfboard = {
    widget = {
        slotpos = {},
        animbank = "boat_hud_raft",
        animbuild = "boat_hud_raft",
        pos = Vector3(750, 75, 0),
        badgepos = Vector3(0, 40, 0),
        equipslotroot = Vector3(-80, 40, 0),
        --side_align_tip = -500,
    },

    inspectwidget = {
        slotpos = {},
        animbank = "boat_inspect_raft",
        animbuild = "boat_inspect_raft",
        pos = Vector3(200, 0, 0),
        badgepos = Vector3(0, 5, 0),
        equipslotroot = {},
    },

    type = "boat",
    side_align_tip = -500,
    canbeopened = false,
    hasboatequipslots = false,
    enableboatequipslots = true,
}

params["boat_msurfboard"] = boat_msurfboard
