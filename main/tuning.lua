local ENV = env
local TUNING = GLOBAL.TUNING
local ALL_KATANA = GLOBAL.ALL_KATANA
GLOBAL.setfenv(1, GLOBAL)

TUNING.MANUTSAWEE_HEALTH = 125
TUNING.MANUTSAWEE_HUNGER = 150
TUNING.MANUTSAWEE_SANITY = 233

local katana = ALL_KATANA[M_CONFIG.StartWeapon]

if katana then
    TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.MANUTSAWEE = {"tokijin", katana}
else
    TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.MANUTSAWEE = {"tokijin"}
end

-- Stop here if MiM enabled
if ENV.is_mim_enabled then
    return
end

local wilson_attack = TUNING.BASE_SURVIVOR_ATTACK

local tuning = {
    KATANA = {
        DAMAGE = wilson_attack * 2,
        TRUE_DAMAGE = wilson_attack * 2.4,
        USES = 800,
    },

    TOKIJIN_DAMAGE = wilson_attack * 1.9,
    HARAKIRI_DAMAGE = wilson_attack,
    YARI_DAMAGE = wilson_attack * 1.5,

    HARAKIRI_USES = 200,
    YARI_USES = 300,
    BLADE_USES = 300,

    --mmiko_armor
    MMIKO_ARMOR_AMOUNT = 1500,
    MMIKO_ARMOR_PRECENT = 0.8,
    MMIKO_ARMOR_COOLDOWN = 3,
    MMIKO_ARMOR_DURATION = 8,

    MINGOT_WORK_REQUIRED = 4,
    MINGOT_LOOT = {
        WORK_MAX_SPAWNS = 10,
        LAUNCH_SPEED = -1.8,
        LAUNCH_HEIGHT = 0.5,
        LAUNCH_ANGLE = 65,
    },

    MANUTSAWEE = {
        HEALTH = 125,
        HUNGER = 150,
        SANITY = 233,
    },

    DEFAULT_DODGE_COOLDOWN_TIME = 1.2,
    DEFAULT_DODGE_TIMEOUT = 0.25,

    KAGE_ATTACK_RADIUS = 20,
}

if MOD_ENABLED.IA then
    tuning.MSURFBOARD_HEALTH = 300
    tuning.MSURFBOARD_SPEED = 4
end

for key, value in pairs(tuning) do
    if TUNING[key] then
        print("OVERRIDE: " .. key .. " in TUNING")
    end

    TUNING[key] = value
end
