GLOBAL.setfenv(1, GLOBAL)

if not rawget(EntityScript, "GetEventCallbacks") then
    function EntityScript:GetEventCallbacks(event, source, source_file)
        source = source or self

        assert(self.event_listening[event] and self.event_listening[event][source])

        for _, fn in ipairs(self.event_listening[event][source]) do
            if source_file then
                local info = debug.getinfo(fn, "S")
                if info and info.source == source_file then
                    return fn
                end
            else
                return fn
            end
        end
    end
end

EntityScript.SetTag = EntityScript.AddOrRemoveTag

function EntityScript:SetComponent(name, condition)
    if condition then
        self:AddComponent(name)
    end
end

function EntityScript:GetHandsEquip()
    return self.components.inventory ~= nil and self.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
end

function EntityScript:GetBodyEquip()
    return self.components.inventory ~= nil and self.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY) or nil
end

function EntityScript:GetHeadEquip()
    return self.components.inventory ~= nil and self.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD) or nil
end

--[[

Mainly used for multiple component judgments, just looks more beautiful :D

]]

function EntityScript:HasComponent(cmp)
    return self.components[cmp]
end

function EntityScript:HasAllComponents(...)
    for i = 1, select("#", ...) do
        local cmp = select(i, ...)
        if not self:HasComponent(cmp) then
            return false
        end
    end
    return true
end

function EntityScript:HasAnyComponent(...)
    for i = 1, select("#", ...) do
        local cmp = select(i, ...)
        if self:HasComponent(cmp) then
            return true
        end
    end
    return false
end

function EntityScript:HasComponents(...)
    local cmps = select(1, ...)
    if type(cmps) == "table" then
        return self:HasAllComponents(unpack(cmps))
    else
        return self:HasAllComponents(...)
    end
end

function EntityScript:HasOneOfComponents(...)
    local cmps = select(1, ...)
    if type(cmps) == "table" then
        return self:HasAnyComponent(unpack(cmps))
    else
        return self:HasAnyComponent(...)
    end
end

function EntityScript:SetScale(scale)
    if self.Transform ~= nil then
        self.Transform:SetScale(scale, scale, scale)
    end
end

local i = 1
function EntityScript:FollwerFx(fx, GUID, symbol, x, y, z)
    print("EntityScript:FollwerFx: ", fx .. tostring(i))
    i = i + 1
    if type(fx) == "string" then
        fx = SpawnPrefab(fx)
    end
    if checkentity(fx) then
        fx.entity:AddFollower()
        fx.Follower:FollowSymbol(GUID or self.GUID, symbol or "swap_body", x or 0, z or 0, y or 0)
        return fx
    end
end

function EntityScript:SpawnPrefabInPos(prefab, scale)
    local prefab = SpawnPrefab(prefab)
    prefab.Transform:SetPosition(self:GetPosition():Get())
    if scale ~= nil then
        self:SetSacle(scale)
    end
    return prefab
end


function EntityScript:IsTimerExists(inst, name)
    return self.inst.components.timer ~= nil and not self.inst.components.timer:TimerExists(name) or nil
end
