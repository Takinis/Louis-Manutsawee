local Curseditem = require("components/curseditem")
GLOBAL.setfenv(1, GLOBAL)

-- FindClosestPlayerInRangeSq, passing over those a curse cannot touch.
local function FindClosestCursablePlayer(x, y, z, rangesq)
    local closest = nil
    local closest_distsq = rangesq
    for _, player in ipairs(AllPlayers) do
        if not player:HasTag("monkeycurse_immune") and not IsEntityDeadOrGhost(player) and player.entity:IsVisible() then
            local distsq = player:GetDistanceSqToPoint(x, y, z)
            if distsq < closest_distsq then
                closest, closest_distsq = player, distsq
            end
        end
    end
    return closest
end

-- The native search only ever considers the nearest player, so an immune one would shield the rest.
function Curseditem:lookforplayer()
    if self.inst.findplayertask then
        self.inst.findplayertask:Cancel()
        self.inst.findplayertask = nil
    end

    self.inst.findplayertask = self.inst:DoPeriodicTask(1, function()
        local x, y, z = self.inst.Transform:GetWorldPosition()
        local player = FindClosestCursablePlayer(x, y, z, 10 * 10)

        if player and not self:checkplayersinventoryforspace(player) then
            player = nil
        end

        if player and player.components.cursable and player.components.cursable:IsCursable(self.inst)
            and not player.components.debuffable:HasDebuff("spawnprotectionbuff") then
            if self.inst.findplayertask then
                self.inst.findplayertask:Cancel()
                self.inst.findplayertask = nil
            end

            self.target = player
            self.starttime = GetTime()
            self.startpos = Vector3(self.inst.Transform:GetWorldPosition())
        end
    end)
end

local _Given = Curseditem.Given
function Curseditem:Given(item, data)
    local player = data.owner
    if player ~= nil and player.components.cursable ~= nil and player:HasTag("monkeycurse_immune") then
        self.target = nil
        return
    end

    _Given(self, item, data)
end
