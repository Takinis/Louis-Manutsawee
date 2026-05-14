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

function EntityScript:SetScale(scale)
    if self.Transform ~= nil then
        self.Transform:SetScale(scale, scale, scale)
    else

    end
end

function EntityScript:FollwerFx(fx, GUID, symbol, x, y, z)
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
        if self.Transform then
            self.Transform:SetScale(scale, scale, scale)
        else
            self.AnimState:SetScale(scale, scale, scale)
        end
    end
    return prefab
end


function EntityScript:IsTimerExists(inst, name)
    return self.inst.components.timer ~= nil and not self.inst.components.timer:TimerExists(name) or nil
end
