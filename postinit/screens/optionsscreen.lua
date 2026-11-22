local AddClassPostConstruct = AddClassPostConstruct
GLOBAL.setfenv(1, GLOBAL)

-- Adds the mod character keys to Options > Controls, below the native keyboard controls.
-- Rows mirror OptionsScreen:_BuildControlGroup and follow the screen's apply / revert / reset flow.

local Widget = require("widgets/widget")
local Text = require("widgets/text")
local Image = require("widgets/image")
local ImageButton = require("widgets/imagebutton")
local PopupDialogScreen = require("screens/redux/popupdialog")
local TEMPLATES = require("widgets/redux/templates")
local Keybinds = require("utils/keybinds")

-- Same layout values as the native controls tab.
local BUTTON_X = -371
local LABEL_WIDTH = 375
local BUTTON_WIDTH = 250
local BUTTON_HEIGHT = 48
local SPACING = 15

local CONFLICT_COLOUR = { 0.9, 0.35, 0.3, 1 }

local function IsBindChanged(self, name)
    return self.m_keybinds_working[name] ~= self.m_keybinds_saved[name]
end

local function HasConflict(self, name)
    local key = self.m_keybinds_working[name]
    if not key then
        return false
    end

    local group = Keybinds.GetGroup(name)
    for other, other_key in pairs(self.m_keybinds_working) do
        if other ~= name and other_key == key and Keybinds.GetGroup(other) == group then
            return true
        end
    end
    return false
end

local function GetSkillControlMode()
    local config = rawget(_G, "M_CONFIG")
    return config ~= nil and config.SkillControlMode or "combo"
end

local function RefreshKeybindRows(self)
    local control_mode = GetSkillControlMode()
    for _, row in ipairs(self.m_hint_rows) do
        row.hint:SetString(Keybinds.FormatHint(row.m_hint, self.m_keybinds_working, control_mode))
    end

    for _, row in ipairs(self.m_keybind_rows) do
        local name = row.m_keybind
        row.binding_btn:SetText(Keybinds.GetKeyName(self.m_keybinds_working[name]))
        row.label:SetColour(HasConflict(self, name) and CONFLICT_COLOUR or UICOLOURS.GOLD_UNIMPORTANT)

        if IsBindChanged(self, name) then
            row.changed_image:Show()
        else
            row.changed_image:Hide()
        end
    end
end

local function SetWorkingBind(self, name, key)
    if self.m_keybinds_working[name] == key then
        return
    end

    self.m_keybinds_working[name] = key
    RefreshKeybindRows(self)
    self:UpdateMenu()
end

local function MapKeybind(self, row)
    local name = row.m_keybind
    local default_text = string.format(STRINGS.UI.CONTROLSSCREEN.DEFAULT_CONTROL_TEXT, Keybinds.GetKeyName(Keybinds.GetDefault(name)))
    local popup = PopupDialogScreen(row.controlName, STRINGS.UI.CONTROLSSCREEN.CONTROL_SELECT .. "\n\n" .. default_text, {})
    popup.dialog.body:SetPosition(0, 0)

    -- Swallow controls while waiting, so the key that is picked never reaches the options screen.
    popup.OnControl = function() return true end

    -- Only accept a key that was pressed while the popup was up; the key that opened it is ignored.
    local pressed = {}
    local done = false
    popup.OnRawKey = function(_, key, down)
        if done then
            return true
        end

        if down then
            pressed[key] = true
            return true
        elseif not pressed[key] then
            return true
        end

        done = true
        if key ~= KEY_ESCAPE then
            SetWorkingBind(self, name, key)
        end
        TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")

        -- Pop a frame later so the release does not reach the options screen as a cancel.
        self.inst:DoTaskInTime(0, function()
            if TheFrontEnd:GetActiveScreen() == popup then
                TheFrontEnd:PopScreen(popup)
            end
            row.binding_btn:SetFocus()
        end)
        return true
    end

    TheFrontEnd:PushScreen(popup)
end

local function BuildHeader(group_id)
    local header = Widget("m_keybind_header_" .. group_id)
    header.control = {}

    header.title = header:AddChild(Text(HEADERFONT, 28))
    header.title:SetString(Keybinds.GetGroupTitle(group_id))
    header.title:SetColour(UICOLOURS.GOLD_SELECTED)
    header.title:SetRegionSize(700, BUTTON_HEIGHT)
    header.title:SetPosition(-60, 0)

    header.underline = header:AddChild(Image("images/frontend_redux.xml", "achievements_divider_top.tex"))
    header.underline:SetScale(0.4, 0.5)
    header.underline:SetPosition(-60, -18)

    return header
end

