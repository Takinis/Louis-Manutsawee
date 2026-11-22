-- Run from the mod directory: lua tests/skill_bugfix.lua
package.path = "scripts/?.lua;" .. package.path
DEGREES = math.pi / 180
FRAMES = 1 / 30
TWOPI = 2 * math.pi
TUNING = { DEFAULT_ATTACK_RANGE = 2 }
EQUIPSLOTS = { HANDS = "hands" }
State = function(t) return t end
EventHandler = function(name, fn) return { name = name, fn = fn } end
TimeEvent = function(time, fn) return { time = time, fn = fn } end
SpawnPrefab = function() return nil end
GetRandomItem = function(t) return t[1] end
TheWorld = { Map = { IsPassableAtPoint = function() return true end } }

local SkillUtil = require("utils/skillutil")

local function Entity(tags, x, z)
    local ent = { tags = {}, hits = {}, components = {} }
    for _, tag in ipairs(tags or {}) do
        ent.tags[tag] = true
    end
    ent.HasTag = function(self, tag) return self.tags[tag] == true end
    ent.IsValid = function() return true end
    ent.IsInLimbo = function() return false end
    ent.GetPhysicsRadius = function() return 0 end
    ent.Transform = { GetWorldPosition = function() return x or 1, 0, z or 0 end }
    ent.components.health = { IsDead = function() return false end }
    ent.components.combat = {
        GetAttacked = function(_, attacker, damage) ent.hits[#ent.hits + 1] = damage end,
    }
    return ent
end

local function Leader(ent, leader)
    ent.components.follower = { GetLeader = function() return leader end }
    return ent
end

local failures = 0
local function check(cond, msg)
    if not cond then
        failures = failures + 1
        print("FAIL: " .. msg)
    end
end

-- Ally filter
local player = Entity({ "player" })
check(SkillUtil.IsProtectedTarget(player, Entity({ "abigail" })), "abigail is protected")
check(SkillUtil.IsProtectedTarget(player, Entity({ "companion" })), "companion is protected")
check(SkillUtil.IsProtectedTarget(player, Leader(Entity({}), player)), "own follower is protected")
check(SkillUtil.IsProtectedTarget(player, Leader(Entity({}), Entity({ "player" }))), "another player's follower is protected")
check(not SkillUtil.IsProtectedTarget(player, Leader(Entity({}), Entity({ "spiderqueen" }))), "monster follower is a target")
check(not SkillUtil.IsProtectedTarget(player, Entity({ "hostile" })), "hostile mob is a target")

-- Immortal slash exit restores invulnerability flag and anim speed
local caster = Entity({ "player" }, 0, 0)
caster.components.combat.SetRange = function() end
caster.AnimState = {}
local immortal = dofile("postinit/stategraphs/skills/immortalslash.lua").states[2]
local speed
caster.inspskill = true
caster.AnimState.SetDeltaTimeMultiplier = function(_, v) speed = v end
caster.components.combat.SetTarget = function() end
caster.components.combat.EnableAreaDamage = function() end
immortal.onexit(caster)
check(caster.inspskill == nil, "immortalslash clears inspskill on exit")
check(speed == 1, "immortalslash restores anim speed on exit")

-- Strings localized
local function read(path)
    local f = assert(io.open(path, "r"))
    local s = f:read("*a")
    f:close()
    return s
end
local manutsawee = read("scripts/prefabs/manutsawee.lua")
check(not manutsawee:find("需要满级才能释放苍龙破", 1, true), "no hardcoded max-level line")
check(not manutsawee:find("奥义·苍龙破", 1, true), "no hardcoded ougi line")
check(manutsawee:find("anim/kiritzuka_guard.zip", 1, true) ~= nil, "manutsawee loads the guard anim")
for _, path in ipairs({ "strings/common.lua", "scripts/languages/strings.pot", "scripts/languages/chinese_s.po", "scripts/languages/chinese_t.po" }) do
    local s = read(path)
    check(s:find("SORYUHA_NEED_MAX_LEVEL", 1, true) ~= nil, path .. " has SORYUHA_NEED_MAX_LEVEL")
    check(s:find("SORYUHA_OUGI_ATTACK", 1, true) ~= nil, path .. " has SORYUHA_OUGI_ATTACK")
end

if failures > 0 then
    os.exit(1)
end
print("skill_bugfix: all checks passed")
