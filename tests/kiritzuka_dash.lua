-- Run from the mod directory: lua tests/kiritzuka_dash.lua
package.path = "scripts/?.lua;" .. package.path
FRAMES = 1 / 30
DEGREES = math.pi / 180
COLLISION = { GROUND = 1 }
CAMERASHAKE = { VERTICAL = 1 }
TUNING = {
    GAMEMODE_STARTING_ITEMS = { DEFAULT = { KIRITZUKA = {} } },
    KIRITZUKA_BOSS_SLAM = { HITS = 5, ARMED_ATTACK_RANGE = 16 },
    KIRITZUKA_DASH = { COOLDOWN = 12, ARMED_ATTACK_RANGE = 12, RANGE = 5, WIDTH = 1.5, SEA_RANGE = 3, DAMAGE_MULT = { 1, 1, 2 } },
    KIRITZUKA_CRIT = { CHANCE = { 0 }, MULTIPLIER = { 1.5 }, CHANCE_STEP = 0, MOMENTUM_GAIN = 5, FX_COUNT = 3, FX_TOWARD = 0.85 },
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
local tick = 1
GetTick = function() return tick end
GetTime = function() return 0 end

GLOBAL = _G
GLOBAL.setfenv = function() end
local states = {}
AddStategraphState = function(name, state)
    if name == "wilson" then states[state.name] = state end
end
AddStategraphPostInit = function() end
dofile("postinit/stategraphs/SGkiritzuka.lua")
local state = assert(states.kiritzuka_dash, "The dash is registered")

local master, dependencies
package.loaded["prefabs/player_common"] = function(_, prefabs, _, _, master_fn)
    dependencies, master = prefabs, master_fn
end
dofile("scripts/prefabs/kiritzuka.lua")

local blocked_from
TheWorld = {
    Map = {
        IsPassableAtPoint = function(_, x) return blocked_from == nil or x < blocked_from end,
        IsPointNearHole = function() return false end,
        IsGroundTargetBlocked = function() return false end,
        IsOceanTileAtPoint = function(_, x) return blocked_from ~= nil and x >= blocked_from end,
        GetPlatformAtPoint = function() return nil end,
    },
}
local entities = {}
TheSim = { FindEntities = function() return entities end }
local spawned = {}
SpawnPrefab = function(name)
    local fx = { name = name, target = { set = function(self, value) self.value = value end } }
    fx.AnimState = { SetBuild = function(_, build) fx.build = build end }
    fx.Transform = {
        SetPosition = function(_, x, _, z) fx.x, fx.z = x, z end,
        SetRotation = function(_, rot) fx.rot = rot end,
        SetScale = function(_, value) fx.scale = value end,
    }
    spawned[#spawned + 1] = fx
    return fx
end

local function Player()
    local inst = { x = 0, z = 0, rot = 0, tags = {}, flags = {}, hits = {}, weapon = { prefab = "baseballbat" } }
    inst.HasTag = function(self, tag) return self.tags[tag] == true end
    inst.GetPosition = function(self) return { x = self.x, y = 0, z = self.z } end
    inst.GetCurrentPlatform = function(self) return self.platform end
    inst.AddComponent = function() end
    inst.ListenForEvent = function() end
    inst.ClearBufferedAction = function(self) self.buffered = nil end
    inst.GetBufferedAction = function(self) return self.buffered end
    inst.ForceFacePoint = function(self, x, _, z)
        self.rot = math.deg(math.atan2(-(z - self.z), x - self.x))
    end
    inst.Transform = {
        GetWorldPosition = function() return inst.x, 0, inst.z end,
        GetRotation = function() return inst.rot end,
    }
    inst.AnimState = {
        SetScale = function() end,
        SetDeltaTimeMultiplier = function(_, value) inst.anim_speed = value end,
        PlayAnimation = function(_, name) inst.animation = name end,
        IsCurrentAnimation = function(_, name) return inst.animation == name end,
        AnimDone = function() return true end,
    }
    inst.SoundEmitter = { PlaySound = function() end }
    inst.Physics = {
        Stop = function() end,
        GetCollisionMask = function() return 123 end,
        SetCollisionMask = function(_, mask) inst.mask = mask end,
        SetMotorVel = function(_, x) inst.motor = x end,
        Teleport = function(_, x, _, z) inst.x, inst.z = x, z end,
    }
    inst.components = {
        hunger = { SetMax = function() end },
        sanity = { SetMax = function() end },
        locomotor = { Stop = function() end },
        talker = { Say = function(_, line) inst.said = line end },
        playercontroller = { IsEnabled = function() return not inst.flags.disabled end },
        rider = { IsRiding = function() return inst.flags.riding end },
        inventory = { IsHeavyLifting = function() return inst.flags.heavy end },
        timer = {
            TimerExists = function() return inst.cooldown ~= nil end,
            StartTimer = function(_, name, duration)
                assert(name == "kiritzuka_dash")
                inst.cooldown = duration
            end,
        },
        health = {
            invincible = false,
            SetMaxHealth = function() end,
            IsDead = function() return inst.flags.dead end,
            SetInvincible = function(self, value) self.invincible = value end,
        },
        combat = {
            attackrange = 2,
            hitrange = 3,
            SetRange = function(self, attack, hit) self.attackrange, self.hitrange = attack, hit end,
            GetWeapon = function() return inst.weapon end,
            CanTarget = function() return true end,
            IsAlly = function() return false end,
            DoAttack = function(self, target, _, _, _, mult)
                assert(self.ignorehitrange, "Dash hits ignore weapon reach")
                inst.hits[#inst.hits + 1] = { target = target, mult = mult }
            end,
        },
    }
    inst.sg = { statemem = {}, tags = {}, currentstate = { name = "idle" } }
    function inst.sg:HasStateTag(tag) return self.tags[tag] == true end
    function inst.sg:AddStateTag(tag) self.tags[tag] = true end
    function inst.sg:RemoveStateTag(tag) self.tags[tag] = nil end
    function inst.sg:SetTimeout(value) self.timeout = value end
    function inst.sg:GoToState(name, data)
        if self.currentstate.onexit ~= nil then self.currentstate.onexit(inst) end
        local next_state = states[name]
        self.currentstate = next_state or { name = name }
        self.statemem, self.tags = {}, {}
        if next_state ~= nil then
            for _, tag in ipairs(next_state.tags) do self.tags[tag] = true end
            next_state.onenter(inst, data)
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
    enemy.GetPosition = function() return { x = enemy.x, y = 0, z = enemy.z } end
    enemy.Transform = { GetWorldPosition = function() return enemy.x, 0, enemy.z end }
    enemy.components = { health = { IsDead = function() return false end }, combat = {} }
    return enemy
end

local function Run(inst, frame)
    local mem = inst.sg.statemem
    for _, event in ipairs(state.timeline) do
        if math.abs(event.time - frame * FRAMES) < 0.0001 and inst.sg.statemem == mem then
            event.fn(inst)
        end
    end
end

local function InPool(line, pool)
    for _, entry in ipairs(pool) do
        if entry == line then return true end
    end
    return false
end

local function Near(a, b)
    return math.abs(a - b) < 0.0001
end

-- Press to ready it, then attack a target: routed in with no state data.
local function Release(inst, target)
    assert(inst:ToggleDash())
    inst.buffered = { target = target }
    inst.sg:GoToState(state.name)
    return inst.sg.currentstate == state
end

local function Dist(ax, az, bx, bz)
    return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

-- Dependencies are loaded with the character.
local found = {}
for _, name in ipairs(dependencies) do found[name] = true end
assert(found.rocky_dash_fx and found.rocky_snip_fx and found.kiritzuka_hit_fx_puff)

-- Pressing only readies it: a line, a longer reach, no state change, and a second press cancels.
local player = Player()
assert(player:ToggleDash() and player:IsDashArmed())
assert(player.sg.currentstate.name == "idle" and player.said == STRINGS.SKILL.KIRITZUKA_DASH_READY)
assert(player.components.combat.attackrange == 12 and player.cooldown == nil)
assert(player:ToggleDash() and not player:IsDashArmed())
assert(player.said == STRINGS.SKILL.KIRITZUKA_SLAM_CANCEL and player.components.combat.attackrange == 2)

-- Readying one skill puts the other away, keeping the original reach.
assert(player:ToggleSlam() and player:ToggleDash())
assert(player:IsDashArmed() and not player:IsSlamArmed())
assert(player:ToggleSlam() and player:IsSlamArmed() and not player:IsDashArmed())
player:DisarmSkill()
assert(player.components.combat.attackrange == 2 and player.components.combat.hitrange == 3)

-- Three lines through the locked target, sixty degrees apart.
player = Player()
local boss = Enemy(10, 0)
entities = {}
spawned = {}
assert(Release(player, boss))
assert(not player:IsDashArmed() and player.components.combat.attackrange == 2, "Release spends the readied dash")
assert(player.sg.statemem.dash_stage == 1 and player.sg.statemem.target == boss)
assert(player.animation == "lunge_pre" and player.anim_speed == 2 and Near(player.rot, 0), "Faces through the target")
assert(player.cooldown == nil, "Cooldown starts on launch")

Run(player, 6)
assert(player.cooldown == 12)
assert(player.components.health.invincible and player.mask == 1, "Untouchable and unblocked in flight")
assert(player.sg:HasStateTag("noattack") and player.sg:HasStateTag("jumping"))
assert(player.animation == "lunge_pst" and player.anim_speed == 1)
assert(Near(player.motor, 15.5 / (4 * FRAMES)), "Reaches through the target in four frames")
assert(spawned[1].name == "rocky_dash_fx" and spawned[1].target.value == player)
assert(spawned[1].build == "rocky_boss_shadow_build", "The red cut")

local bystander = Enemy(5, 0.5)
local off_line = Enemy(5, 5)
local ally = Enemy(5, 0)
ally.tags.companion = true
entities = { bystander, off_line, ally, boss }
Run(player, 10)
assert(Near(player.x, 15.5) and Near(player.z, 0), "Lands past the target")
assert(not player.components.health.invincible and player.mask == 123, "Restores on landing")
assert(player.sg:HasStateTag("nointerrupt"))
assert(spawned[2].name == "rocky_snip_fx" and spawned[2].x == 10 and spawned[2].rot == player.rot, "The cut crosses the target")
assert(#player.hits == 2, "The target and the line, once each")
assert(player.hits[1].target == bystander and player.hits[2].target == boss)
assert(player.hits[1].mult == 1 and player.components.combat.ignorehitrange == false)

local lines = {}
local function RecordLine(inst)
    local from, to = inst.sg.statemem.from, inst.sg.statemem.to
    lines[#lines + 1] = math.deg(math.atan2(to.z - from.z, to.x - from.x)) % 180
end
RecordLine(player)

entities = { boss }
for stage = 2, 3 do
    Run(player, 14)
    assert(player.sg.statemem.dash_stage == stage and player.sg.statemem.target == boss, "Stays locked")
    assert(Near(Dist(player.x, player.z, 10, 0), 5.5), "Starts out to the side of the target")
    Run(player, 6)
    player.cooldown = 3
    player.hits = {}
    Run(player, 10)
    RecordLine(player)
    assert(Near(Dist(player.x, player.z, 10, 0), 5.5), "Ends the same distance out")
    local from, to = player.sg.statemem.from, player.sg.statemem.to
    assert(Near((from.x + to.x) / 2, 10) and Near((from.z + to.z) / 2, 0), "The line runs through the target")
    assert(#player.hits == 1 and player.hits[1].target == boss)
    assert(player.hits[1].mult == (stage == 3 and 2 or 1), "The last line hits hardest")
end
local function SameLine(a, b)
    return Near((a - b + 90) % 180 - 90, 0)
end
assert(SameLine(lines[1], 0) and SameLine(lines[2], 60) and SameLine(lines[3], 120), "Three lines evenly apart")
assert(player.cooldown == 3, "Only the first stage starts the cooldown")
assert(not player.sg:HasStateTag("nointerrupt"))
Run(player, 14)
assert(player.sg.statemem.dash_stage == 3, "Three stages only")
state.events[1].fn(player)
assert(player.sg.currentstate.name == "idle")

-- Everything along the line is hit as the player passes it, once, and the path leaves dust behind.
do
    player = Player()
    boss = Enemy(10, 0)
    local early = Enemy(3, 1)
    local late = Enemy(9, -1)
    local beside = Enemy(5, 6)
    entities = { early, late, beside, boss }
    Release(player, boss)
    Run(player, 6)
    spawned = {}
    state.onupdate(player)
    assert(#player.hits == 0, "Nothing yet at the start line")
    player.x = 4
    state.onupdate(player)
    assert(#player.hits == 1 and player.hits[1].target == early and player.hits[1].mult == 1, "Hit in passing")
    state.onupdate(player)
    assert(#player.hits == 1, "Not hit twice")
    player.x = 12
    state.onupdate(player)
    assert(#player.hits == 3 and player.hits[2].target == late and player.hits[3].target == boss)
    Run(player, 10)
    assert(#player.hits == 3, "Landing does not hit them again")
    local dust = 0
    for _, fx in ipairs(spawned) do
        if fx.name == "kiritzuka_slam_dust_fx" then dust = dust + 1 end
    end
    assert(dust >= 3, "The path is marked")
    assert(player.sg.statemem.sweep_from == nil)
    state.onupdate(player)
    assert(#player.hits == 3, "No sweeping after landing")

    -- Each new line can hit the same enemies again.
    Run(player, 14)
    Run(player, 6)
    Run(player, 10)
    assert(#player.hits > 3, "A new line strikes again")
end

-- The locked target cannot slip the hit by moving off the line.
player = Player()
boss = Enemy(10, 0)
entities = {}
Release(player, boss)
Run(player, 6)
boss.z = 20
Run(player, 10)
assert(#player.hits == 1 and player.hits[1].target == boss)

-- The lines follow a moving target right up to launch.
player = Player()
boss = Enemy(10, 0)
entities = {}
Release(player, boss)
boss.x = 12
Run(player, 6)
assert(Near(player.sg.statemem.to.x, 17.5), "Aims through where the target is now")

-- A dead target ends the chain after the current line.
player = Player()
boss = Enemy(10, 0)
Release(player, boss)
Run(player, 6)
boss.components.health.IsDead = function() return true end
Run(player, 10)
assert(player.sg.statemem.finished and not player.sg:HasStateTag("nointerrupt"))
assert(#player.hits == 0, "A dead target takes no hit")
Run(player, 14)
assert(player.sg.statemem.dash_stage == 1)
state.events[1].fn(player)
assert(player.sg.currentstate.name == "idle")

-- A target removed mid-air keeps the planned end.
player = Player()
boss = Enemy(10, 0)
Release(player, boss)
boss.IsValid = function() return false end
Run(player, 6)
Run(player, 10)
assert(Near(player.x, 15.5) and player.sg.statemem.finished)

-- Unsafe ground pulls the far end in.
player = Player()
boss = Enemy(10, 0)
blocked_from = 13.2
Release(player, boss)
Run(player, 6)
Run(player, 10)
assert(Near(player.x, 13), "Stops at the last safe half unit")
blocked_from = nil

-- At sea the dash is one flight out past the target and home again, with splashes over open water.
local sea = assert(states.kiritzuka_dash_sea, "The sea dash is registered")
local function RunSea(inst, frame)
    for _, event in ipairs(sea.timeline) do
        if math.abs(event.time - frame * FRAMES) < 0.0001 then event.fn(inst) end
    end
end
local function CountFx(name)
    local count = 0
    for _, fx in ipairs(spawned) do
        if fx.name == name then count = count + 1 end
    end
    return count
end

player = Player()
boss = Enemy(10, 0)
blocked_from = 8
entities = { boss }
spawned = {}
Release(player, boss)
assert(player.sg.currentstate == sea, "A target on the water sends the dash out and back")
assert(player.animation == "lunge_pre" and player.cooldown == nil)
RunSea(player, 6)
assert(player.cooldown == 12 and player.components.health.invincible and player.mask == 1)
assert(Near(player.motor, 13.5 / (4 * FRAMES)), "Reaches past the target")
RunSea(player, 10)
assert(Near(player.x, 13.5), "Turns over the water, not refused")
assert(player.components.health.invincible and player.mask == 1, "Still in flight at the turn")
assert(player.sg:HasStateTag("nointerrupt") and player.sg:HasStateTag("noattack"))
assert(#player.hits == 1 and player.hits[1].target == boss and player.hits[1].mult == 1, "Hit on the way out")
assert(CountFx("splash") >= 1, "Splashes over open water")
assert(CountFx("kiritzuka_slam_dust_fx") == 0, "No dust on water")
RunSea(player, 14)
assert(Near(player.x, 0), "Home again")
assert(not player.components.health.invincible and player.mask == 123, "Restored on landing")
assert(not player.sg:HasStateTag("nointerrupt"))
assert(#player.hits == 2 and player.hits[2].mult == 2, "The way home is the finisher")
sea.events[1].fn(player)
assert(player.sg.currentstate.name == "idle")
blocked_from = nil

-- On a boat the way home follows the boat as it sails.
local boat_x = 0
local boat = {
    IsValid = function() return true end,
    Transform = { GetWorldPosition = function() return boat_x, 0, 0 end },
}
player = Player()
player.platform = boat
player.x = 2
boss = Enemy(10, 0)
entities = {}
Release(player, boss)
assert(player.sg.currentstate == sea, "On a boat even a target on land gets the round trip")
RunSea(player, 6)
RunSea(player, 10)
boat_x = 3
RunSea(player, 14)
assert(Near(player.x, 5), "Lands where the same spot on the boat now is")

-- A sunken boat falls back to where the dash began.
player = Player()
player.platform = boat
boat_x = 0
player.x = 2
boss = Enemy(10, 0)
Release(player, boss)
local gone = { IsValid = function() return false end }
player.sg.statemem.home.platform = gone
RunSea(player, 6)
RunSea(player, 10)
RunSea(player, 14)
assert(Near(player.x, 2))

-- Cut short in flight, the player is put back rather than left over the water.
player = Player()
boss = Enemy(10, 0)
blocked_from = 8
Release(player, boss)
RunSea(player, 6)
RunSea(player, 10)
player.sg:GoToState("death")
assert(Near(player.x, 0) and player.mask == 123 and not player.components.health.invincible)
blocked_from = nil

-- On land the three crossing lines stay.
player = Player()
boss = Enemy(10, 0)
assert(Release(player, boss), "Land keeps the original dash")

-- Moving onto the water mid-chain ends the chain on safe ground.
player = Player()
boss = Enemy(10, 0)
Release(player, boss)
Run(player, 6)
Run(player, 10)
assert(Near(player.x, 15.5))
blocked_from = 8
Run(player, 14)
assert(player.sg.currentstate.name == "idle", "No next line")
assert(Near(player.x, 15.5), "No blink into the water")
blocked_from = nil

-- A planned end that sailed away in flight sends the player back to where the line began.
player = Player()
boss = Enemy(10, 0)
Release(player, boss)
Run(player, 6)
blocked_from = 12
Run(player, 10)
assert(Near(player.x, 0), "Back to the start")
assert(not player.components.health.invincible)
blocked_from = nil

-- Launching from a boat over open water is fine as long as both ends are safe.
player = Player()
boss = Enemy(10, 0)
local passable = TheWorld.Map.IsPassableAtPoint
TheWorld.Map.IsPassableAtPoint = function(_, x) return x < 1 or x > 6 end
Release(player, boss)
Run(player, 6)
Run(player, 10)
TheWorld.Map.IsPassableAtPoint = passable
assert(Near(player.x, 15.5), "Crosses the gap")

-- The pre animation ending never skips ahead.
player = Player()
boss = Enemy(10, 0)
Release(player, boss)
state.events[1].fn(player)
assert(player.sg.currentstate == state)

-- Interrupted flight restores everything.
player = Player()
Release(player, Enemy(10, 0))
Run(player, 6)
player.sg:GoToState("death")
assert(not player.components.health.invincible and player.mask == 123 and player.motor == 0 and player.anim_speed == 1)

-- Refusals: the cooldown line, invalid targets, and states that cannot act.
player = Player()
player.cooldown = 5
assert(not player:ToggleDash() and not player:IsDashArmed())
assert(player.said == STRINGS.SKILL.KIRITZUKA_DASH_COOLDOWN)
assert(player.sg.currentstate.name == "idle")
for _, flag in ipairs({ "dead", "riding", "heavy", "disabled" }) do
    player = Player()
    player.flags[flag] = true
    assert(not player:ToggleDash(), flag)
end
player = Player()
player.sg.tags.busy = true
assert(not player:ToggleDash(), "Busy")
player = Player()
player.tags.playerghost = true
assert(not player:ToggleDash(), "Ghost")

player = Player()
local friend = Enemy(10, 0)
friend.tags.companion = true
assert(not Release(player, friend), "Invalid targets spend the readied dash")
assert(player.sg.currentstate.name == "idle" and player.said == STRINGS.SKILL.REFUSE_RELEASE)
assert(not player:IsDashArmed() and player.components.combat.attackrange == 2 and player.cooldown == nil)
player = Player()
assert(not Release(player, nil), "No target refuses")

-- Only the exclusive weapons can ready or release the dash.
for _, weapon in ipairs({ false, "pickaxe", "spear", "nightsword" }) do
    player = Player()
    player.weapon = weapon and { prefab = weapon } or nil
    assert(not player:ToggleDash() and not player:IsDashArmed(), tostring(weapon))
    assert(InPool(player.said, STRINGS.SKILL.KIRITZUKA_WEAPON_REFUSE) and player.components.combat.attackrange == 2)
end
for _, weapon in ipairs({ "baseballbat", "crowbar", "rebar" }) do
    player = Player()
    player.weapon = { prefab = weapon }
    assert(player:ToggleDash() and player:IsDashArmed(), weapon)
end
player = Player()
assert(player:ToggleDash())
player.weapon = nil
player.buffered = { target = Enemy(10, 0) }
player.sg:GoToState(state.name)
assert(player.sg.currentstate.name == "idle" and InPool(player.said, STRINGS.SKILL.KIRITZUKA_WEAPON_REFUSE), "Unequipping spends it")
assert(player.components.combat.attackrange == 2 and player.cooldown == nil)

-- Putting the weapon away stands a readied skill down at once, with a line instead of a late refusal.
EQUIPSLOTS = { HANDS = "hands", BODY = "body" }
player = Player()
local unequip
player.ListenForEvent = function(_, event, fn)
    if event == "unequip" then unequip = fn end
end
master(player)
assert(player:ToggleDash())
unequip(player, { eslot = EQUIPSLOTS.BODY })
assert(player:IsDashArmed(), "Other slots do not matter")
unequip(player, { eslot = EQUIPSLOTS.HANDS })
assert(not player:IsDashArmed() and player.components.combat.attackrange == 2)
assert(player.said == STRINGS.SKILL.KIRITZUKA_SLAM_CANCEL)
player.said = nil
unequip(player, { eslot = EQUIPSLOTS.HANDS })
assert(player.said == nil, "Nothing to stand down")
assert(player:ToggleSlam())
unequip(player, { eslot = EQUIPSLOTS.HANDS })
assert(not player:IsSlamArmed(), "The slam too")

-- Dying with it readied puts it away.
player = Player()
local died
player.ListenForEvent = function(_, event, fn)
    if event == "death" then died = fn end
end
master(player)
player:ToggleDash()
died(player)
assert(not player:IsDashArmed() and player.components.combat.attackrange == 2)

print("kiritzuka_dash: checks passed")
