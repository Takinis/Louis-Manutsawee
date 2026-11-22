local Keybinds = require("utils/keybinds")

local function OnKeybindsChanged(self)
    self:RefreshKeyListeners()
end

local PlayerKeyHandler = Class(function(self, inst)
    self.inst = inst
    self.handlers = {}
    self.key_listeners = {}

    self._onkeybindschanged = function() OnKeybindsChanged(self) end
    Keybinds.AddListener(self._onkeybindschanged)
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

-- Bindings are named in utils/keybinds; a raw key code is still accepted.
local function ResolveKey(bind)
    if type(bind) == "string" then
        return Keybinds.Get(bind)
    end
    return bind
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

function PlayerKeyHandler:IsLocalPlayer()
    return self.inst == ThePlayer
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

-- register returns the native handles for the currently bound keys; they are rebuilt when bindings change.
function PlayerKeyHandler:AddRebindableListener(register)
    local listener = { register = register, handles = register() or {} }
    table.insert(self.key_listeners, listener)
    return listener
end

local function RemoveHandles(listener)
    for _, handle in ipairs(listener.handles) do
        handle:Remove()
    end
    listener.handles = {}
end

function PlayerKeyHandler:RefreshKeyListeners()
    for _, listener in ipairs(self.key_listeners) do
        RemoveHandles(listener)
        listener.handles = listener.register() or {}
    end
end

-- fn(down) gets both edges of the bound key. A key held while it is rebound gets its release.
function PlayerKeyHandler:AddRawKeyListener(bind, fn)
    return self:AddRebindableListener(function()
        local key = ResolveKey(bind)
        if key == nil then
            return
        end

        local is_down = false
        local handler = TheInput:AddSpecialKeyHandler(key, function(_key, down)
            if _key ~= key or not self:IsLocalPlayer() then
                return false
            end
            is_down = down
            return fn(down)
        end)

        return {
            {
                Remove = function()
                    handler:Remove()
                    if is_down then
                        is_down = false
                        fn(false)
                    end
                end,
            },
        }
    end)
end

function PlayerKeyHandler:AddKeyListener(namespace, bind, action, ...)
    local args = {...}
    return self:AddRebindableListener(function()
        local key = ResolveKey(bind)
        if key == nil then
            return
        end

        return {
            TheInput:AddSpecialKeyHandler(key, function(_key, down)
                if down and key == _key and self:IsLocalPlayer() then
                    return self:HandleKeyAction(namespace, action, unpack(args)) or false
                end
            end),
        }
    end)
end

function PlayerKeyHandler:AddSequenceKeyListener(namespace, bind, next_bind, action, timeout, pressed_args, sequence_args)
    if pressed_args ~= nil then
        self:AddKeyListener(namespace, bind, action, unpack(pressed_args))
    end

    if TheInput.SetSequenceTimeout ~= nil then
        TheInput:SetSequenceTimeout(timeout or .5)
    end

    local args = sequence_args or pressed_args or {}
    return self:AddRebindableListener(function()
        local key = ResolveKey(bind)
        local next_key = ResolveKey(next_bind or bind)
        if key == nil or next_key == nil then
            return
        end

        return {
            TheInput:AddSequentialKeyHandler(key, next_key, function()
                if self:IsLocalPlayer() then
                    return self:HandleKeyAction(namespace, action, unpack(args)) or false
                end
            end),
        }
    end)
end

function PlayerKeyHandler:AddHoldKeyListener(namespace, bind, action, hold_time, ...)
    local args = {...}
    return self:AddRebindableListener(function()
        local key = ResolveKey(bind)
        if key == nil then
            return
        end

        return {
            TheInput:AddHoldKeyHandler(key, hold_time, function(_key, phase)
                if self:IsLocalPlayer() then
                    return self:HandleKeyAction(namespace, action, unpack(CopyArgs(args, phase))) or false
                end
            end),
        }
    end)
end

function PlayerKeyHandler:OnRemoveEntity()
    Keybinds.RemoveListener(self._onkeybindschanged)

    for _, listener in ipairs(self.key_listeners) do
        RemoveHandles(listener)
    end
    self.key_listeners = {}

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
        elseif handler.fn ~= nil and type(handler.fn) == "table" and handler.fn.Remove ~= nil then
            handler.fn:Remove()
        end
    end
    self.handlers = {}
end

PlayerKeyHandler.OnRemoveFromEntity = PlayerKeyHandler.OnRemoveEntity

return PlayerKeyHandler
