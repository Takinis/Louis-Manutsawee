-- Run from the mod directory: lua tests/hang_watchdog.lua
package.path = "scripts/?.lua;" .. package.path

local tick = 0
GetTick = function() return tick end
GetStaticTick = function() return 0 end

-- Each check advances the clock one second, so the thresholds pass after a few checks.
local clock = 0
local real_time = os.time
os.time = function() clock = clock + 1 return clock end
os.difftime = function(a, b) return a - b end

local logs = {}
print = function(s) logs[#logs + 1] = s end

local HangWatchdog = require("utils/hangwatchdog")

local function StuckLoop()
    local n = 0
    while true do
        n = n + 1
    end
end

-- Menus and loading are never interrupted.
ThePlayer = nil
assert(HangWatchdog.Start({ instructions = 1000, report_seconds = 3, break_seconds = 6 }))
local spins = 0
for _ = 1, 100000 do
    spins = spins + 1
end
assert(spins == 100000)

-- Frames that keep ticking are never interrupted.
ThePlayer = {}
for _ = 1, 50 do
    tick = tick + 1
    -- Well under one check per frame, so the fake clock never runs ahead inside a frame.
    for _ = 1, 200 do
        spins = spins + 1
    end
end

-- A stuck frame is reported, then broken out of with the stuck line in the error.
local ok, err = pcall(StuckLoop)
HangWatchdog.Stop()
os.time = real_time

assert(not ok, "loop was not broken")
assert(err:find("frame stuck for %d+ seconds, breaking out"), err)
assert(err:find("hang_watchdog.lua:%d+"), "error does not point at the loop: " .. err)

local report
for _, line in ipairs(logs) do
    if line:find("frame stuck for", 1, true) then
        assert(report == nil, "reported more than once")
        report = line
    end
end
assert(report ~= nil, "no traceback was logged")
assert(report:find("StuckLoop") or report:find("hang_watchdog.lua:%d+"), report)

io.write("hang_watchdog: ok\n")
