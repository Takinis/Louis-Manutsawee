local AddClassPostConstruct = AddClassPostConstruct
GLOBAL.setfenv(1, GLOBAL)

local TEMPLATES = require("widgets/redux/templates")

local function LoadModCharacterSkins(self, mod_characters)
    local prefabs = {}
    local seen = {}
    for _, character in ipairs(mod_characters) do
        local clothing = self.user_profile:GetSkinsForCharacter(character)
        for _, skin in ipairs({ character .. "_none", clothing and clothing.base or "" }) do
            local prefab = Prefabs[skin]
            if prefab ~= nil and prefab.base_prefab == character and not seen[skin] then
                seen[skin] = true
                table.insert(prefabs, skin)
            end
        end
    end
    if #prefabs > 0 then
        TheSim:LoadPrefabs(prefabs)
    end
end

local function PositionModPuppets(posse)
    local columns = math.min(#posse, 7)
    local rows = math.ceil(#posse / columns)
    local row_spacing = math.min(150, 300 / math.max(1, rows - 1))
    for i, puppet in ipairs(posse) do
        local row = math.floor((i - 1) / columns)
        local column = (i - 1) % columns
        local row_count = math.min(columns, #posse - row * columns)
        puppet:SetPosition(342 + (column - (row_count - 1) / 2) * 114,
            -150 + ((rows - 1) / 2 - row) * row_spacing)
        puppet:SetScale(1.8 * row_spacing / 150)
    end
end

AddClassPostConstruct("screens/redux/playersummaryscreen", function(self)
    local mod_characters = {}
    local seen = {}
    for _, prefab in ipairs(MODCHARACTERLIST) do
        if not seen[prefab] then
            seen[prefab] = true
            table.insert(mod_characters, prefab)
        end
    end
    if #mod_characters == 0 then
        return
    end

    local refresh_puppets = self._RefreshPuppets
    function self:_RefreshPuppets(...)
        -- Registration alone does not load static skin builds in the frontend.
        LoadModCharacterSkins(self, mod_characters)
        return refresh_puppets(self, ...)
    end
    self:_RefreshPuppets()

    local all_characters = self.character_list
    local strings = STRINGS.UI.PLAYERSUMMARYSCREEN
    local button = self.root:AddChild(TEMPLATES.StandardButton(nil, strings.M_MOD_CHARACTERS_ONLY, {220, 44}))
    button:SetPosition(500, 310)
    button:SetOnClick(function()
        local show_mods = self.character_list == all_characters
        self.character_list = show_mods and mod_characters or all_characters
        self.posse_root:Kill()
        self:_BuildPosse()
        -- Keep the rebuilt lineup above the background and behind the other controls.
        self.posse_root:MoveToBack()
        self.bg:MoveToBack()
        if show_mods then
            PositionModPuppets(self.posse)
        end
        self:_RefreshPuppets()
        button:SetText(show_mods and strings.M_SHOW_ALL_CHARACTERS or strings.M_MOD_CHARACTERS_ONLY)
    end)

    self.menu:SetFocusChangeDir(MOVE_UP, button)
    button:SetFocusChangeDir(MOVE_DOWN, self.menu)
end)
