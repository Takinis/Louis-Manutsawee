-- Run from the mod directory: lua tests/kiritzuka_dumbbell.lua
package.path = "scripts/?.lua;" .. package.path
FRAMES = 1 / 30
TUNING = { KIRITZUKA_BOSS_SLAM = { HITS = 5 } }
State = function(def) return def end
TimeEvent = function(time, fn) return { time = time, fn = fn } end
EventHandler = function(name, fn) return { name = name, fn = fn } end
GLOBAL = _G
GLOBAL.setfenv = function() end
ACTIONS = { ATTACK = {}, LIFT_DUMBBELL = {} }

local states, postinits = { wilson = {}, wilson_client = {} }, {}
AddStategraphState = function(name, state) states[name][state.name] = state end
AddStategraphPostInit = function(name, fn) postinits[name] = fn end
dofile("postinit/stategraphs/SGkiritzuka.lua")

local pre = assert(states.wilson.kiritzuka_dumbbell_pre)
local loop = assert(states.wilson.kiritzuka_dumbbell_loop)
local pst = assert(states.wilson.kiritzuka_dumbbell_pst)
assert(states.wilson_client.kiritzuka_dumbbell_pre and states.wilson_client.kiritzuka_dumbbell_pst)
assert(states.wilson_client.kiritzuka_dumbbell_pre.server_states[2] == "kiritzuka_dumbbell_loop",
    "The client keeps its preview through the server's loop")

local function Event(state, name, inst, data)
    for _, event in ipairs(state.events) do
        if event.name == name then event.fn(inst, data) end
    end
end

