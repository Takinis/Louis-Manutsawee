require "events"
GLOBAL.setfenv(1, GLOBAL)

-- Extends raw key input with three skill control styles:
-- pressed key routes, quick repeated-key sequences, and hold-key routes.

local TheInput = TheInput

local function MakeKeyPairEvent(prefix, key1, key2)
    return prefix .. tostring(key1) .. "_" .. tostring(key2)
end

local function MakeSortedKeyPairEvent(key1, key2)
    local keys = { key1, key2 }
    table.sort(keys)
    return tostring(keys[1]) .. "_" .. tostring(keys[2])
end

TheInput.special_keys = {}
TheInput.onspecialkey = EventProcessor()

TheInput.pressed_keys = {}
TheInput.key_combinations = {}
TheInput.onkeycombo = EventProcessor()

TheInput.last_key_released = nil
TheInput.last_key_release_time = 0
TheInput.sequence_timeout = 0.5
TheInput.onkeysequence = EventProcessor()

TheInput.hold_keys = {}
TheInput.hold_key_states = {}
TheInput.onholdrawkey = EventProcessor()
TheInput.onkeyhold = EventProcessor()

local _OnRawKey = TheInput.OnRawKey

function TheInput:OnRawKey(key, down)
    local current_time = GetTime()
    local sequence_handled = false
    local combo_handled = false
    local hold_handled = false
    local special_handled = false

    if down then
        if self.last_key_released ~= nil and (current_time - self.last_key_release_time <= self.sequence_timeout) then
            local event_name = MakeKeyPairEvent("seq_", self.last_key_released, key)
            sequence_handled = self.onkeysequence:HandleEvent(event_name, key, self.last_key_released) or false
        end

        self.last_key_released = nil
        self.last_key_release_time = 0
        self.pressed_keys[key] = true

        for pressed_key, _ in pairs(self.pressed_keys) do
            if pressed_key ~= key then
                local event = MakeSortedKeyPairEvent(key, pressed_key)

                if self.key_combinations[event] then
                    combo_handled = self.onkeycombo:HandleEvent(event, key, pressed_key) or false
                    if combo_handled then
                        break
                    end
                end
            end
        end
    else
        self.last_key_released = key
        self.last_key_release_time = current_time
        self.pressed_keys[key] = nil
    end

    hold_handled = self.onholdrawkey:HandleEvent("onholdrawkey", key, down) or false
    if not sequence_handled then
        special_handled = self.onspecialkey:HandleEvent("onspecialkey", key, down) or false
    end

    if not sequence_handled and not combo_handled and not hold_handled and not special_handled then
        if _OnRawKey ~= nil then
            return _OnRawKey(self, key, down)
        end
    end
end

function TheInput:AddSpecialKeyHandler(key, fn, action)
    self.special_keys[key] = true
    return self.onspecialkey:AddEventHandler("onspecialkey", fn)
end

function TheInput:AddHoldKeyHandler(key, hold_time, fn)
    local event_name = "hold_" .. tostring(key) .. "_" .. tostring(fn)
    local state = {
        key = key,
        is_down = false,
        task = nil,
    }

    self.hold_keys[key] = true
    self.hold_key_states[event_name] = state

    local raw_fn = function(_key, down)
        if key ~= _key then
            return false
        end

        if down then
            if state.is_down then
                return true
            end

            state.is_down = true
            self.onkeyhold:HandleEvent(event_name, key, "pressed")

            state.task = ThePlayer ~= nil and ThePlayer:DoTaskInTime(hold_time or .5, function()
                state.task = nil
                if state.is_down then
                    self.onkeyhold:HandleEvent(event_name, key, "hold")
                end
            end) or nil
            return true
        end

        state.is_down = false
        if state.task ~= nil then
            state.task:Cancel()
            state.task = nil
        end

        self.onkeyhold:HandleEvent(event_name, key, "released")
        return true
    end

    self.onholdrawkey:AddEventHandler("onholdrawkey", raw_fn)
    self.onkeyhold:AddEventHandler(event_name, fn)

    return raw_fn, event_name, fn, state
end

function TheInput:AddCombinationKeyHandler(key1, key2, fn)
    local event = MakeSortedKeyPairEvent(key1, key2)
    self.key_combinations[event] = true
    return self.onkeycombo:AddEventHandler(event, fn)
end

function TheInput:AddSequentialKeyHandler(key, _key, fn)
    local event_name = MakeKeyPairEvent("seq_", key, _key)
    return self.onkeysequence:AddEventHandler(event_name, fn)
end

function TheInput:SetSequenceTimeout(timeout)
    self.sequence_timeout = timeout or 0.5
end
