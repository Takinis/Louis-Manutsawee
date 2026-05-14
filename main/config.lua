local GetModConfigData = GetModConfigData
local ENV = env
GLOBAL.setfenv(1, GLOBAL)

M_CONFIG = {
    Locale = GetModConfigData("locale"),
    EnableSkill = GetModConfigData("enable_skill"),
    EnableDodge = GetModConfigData("dodge_enable"),
    IsTatsujin = GetModConfigData("is_tatsujin"),

    CounterAtkCooldown = GetModConfigData("counter_attack_cooldown_time"),
    IchimonjiCooldown = GetModConfigData("ichimonji_cooldown_time"),
    FlipCooldown = GetModConfigData("flip_cooldown_time"),
    ThrustCooldown = GetModConfigData("thrust_cooldown_time"),
    SoryuhaCooldown = GetModConfigData("soryuha_cooldown_time"),
    IsshinCooldown = GetModConfigData("isshin_skill_cooldown_time"),
    RyusenSusanooCooldown = GetModConfigData("ryusen_and_susanoo_skill_cooldown_time"),

    IchimonjiKey = GetModConfigData("ichimonji_key"),
    FlipKey = GetModConfigData("flip_key"),
    ThrustKey = GetModConfigData("thrust_key"),
    SoryuhaKey = GetModConfigData("soryuha_key"),
    LevelCheckKey = GetModConfigData("level_check_key"),
    PutGlassesKey = GetModConfigData("put_glasses_key"),
    ChangeHairStyleKey = GetModConfigData("change_hair_style_key"),
    SkillCancelKey = GetModConfigData("skill_cancel_key"),
    CounterAttackKey = GetModConfigData("counter_attkack_key"),
    QuickSheathKey = GetModConfigData("quick_sheath_key"),

    MaxMindPower = GetModConfigData("max_mindpower"),
    RegenMindPowerCount = GetModConfigData("regen_mindpower_count"),
    RegenMindPowerRate = GetModConfigData("regen_mindpower_rate"),
    KenjutsuExpMultiple = GetModConfigData("kenjutsu_exp_multiple"),

    StartWeapon = GetModConfigData("start_weapon"),
    IdleAnimationMode = GetModConfigData("idle_animation_mode"),
}

IA_ENABLED = rawget(_G, "IA_CONFIG") ~= nil
PL_ENABLED = rawget(_G, "PL_CONFIG") ~= nil
AD_ENABLED = KnownModIndex:IsModEnabled("workshop-1847959350")
UM_ENABLED = KnownModIndex:IsModEnabled("workshop-2039181790")
HOF_ENABLED = KnownModIndex:IsModEnabled("workshop-2334209327")
