local function en_zh(en, zhs, zht)
    return (locale == "zh" or locale == "zhr") and zhs or (locale == "zht") and zht or en
end

name = en_zh("Louis Manutsawee", "露易丝 曼莎薇", "露易絲 曼莎薇")

folder_name = folder_name or "workshop-"
if not folder_name:find("workshop-") then
    name = name .. " - Dev"
end

version = "3.0"
description = "*" .. en_zh("Second Creation", "二次创作", "二次創作") .. "\n" ..
en_zh("- Original author：#ffffff", "原作者：ffffff", "原作者：ffffff")

author = "Sydney  " .. en_zh("Version：", "版本：", "版本：") .. version

forumthread = ""

api_version = 10
priority = -1

dst_compatible = true

dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false
all_clients_require_mod = true

mod_dependencies = {
    {
        workshop = "workshop-2521851770",    -- Glassic API
        ["GlassicAPI"] = false,
        ["Glassic API - DEV"] = false,
    },
}

icon_atlas = "images/modicon.xml"
icon = "modicon.tex"

server_filter_tags = {
    "M.louis",
    "Louis",
    "Manutsawee",
}

local options_enable = {
    {description = en_zh("Disabled", "关闭", "關閉"), data = false},
    {description = en_zh("Enabled", "开启", "開啟"), data = true},
}

local function AddTitle(title_en, title_zh, title_zht)
    return {name = en_zh(title_en, title_zh, title_zht) , options = {{description = "", data = false}}, default = false}
end

local function Tips(label)
	return { name = "", label = label, hover = "", options = { {description = "", data = false}, }, default = false, }
end


local skill_cooldown_options = {
    {description="5", data = 5},
    {description="10", data = 10},
    {description="20", data = 20},
    {description="30", data = 30},
    {description="40", data = 40},
    {description="Default(45)", data = 45},
    {description="50", data = 50},
    {description="60", data = 60},
    {description="120", data = 120},
    {description="180", data = 180},
    {description="240", data = 240},
    {description="300", data = 300},
    {description="360", data = 360},
}

local tier2_cooldown_options = {
    {description="50", data = 50},
    {description="60", data = 60},
    {description="Default(90)", data = 90},
    {description="120", data = 120},
    {description="150", data = 150},
    {description="180", data = 180},
    {description="240", data = 240},
    {description="300", data = 300},
    {description="360", data = 360},
}

local tier3_cooldown_options = {
    {description="90", data = 90},
    {description="120", data = 120},
    {description="150", data = 150},
    {description="180", data = 180},
    {description="Default(210)", data = 210},
    {description="240", data = 240},
    {description="300", data = 300},
    {description="360", data = 360},
}

local skill_input_timeout_options = {
    {description="0.3", data = 0.3},
    {description="0.5", data = 0.5},
    {description="0.8", data = 0.8},
    {description="1.0", data = 1.0},
    {description="1.5", data = 1.5},
}

local skill_hold_time_options = {
    {description="0.3", data = 0.3},
    {description="0.5", data = 0.5},
    {description="0.8", data = 0.8},
    {description="1.0", data = 1.0},
    {description="1.5", data = 1.5},
}

