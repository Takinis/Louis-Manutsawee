-- Dev builds only: finds a Lua call that keeps a frame from ever ending.
-- The engine advances the sim tick (or the static tick while paused) between frames,
-- so a tick pair that stays the same for seconds means one call is still running.
-- It logs a traceback first, then raises an error so the game shows where it was stuck.

local DEFAULTS = {
    instructions = 1000000, -- VM instructions between checks
    report_seconds = 5,
    break_seconds = 20,
}

local HangWatchdog = {}

local config = DEFAULTS
local last_tick, last_static_tick
local frame_start
local reported = false

local function Hook()
    -- Loading and the menus run long calls on purpose; only watch once in the world.
    if ThePlayer == nil then
        last_tick = nil
        return
    end

    local tick, static_tick = GetTick(), GetStaticTick()
    local now = os.time()
    if tick ~= last_tick or static_tick ~= last_static_tick then
        last_tick, last_static_tick = tick, static_tick
        frame_start = now
        reported = false
        return
    end

    local elapsed = os.difftime(now, frame_start)
    if elapsed >= config.break_seconds then
        -- A pcall in the loop may swallow this; wait out another full period before raising again.
        frame_start = now
        error(string.format("[HangWatchdog] frame stuck for %d seconds, breaking out", elapsed), 2)
    elseif elapsed >= config.report_seconds and not reported then
        reported = true
        print(string.format("[HangWatchdog] frame stuck for %d seconds:\n%s", elapsed, debug.traceback("", 2)))
    end
end

function HangWatchdog.Start(options)
    if debug == nil or debug.sethook == nil or GetTick == nil or GetStaticTick == nil then
        print("[HangWatchdog] unavailable")
        return false
    end

    config = {}
    for k, v in pairs(DEFAULTS) do
        config[k] = options ~= nil and options[k] or v
    end
    last_tick, last_static_tick, frame_start, reported = nil, nil, nil, false

    debug.sethook(Hook, "", config.instructions)
    print(string.format("[HangWatchdog] watching: report after %ds, break after %ds",
        config.report_seconds, config.break_seconds))
    return true
end

function HangWatchdog.Stop()
    debug.sethook()
end

return HangWatchdog
