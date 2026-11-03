local AddComponentPostInit = AddComponentPostInit
GLOBAL.setfenv(1, GLOBAL)

local function BlockBurnDamage()
    return true
end

local function NoGrogginess()
end

local function IsGuardedFromAllSources(self, inst)
    local guarded = false
    for source in pairs(self.sources) do
        if source:IsValid() and source.sg ~= nil and source.sg:HasStateTag("supernovaburning") then
            local x, _, z = source.Transform:GetWorldPosition()
            if not inst:ParrySustained(x, z) then
                return false
            end
            guarded = true
        end
    end
    return guarded
end

AddComponentPostInit("lunarsupernovaburning", function(self, inst)
    if inst.ParrySustained == nil then
        return
    end

    local _OnUpdate = self.OnUpdate
    function self:OnUpdate(dt)
        if not IsGuardedFromAllSources(self, inst) then
            return _OnUpdate(self, dt)
        end
        -- The burn still runs so its fx stay on; only what it would do to the player is held back.
        local health = inst.components.health
        local grogginess = inst.components.grogginess
        local _redirect = health.redirect
        health.redirect = BlockBurnDamage
        if grogginess ~= nil then
            grogginess.MaximizeGrogginess = NoGrogginess
        end
        _OnUpdate(self, dt)
        health.redirect = _redirect
        if grogginess ~= nil then
            grogginess.MaximizeGrogginess = nil
        end
    end
end)
