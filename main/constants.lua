local FOODTYPE = GLOBAL.FOODTYPE
local ENV = env
GLOBAL.setfenv(1, GLOBAL)

-- when MiM enabled, add it
if ENV.is_mim_enabled then
    local video_urls = {
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        "https://www.youtube.com/watch?v=zXglsI9oH18",
        "https://www.nicovideo.jp/watch/sm2057168",
        "https://www.bilibili.com/video/BV1xx411c7mu",
        "https://www.bilibili.com/video/BV1SG4y1274y",
        "https://manutsawee.blog",
    }
    -- No animation video
    CHARACTER_VIDEOS["manutsawee"] = {GetRandomItem(video_urls)}
end

ALL_KATANA = {}

SKILL_ID = {
    ICHIMONJI = "ichimonji",
    FLIP = "flip",
    THRUST = "thrust",
    ISSHIN = "isshin",
    HEAVENLYSTRIKE = "heavenlystrike",
    RYUSEN = "ryusen",
    SUSANOO = "susanoo",
    SORYUHA = "soryuha",
}

SKILL_INPUT = {
    ICHIMONJI = SKILL_ID.ICHIMONJI,
    FLIP = SKILL_ID.FLIP,
    THRUST = SKILL_ID.THRUST,
    SORYUHA = SKILL_ID.SORYUHA,
}

SG_STATE = {
    ICHIMONJI = SKILL_ID.ICHIMONJI,
    FLIP = SKILL_ID.FLIP,
    THRUST = SKILL_ID.THRUST,
    HEAVENLYSTRIKE = SKILL_ID.HEAVENLYSTRIKE,
    RYUSEN = SKILL_ID.RYUSEN,
    SORYUHA = SKILL_ID.SORYUHA,
    HABAKIRI = "habakiri",
    MONEMIND = "monemind",
}

UNLOCK_LEVEL = {
    ICHIMONJI_INPUT = 1,
    FLIP_INPUT = 3,
    THRUST_INPUT = 4,
    HEAVENLYSTRIKE = 5,
    ISSHIN = 6,
    RYUSEN = 7,
    SUSANOO = 8,
    SORYUHA = 10,
}

INPUT_COOLDOWN = {
    ICHIMONJI = "ichimonji_key_cd",
    FLIP = "flip_key_cd",
    THRUST = "thrust_key_cd",
    SORYUHA = "soryuha_key_cd",
}
