-- Run from the mod directory: lua tests/kiritzuka_boss_slam.lua
package.path = "scripts/?.lua;" .. package.path
FRAMES = 1 / 30
COLLISION = { GROUND = 1 }
CAMERASHAKE = { VERTICAL = 1 }
TUNING = {
    KIRITZUKA_BOSS_SLAM = { DAMAGE = 600, HITS = 5, IMPACT_BURSTS = 0, HIT_BURSTS = 0, BURST_RADIUS = 2, BURST_DAMAGE_MULT = 0.25, BURST_SPREAD = 0.5, RADIUS = 6, RANGE = 20, COOLDOWN = 20, CRATER_DURATION = 12, ARMED_ATTACK_RANGE = 16,
        LANDING_DISTANCE = { small = 2, default = 3, large = 4 } },
    GAMEMODE_STARTING_ITEMS = { DEFAULT = { KIRITZUKA = {} } },
    KIRITZUKA_ARMOR_BREAK = { STEP = 0.05, MAX_STACKS = 10, WINDOW = 5 },
}
TUNING.KIRITZUKA_SKILL_COOLDOWNS = true
STRINGS = dofile("strings/common.lua")
TheNet = { GetServerGameMode = function() return "default" end }
package.loaded["components/spdamageutil"] = {}
TUNING.KIRITZUKA_CRIT = { CHANCE = { 0.1, 0.15, 0.2, 0.25 }, MULTIPLIER = { 1.5, 1.5, 1.5, 2 }, CHANCE_STEP = 0, MOMENTUM_GAIN = 5, FX_COUNT = 3, FX_TOWARD = 0.85 }
-- Never crit here; the crit rolls have their own test.
math.random = function() return 1 end
State = function(def) return def end
TimeEvent = function(time, fn) return { time = time, fn = fn } end
EventHandler = function(name, fn) return { name = name, fn = fn } end
Asset = function() end
FlattenTree = function(tree) return tree[1] end
ShakeAllCameras = function() end
local entities, effects = {}, {}
local unsafe, blocked, hole = false, false, false
local on_boat = false
local ocean_from
TheWorld = {
    ismastersim = true,
    Map = {
        IsPassableAtPoint = function() return not unsafe end,
        IsGroundTargetBlocked = function() return blocked end,
        IsPointNearHole = function() return hole end,
        IsOceanTileAtPoint = function(_, x) return ocean_from ~= nil and x >= ocean_from end,
        GetPlatformAtPoint = function(_, x) return on_boat and {} or nil end,
    },
}
TheSim = {
    FindEntities = function(_, x, y, z, radius)
        local found = {}
        for _, entity in ipairs(entities) do
            if (entity.x - x)^2 + (entity.z - z)^2 <= radius^2 then
                found[#found + 1] = entity
            end
        end
        return found
    end,
}
SpawnPrefab = function(name)
    local effect = { name = name, SetTarget = function() end }
    effect.Transform = {
        SetPosition = function(_, x, y, z) effect.x, effect.z = x, z end,
        SetScale = function(_, x) effect.scale = x end,
    }
    effects[#effects + 1] = effect
    return effect
end

local function Entity(x, tags)
    local inst = { x = x or 0, z = 0, tags = tags or {}, components = {}, damage = 0 }
    function inst:IsValid() return not self.invalid end
    function inst:IsInLimbo() return self.limbo == true end
    function inst:HasTag(tag) return self.tags[tag] == true end
    function inst:HasAnyTag(...)
        for _, tag in ipairs({...}) do
            if self:HasTag(tag) then return true end
        end
        return false
    end
    function inst:GetPosition() return { x = self.x, y = 0, z = self.z } end
    function inst:GetPhysicsRadius(default) return self.physics_radius or default end
    inst.replica = { combat = { CanBeAttacked = function() return not inst.untargetable end } }
    inst.Transform = {
        GetWorldPosition = function() return inst.x, 0, inst.z end,
        SetEightFaced = function() inst.faces = 8 end,
        SetFourFaced = function() inst.faces = 4 end,
    }
    inst.components.health = {
        IsDead = function() return inst.dead == true end,
        SetInvincible = function(self, value) self.invincible = value end,
    }
    inst.components.combat = {
        GetAttacked = function(_, attacker, damage)
            inst.damage = inst.damage + damage
            inst.attacker = attacker
        end,
        CanTarget = function(_, target) return not target.untargetable end,
        IsAlly = function(_, target) return target.ally == true end,
    }
    return inst
end

GLOBAL = _G
local stategraph_states = {}
AddStategraphState = function(name, state) stategraph_states[name .. "." .. state.name] = state end
AddStategraphPostInit = function() end
dofile("postinit/stategraphs/SGkiritzuka.lua")
local state = stategraph_states["wilson.kiritzuka_boss_slam"]
local common, master
package.loaded["prefabs/player_common"] = function(_, _, _, common_fn, master_fn)
    common, master = common_fn, master_fn
end
dofile("scripts/prefabs/kiritzuka.lua")
local function InPool(line, pool)
    for _, entry in ipairs(pool) do
        if entry == line then return true end
    end
    return false
end
local function Player()
    local inst = Entity(0, { player = true })
    inst.prefab = "kiritzuka"
    inst.mask = 123
    inst.shadow = true
    inst.components.health.invincible = false
    inst.components.timer = {
        TimerExists = function() return inst.cooldown ~= nil end,
        StartTimer = function(_, name, duration)
            assert(name == "kiritzuka_boss_slam")
            inst.cooldown = duration
        end,
    }
    inst.components.playercontroller = { IsEnabled = function() return not inst.disabled end }
    inst.components.rider = { IsRiding = function() return inst.riding end }
    inst.components.inventory = { IsHeavyLifting = function() return inst.heavy end }
    inst.components.locomotor = { Stop = function() end }
    inst.components.talker = { Say = function(_, line) inst.said = line end }
    inst.weapon = { prefab = "baseballbat" }
    inst.components.combat.GetWeapon = function() return inst.weapon end
    inst.components.combat.attackrange = 2
    inst.components.combat.hitrange = 3
    inst.components.combat.SetRange = function(self, attack, hit)
        self.attackrange, self.hitrange = attack, hit or attack
    end
    inst.Physics = {
        GetCollisionMask = function() return inst.mask end,
        SetCollisionMask = function(_, mask) inst.mask = mask end,
        Stop = function() end,
        SetMotorVel = function(_, x) inst.motor = x end,
        Teleport = function(_, x, y, z) inst.x, inst.z = x, z end,
    }
    inst.DynamicShadow = { Enable = function(_, enabled) inst.shadow = enabled end }
    inst.AnimState = {
        PlayAnimation = function(_, name) inst.animation = name end,
        AnimDone = function() return true end,
    }
    inst.SoundEmitter = { PlaySound = function() end }
    function inst:ForceFacePoint(x, y, z) self.faced = { x, y, z } end
    function inst:ClearBufferedAction() self.buffered = nil end
    function inst:GetBufferedAction() return self.buffered end
    function inst:GetCurrentPlatform() return self.platform end
    function inst:Hide() self.hidden = true end
    function inst:Show() self.hidden = false end
    inst.components.hunger = { SetMax = function() end }
    inst.components.sanity = { SetMax = function() end }
    inst.components.health.SetMaxHealth = function() end
    inst.AnimState.SetScale = function() end
    function inst:AddComponent() end
    function inst:ListenForEvent() end
    function inst:DoTaskInTime(_, fn, ...) fn(self, ...) end
    master(inst)
    inst.sg = { statemem = {}, tags = {} }
    function inst.sg:HasStateTag(tag) return self.tags[tag] == true end
    function inst.sg:AddStateTag(tag) self.tags[tag] = true end
    function inst.sg:RemoveStateTag(tag) self.tags[tag] = nil end
    function inst.sg:SetTimeout(timeout) self.timeout = timeout end
    function inst.sg:GoToState(name, data)
        if self.currentstate == state.name then state.onexit(inst) end
        self.currentstate = name
        self.statemem = {}
        self.tags = {}
        if name == state.name then
            for _, tag in ipairs(state.tags) do self.tags[tag] = true end
            state.onenter(inst, data)
        end
    end
    return inst
end

-- Press the key, then attack: the attack action routes into the armed state.
local function Start(inst, target)
    if not inst:ToggleSlam() then
        return false
    end
    inst.buffered = { target = target }
    inst.sg:GoToState(state.name)
    return inst.sg.currentstate == state.name
end

local function Frame(inst, frame)
    for _, event in ipairs(state.timeline) do
        if math.abs(event.time - frame * FRAMES) < 0.00001 then event.fn(inst) end
    end
end

local boss = Entity(10, { epic = true })
local other_boss = Entity(5, { boss = true })
local mob = Entity(11, {})
local player = Player()
entities = { mob }
local skill = STRINGS.SKILL
-- Pressing only readies the slam: no state change, a line, and a longer reach.
assert(player:ToggleSlam() and player:IsSlamArmed())
assert(player.said == skill.KIRITZUKA_SLAM_READY and player.sg.currentstate == nil)
assert(player.components.combat.attackrange == 16 and player.components.combat.hitrange == 3)
assert(player.cooldown == nil, "Readying does not cost the cooldown")
-- A second press stands down and restores the reach.
assert(player:ToggleSlam() and not player:IsSlamArmed())
assert(player.said == skill.KIRITZUKA_SLAM_CANCEL)
assert(player.components.combat.attackrange == 2 and player.components.combat.hitrange == 3)
-- Death clears a readied slam.
assert(player:ToggleSlam())
player:DisarmSkill()
assert(not player:IsSlamArmed() and player.components.combat.attackrange == 2)
player:DisarmSkill()
assert(player.components.combat.attackrange == 2, "Disarm is idempotent")
-- Pressing during cooldown only speaks.
player.components.timer.TimerExists = function() return true end
player.said = nil
assert(not player:ToggleSlam() and not player:IsSlamArmed())
assert(player.said == skill.KIRITZUKA_SLAM_COOLDOWN)
player.components.timer.TimerExists = function() return player.cooldown ~= nil end
-- The attack's own target decides; any attackable creature qualifies.
assert(Start(player, mob) and player.sg.statemem.target == mob)
assert(not player:IsSlamArmed() and player.components.combat.attackrange == 2, "Release spends the readied slam")
assert(player.buffered == nil, "The attack action is consumed")
player.sg:GoToState("idle")
-- A rejected release speaks, spends the readied slam and leaves no cooldown.
player.said = nil
assert(not Start(player, {}), "Malformed target must not crash")
assert(player.said == skill.REFUSE_RELEASE and not player:IsSlamArmed())
assert(player.cooldown == nil)
player.sg:GoToState("idle")

entities = { boss, other_boss, mob }
for _, flag in ipairs({ "invalid", "dead", "limbo", "untargetable", "ally" }) do
    boss[flag] = true
    assert(not Start(player, boss), flag)
    boss[flag] = nil
end
boss.x = 21
assert(not Start(player, boss), "Reject distant bosses")
boss.x = 10
for _, flag in ipairs({ "disabled", "riding", "heavy", "dead" }) do
    player[flag] = true
    assert(not Start(player, boss), flag)
    player[flag] = nil
end
player.tags.playerghost = true
assert(not Start(player, boss))
player.tags.playerghost = nil
for _, tag in ipairs({ "busy", "dead", "sleeping", "frozen", "jumping" }) do
    player.sg.tags[tag] = true
    assert(not Start(player, boss), tag)
    player.sg.tags[tag] = nil
end
unsafe = true
assert(not Start(player, boss))
unsafe, blocked = false, true
assert(not Start(player, boss))
blocked, hole = false, true
assert(not Start(player, boss))
hole = false

effects = {}
assert(Start(player, boss))
assert(player.cooldown == nil, "Cooldown starts at takeoff")
Frame(player, 8)
assert(player.cooldown == 20 and player.mask == COLLISION.GROUND)
assert(player.components.health.invincible and player.shadow, "The ground shadow stays visible along the arc")
assert(player.animation == "atk_leap" and player.faces == 8, "The arc comes from the leap animation")
assert(math.abs(player.motor - 6 / (12 * FRAMES)) < 0.0001, "Fly only up to the landing distance")
assert(player.faced[1] == 6)
assert(not player.hidden, "The player stays visible during the whole jump")
assert(effects[1].name == "kiritzuka_crater_fx" and effects[1].x == 0)
assert(not Start(player, boss), "Repeated input cannot interrupt the skill")
state.events[1].fn(player)
assert(not player.hidden and player.x == 0, "Animation end mid-flight changes nothing")
boss.x = 12
Frame(player, 20)
assert(player.x == 8 and player.motor == 0 and not player.hidden, "Land short of the moved target")
assert(player.faced[1] == 12, "Face the target on landing")

local ally = Entity(12, {})
ally.ally = true
local companion = Entity(12, { companion = true })
local bystander = Entity(12, { player = true })
local structure = Entity(12, { structure = true })
local nest = Entity(12, { structure = true })
nest.components.childspawner = {}
local far = Entity(19, {})
entities = { boss, mob, ally, companion, bystander, structure, nest, far }
Frame(player, 21)
assert(player.mask == 123 and player.shadow and not player.components.health.invincible)
assert(boss.damage == 120 and mob.damage == 120 and boss.attacker == player, "The landing is the first of five hits")
assert(player.sg:HasStateTag("nointerrupt"), "The sequence cannot be interrupted")
state.events[1].fn(player)
assert(player.sg.currentstate == state.name, "Animation end cannot cut the hits short")
mob.dead = true
for _, frame in ipairs({ 26, 31, 36 }) do Frame(player, frame) end
assert(boss.damage == 480 and mob.damage == 120, "Each hit damages whatever is still alive there")
mob.dead = nil
assert(not player.sg.statemem.finished)
Frame(player, 41)
assert(boss.damage == 600, "Five hits add up to the full damage")
assert(nest.damage == 600, "A monster nest is a target like any other")
assert(player.sg.statemem.finished and not player.sg:HasStateTag("nointerrupt"))
for _, target in ipairs({ ally, companion, bystander, structure, far }) do
    assert(target.damage == 0, "Protect allies, players, structures and targets outside radius")
end
assert(effects[3].name == "kiritzuka_crater_fx" and effects[3].x == 10, "Impact fx sit between player and target")

-- Without a live target, or with unsafe ground between them, the fx fall back to the landing point.
effects = {}
local lost_target = Entity(12, {})
lost_target.invalid = true
player:DoSlamImpact({ x = 8, y = 0, z = 0 }, lost_target)
assert(effects[1].x == 8, "A lost target centers the impact on the landing")
effects = {}
blocked = true
player:DoSlamImpact({ x = 8, y = 0, z = 0 }, Entity(12, {}))
blocked = false
assert(effects[1].x == 8, "Unsafe ground centers the impact on the landing")
state.events[1].fn(player)
assert(player.sg.currentstate == "idle" and player.x == 8 and player.faces == 4)
assert(not Start(player, boss), "Cooldown remains after recovery")

for _, frame in ipairs({ 0, 8, 20 }) do
    local inst = Player()
    assert(Start(inst, boss))
    if frame >= 8 then Frame(inst, 8) end
    if frame >= 20 then Frame(inst, 20) end
    inst.sg:GoToState("death")
    assert(inst.x == 0 and inst.mask == 123 and inst.shadow and not inst.hidden and inst.motor == 0)
    assert(not inst.components.health.invincible, "Interruption must restore immunity")
end

for _, failure in ipairs({ "invalid", "dead", "range", "terrain" }) do
    local inst = Player()
    assert(Start(inst, boss))
    Frame(inst, 8)
    if failure == "range" then boss.x = 100
    elseif failure == "terrain" then blocked = true
    else boss[failure] = true end
    Frame(inst, 20)
    if failure == "terrain" then
        assert(inst.sg.currentstate == "idle" and inst.x == 0 and inst.mask == 123, "Unsafe landing aborts")
    else
        assert(inst.sg.currentstate == state.name and inst.x == 8, failure .. " keeps the planned landing")
        Frame(inst, 21)
        assert(inst.sg.statemem.impacted and inst.mask == 123, failure .. " still lands and impacts")
    end
    boss.x, boss.invalid, boss.dead, blocked = 12, nil, nil, false
end
local inst = Player()
inst.components.health.invincible = true
assert(Start(inst, boss))
Frame(inst, 8)
Frame(inst, 20)
boss.dead = true
Frame(inst, 21)
assert(inst.x == 8 and inst.components.health.invincible, "Preserve existing invincibility")
boss.dead = nil

-- Landing distance by target type, spacing from physics and blocked approaches.
local function Landing(target, from)
    local inst = Player()
    inst.x = from or 0
    return inst:GetSlamLanding(target, { x = inst.x, y = 0, z = 0 })
end
assert(Landing(Entity(10, {})).x == 7, "Default creatures land 3 away")
assert(Landing(Entity(10, { smallcreature = true })).x == 8, "Small creatures land 2 away")
assert(Landing(Entity(10, { largecreature = true })).x == 6, "Large creatures land 4 away")
local wide = Entity(10, {})
wide.physics_radius = 3
assert(Landing(wide).x == 6, "Wide bodies push the landing out")
wide.physics_radius = 20
assert(Landing(wide).x == 5, "The impact must still reach the target")
local hop = Landing(Entity(10, {}), 8)
assert(hop.x == 8 and hop.z == 0, "Close targets are not backed away from")
local real_passable = TheWorld.Map.IsPassableAtPoint
TheWorld.Map.IsPassableAtPoint = function(_, x, _, z) return not (x < 8 and math.abs(z) < 0.01) end
local around = Landing(Entity(10, {}))
assert(around.z ~= 0 and (around.x - 10) ^ 2 + around.z ^ 2 - 9 < 0.0001, "Blocked approach moves around the target")
TheWorld.Map.IsPassableAtPoint = function() return false end
assert(Landing(Entity(10, {})) == nil, "No safe side means no landing")
TheWorld.Map.IsPassableAtPoint = real_passable
local weak = Entity(10, { smallcreature = true })
weak.untargetable = true
assert(Landing(weak) == nil)

-- Owner-only input registration, HUD gating and cleanup use the existing component.
net_byte = function() return { set = function() end } end
net_tinybyte = net_byte
KEY_V = 118
KEY_B = 98
local dash_input_fn
KEY_G = 103
KEY_M = 109
KEY_K = 107
KEY_H = 104
M_CONFIG = { KiritzukaSlamKey = KEY_V, KiritzukaDashKey = KEY_B, KiritzukaCounterKey = KEY_G, KiritzukaHomeRunKey = KEY_M, KiritzukaDestroyKey = KEY_K, KiritzukaFlurryKey = KEY_H }
local homerun_input_fn
local input_fn, registrations, calls = nil, 0, 0
local input_listener
local hud = true
TheInput = {
    onspecialkey = { RemoveHandler = function() end },
    GetWorldEntityUnderMouse = function() return boss end,
    AddSpecialKeyHandler = function(_, key, fn)
        if key ~= KEY_V then
            if key == KEY_B then
                dash_input_fn = fn
            elseif key == KEY_M then
                homerun_input_fn = fn
            else
                assert(key == KEY_G or key == KEY_K or key == KEY_H)
            end
            return {}
        end
        input_fn = fn
        registrations = registrations + 1
        input_listener = { fn = fn }
        return input_listener
    end,
}
local function InputPlayer()
    local p = Player()
    p.MiniMapEntity = { SetIcon = function() end }
    function p:AddTag(tag) self.tags[tag] = true end
    function p:ListenForEvent(event, fn) self[event] = fn end
    function p:AddComponent(name)
        assert(name == "playerkeyhandler")
        self.components[name] = {
            HandleKeyAction = function(_, namespace, action, target)
                assert(namespace == "LouisManutsawee" and action == "KiritzukaBossSlam")
                assert(target == nil, "The key sends no target")
                if hud then calls = calls + 1 end
                return hud
            end,
            RememberHandler = function(_, processor, event, listener, state, remover)
                assert(processor == TheInput.onspecialkey and event == "onspecialkey")
                assert(remover == processor.RemoveHandler)
            end,
        }
    end
    common(p)
    return p
end
local owner, remote = InputPlayer(), InputPlayer()
ThePlayer = owner
remote.setowner(remote)
assert(registrations == 0)
owner.setowner(owner)
owner.setowner(owner)
assert(registrations == 1)
input_fn(KEY_V, true)
input_fn(KEY_V, true)
assert(calls == 1, "Held keys must not retrigger")
input_fn(KEY_V, false)
hud = false
input_fn(KEY_V, true)
assert(calls == 1, "HUD input block must be respected")
input_fn(KEY_V, false)
ThePlayer = remote
input_fn(KEY_V, true)
assert(calls == 1, "Old owner must not send input")

-- The dash key just asks for the dash to be readied, once per press.
local dash_sent
local dash_handler = owner.components.playerkeyhandler.HandleKeyAction
owner.components.playerkeyhandler.HandleKeyAction = function(_, namespace, action, target)
    assert(namespace == "LouisManutsawee" and action == "KiritzukaDash")
    assert(target == nil, "The key sends no target")
    dash_sent = (dash_sent or 0) + 1
    return true
end
ThePlayer = owner
dash_input_fn(KEY_B, true)
dash_input_fn(KEY_B, true)
dash_input_fn(KEY_B, false)
dash_input_fn(KEY_B, true)
assert(dash_sent == 2, "Held keys must not retrigger the dash")
owner.components.playerkeyhandler.HandleKeyAction = dash_handler

-- The home run key reports both ends of the press, and nothing about the cursor.
local homerun_sent = {}
local homerun_handler = owner.components.playerkeyhandler.HandleKeyAction
owner.components.playerkeyhandler.HandleKeyAction = function(_, namespace, action, x, z)
    assert(namespace == "LouisManutsawee" and x == nil and z == nil)
    homerun_sent[#homerun_sent + 1] = action
    return true
end
ThePlayer = owner
homerun_input_fn(KEY_M, true)
homerun_input_fn(KEY_M, true)
homerun_input_fn(KEY_M, false)
homerun_input_fn(KEY_M, false)
assert(#homerun_sent == 2 and homerun_sent[1] == "KiritzukaHomeRunStart" and homerun_sent[2] == "KiritzukaHomeRunRelease")
owner.components.playerkeyhandler.HandleKeyAction = homerun_handler

-- Exercise the registered RPC and the real host/client input bridge.
local native_scripts = arg[1] or "../../data/databundles/scripts/"
package.path = native_scripts .. "?.lua;" .. package.path
require("class")
GLOBAL = _G
env = {}
dofile("main/constants.lua")
local handlers = {}
AddModRPCHandler = function(namespace, name, fn) handlers[name] = fn end
AddClientModRPCHandler = function() end
AddShardModRPCHandler = function() end
checkentity = function(value) return type(value) == "table" end
dofile("main/RPC.lua")
local rpc = handlers.KiritzukaBossSlam
assert(not handlers.KiritzukaHomeRunStart({ prefab = "wilson" }), "Other characters are refused")
assert(not handlers.KiritzukaDestruction({ prefab = "wilson" }), "Other characters are refused")
local rpc_breaker = Player()
assert(handlers.KiritzukaDestruction(rpc_breaker) and rpc_breaker.kiritzuka_destruction)
local rpc_batter = Player()
rpc_batter.StartHomeRun = function() return true end
rpc_batter.ReleaseHomeRun = function() return true end
assert(handlers.KiritzukaHomeRunStart(rpc_batter) and handlers.KiritzukaHomeRunRelease(rpc_batter))
local rpc_dasher = Player()
rpc_dasher.ToggleDash = function() return true end
assert(handlers.KiritzukaDash(rpc_dasher))
assert(not handlers.KiritzukaDash({ prefab = "wilson" }), "Other characters are refused")
local rpc_player = Player()
rpc_player.prefab = "wilson"
assert(not rpc(rpc_player))
rpc_player.prefab = "kiritzuka"
assert(rpc(rpc_player) and rpc_player:IsSlamArmed())
assert(rpc(rpc_player) and not rpc_player:IsSlamArmed())
GetModRPCHandler = function(_, action) return handlers[action] end
GetModRPC = function(namespace, action) return namespace .. "." .. action end
local sent
SendModRPCToServer = function(id, target) sent = { id, target } end
TheFrontEnd = { GetActiveScreen = function() return { name = "HUD" } end }
rpc_player.HUD = {
    IsCraftingOpen = function() return false end,
    HasInputFocus = function() return false end,
}
local bridge = require("components/playerkeyhandler")(rpc_player)
TheWorld.ismastersim = true
assert(bridge:HandleKeyAction("LouisManutsawee", "KiritzukaBossSlam"))
assert(rpc_player:IsSlamArmed() and sent == nil)
rpc_player:DisarmSkill()
TheWorld.ismastersim = false
assert(bridge:HandleKeyAction("LouisManutsawee", "KiritzukaBossSlam"))
assert(sent[1] == "LouisManutsawee.KiritzukaBossSlam" and sent[2] == nil)
assert(not rpc_player:IsSlamArmed(), "Client only sends the request")
TheFrontEnd.textProcessorWidget = {}
sent = nil
assert(not bridge:HandleKeyAction("LouisManutsawee", "KiritzukaBossSlam"))
assert(sent == nil)
TheFrontEnd.textProcessorWidget = nil
require("events")
local processor = EventProcessor()
local received = 0
local listener = processor:AddEventHandler("key", function() received = received + 1 end)
bridge:RememberHandler(processor, "key", listener, nil, processor.RemoveHandler)
processor:HandleEvent("key")
assert(received == 1)
bridge:OnRemoveEntity()
processor:HandleEvent("key")
assert(received == 1 and #bridge.handlers == 0, "Remove the native event handle on entity removal")

-- Craters are networked, non-persistent visuals with no gameplay components.
local crater_fn
Prefab = function(_, fn) crater_fn = fn end
ANIM_ORIENTATION = { OnGround = 1 }
LAYER_BACKGROUND = 1
ErodeAway = function(fx) fx.eroded = true end
CreateEntity = function()
    local fx = { components = {}, tags = {} }
    local noop = function() end
    fx.entity = {
        AddTransform = noop, AddAnimState = noop,
        AddNetwork = function() fx.networked = true end,
        SetPristine = function() fx.pristine = true end,
    }
    fx.Transform = { SetEightFaced = noop }
    fx.AnimState = {
        SetBank = noop, SetBuild = noop, PlayAnimation = noop,
        SetOrientation = noop, SetLayer = noop, SetSortOrder = noop, SetScale = noop,
    }
    function fx:AddTag(tag) self.tags[tag] = true end
    function fx:DoTaskInTime(delay, fn) self.delay, self.expire = delay, fn end
    return fx
end
dofile("scripts/prefabs/kiritzuka_crater_fx.lua")
TheWorld.ismastersim = false
local client_fx = crater_fn()
assert(client_fx.networked and client_fx.pristine and not client_fx.persists)
assert(client_fx.tags.FX and client_fx.tags.NOCLICK and client_fx.expire == nil)
TheWorld.ismastersim = true
local server_fx = crater_fn()
assert(server_fx.delay == 12 and next(server_fx.components) == nil)
server_fx.expire(server_fx)
assert(server_fx.eroded)

-- At sea the slam is refused outright, with its own lines.
do
    local sailor = Player()
    sailor.platform = {}
    assert(not sailor:ToggleSlam() and not sailor:IsSlamArmed(), "No readying on a boat")
    assert(InPool(sailor.said, skill.KIRITZUKA_SLAM_SEA) and sailor.cooldown == nil)
    assert(sailor.components.combat.attackrange == 2)

    sailor = Player()
    assert(sailor:ToggleSlam())
    sailor.platform = {}
    assert(sailor:ToggleSlam() and not sailor:IsSlamArmed(), "A readied slam can still be put away on a boat")
    assert(sailor.said == skill.KIRITZUKA_SLAM_CANCEL)

    sailor = Player()
    assert(sailor:ToggleSlam())
    sailor.platform = {}
    sailor.buffered = { target = Entity(10, {}) }
    sailor.sg:GoToState(state.name)
    assert(sailor.sg.currentstate == "idle" and InPool(sailor.said, skill.KIRITZUKA_SLAM_SEA), "Stepping aboard spends it")
    assert(sailor.cooldown == nil and sailor.components.combat.attackrange == 2)

    sailor = Player()
    ocean_from = 8
    assert(sailor:ToggleSlam())
    sailor.buffered = { target = Entity(10, {}) }
    sailor.sg:GoToState(state.name)
    ocean_from = nil
    assert(sailor.sg.currentstate == "idle" and InPool(sailor.said, skill.KIRITZUKA_SLAM_SEA), "A target on the water too")

    sailor = Player()
    sailor.weapon = { prefab = "spear" }
    sailor.platform = {}
    sailor:ToggleSlam()
    assert(InPool(sailor.said, skill.KIRITZUKA_SLAM_SEA), "The sea is mentioned first when both apply")
end

-- On a boat there is no crater to leave behind, but the rest of the impact plays.
do
    effects = {}
    on_boat = true
    local boat_player = Player()
    boat_player:DoSlamImpact({ x = 0, y = 0, z = 0 })
    on_boat = false
    local rings = 0
    for _, effect in ipairs(effects) do
        assert(effect.name ~= "kiritzuka_crater_fx", "No crater on a boat")
        if effect.name == "kiritzuka_slam_ring_fx" then rings = rings + 1 end
    end
    assert(rings > 0, "The shockwave still plays")
end

-- Only the exclusive weapons can ready or release the slam.
for _, weapon in ipairs({ false, "pickaxe", "spear", "nightsword" }) do
    local refused = Player()
    refused.weapon = weapon and { prefab = weapon } or nil
    assert(not refused:ToggleSlam() and not refused:IsSlamArmed(), tostring(weapon))
    assert(InPool(refused.said, skill.KIRITZUKA_WEAPON_REFUSE) and refused.components.combat.attackrange == 2)
end
for _, weapon in ipairs({ "baseballbat", "crowbar", "rebar" }) do
    local allowed = Player()
    allowed.weapon = { prefab = weapon }
    assert(allowed:ToggleSlam() and allowed:IsSlamArmed(), weapon)
end
do
    local swapped = Player()
    local swapped_target = Entity(10, {})
    entities = {}
    assert(swapped:ToggleSlam())
    swapped.weapon = nil
    swapped.buffered = { target = swapped_target }
    swapped.sg:GoToState(state.name)
    assert(swapped.sg.currentstate == "idle" and InPool(swapped.said, skill.KIRITZUKA_WEAPON_REFUSE), "Unequipping before the attack spends it")
    assert(swapped.components.combat.attackrange == 2 and swapped.cooldown == nil)

    assert(swapped:ToggleSlam() == false, "Still unarmed")
    swapped.weapon = { prefab = "rebar" }
    assert(swapped:ToggleSlam())
    swapped.weapon = nil
    assert(swapped:ToggleSlam() and not swapped:IsSlamArmed(), "A readied slam can always be put away")
end

-- The impact shockwave outdoes Bearger's single ring and dust, and each hit echoes it.
effects = {}
local shock_player = Player()
shock_player:DoSlamImpact({ x = 0, y = 0, z = 0 })
local rings, dust = {}, 0
for _, effect in ipairs(effects) do
    if effect.name == "kiritzuka_slam_ring_fx" then rings[#rings + 1] = effect.scale end
    if effect.name == "kiritzuka_slam_dust_fx" then dust = dust + 1 end
    assert(effect.name ~= "groundpoundring_fx" and effect.name ~= "groundpound_fx", "Bearger's own fx are replaced")
end
assert(#rings == 4 and rings[1] == 0.8 and rings[2] == 1.25, "Crater ring, then three stacked waves")
assert(dust == 34, "Four dust waves")
effects = {}
shock_player:DoSlamHit({ x = 0, y = 0, z = 0 }, 120)
assert(#effects == 7 and effects[1].name == "kiritzuka_slam_ring_fx", "Follow-up hits are a smaller wave")
effects = {}
unsafe = true
shock_player:DoSlamHit({ x = 0, y = 0, z = 0 }, 120)
unsafe = false
assert(#effects == 1, "No dust on impassable ground")

-- Mega Blight: every segment shares one controller, whose guard the slam breaks at any time.
local function Controller()
    local controller = { tags = { shadowthrall_centipede_controller = true }, valid = true, taken = {} }
    function controller:IsValid() return self.valid end
    function controller:HasTag(tag) return self.tags[tag] == true end
    controller.head = { PushEvent = function(_, name) controller.head_event = name end }
    controller.components = {
        health = {
            invincible = true,
            hp = 2000,
            IsDead = function(self) return self.hp <= 0 end,
            SetInvincible = function(self, value) self.invincible = value end,
        },
        combat = { tough = true },
    }
    controller.components.combat.GetAttacked = function(self, attacker, damage)
        assert(self.tough == false and controller.components.health.invincible == false, "The guard is down for the hit")
        assert(self.redirected_from ~= nil, "Planar fx land on the struck segment")
        table.insert(controller.taken, damage)
        controller.components.health.hp = controller.components.health.hp - damage
    end
    return controller
end
local function Segment(controller)
    local segment = Entity(1, {})
    segment.controller = controller
    segment.components.combat.GetAttacked = function() error("Segments must not take the hit themselves") end
    return segment
end
local blight_player = Player()
local blight = Controller()
entities = { Segment(blight), Segment(blight), Segment(blight) }
blight_player:DoSlamHit({ x = 0, y = 0, z = 0 }, 120)
assert(#blight.taken == 1 and blight.taken[1] == 120, "One hit per controller, however many segments")
assert(blight.components.combat.tough == true and blight.components.health.invincible == true, "The guard comes back")
assert(blight.components.combat.redirected_from == nil and blight.head_event == "attacked")
local struggling = Controller()
struggling.components.combat.tough = false
struggling.components.health.invincible = false
entities = { Segment(struggling) }
blight_player:DoSlamHit({ x = 0, y = 0, z = 0 }, 120)
assert(struggling.components.combat.tough == false and struggling.components.health.invincible == false,
    "A struggling Blight stays open")
local dying = Controller()
dying.components.health.hp = 100
entities = { Segment(dying), Segment(dying) }
blight_player:DoSlamHit({ x = 0, y = 0, z = 0 }, 120)
assert(dying.components.health:IsDead() and #dying.taken == 1, "The slam can kill it")
assert(dying.components.combat.tough == false, "A dead Blight keeps its guard down")
entities = { Segment(dying) }
blight_player:DoSlamHit({ x = 0, y = 0, z = 0 }, 120)
assert(#dying.taken == 1, "A dead Blight takes no more hits")
local mob_with_field = Entity(1, {})
mob_with_field.controller = { HasTag = function() return false end }
entities = { mob_with_field }
blight_player:DoSlamHit({ x = 0, y = 0, z = 0 }, 120)
assert(mob_with_field.damage == 120, "Other entities with a controller field take the normal hit")

-- Random bursts land inside the range, hit only what is near them, and cannot crit.
do
    local tuning = TUNING.KIRITZUKA_BOSS_SLAM
    tuning.IMPACT_BURSTS, tuning.HIT_BURSTS = 6, 3
    local rolls = { 0, 1, 0 }
    local roll_at = 0
    local real_random = math.random
    math.random = function()
        roll_at = roll_at % #rolls + 1
        return rolls[roll_at]
    end
    local burst_player = Player()
    local near = Entity(6, {})
    local distant = Entity(-4, {})
    entities = { near, distant }
    effects = {}
    local crit_rolls = 0
    local delays = {}
    local do_task = burst_player.DoTaskInTime
    function burst_player:DoTaskInTime(delay, fn, ...)
        delays[#delays + 1] = delay
        return do_task(self, delay, fn, ...)
    end
    near.x, near.z = 6, 0
    rolls = { 0, 1, 0.25 }
    burst_player:DoSlamHit({ x = 0, y = 0, z = 0 }, 120)
    math.random = real_random
    local burst_rings = 0
    for _, effect in ipairs(effects) do
        if effect.name == "kiritzuka_slam_ring_fx" and effect.scale == 0.45 then
            burst_rings = burst_rings + 1
        end
    end
    assert(burst_rings == 3, "Each follow-up hit adds three bursts")
    assert(near.damage > 120 and (near.damage - 120) % 30 == 0, "Bursts add a quarter of the hit, never crit-scaled")
    assert(distant.damage == 120, "Only the main hit reaches the far side")
    local staggered = false
    for _, delay in ipairs(delays) do staggered = staggered or delay == 0.125 end
    assert(staggered, "Bursts are spread over time")

    effects = {}
    math.random = function() return 0 end
    Player():DoSlamImpact({ x = 0, y = 0, z = 0 })
    math.random = real_random
    burst_rings = 0
    for _, effect in ipairs(effects) do
        if effect.scale == 0.45 then burst_rings = burst_rings + 1 end
    end
    assert(burst_rings == 6, "The landing adds six bursts")

    effects = {}
    unsafe = true
    entities = {}
    math.random = function() return 0.5 end
    Player():DoSlamHit({ x = 0, y = 0, z = 0 }, 120)
    math.random = real_random
    unsafe = false
    for _, effect in ipairs(effects) do
        assert(effect.scale ~= 0.45, "No bursts on impassable ground")
    end
    tuning.IMPACT_BURSTS, tuning.HIT_BURSTS = 0, 0
end

print("PASS: arming, speech, target validation, authority, range, terrain, cooldown, damage filters, movement, interruption, input, RPC and FX lifecycle")
