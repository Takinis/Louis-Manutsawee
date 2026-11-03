local ENV = env
local MomentumBadge = require("widgets/momentumbadge")
GLOBAL.setfenv(1, GLOBAL)

ENV.AddClassPostConstruct("widgets/statusdisplays", function(self, owner)
    if owner.prefab ~= "kiritzuka" or owner.net_momentum_value == nil then
        return
    end

    self.momentumbadge = self:AddChild(MomentumBadge(owner))
    self.momentumbadge:SetPosition(self.column5, 20, 0)
end)