local function Player()
    local inst = { sg = { statemem = {} }, overrides = {}, played = {} }
    function inst.sg:GoToState(name) self.destination = name end
    inst.dumbbell = { swap_dumbbell = "swap_dumbbell", IsValid = function() return true end }
    inst.components = {
        locomotor = { Stop = function() end },
        dumbbelllifter = {
            StopLifting = function(self)
                inst.stopped = (inst.stopped or 0) + 1
                self.dumbbell = nil
            end,
        },
    }
    function inst:PerformBufferedAction()
        self.components.dumbbelllifter.dumbbell = self.dumbbell
    end
    inst.AnimState = {
        OverrideSymbol = function(_, symbol) inst.overrides[symbol] = true end,
        ClearOverrideSymbol = function(_, symbol) inst.overrides[symbol] = nil end,
        PlayAnimation = function(_, name) inst.played[#inst.played + 1] = name end,
        AnimDone = function() return true end,
    }
    return inst
end

-- It lifts, loops and lowers using only the normal-body animations and no mightiness at all.
local player = Player()
pre.onenter(player)
assert(player.overrides.swap_dumbbell and player.played[1] == "dumbbell_normal_pre")
Event(pre, "animover", player)
assert(player.sg.destination == "kiritzuka_dumbbell_loop")
pre.onexit(player)
assert(player.stopped == nil, "A finished wind-up keeps lifting")

player.sg.statemem = {}
loop.onenter(player)
assert(player.played[2] == "dumbbell_normal_loop")
player.sg.destination = nil
Event(loop, "animover", player)
assert(player.sg.destination == "kiritzuka_dumbbell_loop", "Keeps going until told otherwise")
loop.onexit(player)
assert(player.stopped == nil)

player.sg.statemem = {}
Event(loop, "stopliftingdumbbell", player)
Event(loop, "animover", player)
assert(player.sg.destination == "kiritzuka_dumbbell_pst", "Stopping finishes the rep first")

pst.onenter(player)
assert(player.played[3] == "dumbbell_normal_pst")
Event(pst, "animover", player)
assert(player.sg.destination == "idle")
pst.onexit(player)
assert(player.stopped == 1 and not player.overrides.swap_dumbbell, "Lowers and cleans up")

-- Interruptions and unequipping stop cleanly.
player = Player()
pre.onenter(player)
pre.onexit(player)
assert(player.stopped == 1 and not player.overrides.swap_dumbbell, "Interrupted wind-up stops lifting")

player = Player()
player.sg.statemem = {}
loop.onenter(player)
Event(loop, "stopliftingdumbbell", player, { instant = true })
assert(player.sg.destination == "idle", "Unequipping ends at once")
loop.onexit(player)
assert(player.stopped == 1, "Interrupted loop stops lifting")

player = Player()
player.sg.statemem = {}
Event(pre, "stopliftingdumbbell", player)
Event(pre, "animover", player)
assert(player.sg.destination == "kiritzuka_dumbbell_pst", "Stopping during the wind-up goes straight to lowering")

player = Player()
player.dumbbell = nil
pre.onenter(player)
assert(player.sg.destination == "idle", "Nothing to lift")

-- Routing leaves other characters alone.
local function Graph()
    local graph = {
        actionhandlers = {
            [ACTIONS.ATTACK] = { deststate = function() end },
            [ACTIONS.LIFT_DUMBBELL] = { deststate = function() return "native" end },
        },
        events = { knockback = { fn = function() end } },
    }
    return graph
end
local graph = Graph()
postinits.wilson(graph)
local route = graph.actionhandlers[ACTIONS.LIFT_DUMBBELL].deststate
assert(route({ prefab = "wolfgang" }, {}) == "native")
local lifting = false
local lifter = { components = { dumbbelllifter = { IsLifting = function() return lifting end } }, prefab = "kiritzuka" }
assert(route(lifter, {}) == "kiritzuka_dumbbell_pre")
lifting = true
assert(route(lifter, {}) == "kiritzuka_dumbbell_pst")

graph = Graph()
postinits.wilson_client(graph)
route = graph.actionhandlers[ACTIONS.LIFT_DUMBBELL].deststate
assert(route({ prefab = "wolfgang" }, {}) == "native")
local tagged = false
local client = { prefab = "kiritzuka", HasTag = function(_, tag) return tag == "liftingdumbbell" and tagged end }
assert(route(client, {}) == "kiritzuka_dumbbell_pre")
tagged = true
assert(route(client, {}) == "kiritzuka_dumbbell_pst")

-- The dumbbell restriction opens for Kiritzuka only, on server and client.
local function Restricted(path)
    local Class = { IsRestricted = function() return true end, ToPocket = function() end }
    package.loaded[path] = Class
    dofile("postinit/" .. path .. ".lua")
    return Class
end
for _, path in ipairs({ "components/equippable", "components/equippable_replica" }) do
    local Equippable = Restricted(path)
    local function Item(is_dumbbell)
        return setmetatable({ inst = { HasTag = function(_, tag) return tag == "dumbbell" and is_dumbbell end } },
            { __index = Equippable })
    end
    assert(Item(true):IsRestricted({ prefab = "kiritzuka" }) == false, "Kiritzuka holds dumbbells")
    assert(Item(true):IsRestricted({ prefab = "wilson" }) == true, "Others stay restricted")
    assert(Item(false):IsRestricted({ prefab = "kiritzuka" }) == true, "Other restricted items stay restricted")
end

-- Stopping a lift with no mightiness must not reach the native code that needs it.
do
    local native_stops = 0
    local MightyDumbbell = { StopWorkout = function() native_stops = native_stops + 1 end }
    package.loaded["components/mightydumbbell"] = MightyDumbbell
    dofile("postinit/components/mightydumbbell.lua")
    local removed
    local dumbbell = setmetatable({
        inst = { RemoveTag = function(_, tag) removed = tag end },
        strongman = { components = {} },
    }, { __index = MightyDumbbell })
    dumbbell:StopWorkout()
    assert(removed == "lifting" and dumbbell.strongman == nil and native_stops == 0)
    dumbbell.strongman = { components = { mightiness = {} } }
    dumbbell:StopWorkout()
    assert(native_stops == 1, "Wolfgang keeps the native path")
end

print("kiritzuka_dumbbell: checks passed")
