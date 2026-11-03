-- Run from the mod directory: lua tests/predictive_counter_attack.lua
local native_scripts = arg[1] or "../../data/databundles/scripts/"
package.path = "scripts/?.lua;" .. native_scripts .. "?.lua;" .. package.path
require("class")

GLOBAL = _G
FRAMES = 1 / 30
DEGREES = math.pi / 180
EQUIPSLOTS = {HANDS = "hands"}
TUNING = {DEFAULT_ATTACK_RANGE = 2}
STRINGS = {SKILL = {SKILL_CANCEL = "Cancelled"}}
State = function(state) return state end
TimeEvent = function(time, fn) return {time = time, fn = fn} end
EventHandler = function(name, fn) return {name = name, fn = fn} end

local now = 10
local entities = {}
local checked = 0
GetTime = function() return now end

local function Check(value, message)
    assert(value, message)
    checked = checked + 1
end

local function NoOp() end
package.preload["utils/skillutil"] = function()
    return {AddFollowerFx = NoOp, GroundPoundFx = NoOp}
end

local Combat = Class(function(self, inst)
    self.inst = inst
    self.range = 3
end)
function Combat:StartAttack() self.laststartattacktime = now end
function Combat:GetWeapon() return self.weapon end
function Combat:SetRange(range) self.range = range end
function Combat:SetTarget(target) self.target = target end
function Combat:EnableAreaDamage() end
function Combat:CanHitTarget(target)
    return self.inst:GetDistanceSqToInst(target) <= (self.range + target:GetPhysicsRadius(0)) ^ 2
        and self.facing_away ~= true
end
function Combat:GetAttacked(attacker, damage, weapon, stimuli, spdamage, extra)
    self.inst.damage_calls = self.inst.damage_calls + 1
    self.inst.damage_args = {attacker, damage, weapon, stimuli, spdamage, extra}
    return false
end
function Combat:DoAttack(target)
    self.attack_calls = (self.attack_calls or 0) + 1
    self.last_attack_target = target
    if target ~= nil and self:CanHitTarget(target) then
        target.components.combat:GetAttacked(self.inst, 10, self.weapon)
    end
    self.lastdoattacktime = now
end
package.loaded["components/combat"] = Combat
local combat_postinit
AddComponentPostInit = function(name, fn)
    assert(name == "combat")
    combat_postinit = fn
end
dofile("postinit/components/combat.lua")

local Controller = require("components/playerskillcontroller")
local Predictor = require("components/counterpredictor")
local counter = dofile("postinit/stategraphs/skills/counter_attack.lua").states[1]

