-- Run from the mod directory: lua tests/immortalslash.lua
package.path = "scripts/?.lua;" .. package.path
DEGREES = math.pi / 180
FRAMES = 1 / 30
TUNING = { DEFAULT_ATTACK_RANGE = 2 }
EQUIPSLOTS = { HANDS = "hands" }
State = function(t) return t end
EventHandler = function(name, fn) return { name = name, fn = fn } end
TimeEvent = function(time, fn) return { time = time, fn = fn } end
local noop = setmetatable({}, { __index = function() return function() end end })
SpawnPrefab = function()
    return { Transform = noop, AnimState = noop, entity = noop, Reverse = function() end }
end
local now = 0
GetTime = function() return now end

local failures = 0
local function check(cond, msg)
    if not cond then
        failures = failures + 1
        print("FAIL: " .. msg)
    end
end

local function HasTag(list, tag)
    for _, v in ipairs(list) do
        if v == tag then
            return true
        end
    end
    return false
end

-- Health hook: the scar blocks healing until it fades.
local Health = {}
function Health:DoDelta(amount)
    self.current = self.current + amount
    return amount
end
package.loaded["components/health"] = Health
GLOBAL = { setfenv = function() end }
dofile("postinit/components/health.lua")

local function Mob(tags, x, z, hp, maxhp)
    local mob = { tags = {}, hits = {}, components = {} }
    for _, tag in ipairs(tags or {}) do
        mob.tags[tag] = true
    end
    mob.HasTag = function(self, tag) return self.tags[tag] == true end
    mob.IsValid = function() return true end
    mob.IsInLimbo = function() return false end
    mob.GetPhysicsRadius = function() return 0.5 end
    mob.GetPosition = function() return { Get = function() return x, 0, z end } end
    mob.Transform = { GetWorldPosition = function() return x, 0, z end }
    local health = setmetatable({ inst = mob, current = hp or 1000, maxhealth = maxhp or 1000 }, { __index = Health })
    health.currenthealth = nil
    health.IsDead = function(self) return self.current <= 0 end
    health.IsInvincible = function() return false end
    health.GetPercent = function(self) return self.current / self.maxhealth end
    mob.components.health = setmetatable({}, {
        __index = function(_, k)
            if k == "currenthealth" then
                return health.current
            end
            return health[k]
        end,
    })
    mob.health = health
    mob.components.combat = {
        GetAttacked = function(_, _, damage)
            mob.hits[#mob.hits + 1] = damage
            health.current = health.current - damage
        end,
    }
    return mob
end

local function Weapon(tags, damage)
    local weapon = { tags = {}, components = { weapon = { damage = damage } } }
    for _, tag in ipairs(tags) do
        weapon.tags[tag] = true
    end
    weapon.HasTag = function(self, tag) return self.tags[tag] == true end
    weapon.IsShadow = function(target) return target:HasTag("shadow") end
    weapon.IsLunar = function(target) return target:HasTag("lunar_aligned") end
    return weapon
end

local module = dofile("postinit/stategraphs/skills/immortalslash.lua")
local windup, strike = module.states[1], module.states[2]

check(not HasTag(windup.tags, "nointerrupt"), "windup can be interrupted")
check(HasTag(strike.tags, "nointerrupt"), "strike cannot be interrupted")

local function Caster(weapon, mobs)
    local caster = { components = {}, sg = { statemem = {}, RemoveStateTag = function() end } }
    caster.components.inventory = { GetEquippedItem = function() return weapon end }
    caster.components.combat = {
        CanTarget = function() return true end,
        SetTarget = function() end,
        SetRange = function(_, r) caster.range = r end,
    }
    caster.components.locomotor = { Stop = function() end }
    caster.Transform = {
        GetWorldPosition = function() return 0, 0, 0 end,
        GetRotation = function() return 0 end, -- facing +x
    }
    caster.AnimState = { PlayAnimation = function() end, SetDeltaTimeMultiplier = function(_, v) caster.speed = v end }
    caster.SoundEmitter = { PlaySound = function() end }
    caster.prefab = "manutsawee"
    caster.HasTag = function() return false end
    TheSim = { FindEntities = function() return mobs end }
    return caster
end

local function TimelineAt(frame)
    for _, ev in ipairs(strike.timeline) do
        if math.abs(ev.time - frame * FRAMES) < 1e-6 then
            return ev.fn
        end
    end
end

-- Mortal Blade: line reaches 10, x4, x2 vs shadow, executes under 15% (5% epic)
local ahead = Mob({}, 9, 0)
local beside = Mob({}, 3, 4)
local shadow = Mob({ "shadow" }, 5, 0.5)
local weak = Mob({}, 4, 0, 200, 1000)
local weak_epic = Mob({ "epic" }, 6, 0, 1000, 10000)
local mortal = Weapon({ "mortalblade", "katana" }, 50)
local caster = Caster(mortal, { ahead, beside, shadow, weak, weak_epic })

TimelineAt(3)(caster)
check(ahead.hits[1] == 200, "mortal line hits x4 at range 9, got " .. tostring(ahead.hits[1]))
check(#beside.hits == 0, "target off the line is not hit")
check(shadow.hits[1] == 400, "shadow foe takes x2 planar bonus, got " .. tostring(shadow.hits[1]))
check(weak.health.current <= 0, "15%-or-lower foe is executed")
check(weak_epic.health.current == 800, "epic at 8% is not executed")

-- Backswing: radius 4.5 around the caster, x1.5
local near = Mob({}, 2, 2)
caster = Caster(mortal, { near })
TimelineAt(19)(caster)
check(near.hits[1] == 75, "backswing hits x1.5, got " .. tostring(near.hits[1]))

-- Imitation: shorter line, x3, no execute
local far = Mob({}, 9, 0)
local mid = Mob({}, 7, 0)
local low = Mob({}, 3, 0, 200, 1000) -- 50 left after the hit: 5%, under the Mortal Blade line
caster = Caster(Weapon({ "katana" }, 50), { far, mid, low })
TimelineAt(3)(caster)
check(#far.hits == 0, "imitation line stops short of 9")
check(mid.hits[1] == 150, "imitation line hits x3, got " .. tostring(mid.hits[1]))
check(low.health.current > 0, "imitation never executes")

-- Scar: no healing while it lasts, healing returns afterwards
local before = mid.health.current
mid.health:DoDelta(100)
check(mid.health.current == before, "scarred target cannot heal")
mid.health:DoDelta(-10)
check(mid.health.current == before - 10, "scar does not block damage")
now = 6
mid.health:DoDelta(100)
check(mid.health.current == before + 90, "healing returns once the scar fades")

-- Exits restore state
caster.inspskill = true
strike.onexit(caster)
check(caster.inspskill == nil and caster.speed == 1, "strike exit clears immunity and anim speed")
caster.range = 8
windup.onexit(caster)
check(caster.range == TUNING.DEFAULT_ATTACK_RANGE, "interrupted windup resets combat range")

if failures > 0 then
    os.exit(1)
end
print("immortalslash: all checks passed")
