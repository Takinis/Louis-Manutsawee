local GetModConfigData = GetModConfigData
local ENV = env
GLOBAL.setfenv(1, GLOBAL)

M_CONFIG = {
    Locale = GetModConfigData("locale"),
    EnableSkill = GetModConfigData("enable_skill"),
    SkillControlMode = GetModConfigData("skill_control_mode"),
    SkillInputTimeout = GetModConfigData("skill_input_timeout"),
    SkillHoldTime = GetModConfigData("skill_hold_time"),
    EnableDodge = GetModConfigData("enable_dodge"),
    IsTatsujin = GetModConfigData("is_tatsujin"),

    IchimonjiCooldown = GetModConfigData("ichimonji_cooldown_time"),
    FlipCooldown = GetModConfigData("flip_cooldown_time"),
    ThrustCooldown = GetModConfigData("thrust_cooldown_time"),
    SoryuhaCooldown = GetModConfigData("soryuha_cooldown_time"),
    ImmortalSlashCooldown = GetModConfigData("immortalslash_cooldown_time"),
    IsshinCooldown = GetModConfigData("isshin_skill_cooldown_time"),
    RyusenSusanooCooldown = GetModConfigData("ryusen_and_susanoo_skill_cooldown_time"),

    MaxMindPower = GetModConfigData("max_mindpower"),
    RegenMindPowerCount = GetModConfigData("regen_mindpower_count"),
    RegenMindPowerRate = GetModConfigData("regen_mindpower_rate"),
    KenjutsuExpMultiple = GetModConfigData("kenjutsu_exp_multiple"),

    StartWeapon = GetModConfigData("start_weapon"),
    IdleAnimationMode = GetModConfigData("idle_animation_mode"),
}

IA_ENABLED = rawget(_G, "IA_CONFIG") ~= nil
-- Mods with the same priority load in name order, which follows the game language, so PL_CONFIG may not exist yet.
PL_ENABLED = rawget(_G, "PL_CONFIG") ~= nil
    or KnownModIndex:IsModEnabledAny("workshop-3322803908")
    or KnownModIndex:IsModEnabledAny("PorkLand")
AD_ENABLED = KnownModIndex:IsModEnabled("workshop-1847959350")
UM_ENABLED = KnownModIndex:IsModEnabledAny("workshop-2039181790")
HOF_ENABLED = KnownModIndex:IsModEnabled("workshop-2334209327")

ENV.PL_ENABLED = PL_ENABLED
