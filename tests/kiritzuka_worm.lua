-- Run from the mod directory: lua tests/kiritzuka_worm.lua
package.path = "scripts/?.lua;" .. package.path
TWOPI, RADIANS = 2 * math.pi, 180 / math.pi
TUNING = {
    GAMEMODE_STARTING_ITEMS = { DEFAULT = { KIRITZUKA = {} } },
    KIRITZUKA_WORM_BREAK = { DELAY = 1, DAMAGE = 200, LAUNCH = 2, JUMP_CHANCE = 0, JUMP_DISTANCE = 4 },
}
CAMERASHAKE = { VERTICAL = 1 }
STRINGS = dofile("strings/common.lua")
TheNet = { GetServerGameMode = function() return "default" end }
FlattenTree = function(tree) return tree[1] end
Asset = function() end
package.loaded["components/spdamageutil"] = {}
local shakes = 0
ShakeAllCameras = function() shakes = shakes + 1 end
local walkable = 1
FindWalkableOffset = function() return {}, walkable end
TheWorld = { Map = { IsPassableAtPoint = function() return true end } }
local spawned = {}
SpawnPrefab = function(name)
    local fx = { name = name }
    fx.Transform = { SetPosition = function(_, x, y, z) fx.x, fx.y, fx.z = x, y, z end, SetScale = function(_, value) fx.scale = value end }
    spawned[#spawned + 1] = fx
    return fx
end

local master
package.loaded["prefabs/player_common"] = function(_, _, _, _, master_fn) master = master_fn end
dofile("scripts/prefabs/kiritzuka.lua")

local function Player()
    local inst = { tasks = {}, listeners = {}, events = {} }
    inst.AddComponent = function() end
    inst.HasTag = function() return false end
    inst.ListenForEvent = function(self, event, fn) self.listeners[event] = fn end
    inst.DoTaskInTime = function(self, delay, fn, ...)
        local args = { ... }
        table.insert(self.tasks, { delay = delay, run = function() fn(self, unpack(args)) end })
        return {}
    end
    inst.PushEventImmediate = function(self, name, data) self.events[name] = data end
    inst.GetPhysicsRadius = function() return 0.5 end
    inst.GetPosition = function() return { x = 3, y = 0, z = 4 } end
    inst.Transform = { GetWorldPosition = function() return 3, 0, 4 end }
    inst.AnimState = { SetScale = function() end }
    inst.sg = { statemem = {}, tags = {} }
    function inst.sg:HasStateTag(tag) return self.tags[tag] == true end
    function inst.sg:GoToState(name, data) self.destination, self.data = name, data end
    inst.components = {
        hunger = { SetMax = function() end },
        sanity = { SetMax = function() end },
        health = { SetMaxHealth = function() end },
        combat = {},
    }
    master(inst)
    return inst
end

local function Worm(prefab)
    local worm = { prefab = prefab or "worm_boss" }
    worm.IsValid = function() return worm.gone ~= true end
    worm.components = {
        health = { IsDead = function() return worm.dead == true end },
        combat = { GetAttacked = function(_, attacker, damage) worm.hit_by, worm.hit_for = attacker, damage end },
    }
    return worm
end

local function Swallow(player, worm)
    worm.devoured = worm.devoured or {}
    table.insert(worm.devoured, player)
    player.listeners.devoured(player, { attacker = worm })
    player.sg.tags.devoured = true
    player.sg.statemem.attacker = worm
end

-- She waits a moment, then bursts out and hurts the worm on the way.
local player, worm = Player(), Worm()
local other = { prefab = "wilson" }
worm.devoured = { other }
Swallow(player, worm)
assert(#player.tasks == 1 and player.tasks[1].delay == 1, "Breaks out after the delay")
assert(player.events.spitout == nil, "Not at once")
player.tasks[1].run()
local spit = player.events.spitout
assert(spit ~= nil and spit.spitter == player and spit.starthigh == true, "Leaves as the worm's own spit does")
assert(spit.radius == 2 and spit.rot == RADIANS)
assert(spit.strengthmult == 2, "Thrown further than the worm's own spit")
assert(#worm.devoured == 2 and worm.devoured[1] == other, "Whoever else is in there stays")
assert(worm.devoured[2].blankfiller == true, "She leaves a native filler in her place")
assert(worm.hit_by == player and worm.hit_for == 200, "The worm pays for it")
assert(spawned[#spawned].name == "kiritzuka_slam_ring_fx" and spawned[#spawned].x == 3 and shakes == 1)
assert(player.was_spat_out_by_worm ~= nil, "Native leniency against being swallowed straight back")
player.tasks[2].run()
assert(player.was_spat_out_by_worm == nil, "Which runs out")

-- The body bursts once, at the part she came through.
local function Segment(x, percent)
    local segment = { percentdist = percent }
    segment.IsValid = function() return segment.gone ~= true end
    segment.Transform = { GetWorldPosition = function() return x, 0, 0 end }
    return segment
end
local function Explosions()
    local found = {}
    for _, fx in ipairs(spawned) do
        if fx.name == "explode_small" then found[#found + 1] = fx end
    end
    return found
end
local function Near(a, b) return math.abs(a - b) < 0.0001 end

player, worm = Player(), Worm()
local far_chunk = { segments = { Segment(-50, 0.5) } }
local near_chunk = { segments = { Segment(0, 0), Segment(1, 0.25), Segment(2, 0.5), Segment(3, 0.75), Segment(4, 1), Segment(20, 0.5) } }
worm.chunks = { far_chunk, near_chunk }
Swallow(player, worm)
spawned = {}
player.tasks[1].run()
assert(near_chunk.hit == 1 and far_chunk.hit == nil, "Only the part she came through squeezes")
local blasts = Explosions()
assert(#blasts == 1 and blasts[1].x == 3, "One bang, at the nearest segment to her")
assert(Near(blasts[1].y, math.sin(0.75 * math.pi) * 3.5), "At the height the arc has there")
assert(blasts[1].scale == 1.4, "A little bigger than usual")
local dust = 0
for _, fx in ipairs(spawned) do
    if fx.name == "kiritzuka_slam_dust_fx" then dust = dust + 1 end
end
assert(dust == 6, "With dust thrown up where she lands")

-- At the end of the body there are simply fewer neighbours, and a dead piece makes no blast.
player, worm = Player(), Worm()
local edge = { segments = { Segment(3, 0.5), Segment(30, 0.5) } }
edge.segments[2].gone = true
worm.chunks = { edge }
Swallow(player, worm)
spawned = {}
player.tasks[1].run()
assert(#Explosions() == 1 and edge.hit == 1)

-- With nothing above ground the blast goes off where she is.
player, worm = Player(), Worm()
worm.chunks = { { segments = {} } }
Swallow(player, worm)
spawned = {}
player.tasks[1].run()
blasts = Explosions()
assert(#blasts == 1 and blasts[1].x == 3 and blasts[1].z == 4)

-- Out and on the ground, she has something to say about it.
player, worm = Player(), Worm()
local said
player.components.talker = { Say = function(_, line) said = line end }
Swallow(player, worm)
player.tasks[1].run()
assert(said == nil, "Not while still being thrown out")
assert(player.tasks[3].delay == 1)
player.tasks[3].run()
local matched = false
for _, line in ipairs(STRINGS.SKILL.KIRITZUKA_WORM_DISGUST) do
    matched = matched or line == said
end
assert(matched, "Complains about the inside")

-- Alone inside, the list must survive: the worm's states read it straight after this, which
-- once crashed the game in SetWormDigestionSound when it had been cleared.
player, worm = Player(), Worm()
Swallow(player, worm)
player.tasks[1].run()
assert(worm.devoured ~= nil and #worm.devoured == 1 and worm.devoured[1].prefab == nil)
for _, swallowed in ipairs(worm.devoured) do assert(swallowed ~= player) end

-- Nowhere walkable nearby still throws her clear.
walkable = nil
player, worm = Player(), Worm()
Swallow(player, worm)
player.tasks[1].run()
assert(type(player.events.spitout.rot) == "number")
walkable = 1

-- The shadow version counts too.
player, worm = Player(), Worm("worm_boss_shadow")
Swallow(player, worm)
assert(#player.tasks == 1)

-- If she is already out, or something else swallowed her, nothing happens.
player, worm = Player(), Worm()
Swallow(player, worm)
player.sg.tags.devoured = nil
player.tasks[1].run()
assert(player.events.spitout == nil and worm.hit_by == nil, "Already out")

player, worm = Player(), Worm()
Swallow(player, worm)
player.sg.statemem.attacker = Worm()
player.tasks[1].run()
assert(player.events.spitout == nil, "A different swallow")

player, worm = Player(), Worm()
Swallow(player, worm)
worm.gone = true
player.tasks[1].run()
assert(player.events.spitout == nil, "The worm is gone")

player = Player()
player.listeners.devoured(player, { attacker = Worm("pigking") })
assert(#player.tasks == 0, "Only this worm")
player.listeners.devoured(player, {})
player.listeners.devoured(player)
assert(#player.tasks == 0)

-- A dead worm takes no more damage.
player, worm = Player(), Worm()
Swallow(player, worm)
worm.dead = true
player.tasks[1].run()
assert(player.events.spitout ~= nil and worm.hit_by == nil)

-- Sometimes she leaps out instead of being thrown, with the rest of the break the same.
local real_find = FindWalkableOffset
FindWalkableOffset = function(_, _, distance) return { x = distance, z = 0 }, 1 end
TUNING.KIRITZUKA_WORM_BREAK.JUMP_CHANCE = 1
player, worm = Player(), Worm()
worm.chunks = {}
Swallow(player, worm)
spawned = {}
player.tasks[1].run()
assert(player.sg.destination == "kiritzuka_worm_leap", "Leaps")
assert(player.sg.data.x == 7 and player.sg.data.z == 4, "To somewhere walkable the jump distance away")
assert(player.events.spitout == nil, "Not thrown as well")
assert(worm.hit_for == 200 and worm.devoured[1].blankfiller, "The worm pays all the same")
assert(player.was_spat_out_by_worm ~= nil)

-- No room to land falls back to being thrown.
FindWalkableOffset = function(_, _, distance)
    if distance == 4 then return nil end
    return {}, 1
end
player, worm = Player(), Worm()
Swallow(player, worm)
player.tasks[1].run()
assert(player.sg.destination == nil and player.events.spitout ~= nil, "Thrown instead")
FindWalkableOffset = real_find
TUNING.KIRITZUKA_WORM_BREAK.JUMP_CHANCE = 0

-- The leap itself: untouchable flight, landing where it aimed, restored afterwards.
FRAMES = 1 / 30
COLLISION = { GROUND = 1 }
TUNING.KIRITZUKA_BOSS_SLAM = { HITS = 5 }
State = function(def) return def end
TimeEvent = function(time, fn) return { time = time, fn = fn } end
EventHandler = function(name, fn) return { name = name, fn = fn } end
GLOBAL = _G
GLOBAL.setfenv = function() end
local states = {}
AddStategraphState = function(name, state) if name == "wilson" then states[state.name] = state end end
AddStategraphPostInit = function() end
dofile("postinit/stategraphs/SGkiritzuka.lua")
local leap = assert(states.kiritzuka_worm_leap)

local jumper = { x = 0, z = 0, sg = { statemem = {}, tags = {} } }
for _, tag in ipairs(leap.tags) do jumper.sg.tags[tag] = true end
function jumper.sg:RemoveStateTag(tag) self.tags[tag] = nil end
function jumper.sg:SetTimeout() end
function jumper.sg:GoToState(name) self.destination = name end
jumper.components = { health = { invincible = false, SetInvincible = function(self, value) self.invincible = value end } }
jumper.Physics = {
    GetCollisionMask = function() return 123 end,
    SetCollisionMask = function(_, mask) jumper.mask = mask end,
    Stop = function() end,
    SetMotorVel = function(_, value) jumper.motor = value end,
    Teleport = function(_, x, _, z) jumper.x, jumper.z = x, z end,
}
jumper.Transform = {
    SetEightFaced = function() jumper.faces = 8 end,
    SetFourFaced = function() jumper.faces = 4 end,
    GetWorldPosition = function() return jumper.x, 0, jumper.z end,
}
jumper.ForceFacePoint = function() end
jumper.AnimState = {
    PlayAnimation = function(_, name) jumper.anim = name end,
    PushAnimation = function(_, name, loop) jumper.queued, jumper.queued_loop = name, loop end,
    AnimDone = function() return true end,
}
jumper.SoundEmitter = { PlaySound = function() end }

leap.onenter(jumper, { x = 4, z = 0 })
assert(jumper.anim == "boat_jump_pre" and jumper.queued == "boat_jump_loop" and jumper.queued_loop == true, "The boat hop")
assert(jumper.components.health.invincible and jumper.mask == 1)
assert(math.abs(jumper.motor - 4 / (12 * FRAMES)) < 0.0001)
leap.events[1].fn(jumper)
assert(jumper.sg.destination == nil, "The animation ending in the air changes nothing")
leap.timeline[1].fn(jumper)
assert(jumper.x == 4 and not jumper.components.health.invincible and jumper.mask == 123 and jumper.motor == 0)
assert(jumper.anim == "boat_jump_pst", "Comes down with its landing")
assert(not jumper.sg.tags.noattack and not jumper.sg.tags.nointerrupt)
leap.events[1].fn(jumper)
assert(jumper.sg.destination == "idle")
leap.onexit(jumper)

jumper.x, jumper.sg.statemem = 0, {}
leap.onenter(jumper, { x = 4, z = 0 })
leap.onexit(jumper)
assert(jumper.x == 4 and not jumper.components.health.invincible, "Cut short, she still lands safely")

print("kiritzuka_worm: checks passed")
