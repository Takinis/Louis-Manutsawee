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