configuration_options = {
	AddTitle("Options", "设定", "設定"),
    {
        name = "locale",
        label = en_zh("Translation", "翻译", "翻譯"),
        hover = en_zh("Select a translation to enable it regardless of language packs. \n Note：Except for Chinese and English, the rest use Google Translate.", "选择翻译，而不是自动", "選擇翻譯，而不是自動"),
        options = {
            {description = en_zh("Auto", "自动", "自動"), data = false},
            {description = "Deutsch", data = "de"},
            {description = "Español", data = "es"},
            {description = "Français", data = "fr"},
            {description = "Italiano", data = "it"},
            {description = "한국어", data = "ko"},
            {description = "Polski", data = "pl"},
            {description = "Português", data = "pt"},
            {description = "Русский", data = "ru"},
            {description = "中文 (简体)", data = "sc"},
            {description = "中文 (繁体)", data = "tc"},
            {description = "中文 (粤语)", data = "ct"},
        },
        default = false,
    },
	{
        name = "start_weapon",
        label = en_zh("Start Weapon", "初始武器", "初始武器"),
        hover = en_zh("Choose a starting weapon for your girl!", "为你的少女选择初始武器！", "為你的少女選擇初始武器！"),
        options = {
            {description = en_zh("Nothing", "两手空空", "兩手空空"), data = false},
			{description = en_zh("Shinai", "竹刀", "竹刀"), data = "shinai"},
            {description = en_zh("Raikiri", "雷切", "雷切"), data = "raikiri"},
            {description = en_zh("Yasha", "夜叉", "夜叉"), data = "shirasaya"},
            {description = en_zh("Sakakura", "阪倉", "阪倉"), data = "koshirae"},
            {description = en_zh("hitokiri", "人斩", "人斬"), data = "hitokiri"},

            {description = en_zh("Raikiri The Lightning Cutter", "雷切·雷光斩", "雷切·雷光斬"), data = "true_raikiri"},
            {description = en_zh("Yasha The Demon Slayer", "夜叉·妖魔杀手", "夜叉·妖魔殺手"), data = "true_shirasaya"},
            {description = en_zh("Sakakura The Giant Slayers", "阪倉·巨人屠戮者", "阪倉·巨人屠戮者"), data = "true_koshirae"},
            {description = en_zh("Nihiru The Bloodseeker", "逆流·嗜血猎手", "逆流·嗜血獵手"), data = "true_hitokiri"},

			{description = en_zh("Mortal Blade", "拜泪·不死斩", "拜淚·不死斬"), data = "mortalblade"},
			{description = en_zh("Shusui", "秋水", "秋水"), data = "shusui"},
			{description = en_zh("Kage", "影", "影"), data = "kage"},
        },
        default = false,
    },
    {
        name = "idle_animation_mode",
        label = en_zh("Idle Animation", "空闲动画", "空閒動畫"),
        hover = en_zh("Default mode：Each skin has a separate idle animation. \n Random mode：Idle animations are played randomly.", "默认模式：每个皮肤都有单独的空闲动画 \n 随机模式：随机播放空闲动画", "預設模式：每個皮膚都有單獨的空閒動畫 \n 隨機模式：隨機播放空閒動畫"),
        options = {
            {description = en_zh("Default", "默认", "預設"), data = "Default"},
            {description = en_zh("Random", "随机", "隨機"), data = "Random"},
            {description = en_zh("Disable", "关闭", "關閉"), data = false},
        },
        default = "Default",
    },
    {
        name = "enable_dodge",
        label = en_zh("Dodge Ability", "闪避技能", "閃避技能"),
        hover = en_zh("Left click to dodge to the mouse direction.", "左键点击闪避到鼠标方向位置", "左鍵點擊閃避到滑鼠方向位置"),
        options = options_enable,
        default = true,
        -- default = false,
    },
	{
        name = "is_tatsujin",
        label = en_zh("Limiter", "限制器", "限制器"),
        hover = en_zh("This is the secret to being powerful!", "解除限制器，这就是强大的秘诀！", "解除限制器，這就是強大的秘訣！"),
        options = options_enable,
        default = true,
        -- default = false,
    },

    AddTitle("Custom Kenjutsu", "自定义剑术", "自訂劍術"),
    {
        name = "max_mindpower",
        label = en_zh("Set Mind  󰀈", "设置能量点 󰀈", "設定能量點 󰀈") ,
        hover = en_zh("Set Mind when start. level max + 50", "设置起始能量点, 最大50。", "設定起始能量點, 最大50。"),
        options = {
            {description="0", data = 0},
            {description="10", data = 10},
            {description="20", data = 20},
            {description="30", data = 30},
            {description="40", data = 40},
            {description="50", data = 50},
        },
        default = 0,
    },
	{
        name = "regen_mindpower_rate",
        label = en_zh("Mind 󰀈 Regen half of max / seccond ", "󰀈恢复最大的一半/秒", "󰀈恢復最大的一半/秒") ,
        hover = en_zh("Mind regenaration unlock level 4.", "心灵再生解锁4级", "心靈再生解鎖4級"),
        options = {
			{description="1", data = 1},
			{description="10", data = 10},
            {description="20", data = 20},
            {description="30", data = 30},
            {description="60", data = 60},
            {description="90", data = 90},
            {description="120", data = 120},
            {description="150", data = 150},
            {description="180", data = 180},
            {description="210", data = 210},
            {description="240", data = 240},
            {description="270", data = 270},
            {description="300", data = 300},
            {description="360", data = 360},
            {description="420", data = 420},
        },
        default = 1,
        -- default = 300,
    },
    {
        name = "regen_mindpower_count",
        label = en_zh("Mind  󰀈 Regen / hit", "每次攻击恢复心灵", "每次攻擊恢復心靈"),
        hover = en_zh("Mind regen/hit that attack with katana", "心灵恢复/用武士刀攻击该攻击", "心靈恢復/用武士刀攻擊該攻擊"),
        options = {
            {description="4", data = 4},
            {description="6", data = 6},
            {description="8", data = 8},
            {description="10", data = 10},
            {description="12", data = 12},
            {description="14", data = 14},
            {description="16", data = 16},
            {description="18", data = 18},
            {description="20", data = 20},
        },
        default = 10,
    },
	{
        name = "kenjutsu_exp_multiple",
        label = en_zh("Kenjutsu EXP Multiple", "剑术经验获取倍率", "劍術經驗獲取倍率"),
        hover = en_zh("fast Kenjutsu exp gain", "勤能补拙，风灵月影亦能！", "勤能補拙，風靈月影亦能！"),
        options = {
            {description="x1", data = 1},
            {description="x2", data = 2},
            {description="x3", data = 3},
            {description="x4", data = 4},
            {description="x5", data = 5},
            {description="x6", data = 6},
            {description="x7", data = 7},
            {description="x8", data = 8},
            {description="x9", data = 9},
            {description="x10", data = 10},
        },
        default = 1,
    },

    AddTitle("Kenjutsu 󰀈", "剑技 󰀈", "劍技 󰀈"),
	{
        name = "enable_skill",
        label = en_zh("Skill 󰀈", "角色技能 󰀈", "角色技能 󰀈"),
        hover = en_zh("Turn On or Off Character Skill.", "开启或者关闭角色技能", "開啟或者關閉角色技能") ,
        options = options_enable,
        default = true,
	},
    {
        name = "skill_control_mode",
        label = en_zh("Skill Control", "技能控制方案", "技能控制方案"),
        hover = en_zh("Choose how chained skills are triggered.", "选择后续剑技的触发方式。", "選擇後續劍技的觸發方式。"),
        options = {
            {description = en_zh("Key Combo", "按键组合", "按鍵組合"), data = "combo", hover = en_zh("Press a leading skill key, then press the next skill key.", "前置按键 + 后续按键。", "前置按鍵 + 後續按鍵。")},
            {description = en_zh("Key Sequence", "按键序列", "按鍵序列"), data = "sequence", hover = en_zh("Quickly press the same skill key again to advance the chain.", "快速重复按同一个按键推进连段。", "快速重複按同一個按鍵推進連段。")},
            {description = en_zh("Hold Key", "长按按键", "長按按鍵"), data = "hold", hover = en_zh("Hold a skill key to advance from the leading route.", "按住前置按键超过指定时间触发后续路由。", "按住前置按鍵超過指定時間觸發後續路由。")},
        },
        default = "combo",
    },
    {
        name = "skill_input_timeout",
        label = en_zh("Skill Input Timeout", "技能输入窗口", "技能輸入窗口"),
        hover = en_zh("Time allowed between chained skill inputs.", "连段输入之间允许的时间。", "連段輸入之間允許的時間。"),
        options = skill_input_timeout_options,
        default = 0.8,
    },
    {
        name = "skill_hold_time",
        label = en_zh("Skill Hold Time", "技能长按时间", "技能長按時間"),
        hover = en_zh("Hold duration needed to trigger the next route.", "长按触发后续路由所需时间。", "長按觸發後續路由所需時間。"),
        options = skill_hold_time_options,
        default = 0.5,
    },
	{
        name = "ichimonji_cooldown_time",
        label = en_zh("ICHIMONJI Cooldown time(s).", "一文字冷却时间", "一文字冷卻時間"),
        hover = en_zh("Set ICHIMONJI cooldown time.", "设置一文字冷却时间", "設定一文字冷卻時間"),
        options = skill_cooldown_options,
        default = 45,
    },
	{
        name = "flip_cooldown_time",
        label = en_zh("FLIP Cooldown time(s).", "翻斩冷却时间", "翻斬冷卻時間"),
        hover = en_zh("Set FLIP cooldown time.", "设置翻斩冷却时间", "設定翻斬冷卻時間"),
        options = skill_cooldown_options,
        default = 45,
    },
	{
        name = "thrust_cooldown_time",
        label = en_zh("THRUST Cooldown time(s).", "突刺冷却时间", "突刺冷卻時間"),
        hover = en_zh("Set THRUST cooldown time.", "设置突刺冷却时间", "設定突刺冷卻時間"),
        options = skill_cooldown_options,
        default = 45,
    },
    {
        name = "immortalslash_cooldown_time",
        label = en_zh("IMMORTAL SLASH Cooldown time(s).", "不死斩冷却时间", "不死斬冷卻時間"),
        hover = en_zh("Set IMMORTAL SLASH cooldown time.", "设置不死斩冷却时间", "設定不死斬冷卻時間"),
        options = skill_cooldown_options,
        default = 45,
    },
    {
        name = "soryuha_cooldown_time",
        label = en_zh("SORYUHA Cooldown time(s).", "苍龙破冷却时间", "雙龍破冷卻時間"),
        hover = en_zh("Set SORYUHA cooldown time.", "设置苍龙破冷却时间", "設定雙龍破冷卻時間"),
        options = skill_cooldown_options,
        default = 45,
    },
	{
        name = "isshin_skill_cooldown_time",
        label = en_zh("ISSHIN Cooldown time(s).", "一心冷却时间", "一心冷卻時間"),
        hover = en_zh("Set ISSHIN and HEAVENLYSTRIKE cooldown time.", "设置一心和天翔龙闪冷却时间", "設定一心和天翔龍閃冷卻時間"),
        options = tier2_cooldown_options,
        default = 90,
    },
	{
        name = "ryusen_and_susanoo_skill_cooldown_time",
        label = en_zh("RYUSEN/SUSANOO Cooldown time(s).", "龙闪/须佐冷却时间", "龍閃/須佐冷卻時間"),
        hover = en_zh("Set RYUSEN and SUSANOO cooldown time.", "设置龙闪和须佐冷却时间", "設定龍閃和須佐冷卻時間"),
        options = tier3_cooldown_options,
        default = 210,
    },
}
