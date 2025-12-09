local AddModCharacter = AddModCharacter
GLOBAL.setfenv(1, GLOBAL)

local skin_modes = {{
    type = "ghost_skin",
    anim_bank = "ghost",
    idle_anim = "idle",
    scale = 0.75,
    offset = {0, -25}
}}

AddModCharacter("manutsawee", "FEMALE", skin_modes)
-- AddModCharacter("kiritzuka", "FEMALE", skin_modes)
-- AddModCharacter("inoue", "FEMALE", skin_modes)
-- AddModCharacter("Iraiza", "FAMALE", skin_modes)
