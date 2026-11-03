-- Run from the mod directory: lua tests/momentum_badge.lua
local native_scripts = arg[1] or "../../data/databundles/scripts/"
package.path = "scripts/?.lua;" .. native_scripts .. "?.lua;" .. package.path
require("class")

math.clamp = function(v, lo, hi) return math.max(lo, math.min(hi, v)) end
BODYTEXTFONT, ANCHOR_MIDDLE = "font", 0
GLOBAL = _G
env = { is_mim_enabled = true }
ALL_KATANA, M_CONFIG = {}, {}
TUNING = { TOTAL_DAY_TIME = 480, GAMEMODE_STARTING_ITEMS = { DEFAULT = {} } }
dofile("main/tuning.lua")
STRINGS = dofile("strings/common.lua")

local calls = {}
local Meter = { GetAnimState = function() return { SetMultColour = function(_, ...) calls.tint = { ... } end } end }
local Text = Class(function(self)
    self.str = ""
end)
function Text:SetPosition() end
function Text:SetHAlign() end
function Text:SetString(s) self.str = s end
function Text:GetString() return self.str end
function Text:SetColour() end
package.loaded["widgets/text"] = Text
package.loaded["widgets/badge"] = Class(function(self, _, owner)
    self.owner = owner
    self.circular_meter = Meter
    self.inst = {
        ListenForEvent = function(_, event, fn, source)
            source.listeners = source.listeners or {}
            source.listeners[event] = fn
        end,
    }
end)
local Badge = package.loaded["widgets/badge"]
function Badge:AddChild(child) return child end
function Badge:Show() self.shown = true end
function Badge:Hide() self.shown = false end
function Badge:SetPercent(v, max) self.percent, self.max = v, max end
function Badge:PulseGreen() calls.pulse = (calls.pulse or 0) + 1 end
function Badge:StartWarning() calls.warning = true end
function Badge:StopWarning() calls.warning = false end

local MomentumBadge = dofile("scripts/widgets/momentumbadge.lua")
local owner = {
    net_momentum_value = { v = 0, value = function(self) return self.v end },
    net_momentum_stage = { v = 1, value = function(self) return self.v end },
}
local badge = MomentumBadge(owner)
assert(badge.shown == false, "Idle gauge is hidden")

local function Set(value, stage)
    owner.net_momentum_value.v, owner.net_momentum_stage.v = value, stage
    owner.listeners.momentumdirty()
end

Set(30, 2)
assert(badge.shown and badge.percent == 0.3 and badge.max == 100)
assert(badge.stagetext:GetString() == STRINGS.UI.KIRITZUKA_MOMENTUM.STAGE_RISE)
assert(calls.pulse == 1 and calls.warning == false)
Set(40, 2)
assert(calls.pulse == 1, "Same stage does not pulse")
Set(90, 4)
assert(calls.pulse == 2 and calls.warning == true)
assert(badge.stagetext:GetString() == STRINGS.UI.KIRITZUKA_MOMENTUM.STAGE_ZENITH)
Set(20, 2)
assert(calls.pulse == 2 and calls.warning == false, "Falling stage stops the warning without pulsing")
Set(0, 1)
assert(badge.shown == false)
print("PASS: momentum badge visibility, percent, stage text, pulses and warning")
