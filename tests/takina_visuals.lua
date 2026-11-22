-- Run from the mod directory: lua tests/takina_visuals.lua
package.path = "scripts/?.lua;" .. package.path
hash = function(value) return value end
local Visuals = require("utils/takinavisuals")

local inst = { bank = "wilson", build = "takina", tasks = {}, scales = { other = 0.9, takina_visuals = 1.08 } }
inst.AnimState = {
    GetBankHash = function() return inst.bank end,
    SetBank = function(_, bank) inst.bank = bank; inst.bank_writes = (inst.bank_writes or 0) + 1 end,
    GetSkinBuild = function() return inst.skin_build end,
    GetBuild = function() return inst.build end,
    PlayAnimation = function() error("Changing the bank must not restart animations") end,
    SetScale = function() error("UI previews must not mutate AnimState scale") end,
}
function inst:HasTag(tag) return tag == "playerghost" and self.ghost or false end
function inst:DoPeriodicTask(_, fn)
    table.insert(self.tasks, fn)
    return { fn = fn }
end
function inst:ApplyAnimScale(source, scale)
    self.scales[source] = scale ~= 1 and scale or nil
    self.scale = 1
    for _, value in pairs(self.scales) do self.scale = self.scale * value end
end
local function Tick() for _, fn in ipairs(inst.tasks) do fn(inst) end end

Visuals.Attach(inst)
assert(inst.bank == "takina_player")
assert(inst.scale == 0.9 and inst.scales.takina_visuals == nil)
Visuals.Attach(inst)
for _ = 1, 20 do Tick() end
assert(#inst.tasks == 1 and inst.bank_writes == 1)
assert(inst.scale == 0.9, "No extra or accumulated scaling")

inst.bank = "wilson_sitting"
Tick()
assert(inst.bank == "wilson_sitting", "Temporary stategraph banks are preserved")
inst.bank = "wilson"
Tick()
assert(inst.bank == "takina_player", "Native state exits restore the Takina bank")

inst.ghost, inst.bank, inst.skin_build = true, "ghost", "ghost_manutsawee_build"
Tick()
assert(inst.bank == "ghost" and inst.scale == 0.9, "Ghost uses its native bank and no Takina scale")
inst.ghost, inst.bank, inst.skin_build = false, "wilson", "takina"
Tick()
assert(inst.bank == "takina_player" and inst.scales.takina_visuals == nil)

inst.skin_build = "inoue"
Tick()
assert(inst.bank == "wilson" and inst.scale == 0.9, "Changing skin removes only the Takina modifier")

Visuals.ApplyPreview(inst.AnimState, "takina")
assert(inst.bank == "takina_player")
Visuals.ApplyPreview(inst.AnimState, "inoue")
assert(inst.bank == "wilson")
for _ = 1, 5 do
    Visuals.ApplyPreview(inst.AnimState, "takina")
    Visuals.ApplyPreview(inst.AnimState, "wilson")
    assert(inst.bank == "wilson", "Reused puppets must restore the native bank without rescaling")
end

-- Client instances do not have the master's scale helper.
inst.ApplyAnimScale = nil
inst.skin_build, inst.bank = "takina", "wilson"
Visuals.Refresh(inst, "takina")
assert(inst.bank == "takina_player")
print("takina visuals: scale, bank recovery, ghost, skin changes, preview and client paths passed")
