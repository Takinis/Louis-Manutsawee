local PlayerKeyHandler = Class(function(self, inst)
    self.inst = inst
    self.handlers = {}
end)

local unpack = unpack

local function CopyArgs(args, extra)
    local copied = {}
    for i = 1, #args do
        copied[i] = args[i]
    end

    if extra ~= nil then
        copied[#copied + 1] = extra
    end

    return copied
end

local function IsActiveHUDScreen()
    local screen = TheFrontEnd and TheFrontEnd:GetActiveScreen()
    return screen ~= nil and screen.name == "HUD"
end

local function IsHUDInputBlocked(inst)
    local hud = inst ~= nil and inst.HUD or (ThePlayer ~= nil and ThePlayer.HUD or nil)

    if hud ~= nil then
        if hud.IsCraftingOpen ~= nil and hud:IsCraftingOpen() then
            return true
        end

        if hud.HasInputFocus ~= nil and hud:HasInputFocus() then
            return true
        end
    end

    return TheFrontEnd ~= nil and TheFrontEnd.textProcessorWidget ~= nil
end

function PlayerKeyHandler:HandleKeyAction(namespace, action, ...)
    if IsActiveHUDScreen() and not IsHUDInputBlocked(self.inst) then
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

function PlayerKeyHandler:RememberHandler(processor, event, fn, state, remover, remover_args)
    table.insert(self.handlers, {event = event, fn = fn, processor = processor, state = state, remover = remover, remover_args = remover_args})
end

function PlayerKeyHandler:AddKeyListener(namespace, key, action, ...)
    local args = {...}
    local fn = function(_key, down)
        if down and key == _key then
            return self:HandleKeyAction(namespace, action, unpack(args)) or false
        end
    end

    TheInput:AddSpecialKeyHandler(key, fn)
    self:RememberHandler(TheInput.onspecialkey, "onspecialkey", fn)
end

function PlayerKeyHandler:AddSequenceKeyListener(namespace, key, next_key, action, timeout, pressed_args, sequence_args)
    if pressed_args ~= nil then
        self:AddKeyListener(namespace, key, action, unpack(pressed_args))
    end

    local args = sequence_args or pressed_args or {}
    local fn = function(k1, k2)
        return self:HandleKeyAction(namespace, action, unpack(args)) or false
    end

    if TheInput.SetSequenceTimeout ~= nil then
        TheInput:SetSequenceTimeout(timeout or .5)
    end

    TheInput:AddSequentialKeyHandler(key, next_key or key, fn)

    local event_name = "seq_" .. tostring(key) .. "_" .. tostring(next_key or key)
    self:RememberHandler(TheInput.onkeysequence, event_name, fn)
end

function PlayerKeyHandler:AddHoldKeyListener(namespace, key, action, hold_time, ...)
    local args = {...}
    local fn = function(_key, phase)
        return self:HandleKeyAction(namespace, action, unpack(CopyArgs(args, phase))) or false
    end

    local raw_fn, event_name, hold_fn, state = TheInput:AddHoldKeyHandler(key, hold_time, fn)
    self:RememberHandler(TheInput, nil, raw_fn, state, TheInput.RemoveHoldKeyHandler, {event_name, hold_fn})
end

function PlayerKeyHandler:OnRemoveEntity()
    for _, handler in ipairs(self.handlers) do
        if handler.state ~= nil and handler.state.task ~= nil then
            handler.state.task:Cancel()
            handler.state.task = nil
        end

        if handler.remover ~= nil then
            if handler.remover_args ~= nil then
                handler.remover(handler.processor, handler.fn, unpack(handler.remover_args))
            else
                handler.remover(handler.processor, handler.fn)
            end
        elseif handler.processor and handler.processor.RemoveEventHandler then
            handler.processor:RemoveEventHandler(handler.event, handler.fn)
        end
    end
    self.handlers = {}
end

PlayerKeyHandler.OnRemoveFromEntity = PlayerKeyHandler.OnRemoveEntity

return PlayerKeyHandler
