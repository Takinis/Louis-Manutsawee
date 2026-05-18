require "events"
GLOBAL.setfenv(1, GLOBAL)

--[[

好的，接下来我们重构技能按键的控制。当前投入使用的是“前置技能状态 + 后续输入”。即按键组合。

现在的需求时实现三种按键控制方案：

方案一: 按键组合
前置按键 + 后续按键。即先按，再按
KEY_A (第一路由) + KEY_B (触发第二路由)
同时也实现多个按键组合。
KEY_A (第一路由) + KEY_B (触发第二路由) + KEY_C (触发第三路由) + xxx

方案二: 按键序列 (快速连按)
重复按下控键。
KEY_A (第一路由) ==> KEY_A (触发第二路由)
同时也实现多个按键序列。
KEY_A (第一路由) ==> KEY_A (触发第二路由) ==> KEY_A (触发第三路由) ==> xxx

方案三: 长按按键 (长按不动)
按住某个按键 超过指定时间。
KEY_A (第一路由) -pressed_time-> (触发第二路由)

在modinfo中可以调整使用的按键控制方案

相关的文件：
modinfo.lua
postinit/input.lua
scripts/components/kenjutsuka.lua
scripts/components/playerkeyhandler.lua
scripts/components/playerskillcontroller.lua
scripts/prefabs/manutsawee.lua

]]

local TheInput = TheInput

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
            local event_name = "seq_" .. tostring(self.last_key_released) .. "_" .. tostring(key)
            sequence_handled = self.onkeysequence:HandleEvent(event_name, key, self.last_key_released) or false
        end

        self.last_key_released = nil
        self.last_key_release_time = 0

        self.pressed_keys[key] = true

        for pressed_key, _ in pairs(self.pressed_keys) do
            if pressed_key ~= key then
                local keys = { key, pressed_key }
                table.sort(keys)
                local event = keys[1] .. "_" .. keys[2]

                if self.key_combinations[event] then
                    combo_handled = self.onkeycombo:HandleEvent(event, key, pressed_key) or false
                    if combo_handled then break end
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

    local handler = function(_key, down)
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

    self.onholdrawkey:AddEventHandler("onholdrawkey", handler)
    self.onkeyhold:AddEventHandler(event_name, fn)
    return handler, event_name, fn, state
end

function TheInput:AddCombinationKeyHandler(key1, key2, fn)
    local keys = { key1, key2 }
    table.sort(keys)
    local event = keys[1] .. "_" .. keys[2]
    self.key_combinations[event] = true
    return self.onkeycombo:AddEventHandler(event, fn)
end

function TheInput:AddSequentialKeyHandler(key, _key, fn)
    local event_name = "seq_" .. tostring(key) .. "_" .. tostring(_key)
    return self.onkeysequence:AddEventHandler(event_name, fn)
end

function TheInput:SetSequenceTimeout(timeout)
    self.sequence_timeout = timeout or 1 -- 默认0.5
end
