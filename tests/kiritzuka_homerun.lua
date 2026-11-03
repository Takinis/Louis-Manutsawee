-- Run from the mod directory: lua tests/kiritzuka_homerun.lua
package.path = "scripts/?.lua;" .. package.path
FRAMES = 1 / 30
DEGREES = math.pi / 180
CAMERASHAKE = { VERTICAL = 1 }
TUNING = {
    GAMEMODE_STARTING_ITEMS = { DEFAULT = { KIRITZUKA = {} } },
    KIRITZUKA_BOSS_SLAM = { HITS = 5, ARMED_ATTACK_RANGE = 16 },
    KIRITZUKA_DASH = { ARMED_ATTACK_RANGE = 12 },
    KIRITZUKA_HOMERUN = {
        COOLDOWN = 10, CHARGE_TIME = 1.5, MAX_HOLD = 4, RANGE = 3, ARC = 120,
        DAMAGE_MULT = { 1, 4 }, KNOCK_DISTANCE = { 2, 10 }, KNOCK_SCALE = { large = 0.5, epic = 0.25 },
    },
}
TUNING.KIRITZUKA_SKILL_COOLDOWNS = true
STRINGS = dofile("strings/common.lua")
TheNet = { GetServerGameMode = function() return "default" end }
FlattenTree = function(tree) return tree[1] end
Asset = function() end
State = function(def) return def end
TimeEvent = function(time, fn) return { time = time, fn = fn } end
EventHandler = function(name, fn) return { name = name, fn = fn } end
math.clamp = math.clamp or function(value, low, high) return math.min(math.max(value, low), high) end
package.loaded["components/spdamageutil"] = {}
local now = 0
GetTime = function() return now end
DiffAngle = function(a, b)
    local diff = math.abs(a - b) % 360
    return diff > 180 and 360 - diff or diff
end
ShakeAllCameras = function() end

GLOBAL = _G
GLOBAL.setfenv = function() end
local states = {}
AddStategraphState = function(name, state)
    if name == "wilson" then states[state.name] = state end
end
AddStategraphPostInit = function() end
dofile("postinit/stategraphs/SGkiritzuka.lua")
local charge = assert(states.kiritzuka_homerun_charge)
local swing = assert(states.kiritzuka_homerun_swing)

local master
package.loaded["prefabs/player_common"] = function(_, _, _, _, master_fn) master = master_fn end
dofile("scripts/prefabs/kiritzuka.lua")

