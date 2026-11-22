-- Run from the mod directory: lua tests/soryuha.lua
package.path = "scripts/?.lua;" .. package.path
DEGREES = math.pi / 180
FRAMES = 1 / 30
TWOPI = 2 * math.pi
TUNING = { DEFAULT_ATTACK_RANGE = 2, ELECTRIC_WET_DAMAGE_MULT = 1 }
EQUIPSLOTS = { HANDS = "hands" }
STRINGS = { SKILL = { SORYUHA_SHATTERED = "shattered", SORYUHA_FRAGILE = "fragile" } }
State = function(t) return t end
EventHandler = function(name, fn) return { name = name, fn = fn } end
TimeEvent = function(time, fn) return { time = time, fn = fn } end
GetRandomItem = function(t) return t[1] end
PrefabExists = function(name) return name == "broken_raikiri" end

local noop = setmetatable({}, { __index = function() return function() end end })
local spawned = {}
local pits = {}
ErodeAway = function(ent) ent.eroded = true end
SpawnPrefab = function(name)
    spawned[#spawned + 1] = name
    local ent = { prefab = name, components = {}, Follower = noop, AnimState = noop, entity = noop, RemoveTag = function() end }
    ent.Transform = { SetPosition = function(_, x, _, z) ent.x, ent.z = x, z end, SetScale = function() end, SetRotation = function() end }
    ent.IsValid = function() return not ent.removed end
    ent.Remove = function() ent.removed = true end
    ent.DoTaskInTime = function(_, t, fn) ent.linger, ent.linger_fn = t, fn end
    if name == "antlion_sinkhole" then
        pits[#pits + 1] = ent
    end
    return ent
end

local rolls = {}
math.random = function(...)
    if select("#", ...) > 0 then
        return 1
    end
    return table.remove(rolls, 1) or 0.99
end

local failures = 0
local function check(cond, msg)
    if not cond then
        failures = failures + 1
        print("FAIL: " .. msg)
    end
end

function MobTask(mob, t, fn)
    return ScheduleGlobal(t, fn, nil, nil, mob)
end

local function Mob(tags, x, z, wet, radius)
    local mob = { tags = {}, hits = {}, components = {} }
    for _, tag in ipairs(tags or {}) do
        mob.tags[tag] = true
    end
    mob.HasTag = function(self, tag) return self.tags[tag] == true end
    mob.IsValid = function() return true end
    mob.IsInLimbo = function() return false end
    mob.GetPhysicsRadius = function() return radius or 0.5 end
    mob.GetWetMultiplier = function() return wet or 0 end
    mob.x, mob.z = x, z
    mob.Transform = { GetWorldPosition = function() return mob.x, 0, mob.z end }
    mob.components.health = { IsDead = function() return false end }
    mob.events = {}
    mob.PushEvent = function(self, name, data) self.events[#self.events + 1] = { name = name, data = data } end
    mob.sg = { mem = {}, HasState = function(_, name) return name == "electrocute" and not mob.no_shock end }
    mob.StopBrain = function(self, reason) self.brain_stopped = reason end
    mob.RestartBrain = function(self, reason)
        if self.brain_stopped == reason then
            self.brain_stopped = nil
        end
    end
    mob.DoTaskInTime = function(self, t, fn) return MobTask(self, t, fn) end
    mob.components.combat = {
        GetAttacked = function(_, _, damage, _, stimuli)
            mob.hits[#mob.hits + 1] = damage
            mob.stimuli = stimuli
        end,
    }
    return mob
end

local function Weapon(prefab, tags, damage, uses)
    local weapon = { prefab = prefab, tags = {}, components = { weapon = { damage = damage } } }
    for _, tag in ipairs(tags) do
        weapon.tags[tag] = true
    end
    weapon.HasTag = function(self, tag) return self.tags[tag] == true end
    weapon.IsValid = function() return true end
    if uses ~= nil then
        weapon.components.finiteuses = {
            total = uses,
            current = uses,
            Use = function(self, n) self.current = self.current - n end,
            SetUses = function(self, n) self.current = n end,
        }
    end
    return weapon
end

-- World: a small absolute-time scheduler so delayed hits and the travelling beam can run.
local tasks, clock = {}, 0
local Schedule
Schedule = function(delay, fn, period, args, owner)
    local task = { time = clock + (delay or 0), fn = fn, period = period, args = args or {}, owner = owner }
    task.Cancel = function() task.cancelled = true end
    tasks[#tasks + 1] = task
    return task
end

local function Caster(weapon, mobs)
    local caster = { components = {}, sg = { statemem = {} }, said = {}, given = {} }
    caster.components.inventory = {
        GetEquippedItem = function() return weapon end,
        GiveItem = function(_, item) caster.given[#caster.given + 1] = item end,
    }
    caster.components.combat = {
        CanTarget = function() return true end,
        SetTarget = function() end,
        SetRange = function(_, r) caster.range = r end,
    }
    caster.components.locomotor = { Stop = function() end }
    caster.components.talker = { Say = function(_, s) caster.said[#caster.said + 1] = s end }
    caster.components.kenjutsuka = {
        mp = 0,
        GetMindpower = function(self) return self.mp end,
        SetMindpower = function(self, v) self.mp = v end,
    }
    caster.components.playerskillcontroller = {
        IsLimiterReleased = function() return false end,
        GetSkillData = function() return { mindpower = 50 } end,
    }
    caster.Transform = {
        GetWorldPosition = function() return 0, 0, 0 end,
        GetRotation = function() return 0 end, -- facing +x
    }
    caster.AnimState = { PlayAnimation = function(_, a) caster.anim = a end, PushAnimation = function() end, SetDeltaTimeMultiplier = function() end }
    caster.SoundEmitter = noop
    caster.IsValid = function() return true end
    caster.GUID = 1
    caster.HasTag = function() return false end
    caster.ClearBufferedAction = function() end
    caster.ForceFacePoint = function() end
    caster.DoTaskInTime = function(_, t, fn) return Schedule(t, fn) end
    caster.DoPeriodicTask = function(_, period, fn, delay, ...)
        return Schedule(delay or period, fn, period, { ... })
    end
    caster.sg.SetTimeout = function() end
    caster.sg.GoToState = function(_, name) caster.state = name end
    TheSim = {
        FindEntities = function(_, x, _, z, r)
            local found = {}
            for _, m in ipairs(mobs) do
                local mx, _, mz = m.Transform:GetWorldPosition()
                if (mx - x) ^ 2 + (mz - z) ^ 2 <= r * r then
                    found[#found + 1] = m
                end
            end
            return found
        end,
    }
    return caster
end

local function RunWorld(caster, seconds)
    local stop = clock + seconds
    while clock <= stop do
        local i = 1
        while i <= #tasks do
            local task = tasks[i]
            if task.cancelled then
                table.remove(tasks, i)
            elseif task.time <= clock + 1e-9 then
                task.fn(task.owner or caster, unpack(task.args))
                if task.period ~= nil and not task.cancelled then
                    task.time = clock + task.period
                    i = i + 1
                else
                    table.remove(tasks, i)
                end
            else
                i = i + 1
            end
        end
        clock = clock + FRAMES
    end
end

local module = dofile("postinit/stategraphs/skills/soryuha.lua")
local charge, release = module.states[1], module.states[2]

-- Charging is exposed (no inspskill) but cannot be staggered by lesser hits.
local caster = Caster(Weapon("tokijin", { "tokijin" }, 50), {})
charge.onenter(caster, nil)
check(caster.inspskill == nil, "charge is not immune")
charge.events[1].fn(caster) -- soryuha_interrupted
check(caster.components.kenjutsuka.mp == 25, "boss interrupt refunds half Mind Power")
check(caster.state == "hit", "boss interrupt staggers the caster")
charge.onexit(caster)
check(pits[1].removed, "an interrupted charge closes its pit at once")

-- A completed charge leaves its pit open for a while.
pits = {}
caster = Caster(Weapon("tokijin", { "tokijin" }, 50), {})
charge.onenter(caster, nil)
caster.sg.statemem.charged = true
charge.onexit(caster)
check(not pits[1].removed and pits[1].linger == 10 and pits[1].linger_fn == ErodeAway, "caster's pit lingers 10s then erodes")

local function Count(list, value)
    local n = 0
    for _, v in ipairs(list) do
        if v == value then
            n = n + 1
        end
    end
    return n
end

ScheduleGlobal = function(...) return Schedule(...) end

-- Tokijin: five dragons over 180 degrees plus two from behind home in on the target,
-- then a 5s storm follows it.
tasks = {}
local ahead = Mob({}, 20, 0)
local wet = Mob({}, 10, 0.5, 1)
local flank = Mob({}, 0, 3)         -- in the path of the leftmost dragon as it sets out
local behind = Mob({}, -4, 6)        -- on the loop of the dragon leaving behind-left
local bystander = Mob({}, 28, 0)     -- inside the storm, out of chain range
local boss = Mob({ "epic" }, 22, -3)
local stone = Mob({}, 18, 3)
stone.no_shock = true                -- no shock animation: held by its brain alone
local boulder = { worked = 0, components = {}, IsValid = function() return true end, IsInLimbo = function() return false end, HasTag = function() return false end }
boulder.Transform = { GetWorldPosition = function() return 21, 0, 2 end }
boulder.components.workable = {
    CanBeWorked = function() return true end,
    WorkedBy = function(_, _, n) boulder.worked = boulder.worked + n end,
}
local tokijin = Weapon("tokijin", { "tokijin" }, 50)
caster = Caster(tokijin, { ahead, wet, flank, behind, bystander, boulder, boss, stone })
caster.sg.statemem = {}
release.onenter(caster, ahead)
check(caster.inspskill == true, "release is immune")
RunWorld(caster, 2)
check(ahead.events[1] ~= nil and ahead.events[1].name == "electrocute" and ahead.events[1].data.duration == 6, "struck target plays a 6s shock")
check(#ahead.events == 1, "the shock is applied once per cast, got " .. #ahead.events)
check(boss.events[1] ~= nil and boss.events[1].data.duration == 3, "bosses are shocked for 3s")
check(#stone.events == 0 and stone.brain_stopped == "soryuha_stun", "creatures without a shock state are held by their brain")
RunWorld(caster, 6)
check(ahead.brain_stopped == nil and stone.brain_stopped == nil, "brains restart when the stun ends")

check(Count(ahead.hits, 75) == 4, "target takes 4 dragon hits x1.5, got " .. Count(ahead.hits, 75))
check(Count(ahead.hits, 37.5) >= 20, "storm strikes the target 20 times x0.75 over 5s, got " .. Count(ahead.hits, 37.5))
check(ahead.stimuli == "electric", "damage is electric")
check(wet.hits[1] == 150, "wet target takes double, got " .. tostring(wet.hits[1]))
check(flank.hits[1] == 75, "a dragon leaving at 90 degrees strikes beside the caster, got " .. tostring(flank.hits[1]))
check(Count(behind.hits, 75) == 4, "a rear dragon strikes behind the caster, got " .. Count(behind.hits, 75))
check(Count(bystander.hits, 37.5) == 20 and #bystander.hits == 20, "storm hits everything in its radius, got " .. #bystander.hits)
check(boulder.worked == 15, "the storm shatters a boulder once, worked " .. boulder.worked)
check(Count(spawned, "groundpoundring_fx") == 1, "one shockwave per cast, got " .. Count(spawned, "groundpoundring_fx"))
local impact_pit = pits[#pits]
check(impact_pit ~= nil and impact_pit.x == 20 and impact_pit.z == 0, "a pit opens where the dragons strike")
check(impact_pit ~= nil and impact_pit.linger == 15 and not impact_pit.removed, "the impact pit outlasts the storm by 10s")
check(Count(spawned, "lightning") == 5, "a native bolt every second of the storm, got " .. Count(spawned, "lightning"))

release.onexit(caster)
check(caster.inspskill == nil and caster.range == TUNING.DEFAULT_ATTACK_RANGE, "release exit clears immunity and range")

-- The storm follows its target.
tasks = {}
local runner = Mob({}, 12, 0)
local left_behind = Mob({}, 12, 4)
caster = Caster(tokijin, { runner, left_behind })
release.onenter(caster, runner)
RunWorld(caster, 1.5)
local before = #left_behind.hits
runner.x = 40
RunWorld(caster, 6)
check(#left_behind.hits == before, "storm leaves the old spot when the target moves")
check(Count(runner.hits, 37.5) == 20, "storm keeps striking the moving target, got " .. Count(runner.hits, 37.5))

-- No target in reach: the dragons meet 8 tiles ahead and the storm breaks there.
tasks = {}
local distant = Mob({}, 50, 0)
local at_reach = Mob({}, 32, 0)
caster = Caster(tokijin, { distant, at_reach })
release.onenter(caster, distant)
RunWorld(caster, 8)
check(#distant.hits == 0, "a target past 8 tiles is not chased")
check(Count(at_reach.hits, 37.5) == 20, "storm breaks at full reach, got " .. Count(at_reach.hits, 37.5))

-- Ordinary katana: three dragons, none from behind; chain arcs from a struck foe.
tasks = {}
local imitation_target = Mob({}, 20, 0)
local side = Mob({}, 0, 3)               -- in the path of the leftmost dragon
local chained = Mob({}, -3, 4, 0, 0)     -- out of every dragon's reach, within chain range of `side`
local rear = Mob({}, -6, 0)
caster = Caster(Weapon("koshirae", { "katana" }, 50), { imitation_target, side, chained, rear })
rolls = { 0.99 }
release.onenter(caster, imitation_target)
RunWorld(caster, 8)
check(side.hits[1] == 50, "imitation dragon hits x1, got " .. tostring(side.hits[1]))
check(chained.hits[1] == 25 and #chained.hits == 1, "chain arcs once to a nearby foe at x0.5")
check(#rear.hits == 0, "an ordinary katana sends nothing behind")

-- Ordinary katana: shorter beam, wear, and it can shatter
tasks = {}
local raikiri = Weapon("raikiri", { "katana" }, 50, 100)
local far = Mob({}, 32, 0) -- past the 6-tile reach plus the 4 storm
caster = Caster(raikiri, { far })
rolls = { 0.99 }
release.onenter(caster)
RunWorld(caster, 8)
check(raikiri.components.finiteuses.current == 90, "katana loses 10% durability")
check(#far.hits == 0, "imitation dragons and storm stop short of 8 tiles")
check(caster.said[1] == "fragile", "katana strain is voiced")

tasks = {}
local doomed = Weapon("raikiri", { "katana" }, 50, 100)
caster = Caster(doomed, {})
rolls = { 0.1 }
release.onenter(caster)
check(doomed.components.finiteuses.current == 0, "shattered katana is used up")
check(caster.given[1] ~= nil and caster.given[1].prefab == "broken_raikiri", "shattered katana leaves its broken blade")

tasks = {}
local plain = Weapon("katanablade", { "katana" }, 50, 100)
caster = Caster(plain, {})
rolls = { 0.1 }
release.onenter(caster)
check(plain.components.finiteuses.current == 90, "katana without a broken form only wears")

if failures > 0 then
    os.exit(1)
end
print("soryuha: all checks passed")
