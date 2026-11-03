local Badge = require "widgets/badge"
local Text = require "widgets/text"

local TINTS = {
    { 0.55, 0.55, 0.6, 1 },
    { 0.95, 0.8, 0.35, 1 },
    { 0.95, 0.5, 0.2, 1 },
    { 0.9, 0.15, 0.15, 1 },
}

local function OnMomentumDirty(inst, self)
    self:Refresh()
end

local MomentumBadge = Class(Badge, function(self, owner)
    Badge._ctor(self, nil, owner, TINTS[1], nil, true, nil, true)

    self.stage = 1
    self.stagetext = self:AddChild(Text(BODYTEXTFONT, 20))
    self.stagetext:SetPosition(0, -48, 0)
    self.stagetext:SetHAlign(ANCHOR_MIDDLE)

    self.inst:ListenForEvent("momentumdirty", function() OnMomentumDirty(self.inst, self) end, owner)
    self:Refresh()
end)

function MomentumBadge:GetStageString(stage)
    local name = TUNING.MOMENTUM.STAGES[stage].name
    return STRINGS.UI.KIRITZUKA_MOMENTUM["STAGE_" .. string.upper(name)]
end

function MomentumBadge:Refresh()
    local owner = self.owner
    local value = owner.net_momentum_value:value()
    local stage = math.clamp(owner.net_momentum_stage:value(), 1, #TINTS)

    -- Idle gauge stays out of the way; it appears with the first point of momentum.
    if value <= 0 then
        self:Hide()
    else
        self:Show()
    end

    self:SetPercent(value / TUNING.MOMENTUM.MAX, TUNING.MOMENTUM.MAX)

    if stage ~= self.stage then
        local rising = stage > self.stage
        self.stage = stage
        self.circular_meter:GetAnimState():SetMultColour(unpack(TINTS[stage]))
        self.stagetext:SetString(self:GetStageString(stage))
        self.stagetext:SetColour(unpack(TINTS[stage]))
        if rising then
            self:PulseGreen()
        end
        if stage == #TINTS then
            self:StartWarning(unpack(TINTS[stage]))
        else
            self:StopWarning()
        end
    elseif self.stagetext:GetString() == "" then
        self.stagetext:SetString(self:GetStageString(stage))
    end
end

return MomentumBadge
