local fx = {
    "m_shadowhand_fx",
    "mforcefield",
}

for _, v in pairs(fx) do
    table.insert(PrefabFiles, v)
end

GLOBAL.setfenv(1, GLOBAL)

local function FinalOffset1(inst)
    inst.AnimState:SetFinalOffset(1)
end

local function SetSortOrder(inst)
    inst.AnimState:SetSortOrder(2)
end

local fx = {
    {
        name = "thunderbird_fx_idle",
        bank = "thunderbird_fx",
        build = "thunderbird_fx",
        anim = "idle",
        fn = SetSortOrder,
    },
    {
        name = "thunderbird_fx_shoot",
        bank = "thunderbird_fx",
        build = "thunderbird_fx",
        anim = "shoot",
        fn = SetSortOrder,
    },
    {
        name = "thunderbird_fx_charge_loop",
        bank = "thunderbird_fx",
        build = "thunderbird_fx",
        anim = "charge_loop",
        fn = SetSortOrder,
    },
    {
        name = "thunderbird_fx_charge_pre",
        bank = "thunderbird_fx",
        build = "thunderbird_fx",
        anim = "charge_pre",
        fn = SetSortOrder,
    },
    {
        name = "thunderbird_fx_charge_pst",
        bank = "thunderbird_fx",
        build = "thunderbird_fx",
        anim = "charge_pst",
        fn = SetSortOrder,
    },
    {
        name = "battlesong_instant_attack_fx",
        bank = "fx_wathgrithr_buff",
        build = "fx_wathgrithr_buff",
        anim = "quote_electric",
    },
    {
        name = "fx_attack_pop",
        bank = "fx_dock_crackleandpop",
        build = "fx_dock_crackleandpop",
        anim = "pop",
        sound = "turnoftides/common/together/moon_glass/mine",
    },
    {
        name = "balloon_attack_pop",
        bank = "balloon_pop",
        build = "balloon_pop",
        anim = "pop_low",
        sound = "turnoftides/common/together/moon_glass/mine",
        fn = FinalOffset1,
    },
    {
		name = "purebrilliance_mark_attack_fx",
		bank = "slingshotammo_purebrilliance_mark_fx",
		build = "slingshotammo_purebrilliance_mark_fx",
		anim = "fx_hit",
        sound = "turnoftides/common/together/moon_glass/mine",
		fn = function(inst)
			local scale = 1.2 + math.random() * .2
			inst.AnimState:SetScale(math.random() < .5 and scale or -scale, scale)
			inst.AnimState:SetFinalOffset(7)
		end,
	},
    {
        name = "round_puff_attack_fx",
        bank = "round_puff_fx",
        build = "round_puff_fx",
        anim = "puff_lg",
        sound = "turnoftides/common/together/moon_glass/mine",
        fn = FinalOffset1,
    },
    {
        name = "chester_transform_attack_fx",
        bank = "die_fx",
        build = "die",
        anim = "small",
        sound = "turnoftides/common/together/moon_glass/mine",
    },
}

-- Sneakily add these to the FX table
-- Also force-load the assets because the fx file won't do for some reason

local fx = require("fx")

for _, v in ipairs(fx) do
    table.insert(fx, v)
end
