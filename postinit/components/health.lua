local Health = require("components/health")
GLOBAL.setfenv(1, GLOBAL)

-- Immortal Slash scar: no healing until it fades.
local _DoDelta = Health.DoDelta
function Health:DoDelta(amount, ...)
    local scar_until = self.inst.immortalslash_scar_until
    if scar_until ~= nil and amount ~= nil and amount > 0 then
        if GetTime() < scar_until then
            return 0
        end
        self.inst.immortalslash_scar_until = nil
    end
    return _DoDelta(self, amount, ...)
end
