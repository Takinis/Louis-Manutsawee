local PlayerKeyHandler = Class(function(self, inst)
    self.inst = inst
    self.handlers = {}
end)

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

function PlayerKeyHandler:AddKeyListener(namespace, key, action, phase)
    local fn = function(_key, down)
        if down and key == _key then
            return self:HandleKeyAction(namespace, action, phase or "pressed") or false
        end
    end
    -- Still call AddSpecialKeyHandler to ensure TheInput.special_keys is updated if needed by the mod
    TheInput:AddSpecialKeyHandler(key, fn)
    table.insert(self.handlers, {event = "onspecialkey", fn = fn, processor = TheInput.onspecialkey})
end

function PlayerKeyHandler:AddSkillKeyListener(namespace, key, action, control_mode)
    control_mode = control_mode or (M_CONFIG ~= nil and M_CONFIG.SkillControlMode) or SKILL_CONTROL_MODE.COMBO

    if control_mode == SKILL_CONTROL_MODE.HOLD then
        self:AddHoldKeyListener(namespace, key, action, M_CONFIG.SkillHoldTime)
    elseif control_mode == SKILL_CONTROL_MODE.SEQUENCE then
        self:AddKeyListener(namespace, key, action, "pressed")
        self:AddSequentialKeyHandler(namespace, key, key, action, "sequence")
    else
        self:AddKeyListener(namespace, key, action, "pressed")
    end
end

function PlayerKeyHandler:AddHoldKeyListener(namespace, key, action, hold_time)
    local fn = function(_key, phase)
        return self:HandleKeyAction(namespace, action, phase) or false
    end

    local raw_fn, event_name, _, state = TheInput:AddHoldKeyHandler(key, hold_time, fn)
    table.insert(self.handlers, {event = "onholdrawkey", fn = raw_fn, processor = TheInput.onholdrawkey, state = state})
    table.insert(self.handlers, {event = event_name, fn = fn, processor = TheInput.onkeyhold})
end

function PlayerKeyHandler:AddCombinationKeyListener(namespace, key, _key, action, phase)
    local fn = function(k1, k2)
        return self:HandleKeyAction(namespace, action, phase or "combo") or false
    end
    TheInput:AddCombinationKeyHandler(key, _key, fn)

    local keys = { key, _key }
    table.sort(keys)
    local event = keys[1] .. "_" .. keys[2]
    table.insert(self.handlers, {event = event, fn = fn, processor = TheInput.onkeycombo})
end

function PlayerKeyHandler:AddSequentialKeyHandler(namespace, key, _key, action, phase)
    local fn = function(k1, k2)
        return self:HandleKeyAction(namespace, action, phase or "sequence") or false
    end
    TheInput:AddSequentialKeyHandler(key, _key, fn)

    local event_name = "seq_" .. tostring(key) .. "_" .. tostring(_key)
    table.insert(self.handlers, {event = event_name, fn = fn, processor = TheInput.onkeysequence})
end

function PlayerKeyHandler:OnRemoveEntity()
    for _, handler in ipairs(self.handlers) do
        if handler.state ~= nil and handler.state.task ~= nil then
            handler.state.task:Cancel()
            handler.state.task = nil
        end

        if handler.processor and handler.processor.RemoveEventHandler then
            handler.processor:RemoveEventHandler(handler.event, handler.fn)
        end
    end
    self.handlers = {}
end

PlayerKeyHandler.OnRemoveFromEntity = PlayerKeyHandler.OnRemoveEntity

return PlayerKeyHandler