local function NewEntity(prefab, x, tags)
    local inst = {
        prefab = prefab, x = x or 0, z = 0, rotation = 0, radius = .5,
        tags = tags or {}, components = {}, listeners = {}, updating = {},
        damage_calls = 0, valid = true,
    }
    inst.Transform = {
        GetWorldPosition = function() return inst.x, 0, inst.z end,
        GetRotation = function() return inst.rotation end,
    }
    function inst:IsValid() return self.valid end
    function inst:IsInLimbo() return self.limbo == true end
    function inst:HasTag(tag) return self.tags[tag] == true end
    function inst:AddTag(tag) self.tags[tag] = true end
    function inst:RemoveTag(tag) self.tags[tag] = nil end
    function inst:HasOneOfTags(tags_to_check)
        for _, tag in ipairs(tags_to_check) do
            if self:HasTag(tag) then return true end
        end
        return false
    end
    function inst:GetPhysicsRadius(default) return self.radius or default end
    function inst:GetPosition() return {Get = function() return inst.x, 0, inst.z end} end
    function inst:GetDistanceSqToInst(other) return (self.x - other.x) ^ 2 + (self.z - other.z) ^ 2 end
    function inst:ForceFacePoint() end
    function inst:ClearBufferedAction() self.bufferedaction = nil end
    function inst:StartUpdatingComponent(component) self.updating[component] = true end
    function inst:StopUpdatingComponent(component) self.updating[component] = nil end
    function inst:ListenForEvent(event, fn)
        self.listeners[event] = self.listeners[event] or {}
        table.insert(self.listeners[event], fn)
    end
    function inst:RemoveEventCallback(event, fn)
        for i, callback in ipairs(self.listeners[event] or {}) do
            if callback == fn then table.remove(self.listeners[event], i); break end
        end
    end
    function inst:PushEvent(event, data)
        for _, fn in ipairs(self.listeners[event] or {}) do fn(self, data) end
    end
    inst.components.health = {IsDead = function() return inst.dead == true end}
    inst.components.combat = Combat(inst)
    combat_postinit(inst.components.combat, inst)
    inst.sg = {
        inst = inst, tags = {}, statemem = {}, currentstate = {name = "idle"},
        statestarttime = now, counter_entries = 0,
    }
    function inst.sg:HasStateTag(tag) return self.tags[tag] == true end
    function inst.sg:GoToState(name, target)
        if self.currentstate.onexit ~= nil then self.currentstate.onexit(inst) end
        self.currentstate = name == "counter_attack" and counter or {name = name}
        self.tags = {}
        for _, tag in ipairs(self.currentstate.tags or {}) do self.tags[tag] = true end
        self.statemem = {}
        self.statestarttime = now
        self.timeline_index = 1
        if name == "counter_attack" then
            self.counter_entries = self.counter_entries + 1
            self.currentstate.onenter(inst, target)
        end
    end
    entities[#entities + 1] = inst
    return inst
end

SpawnPrefab = function()
    return {Transform = {SetPosition = NoOp}}
end
TheSim = {
    FindEntities = function(_, x, y, z, radius, must, cant, one_of)
        local found = {}
        for _, inst in ipairs(entities) do
            local include = inst.valid and (inst.x - x) ^ 2 + (inst.z - z) ^ 2 <= radius ^ 2
            for _, tag in ipairs(cant or {}) do include = include and not inst:HasTag(tag) end
            include = include and (one_of == nil or inst:HasOneOfTags(one_of))
            if include then found[#found + 1] = inst end
        end
        return found
    end,
}

local function NewPlayer()
    local inst = NewEntity("manutsawee", 0, {kenjutsuka = true, _combat = true})
    inst.hand = NewEntity("katana", 0, {katana = true, weapon = true})
    inst.components.inventory = {
        GetEquippedItem = function() return inst.hand end,
        IsHeavyLifting = function() return inst.heavy == true end,
    }
    inst.components.sleeper = {IsAsleep = function() return inst.asleep == true end}
    inst.components.freezable = {IsFrozen = function() return inst.frozen == true end}
    inst.components.rider = {IsRiding = function() return inst.riding == true end}
    inst.components.locomotor = {Stop = NoOp}
    inst.AnimState = {PlayAnimation = NoOp, OverrideSymbol = NoOp, SetDeltaTimeMultiplier = NoOp}
    inst.SoundEmitter = {PlaySound = NoOp}
    inst.components.playerskillcontroller = Controller(inst)
    inst.components.counterpredictor = Predictor(inst)
    return inst, inst.components.playerskillcontroller, inst.components.counterpredictor
end

local function WindUp(attacker, target, target_after_start)
    attacker.sg:GoToState("attack")
    attacker.sg.tags.attack = true
    attacker.components.combat.target = target
    if not target_after_start then attacker.sg.statemem.target = target end
    attacker.components.combat:StartAttack()
    attacker.sg.statemem.target = target
end

local function Tick(dt, stategraphs_first)
    now = now + dt
    local function UpdateStates()
        for _, inst in ipairs(entities) do
            local sg = inst.sg
            local state = sg.currentstate
            while state.timeline ~= nil and state.timeline[sg.timeline_index] ~= nil
                and state.timeline[sg.timeline_index].time <= now - sg.statestarttime + .000001 do
                local event = state.timeline[sg.timeline_index]
                sg.timeline_index = sg.timeline_index + 1
                event.fn(inst)
                if sg.currentstate ~= state then break end
            end
        end
    end
    local function UpdateComponents()
        for _, inst in ipairs(entities) do
            for component in pairs(inst.updating) do component:OnUpdate(dt) end
        end
    end
    if stategraphs_first then UpdateStates(); UpdateComponents()
    else UpdateComponents(); UpdateStates() end
end

local function Reset()
    entities = {}
    now = now + 10
end

local player, controller, predictor = NewPlayer()
local hound = NewEntity("hound", 2, {_combat = true})
Check(not predictor.enabled and next(player.updating) == nil, "Disabled mode must not run scans")
controller:StartCounterAttack()
Check(predictor.enabled and player.sg.currentstate.name == "idle", "Enabling must not open a timed parry window")
WindUp(hound, player, true)
Tick(FRAMES)
Check(player.sg.currentstate.name == "counter_attack", "Attack wind-up must trigger counter before damage")
Check(player.damage_calls == 0 and hound.components.combat.attack_calls == nil, "Prediction must precede enemy DoAttack")
Check(player.sg.statemem.target == hound, "Prediction must select the attacker")
Tick(3 * FRAMES, true)
Check(player.components.combat.attack_calls == 1 and hound.damage_calls == 1, "Counter must attack at its animation frame")
player.sg:GoToState("idle")
hound.components.combat:DoAttack(player)
Check(player.damage_calls == 0, "Previously predicted attack must remain blocked after counter animation")
Tick(FRAMES)
Check(player.sg.counter_entries == 1, "One enemy swing must not repeat counters")
WindUp(hound, player)
Tick(FRAMES)
Check(player.sg.counter_entries == 2, "New swing must counter immediately without cooldown")

controller:StartCounterAttack()
Check(not predictor.enabled and next(predictor.attackers) == nil, "Second press must stop prediction and clear records")
local entries = player.sg.counter_entries
player.components.combat:GetAttacked(hound, 10)
Check(player.damage_calls == 1 and player.sg.counter_entries == entries, "Damage callback must never start a counter")

Reset()
player, controller, predictor = NewPlayer()
hound = NewEntity("hound", 2, {_combat = true})
WindUp(hound, player)
hound.components.combat:DoAttack(player)
controller:StartCounterAttack()
Check(player.sg.counter_entries == 0, "Enabling after enemy hit must not predict an already delivered strike")
hound.sg:GoToState("idle")
now = now + FRAMES
WindUp(hound, player)
Tick(FRAMES, true)
Check(player.sg.counter_entries == 1, "Enabling during a later wind-up must predict normally")
local surprise = NewEntity("surprise", 2, {_combat = true})
player.components.combat:GetAttacked(surprise, 11, nil, "test", {planar = 2}, "extra")
Check(player.damage_calls == 2, "Counter animation must not grant immunity to unpredicted attacks")
Check(player.damage_args[4] == "test" and player.damage_args[5].planar == 2
    and player.damage_args[6] == "extra", "Unblocked damage must preserve all native arguments")
hound.sg:GoToState("idle")
Check(not predictor:ShouldBlockAttack(hound), "Cancelled attack must invalidate its prediction immediately")
WindUp(hound, surprise)
Check(not predictor:ShouldBlockAttack(hound), "Retargeting must invalidate prediction immediately")

Reset()
player, controller, predictor = NewPlayer()
hound = NewEntity("hound", 9, {_combat = true})
controller:StartCounterAttack()
WindUp(hound, player)
Tick(FRAMES)
Check(player.sg.counter_entries == 0, "Out-of-range wind-up must not counter")
hound.x = 2
hound.components.combat.facing_away = true
Tick(FRAMES)
Check(player.sg.counter_entries == 0, "Attack facing away must not counter")
hound.components.combat.facing_away = false
Tick(FRAMES)
Check(player.sg.counter_entries == 1, "Moving into a threatening attack range must predict")
hound.dead = true
Check(not predictor:ShouldBlockAttack(hound), "Dead attacker must not retain a melee guard")
hound.dead = false
hound.valid = false
Tick(FRAMES)
Check(predictor.attackers[hound] == nil, "Removed attacker must release its prediction record")

Reset()
player, controller, predictor = NewPlayer()
local first = NewEntity("hound", 2, {_combat = true})
local second = NewEntity("spider", 3, {_combat = true})
controller:StartCounterAttack()
WindUp(first, player)
WindUp(second, player)
Tick(FRAMES)
Check(player.sg.statemem.target == first, "Nearest simultaneous melee threat must counter first")
Check(predictor:ShouldBlockAttack(first) and predictor:ShouldBlockAttack(second), "Both predicted attackers must be guarded")
Tick(FRAMES)
Check(player.sg.counter_entries == 1, "New threats must not restart the counter before its attack frame")
Tick(3 * FRAMES, true)
Check(player.sg.counter_entries == 2 and player.sg.statemem.target == second, "Pending threat must chain without cooldown after attack commits")
Tick(3 * FRAMES, true)
Check(player.components.combat.attack_calls == 2, "Each predicted swing must execute one counterattack")

local function NewProjectile(owner, x, homing)
    local entity = NewEntity("spit", x, {projectile = true})
    entity.rotation = 180
    entity.components.projectile = {owner = owner, target = player, speed = 15, hitdist = .5, homing = homing}
    return entity
end

Reset()
player, controller, predictor = NewPlayer()
local shooter = NewEntity("spitter", 10, {_combat = true})
shooter.components.combat.weapon = NewEntity("ranged", 0, {rangedweapon = true})
controller:StartCounterAttack()
WindUp(shooter, player)
Tick(FRAMES)
Check(player.sg.counter_entries == 0, "Ranged wind-up must wait for an actual incoming projectile")
local bolt = NewProjectile(shooter, 12, true)
player:PushEvent("hostileprojectile")
Check(player.sg.counter_entries == 0, "Distant projectile must not counter before its approach")
bolt.x = 3
Tick(FRAMES)
Check(player.sg.counter_entries == 1, "Projectile trajectory must trigger counter before impact")
Check(player.damage_calls == 0, "Projectile forecast must not require receiving damage")
bolt.components.projectile.target = nil
bolt.components.projectile.owner = nil
Check(predictor:ShouldBlockAttack(shooter, bolt), "Predicted projectile must remain blockable during native Hit cleanup")
Check(not predictor:ShouldBlockAttack(shooter, bolt), "One projectile prediction must only block once")
local unknown_bolt = NewProjectile(shooter, 3, true)
Check(not predictor:ShouldBlockAttack(shooter, unknown_bolt), "Prediction must not cover another projectile from the same shooter")

Reset()
player, controller, predictor = NewPlayer()
shooter = NewEntity("spitter", 10, {_combat = true})
controller:StartCounterAttack()
bolt = NewProjectile(shooter, 3, false)
bolt.rotation = 0
player:PushEvent("hostileprojectile")
Check(player.sg.counter_entries == 0, "Projectile travelling away must not counter")
bolt.rotation = 180
bolt.z = 4
player:PushEvent("hostileprojectile")
Check(player.sg.counter_entries == 0, "Projectile trajectory missing the player must not counter")
bolt.z = 0
player:PushEvent("hostileprojectile")
Check(player.sg.counter_entries == 1, "Intersecting straight trajectory must counter")
bolt.x = 5
Tick(FRAMES)
Check(not predictor:ShouldBlockAttack(shooter, bolt), "Increasing arrival time must disarm an early projectile forecast")
bolt.x = 3
Tick(FRAMES)
Check(player.sg.counter_entries == 1, "Trajectory updates must not counter the same projectile repeatedly")
bolt.rotation = 0
Tick(FRAMES)
Check(not predictor:ShouldBlockAttack(shooter, bolt), "Projectile turning away must invalidate guard")
Tick(FRAMES)
bolt.rotation = 180
Tick(FRAMES)
Check(player.sg.counter_entries == 1, "Temporary trajectory misses must preserve per-flight deduplication")
bolt.components.projectile.start = {}
Tick(3 * FRAMES, true)
Check(player.sg.counter_entries == 2, "A new throw of a reused projectile must start a new prediction")
bolt.valid = false
Tick(FRAMES)
Check(predictor.projectiles[bolt] == nil, "Removed projectile must release its prediction record")

Reset()
player, controller, predictor = NewPlayer()
shooter = NewEntity("spitter", 10, {_combat = true})
controller:StartCounterAttack()
bolt = NewProjectile(shooter, 3, true)
bolt:AddTag("FX")
player:PushEvent("hostileprojectile")
Check(player.sg.counter_entries == 1, "FX-tagged projectiles must remain detectable")
shooter.dead = true
Check(predictor:ShouldBlockAttack(shooter, bolt), "Predicted projectile must remain dangerous after its shooter dies")

Reset()
player, controller, predictor = NewPlayer()
hound = NewEntity("hound", 2, {_combat = true})
controller:StartCounterAttack()
WindUp(hound, player)
hound.sg.tags.counterattack = true
Tick(FRAMES)
Check(player.sg.counter_entries == 0, "Counterattacks must not create recursive prediction loops")
hound.sg.tags.counterattack = nil
player.bufferedaction = {}
controller:AddSkill("queued_skill", {tag = "queued_skill"})
controller.active_skill = "queued_skill"
player:AddTag("queued_skill")
Tick(FRAMES)
Check(player.bufferedaction == nil and not player:HasTag("queued_skill"), "Prediction must clear buffered actions and queued skills")
Check(controller.auto_counter_attack, "Clearing a queued skill must preserve predictive mode")

Reset()
player, controller, predictor = NewPlayer()
controller:StartCounterAttack()
Check(not predictor:ShouldBlockAttack(nil), "Missing attacker must not be treated as a prediction")
player.inspskill = true
Check(player.components.combat:GetAttacked(nil, 10), "Other skills must retain their existing damage immunity")
player.inspskill = nil
player.sg.tags.mdodgeing = true
Check(player.components.combat:GetAttacked(nil, 10), "Dodge must retain its existing damage immunity")
player.sg.tags.mdodgeing = nil
player.hand = nil
hound = NewEntity("hound", 2, {_combat = true})
WindUp(hound, player)
Tick(FRAMES)
Check(player.sg.counter_entries == 0, "Losing the weapon must prevent prediction")
controller:StartCounterAttack()
Check(not predictor.enabled, "Disabling must work without a weapon")

for _, field in ipairs({"frozen", "asleep", "riding", "dead", "heavy"}) do
    Reset()
    player, controller, predictor = NewPlayer()
    hound = NewEntity("hound", 2, {_combat = true})
    controller:StartCounterAttack()
    player[field] = true
    WindUp(hound, player)
    Tick(FRAMES)
    Check(player.sg.counter_entries == 0, field .. " must prevent prediction")
end
for _, tag in ipairs({"nointerrupt", "noattack"}) do
    Reset()
    player, controller, predictor = NewPlayer()
    controller:StartCounterAttack()
    player.sg.tags[tag] = true
    hound = NewEntity("hound", 2, {_combat = true})
    WindUp(hound, player)
    Tick(FRAMES)
    Check(player.sg.counter_entries == 0, tag .. " must not be interrupted by prediction")
end
for _, event in ipairs({"mounted", "death", "ms_playerreroll"}) do
    Reset()
    player, controller, predictor = NewPlayer()
    controller:StartCounterAttack()
    player:PushEvent(event)
    Check(not predictor.enabled and not controller.auto_counter_attack, event .. " must disable prediction")
end
Reset()
player, controller, predictor = NewPlayer()
controller:StartCounterAttack()
player:PushEvent("unequip", {eslot = EQUIPSLOTS.HANDS})
Check(not predictor.enabled, "Unequipping hands must disable prediction")
controller:StartCounterAttack()
controller:CancelActiveSkill()
Check(not predictor.enabled, "Skill cancel must disable prediction")
controller:StartCounterAttack()
predictor:OnEntitySleep()
Check(next(player.updating) == nil, "Entity sleep must stop scans")
predictor:OnEntityWake()
Check(player.updating[predictor], "Entity wake must resume enabled prediction")
controller:OnRemoveFromEntity()
Check(not predictor.enabled and next(player.updating) == nil, "Controller removal must stop prediction")
predictor:OnRemoveFromEntity()
Check(#player.listeners.hostileprojectile == 0, "Predictor removal must remove event listeners")

Reset()
local other, other_controller = NewPlayer()
player, controller, predictor = NewPlayer()
controller:StartCounterAttack()
hound = NewEntity("hound", 2, {_combat = true})
WindUp(hound, other)
Tick(FRAMES)
Check(player.sg.counter_entries == 0 and other.sg.counter_entries == 0, "Prediction must not counter attacks aimed at another player")
other_controller:StartCounterAttack()
Tick(FRAMES)
Check(other.sg.counter_entries == 1 and player.sg.counter_entries == 0, "Each player must own independent predictions")
hound.valid = false
Tick(3 * FRAMES, true)
Check(other.components.combat.attack_calls == nil, "Counter must not attack a removed target or fall back to combat.target")
Check(other.sg.statemem.counter_committed, "Invalid target must still release the pending counter chain")

-- Exercise the shipped StateGraphInstance, including native statemem resets.
require("stategraph")
TheWorld = {ismastersim = true}
SGTagsToEntTags = {}
ModManager = {GetPostInitData = function() return {} end, GetPostInitFns = function() return {} end}
local native_counter = dofile("postinit/stategraphs/skills/counter_attack.lua").states[1]
local legacy_start = dofile("postinit/stategraphs/skills/start_counter_attack.lua")
Reset()
player, controller, predictor = NewPlayer()
hound = NewEntity("hound", 2, {_combat = true})
player.sg = StateGraphInstance(StateGraph("counter_test", {
    State{name = "idle"},
    native_counter,
}, {}, "idle"), player)
hound.sg = StateGraphInstance(StateGraph("attacker_test", {
    State{name = "idle"},
    State{
        name = "attack",
        tags = {"attack", "busy"},
        onenter = function(inst, target)
            inst.components.combat:StartAttack()
            inst.sg.statemem.target = target
        end,
        timeline = {
            TimeEvent(16 * FRAMES, function(inst)
                inst.components.combat:DoAttack(inst.sg.statemem.target)
            end),
        },
    },
}, {}, "idle"), hound)
player.sg:GoToState("idle")
hound.sg:GoToState("idle")
legacy_start.events[1].fn(player)
Check(predictor.enabled, "Legacy start event must enable predictive mode")
hound.components.combat.target = player
hound.sg:GoToState("attack", player)
now = now + FRAMES
predictor:OnUpdate(FRAMES)
Check(player.sg:HasStateTag("counterattack"), "Native SG must enter counter during enemy wind-up")
Check(player.damage_calls == 0, "Native SG prediction must precede the hit timeline")
Check(not player.inspskill, "Native counter must not enable blanket skill immunity")
for _ = 1, 4 do
    now = now + FRAMES
    player.sg:UpdateState(FRAMES)
    hound.sg:UpdateState(FRAMES)
    predictor:OnUpdate(FRAMES)
end
Check(player.sg.statemem.counter_committed and player.components.combat.attack_calls == 1,
    "Native counter timeline must commit exactly one attack")
player.sg:GoToState("idle")
Check(player.components.combat.range == TUNING.DEFAULT_ATTACK_RANGE,
    "Native counter exit must restore combat range")
for _ = 1, 13 do
    now = now + FRAMES
    hound.sg:UpdateState(FRAMES)
    predictor:OnUpdate(FRAMES)
end
Check(hound.components.combat.attack_calls == 1 and player.damage_calls == 0,
    "Native delayed enemy strike must use its existing prediction")
now = now + FRAMES
hound.sg:GoToState("attack", player)
now = now + FRAMES
predictor:OnUpdate(FRAMES)
Check(player.sg:HasStateTag("counterattack") and player.sg.statemem.counter_committed == nil,
    "Native state reentry must allow a new counter without cooldown")
legacy_start.events[1].fn(player)
Check(not predictor.enabled, "Legacy start event must also disable predictive mode")
print(string.format("PASS: %d predictive counter checks", checked))
