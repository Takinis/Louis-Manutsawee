local ENV = env
local TUNING = GLOBAL.TUNING
GLOBAL.setfenv(1, GLOBAL)

TUNING.MANUTSAWEE_HEALTH = 125
TUNING.MANUTSAWEE_HUNGER = 150
TUNING.MANUTSAWEE_SANITY = 233

TUNING.INOUE_HEALTH = 150
TUNING.INOUE_HUNGER = 150
TUNING.INOUE_SANITY = 200

TUNING.KIRITZUKA_HEALTH = 101.0
TUNING.KIRITZUKA_HUNGER = 164
TUNING.KIRITZUKA_SANITY = 234
TUNING.KIRITZUKA_LOW_HEALTH_DAMAGE = 0.75
-- Off for now: no Kiritzuka skill has a cooldown while this is false.
TUNING.KIRITZUKA_SKILL_COOLDOWNS = false
-- With an exclusive weapon, every attack faced is blocked rather than only the ones that knock back.
TUNING.KIRITZUKA_PARRY_ALL = true
-- How much harder a parried knockback pushes her back; at 1 it barely moves her a unit.
TUNING.KIRITZUKA_PARRY_RETREAT = 2.5
-- Slurpers and Hound Batilisks faced mid-pounce are thrown back instead of blocked.
TUNING.KIRITZUKA_POUNCE_REPEL = {
    -- How close a Hound Batilisk gets before it is thrown off; it latches on at 0.7.
    RANGE = 1,
    RADIUS = 3,
    STRENGTH = 1.5,
}
TUNING.KIRITZUKA_BOSS_SLAM = {
    -- Total across all hits.
    DAMAGE = 600,
    HITS = 5,
    -- Random smaller blasts around the impact, on top of the main hits.
    IMPACT_BURSTS = 6,
    HIT_BURSTS = 3,
    BURST_RADIUS = 2,
    BURST_DAMAGE_MULT = 0.25,
    BURST_SPREAD = 0.5,
    RADIUS = 6,
    RANGE = 20,
    COOLDOWN = 20,
    CRATER_DURATION = 12,
    MOMENTUM_COST = 30,
    -- Leaves room for weapon reach and target size inside RANGE.
    ARMED_ATTACK_RANGE = 16,
    LANDING_DISTANCE = { small = 2, default = 3, large = 4 },
}
TUNING.KIRITZUKA_DASH = {
    COOLDOWN = 12,
    -- Leaves room for weapon reach and target size, like the slam's.
    ARMED_ATTACK_RANGE = 12,
    -- How far each line runs out past the target's body on either side.
    RANGE = 5,
    -- How far to either side of the line the dash hits.
    WIDTH = 2.5,
    -- How far past the target's body the round trip at sea turns back.
    SEA_RANGE = 3,
    -- Scales the weapon's damage on each of the three stages.
    DAMAGE_MULT = { 1, 1, 2 },
}
TUNING.KIRITZUKA_FLURRY = {
    COOLDOWN = 10,
    -- Scales the weapon's damage on each of the ten hits.
    DAMAGE_MULT = 0.4,
    -- How far the images stand from the target's body, and how far round from her they can appear.
    IMAGE_DISTANCE = 1.2,
    IMAGE_ARC = 180,
}
TUNING.KIRITZUKA_WORM_BREAK = {
    -- Seconds inside the Great Depths Worm before breaking out, and the damage it does on the way.
    DELAY = 8,
    DAMAGE = 200,
    -- How hard she is thrown clear; the worm's own spit is 1.
    LAUNCH = 2,
    -- Chance she leaps out on her own feet instead of being thrown, and how far the leap goes.
    JUMP_CHANCE = 0.5,
    JUMP_DISTANCE = 4,
}
TUNING.KIRITZUKA_ARMOR_BREAK = {
    -- Extra damage per hit landed in a row on the same target.
    STEP = 0.05,
    MAX_STACKS = 10,
    -- Seconds without a hit before the stacks are lost.
    WINDOW = 5,
}
TUNING.KIRITZUKA_HOMERUN = {
    COOLDOWN = 10,
    -- Seconds to a full charge, and how long it can be held before it swings by itself.
    CHARGE_TIME = 1.5,
    MAX_HOLD = 4,
    RANGE = 3,
    ARC = 120,
    -- Each scales from an instant release to a full charge.
    DAMAGE_MULT = { 1, 4 },
    KNOCK_DISTANCE = { 2, 10 },
    -- Share of the knock distance that bigger targets actually travel.
    KNOCK_SCALE = { large = 0.5, epic = 0.25 },
}
TUNING.KIRITZUKA_COUNTER = {
    WINDOW = 1,
    -- Recovery after a stance that caught nothing.
    WHIFF_TIME = 0.5,
    COOLDOWN = 8,
    SUCCESS_COOLDOWN = 2,
    -- The swing scales the weapon's damage and adds a share of what was blocked.
    DAMAGE_MULT = 2,
    BLOCKED_DAMAGE_MULT = 0.5,
    MOMENTUM_GAIN = 15,
}
TUNING.KIRITZUKA_CRIT = {
    -- By momentum stage: calm, rise, surge, zenith.
    CHANCE = { 0.1, 0.15, 0.2, 0.25 },
    MULTIPLIER = { 1.5, 1.5, 1.5, 2 },
    -- Added to the chance by each hit that does not crit, until one does.
    CHANCE_STEP = 0.05,
    MOMENTUM_GAIN = 5,
    FX_COUNT = 3,
    -- How far along the line from player to target the fx appear.
    FX_TOWARD = 0.85,
}
TUNING.MOMENTUM = {
    MAX = 100,
    TICK = 0.5,
    SCAN_RADIUS = 30,
    SCAN_PERIOD = 0.5,
    GROUP_COUNT = 3,
    DAMAGE_CAP = 12,
    -- Passive gain rises toward a ceiling set by the surrounding threat.
    THREAT_GAIN = 4,
    CEILING_BASE = 15,
    CEILING_SLOPE = 20,
    THREAT_WEIGHTS = { low = 0.4, normal = 1, high = 3, keep = 6 },
    AREA_THREAT = 4,
    -- Gauge above the ceiling drains after a pause in combat activity.
    DECAY_DELAY = 6,
    DECAY_RATE = 8,
    SOFT_DECAY_RATE = 2,
    HIT_GAIN = { low = 1.5, normal = 2, high = 3, keep = 3 },
    KILL_GAIN = { low = 3, normal = 6, high = 20, keep = 30 },
    DAMAGED_SCALE = 250,
    DAMAGED_MAX = 40,
    CRITICAL_HEALTH = 0.01,
    CRITICAL_MULTIPLIERS = { 2, 4, 6, 8 },
    EFFECT_CAPS = { speed = 1.25 },
    STAGES = {
        { name = "calm", enter = 0, exit = 0, effects = {} },
        { name = "rise", enter = 25, exit = 18, effects = { damage = 1.1, slam_damage = 1.15 } },
        { name = "surge", enter = 55, exit = 45, effects = { damage = 1.3, slam_damage = 1.4, speed = 1.05 } },
        { name = "zenith", enter = 85, exit = 75, effects = { damage = 1.6, slam_damage = 1.8, speed = 1.1 } },
    },
    -- { health percent upper bound, multiplier at empty gauge, multiplier at full gauge }
    HEALTH_BANDS = {
        { 0.04, 1.91, 2.00 },
        { 0.13, 1.75, 1.91 },
        { 0.18, 1.66, 1.75 },
        { 0.26, 1.53, 1.66 },
        { 0.42, 1.49, 1.53 },
        { 0.49, 1.32, 1.49 },
        { 0.66, 1.24, 1.32 },
        { 0.75, 1.13, 1.24 },
        { 0.89, 1.09, 1.13 },
    },
    ENEMY_TAGS = {
        epic = "high",
        boss = "high",
        hostile = "normal",
        monster = "normal",
        shadowcreature = "normal",
    },
    ENEMY_PREFABS = {
        bearger = "high",
        stalker_atrium = "keep",
        frog = "normal",
    },
    AREA_TAGS = { Atrium = true, MushGnomeSpawnArea = true },
    AREA_IDS = { "Atrium", "MoonMush" },
}

local katana = ALL_KATANA[M_CONFIG.StartWeapon]

if katana then
    TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.MANUTSAWEE = {"tokijin", katana}
else
    TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.MANUTSAWEE = {"tokijin"}
end

TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.KIRITZUKA = {"baseballbat", "crowbar", "rebar"}
TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.INOUE = {}

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

    CROWBAR_DAMAGE = wilson_attack * 1.5,

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

if IA_ENABLED then
    tuning.MSURFBOARD_HEALTH = 300
    tuning.MSURFBOARD_SPEED = 4
end

for key, value in pairs(tuning) do
    if TUNING[key] then
        print("OVERRIDE: " .. key .. " in TUNING")
    end

    TUNING[key] = value
end
