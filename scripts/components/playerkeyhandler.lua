local PlayerKeyHandler = Class(function(self, inst)
    self.inst = inst
    self.handlers = {}
end)

local function IsActiveHUDScreen()
    local screen = TheFrontEnd and TheFrontEnd:GetActiveScreen()
    return screen ~= nil and screen.name == "HUD"
end

function PlayerKeyHandler:HandleKeyAction(namespace, action, ...)
    if IsActiveHUDScreen() then
        if TheWorld.ismastersim then
            local fn = GetModRPCHandler(namespace, action)
            if fn ~= nil then
                fn(self.inst, ...)
            end
        else
            SendModRPCToServer(GetModRPC(namespace, action), ...)
        end
        return true
    end
    return false
end

function PlayerKeyHandler:AddKeyListener(namespace, key, action)
    local fn = function(_key, down)
        if down and key == _key then
            for k, _ in pairs(TheInput.pressed_keys) do
                if k ~= key then
                    return false
                end
            end
            return self:HandleKeyAction(namespace, action) or false
        end
    end
    -- Still call AddSpecialKeyHandler to ensure TheInput.special_keys is updated if needed by the mod
    TheInput:AddSpecialKeyHandler(key, fn)
    table.insert(self.handlers, {event = "onspecialkey", fn = fn, processor = TheInput.onspecialkey})
end

function PlayerKeyHandler:AddCombinationKeyListener(namespace, key, _key, action)
    local fn = function(k1, k2)
        self:HandleKeyAction(namespace, action)
    end
    TheInput:AddCombinationKeyHandler(key, _key, fn)
    
    local keys = { key, _key }
    table.sort(keys)
    local event = keys[1] .. "_" .. keys[2]
    table.insert(self.handlers, {event = event, fn = fn, processor = TheInput.onkeycombo})
end

function PlayerKeyHandler:AddSequentialKeyHandler(namespace, key, _key, action)
    local fn = function(k1, k2)
        self:HandleKeyAction(namespace, action)
    end
    TheInput:AddSequentialKeyHandler(key, _key, fn)

    local event_name = "seq_" .. tostring(key) .. "_" .. tostring(_key)
    table.insert(self.handlers, {event = event_name, fn = fn, processor = TheInput.onkeysequence})
end

function PlayerKeyHandler:OnRemoveEntity()
    for _, handler in ipairs(self.handlers) do
        if handler.processor and handler.processor.RemoveEventHandler then
            handler.processor:RemoveEventHandler(handler.event, handler.fn)
        end
    end
    self.handlers = {}
end

PlayerKeyHandler.OnRemoveFromEntity = PlayerKeyHandler.OnRemoveEntity

return PlayerKeyHandler