local function BuildBindRow(self, name)
    local row = Widget("m_keybind_" .. name)
    row.bg = row:AddChild(TEMPLATES.ListItemBackground(700, BUTTON_HEIGHT))
    row.bg:SetPosition(-60, 0)
    row.bg:SetScale(1.025, 1)
    row:SetScale(1, 1, 0.75)

    -- Keep native RefreshControls from treating this row as an engine control.
    row.control = {}
    row.m_keybind = name
    row.controlName = Keybinds.GetLabel(name)

    local x = BUTTON_X
    row.label = row:AddChild(Text(CHATFONT, 28))
    row.label:SetString(row.controlName)
    row.label:SetHAlign(ANCHOR_LEFT)
    row.label:SetColour(UICOLOURS.GOLD_UNIMPORTANT)
    row.label:SetRegionSize(LABEL_WIDTH, 50)
    x = x + LABEL_WIDTH / 2
    row.label:SetPosition(x, 0)
    x = x + LABEL_WIDTH / 2 + SPACING
    row.label:SetClickable(false)

    x = x + BUTTON_WIDTH / 2
    row.changed_image = row:AddChild(Image("images/global_redux.xml", "wardrobe_spinner_bg.tex"))
    row.changed_image:SetTint(1, 1, 1, 0.3)
    row.changed_image:ScaleToSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    row.changed_image:SetPosition(x, 0)
    row.changed_image:Hide()

    row.binding_btn = row:AddChild(ImageButton("images/global_redux.xml", "blank.tex", "spinner_focus.tex"))
    row.binding_btn:ForceImageSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    row.binding_btn:SetTextColour(UICOLOURS.GOLD_CLICKABLE)
    row.binding_btn:SetTextFocusColour(UICOLOURS.GOLD_FOCUS)
    row.binding_btn:SetFont(CHATFONT)
    row.binding_btn:SetDisabledFont(CHATFONT)
    row.binding_btn:SetTextSize(30)
    row.binding_btn:SetPosition(x, 0)
    row.binding_btn:SetHelpTextMessage(STRINGS.UI.CONTROLSSCREEN.CHANGEBIND)
    row.binding_btn:SetOnClick(function()
        MapKeybind(self, row)
    end)
    x = x + BUTTON_WIDTH / 2 + SPACING

    row.unbinding_btn = row:AddChild(ImageButton("images/global_redux.xml", "close.tex", "close.tex"))
    row.unbinding_btn:SetOnClick(function()
        SetWorkingBind(self, name, false)
    end)
    row.unbinding_btn:SetPosition(x - 5, 0)
    row.unbinding_btn:SetScale(0.4, 0.4)
    row.unbinding_btn:SetHoverText(STRINGS.UI.CONTROLSSCREEN.UNBIND)

    row.focus_forward = row.binding_btn

    return row
end

-- Shows how a chained skill is entered; it follows the bound keys and cannot be edited.
local function BuildHintRow(hint)
    local row = Widget("m_keybind_hint_" .. hint.name)
    row.bg = row:AddChild(TEMPLATES.ListItemBackground(700, BUTTON_HEIGHT))
    row.bg:SetPosition(-60, 0)
    row.bg:SetScale(1.025, 1)
    row:SetScale(1, 1, 0.75)

    row.control = {}
    row.m_hint = hint

    local x = BUTTON_X
    row.label = row:AddChild(Text(CHATFONT, 28))
    row.label:SetString(Keybinds.GetLabel(hint.name))
    row.label:SetHAlign(ANCHOR_LEFT)
    row.label:SetColour(UICOLOURS.GOLD_UNIMPORTANT)
    row.label:SetRegionSize(LABEL_WIDTH, 50)
    x = x + LABEL_WIDTH / 2
    row.label:SetPosition(x, 0)
    x = x + LABEL_WIDTH / 2 + SPACING
    row.label:SetClickable(false)

    x = x + BUTTON_WIDTH / 2
    row.hint = row:AddChild(Text(CHATFONT, 30))
    row.hint:SetColour(UICOLOURS.GOLD_UNIMPORTANT)
    row.hint:SetRegionSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    row.hint:SetPosition(x, 0)
    row.hint:SetClickable(false)

    return row
end

AddClassPostConstruct("screens/redux/optionsscreen", function(self)
    -- Console layouts have no keyboard control list.
    if self.kb_controlwidgets == nil or self.kb_controllist == nil then
        return
    end

    self.m_keybinds_saved = Keybinds.GetAll()
    self.m_keybinds_working = Keybinds.GetAll()
    self.m_keybind_rows = {}
    self.m_hint_rows = {}

    local first_new = #self.kb_controlwidgets + 1
    for _, group in ipairs(Keybinds.GROUPS) do
        table.insert(self.kb_controlwidgets, BuildHeader(group.id))
        for _, bind in ipairs(group.binds) do
            local row = BuildBindRow(self, bind.name)
            table.insert(self.kb_controlwidgets, row)
            table.insert(self.m_keybind_rows, row)
            row.binding_btn.idx = #self.kb_controlwidgets
        end
        for _, hint in ipairs(group.hints or {}) do
            local row = BuildHintRow(hint)
            table.insert(self.kb_controlwidgets, row)
            table.insert(self.m_hint_rows, row)
        end
    end

    for i = first_new, #self.kb_controlwidgets do
        self.kb_controllist:AddChild(self.kb_controlwidgets[i])
    end
    self.kb_controllist:SetList(self.kb_controlwidgets, true)
    RefreshKeybindRows(self)

    local _IsDirty = self.IsDirty
    function self:IsDirty(...)
        if _IsDirty(self, ...) then
            return true
        end

        -- The base constructor calls UpdateMenu before our state exists.
        if self.m_keybinds_working == nil then
            return false
        end

        for name in pairs(self.m_keybinds_working) do
            if IsBindChanged(self, name) then
                return true
            end
        end
        return false
    end

    local _Save = self.Save
    function self:Save(...)
        Keybinds.SetAll(self.m_keybinds_working)
        self.m_keybinds_saved = Keybinds.GetAll()
        RefreshKeybindRows(self)
        return _Save(self, ...)
    end

    local _RevertChanges = self.RevertChanges
    function self:RevertChanges(...)
        self.m_keybinds_working = Keybinds.GetAll()
        return _RevertChanges(self, ...)
    end

    local _LoadDefaultControls = self.LoadDefaultControls
    function self:LoadDefaultControls(...)
        self.m_keybinds_working = Keybinds.GetDefaults()
        return _LoadDefaultControls(self, ...)
    end

    local _RefreshControls = self.RefreshControls
    function self:RefreshControls(...)
        local result = _RefreshControls(self, ...)
        RefreshKeybindRows(self)
        return result
    end

    self:UpdateMenu()
end)