local coast
TheWorld = { Map = { IsPassableAtPoint = function(_, x) return coast == nil or x < coast end } }
local entities = {}
TheSim = { FindEntities = function() return entities end }
local spawned = {}
SpawnPrefab = function(name)
    local fx = { name = name }
    fx.AnimState = { SetBuild = function() end }
    fx.Transform = {
        SetPosition = function(_, x, _, z) fx.x, fx.z = x, z end,
        SetRotation = function() end,
        SetScale = function() end,
    }
    spawned[#spawned + 1] = fx
    return fx
end

local function Player()
    local inst = { tags = {}, flags = {}, hits = {}, x = 0, z = 0, rot = 0, weapon = { prefab = "baseballbat" } }
    inst.HasTag = function(self, tag) return self.tags[tag] == true end
    inst.AddComponent = function() end
    inst.ListenForEvent = function() end
    inst.ClearBufferedAction = function() end
    inst.GetAngleToPoint = function(self, x, _, z)
        return math.deg(math.atan2(-(z - self.z), x - self.x))
    end
    inst.ForceFacePoint = function(self, x, _, z) self.rot = self:GetAngleToPoint(x, 0, z) end
    inst.Transform = {
        GetRotation = function() return inst.rot end,
        GetWorldPosition = function() return inst.x, 0, inst.z end,
    }
    inst.AnimState = {
        SetScale = function() end,
        SetDeltaTimeMultiplier = function(_, value) inst.anim_speed = value end,
        SetAddColour = function(_, r) inst.tint = r end,
        PlayAnimation = function(_, name) inst.animation = name end,
        PushAnimation = function(_, name, loop) inst.queued, inst.queued_loop = name, loop end,
        AnimDone = function() return true end,
    }
    inst.SoundEmitter = { PlaySound = function() end }
    inst.components = {
        hunger = { SetMax = function() end },
        sanity = { SetMax = function() end },
        locomotor = { Stop = function() end },
        talker = { Say = function(_, line) inst.said = line end },
        playercontroller = { IsEnabled = function() return not inst.flags.disabled end },
        rider = { IsRiding = function() return inst.flags.riding == true end },
        inventory = { IsHeavyLifting = function() return inst.flags.heavy == true end },
        timer = {
            TimerExists = function() return inst.cooldown ~= nil end,
            StartTimer = function(_, name, duration)
                assert(name == "kiritzuka_homerun")
                inst.cooldown = duration
            end,
        },
        health = { SetMaxHealth = function() end, IsDead = function() return inst.flags.dead == true end },
        combat = {
            attackrange = 2,
            hitrange = 3,
            SetRange = function(self, attack, hit) self.attackrange, self.hitrange = attack, hit end,
            GetWeapon = function() return inst.weapon end,
            CanTarget = function() return true end,
            IsAlly = function() return false end,
            DoAttack = function(self, target, _, _, _, mult)
                assert(self.ignorehitrange)
                inst.hits[#inst.hits + 1] = { target = target, mult = mult }
            end,
        },
    }
    inst.sg = { statemem = {}, tags = {}, currentstate = { name = "idle" } }
    function inst.sg:HasStateTag(tag) return self.tags[tag] == true end
    function inst.sg:RemoveStateTag(tag) self.tags[tag] = nil end
    function inst.sg:SetTimeout(value) self.timeout = value end
    function inst.sg:GoToState(name, data)
        if self.currentstate.onexit ~= nil then self.currentstate.onexit(inst) end
        local nextstate = states[name]
        self.currentstate = nextstate or { name = name }
        self.statemem, self.tags = {}, {}
        if nextstate ~= nil then
            for _, tag in ipairs(nextstate.tags) do self.tags[tag] = true end
            nextstate.onenter(inst, data)
        end
    end
    master(inst)
    return inst
end

local function Enemy(x, z, tags)
    local enemy = { x = x, z = z, tags = tags or {} }
    enemy.IsValid = function() return true end
    enemy.IsInLimbo = function() return false end
    enemy.HasTag = function(_, tag) return enemy.tags[tag] == true end
    enemy.HasAnyTag = function(_, ...)
        for _, tag in ipairs({ ... }) do
            if enemy.tags[tag] then return true end
        end
        return false
    end
    enemy.GetPhysicsRadius = function() return 0.5 end
    enemy.Transform = { GetWorldPosition = function() return enemy.x, 0, enemy.z end }
    enemy.Physics = { Teleport = function(_, x, _, z) enemy.x, enemy.z = x, z end }
    enemy.components = {
        health = { IsDead = function() return enemy.dead == true end },
        combat = {},
        locomotor = {},
    }
    enemy.DoPeriodicTask = function(self, _, fn, _, slide)
        self.slide = { fn = fn, data = slide, cancelled = false }
        return { Cancel = function() self.slide.cancelled = true end }
    end
    return enemy
end

local function RunSlide(enemy)
    for _ = 1, 200 do
        if enemy.slide == nil or enemy.slide.cancelled then return end
        enemy.slide.fn(enemy, enemy.slide.data)
    end
end

local function Near(a, b, tolerance)
    return math.abs(a - b) < (tolerance or 0.0001)
end

-- Holding charges in a loop with no cooldown yet.
local player = Player()
player.rot = 30
now = 0
assert(player:StartHomeRun())
assert(player.sg.currentstate == charge and player.rot == 30, "Keeps the way the player already faces")
assert(player.animation == "scythe_pre" and player.queued == "scythe_lag" and player.queued_loop == true)
assert(player.sg.timeout == 4 and player.cooldown == nil)
assert(not player.sg:HasStateTag("busy"), "Moving drops the charge")

-- The full charge is marked once, at the moment it is reached.
now = 1.4
charge.onupdate(player)
assert(player.said == nil)
now = 1.5
charge.onupdate(player)
assert(player.said == STRINGS.SKILL.KIRITZUKA_HOMERUN_READY and player.sg.statemem.full)
assert(player.tint == nil, "The full charge is spoken, not lit up")
player.said = nil
charge.onupdate(player)
assert(player.said == nil, "Said once")

-- Releasing swings the same way, and starts the cooldown.
assert(player:ReleaseHomeRun())
assert(player.sg.currentstate == swing and player.rot == 30)
player.rot = 0
assert(player.cooldown == 10 and player.sg.statemem.charge == 1)
assert(player.said == STRINGS.SKILL.KIRITZUKA_HOMERUN_FULL)
assert(player.sg.statemem.signature_crit == true, "A full charge always crits")
assert(player.animation == "scythe_loop" and player.anim_speed == 1.5)

-- It hits an arc in front, scaled by the charge, and sends what survives flying.
local front = Enemy(2, 0)
local side = Enemy(0, 3)
local behind = Enemy(-2, 0)
local far = Enemy(6, 0)
local friend = Enemy(1, 0, { companion = true })
entities = { front, side, behind, far, friend }
spawned = {}
assert(swing.timeline[1].time == 2 * FRAMES)
swing.timeline[1].fn(player)
assert(#player.hits == 1 and player.hits[1].target == front and player.hits[1].mult == 4)
assert(player.components.combat.ignorehitrange == false)
assert(not player.sg:HasStateTag("nointerrupt"))
RunSlide(front)
assert(Near(front.x, 12, 0.5) and Near(front.z, 0), "A full charge sends it ten units away")
assert(front.slide.cancelled, "The slide ends by itself")
assert(spawned[1].name == "rocky_snip_fx", "The full charge cuts")
swing.events[1].fn(player)
assert(player.sg.currentstate.name == "idle" and player.anim_speed == 1)

-- A tap is a plain swing: lowest damage, shortest knock, no extras.
player = Player()
now = 10
player:StartHomeRun()
player:ReleaseHomeRun()
assert(player.sg.statemem.charge == 0 and player.sg.statemem.signature_crit == nil and player.said == nil)
front = Enemy(2, 0)
entities = { front }
spawned = {}
swing.timeline[1].fn(player)
assert(player.hits[1].mult == 1 and #spawned == 0)
RunSlide(front)
assert(Near(front.x, 4, 0.1))

-- Half a charge sits between.
player = Player()
now = 20
player:StartHomeRun()
now = 20.75
player:ReleaseHomeRun()
front = Enemy(2, 0)
entities = { front }
swing.timeline[1].fn(player)
assert(Near(player.hits[1].mult, 2.5))
RunSlide(front)
assert(Near(front.x, 8, 0.1))

-- Bigger things barely move, rooted things not at all, and land creatures stop at the shore.
for _, case in ipairs({
    { { largecreature = true }, 7 },
    { { epic = true }, 4.5 },
}) do
    player = Player()
    now = 30
    player:StartHomeRun()
    now = 32
    player:ReleaseHomeRun()
    local big = Enemy(2, 0, case[1])
    entities = { big }
    swing.timeline[1].fn(player)
    RunSlide(big)
    assert(Near(big.x, case[2], 0.1), "Scaled knock")
end

player = Player()
now = 40
player:StartHomeRun()
now = 42
player:ReleaseHomeRun()
local rooted = Enemy(2, 0)
rooted.components.locomotor = nil
entities = { rooted }
swing.timeline[1].fn(player)
assert(rooted.slide == nil and #player.hits == 1, "Hit but not moved")

player = Player()
now = 50
player:StartHomeRun()
now = 52
player:ReleaseHomeRun()
local shore = Enemy(2, 0)
coast = 6
entities = { shore }
swing.timeline[1].fn(player)
RunSlide(shore)
coast = nil
assert(shore.x < 6 and shore.slide.cancelled, "Stops at the shore")

player = Player()
now = 60
player:StartHomeRun()
now = 62
player:ReleaseHomeRun()
local flyer = Enemy(2, 0, { flying = true })
coast = 6
entities = { flyer }
swing.timeline[1].fn(player)
RunSlide(flyer)
coast = nil
assert(Near(flyer.x, 12, 0.5), "Flyers go over the water")

-- A killing blow leaves nothing to knock.
player = Player()
now = 70
player:StartHomeRun()
player:ReleaseHomeRun()
local doomed = Enemy(2, 0)
player.components.combat.DoAttack = function(self) doomed.dead = true end
entities = { doomed }
swing.timeline[1].fn(player)
assert(doomed.slide == nil)

-- A slide ends if the target dies on the way.
player = Player()
now = 80
player:StartHomeRun()
now = 82
player:ReleaseHomeRun()
local dying = Enemy(2, 0)
entities = { dying }
swing.timeline[1].fn(player)
dying.slide.fn(dying, dying.slide.data)
local stopped_at = dying.x
dying.dead = true
dying.slide.fn(dying, dying.slide.data)
assert(dying.x == stopped_at and dying.slide.cancelled)

-- Held too long it swings by itself.
player = Player()
now = 90
player:StartHomeRun()
now = 94
charge.ontimeout(player)
assert(player.sg.currentstate == swing and player.sg.statemem.charge == 1 and player.cooldown == 10)

-- Dropping the charge costs nothing, and a late release does nothing.
player = Player()
now = 100
player:StartHomeRun()
now = 101.5
charge.onupdate(player)
player.sg:GoToState("run_start")
assert(player.cooldown == nil)
assert(not player:ReleaseHomeRun() and player.cooldown == nil, "No swing out of nothing")
assert(player.sg.currentstate.name == "run_start")

-- Refusals.
player = Player()
player.cooldown = 3
assert(not player:StartHomeRun() and player.said == STRINGS.SKILL.KIRITZUKA_HOMERUN_COOLDOWN)
for _, prefab in ipairs({ "pickaxe", "spear" }) do
    player = Player()
    player.weapon.prefab = prefab
    assert(not player:StartHomeRun() and player.cooldown == nil, prefab)
    local matched = false
    for _, line in ipairs(STRINGS.SKILL.KIRITZUKA_WEAPON_REFUSE) do
        matched = matched or line == player.said
    end
    assert(matched)
end
player = Player()
player.weapon = nil
assert(not player:StartHomeRun())
for _, flag in ipairs({ "dead", "riding", "heavy", "disabled" }) do
    player = Player()
    player.flags[flag] = true
    assert(not player:StartHomeRun(), flag)
end
player = Player()
player.sg.tags.busy = true
assert(not player:StartHomeRun(), "Busy")

-- A readied skill is put away.
player = Player()
player:ToggleDash()
assert(player:StartHomeRun())
assert(not player:IsDashArmed() and player.components.combat.attackrange == 2)

print("kiritzuka_homerun: checks passed")
