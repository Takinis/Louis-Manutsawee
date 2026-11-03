-- Run from the mod directory: lua tests/kiritzuka_combat_speech.lua
package.path = "scripts/?.lua;" .. package.path

local speech = dofile("strings/kiritzuka.lua")
STRINGS = { CHARACTERS = { KIRITZUKA = speech } }
TUNING = { KIRITZUKA_LOW_HEALTH_DAMAGE = 0.75 }
TUNING.GAMEMODE_STARTING_ITEMS = { DEFAULT = { KIRITZUKA = {} } }
FlattenTree = function() return {} end
TheNet = { GetServerGameMode = function() return "default" end }
Asset = function() end
math.clamp = function(value, min, max)
    return math.max(min, math.min(max, value))
end

local now = 0
GetTime = function() return now end

-- Match native lookup, including the unselected GENERIC fallback array.
GetString = function(inst, key, modifier)
    local topic = STRINGS.CHARACTERS[string.upper(inst.prefab)][key]
    local value = topic[modifier ~= nil and string.upper(modifier) or "GENERIC"]
    if value ~= nil then
        return type(value) == "table" and value[math.random(#value)] or value
    end
    return topic.GENERIC
end

local common_postinit
local master_postinit
package.loaded["prefabs/player_common"] = function(_, _, _, common, master)
    common_postinit = common
    master_postinit = master
end
net_byte = function() return { set = function() end } end
net_tinybyte = net_byte
package.loaded["components/spdamageutil"] = {}
dofile("scripts/prefabs/kiritzuka.lua")

local function NewPlayer()
    local listeners = {}
    local inst = {
        AddComponent = function(_, name)
            assert(name == "enemytracker" or name == "momentum" or name == "dumbbelllifter")
        end,
        prefab = "kiritzuka",
        GUID = 1,
        tags = {},
        lines = {},
        AnimState = { SetScale = function() end },
        MiniMapEntity = { SetIcon = function() end },
        components = {
            momentum = { SetSource = function() end },
            health = {
                SetMaxHealth = function() end,
                GetPercent = function() return 1 end,
                IsDead = function(self) return self.dead == true end,
            },
            hunger = { SetMax = function() end },
            sanity = { SetMax = function() end },
            skilltreeupdater = { IsActivated = function() return false end },
            eater = { SetRejectEatingTag = function() end },
        },
    }
    function inst:AddTag(tag) self.tags[tag] = true end
    function inst:HasTag(tag) return self.tags[tag] == true end
    function inst:ListenForEvent(event, fn)
        listeners[event] = listeners[event] or {}
        table.insert(listeners[event], fn)
    end
    function inst:PushEvent(event, data)
        for _, fn in ipairs(listeners[event] or {}) do
            fn(self, data)
        end
    end
    inst.components.talker = {
        Say = function(_, text, duration, noanim, force)
            assert(type(text) == "string" and text ~= "")
            assert(duration == 2 and noanim == true and force == nil)
            table.insert(inst.lines, text)
        end,
    }
    inst.components.combat = {
        inst = inst,
        externaldamagemultipliers = { RemoveModifier = function() end },
        GetBattleCryString = function(self, target)
            if target == nil or not target:IsValid() then
                return nil
            elseif target.metadata then
                return "Original cry", "original_id", 7
            end
            return GetString(self.inst, "BATTLECRY", target.prefab)
        end,
        ResetBattleCryCooldown = function(self, time)
            self.nextbattlecrytime = time + 5
        end,
    }
    common_postinit(inst)
    return inst
end

local function Target(prefab)
    return { prefab = prefab, IsValid = function(self) return not self.invalid end }
end

local function Contains(pool, value)
    for _, text in ipairs(pool) do
        if text == value then return true end
    end
    return false
end

local function CountKeys(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

math.randomseed(74621)
local client = NewPlayer()
client:PushEvent("attacked", { damageresolved = 50 })
assert(#client.lines == 0, "Common initialization must not register authoritative speech")

local inst = NewPlayer()
master_postinit(inst)
local combat = inst.components.combat
local original_interval = combat.battlecryinterval
for _, prefab in ipairs({ "bearger", "pig", "deer", "prey", "spider", "spider_warrior" }) do
    local target = Target(prefab)
    local pool = speech.BATTLECRY[string.upper(prefab)] or speech.BATTLECRY.GENERIC
    local seen = {}
    for _ = 1, 100 do
        local line = combat:GetBattleCryString(target)
        assert(Contains(pool, line), "Unexpected attack line for " .. prefab)
        seen[line] = true
    end
    assert(CountKeys(seen) == #pool, "Attack pool must be sampled randomly: " .. prefab)
end
assert(combat.battlecryinterval == original_interval, "Keep the native attack speech interval")
assert(combat:GetBattleCryString(nil) == nil)
local invalid = Target("bearger")
invalid.invalid = true
assert(combat:GetBattleCryString(invalid) == nil)
local special = Target("bearger")
special.metadata = true
local text, strid, priority = combat:GetBattleCryString(special)
assert(text == "Original cry" and strid == "original_id" and priority == 7)

local function Hit(player, damage, extra)
    local data = extra or {}
    data.damageresolved = damage
    player:PushEvent("attacked", data)
end

for _, case in ipairs({
    { 0.1, "LIGHT" }, { 9.99, "LIGHT" },
    { 10, "MEDIUM" }, { 24.99, "MEDIUM" },
    { 25, "HEAVY" }, { 80, "HEAVY" },
}) do
    now = now + 3
    local count = #inst.lines
    Hit(inst, case[1])
    assert(#inst.lines == count + 1)
    assert(Contains(speech.ANNOUNCE_HURT[case[2]], inst.lines[#inst.lines]))
    assert(combat.nextbattlecrytime > now + 2, "Attacks must not immediately replace hurt speech")
end

now = now + 3
Hit(inst, 1, { damage = 100, original_damage = 500 })
assert(Contains(speech.ANNOUNCE_HURT.LIGHT, inst.lines[#inst.lines]), "Use damage after mitigation")
local count = #inst.lines
inst:PushEvent("attacked")
inst:PushEvent("attacked", { damage = 100 })
Hit(inst, 0, { damage = 100 })
Hit(inst, -10)
Hit(inst, 30, { redirected = {} })
assert(#inst.lines == count, "Ignore missing damage, blocked hits and redirected damage")
assert(inst._hurt_speech_time == now + 2)

inst.components.health.dead = true
now = now + 3
Hit(inst, 100)
inst.components.health.dead = false
inst.tags.playerghost = true
Hit(inst, 20)
inst.tags.playerghost = nil
local talker = inst.components.talker
inst.components.talker = nil
Hit(inst, 20)
inst.components.talker = talker
assert(#inst.lines == count, "Dead players, ghosts and missing talkers must stay silent")

inst:PushEvent("healthdelta", { amount = -20, cause = "hunger" })
assert(#inst.lines == count, "Non-combat health changes must not trigger hurt speech")

local other = NewPlayer()
master_postinit(other)
now = 100
Hit(other, 1)
now = 100.1
Hit(other, 2)
assert(#other.lines == 1, "Throttle repeated hits")
Hit(other, 10)
assert(#other.lines == 2, "Medium damage may interrupt light damage")
now = 100.2
Hit(other, 25)
assert(#other.lines == 3, "Heavy damage may interrupt medium damage")
Hit(other, 30)
Hit(other, 5)
assert(#other.lines == 3, "Do not replace heavy speech with equal or lower severity")
now = 102.2
Hit(other, 1)
assert(#other.lines == 4, "Speech resumes at the cooldown boundary")
assert(#inst.lines == count, "Speech cooldown is per player")

for _, level in ipairs({ { 1, "LIGHT" }, { 10, "MEDIUM" }, { 25, "HEAVY" } }) do
    local seen = {}
    for _ = 1, 100 do
        now = now + 3
        Hit(inst, level[1])
        seen[inst.lines[#inst.lines]] = true
    end
    assert(CountKeys(seen) == #speech.ANNOUNCE_HURT[level[2]], "Random hurt pool: " .. level[2])
end

print("PASS: random attack pools, native fallback and metadata, actual damage tiers, cooldown escalation, silence guards and player isolation")
