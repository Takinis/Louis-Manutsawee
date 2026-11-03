-- Run from the mod directory: lua tests/kiritzuka_counter.lua
package.path = "scripts/?.lua;" .. package.path
FRAMES = 1 / 30
TUNING = {
    GAMEMODE_STARTING_ITEMS = { DEFAULT = { KIRITZUKA = {} } },
    KIRITZUKA_BOSS_SLAM = { HITS = 5, ARMED_ATTACK_RANGE = 16 },
    KIRITZUKA_DASH = { ARMED_ATTACK_RANGE = 12 },
    KIRITZUKA_COUNTER = {
        WINDOW = 0.5, WHIFF_TIME = 0.5, COOLDOWN = 8, SUCCESS_COOLDOWN = 2,
        DAMAGE_MULT = 2, BLOCKED_DAMAGE_MULT = 0.5, MOMENTUM_GAIN = 15,
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
package.loaded["components/spdamageutil"] = {
    CalcTotalDamage = function(tbl)
        local total = 0
        for _, value in pairs(tbl or {}) do total = total + value end
        return total
    end,
}
local tick = 1
GetTick = function() return tick end
GetTime = function() return 0 end
DiffAngle = function(a, b)
    local diff = math.abs(a - b) % 360
    return diff > 180 and 360 - diff or diff
end

GLOBAL = _G
GLOBAL.setfenv = function() end
local states = {}
AddStategraphState = function(name, state)
    if name == "wilson" then states[state.name] = state end
end
AddStategraphPostInit = function() end
dofile("postinit/stategraphs/SGkiritzuka.lua")
local stance = assert(states.kiritzuka_counter)
local swing = assert(states.kiritzuka_counter_swing)

local master
package.loaded["prefabs/player_common"] = function(_, _, _, _, master_fn) master = master_fn end
dofile("scripts/prefabs/kiritzuka.lua")

local spawned = {}
SpawnPrefab = function(name)
    local fx = { name = name }
    fx.AnimState = { SetBuild = function(_, build) fx.build = build end }
    fx.Transform = {
        SetPosition = function(_, x, _, z) fx.x, fx.z = x, z end,
        SetRotation = function() end,
    }
    spawned[#spawned + 1] = fx
    return fx
end

local function Player()
    local inst = { tags = {}, flags = {}, hits = {}, gained = 0, weapon = { prefab = "baseballbat" } }
    inst.HasTag = function(self, tag) return self.tags[tag] == true end
    inst.AddComponent = function() end
    inst.ListenForEvent = function() end
    inst.ClearBufferedAction = function() end
    inst.GetAngleToPoint = function(_, x) return x end
    inst.ForceFacePoint = function(self, x, _, z) self.faced = { x, z } end
    inst.DoTaskInTime = function(self, _, fn) self.task = fn end
    inst.Transform = { GetRotation = function() return 0 end, GetWorldPosition = function() return 0, 0, 0 end }
    inst.AnimState = {
        SetScale = function() end,
        SetDeltaTimeMultiplier = function(_, value) inst.anim_speed = value end,
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
        inventory = {
            IsHeavyLifting = function() return inst.flags.heavy == true end,
            EquipHasTag = function() return false end,
        },
        momentum = { Gain = function(_, amount) inst.gained = inst.gained + amount end },
        timer = {
            TimerExists = function() return inst.cooldown ~= nil end,
            StopTimer = function() inst.cooldown = nil end,
            StartTimer = function(_, name, duration)
                assert(name == "kiritzuka_counter")
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
                assert(self.ignorehitrange, "The swing reaches whoever it answers")
                inst.hits[#inst.hits + 1] = { target = target, mult = mult }
            end,
        },
    }
    inst.sg = { statemem = {}, tags = {}, currentstate = { name = "idle" } }
    function inst.sg:HasStateTag(tag) return self.tags[tag] == true end
    function inst.sg:RemoveStateTag(tag) self.tags[tag] = nil end
    function inst.sg:AddStateTag(tag) self.tags[tag] = true end
    function inst.sg:SetTimeout(value) self.timeout = value end
    function inst.sg:GoToState(name, data)
        local current = self.currentstate
        if current.onexit ~= nil then current.onexit(inst) end
        self.currentstate = states[name] or { name = name }
        self.statemem, self.tags = {}, {}
        local state = states[name]
        if state ~= nil then
            for _, tag in ipairs(state.tags) do self.tags[tag] = true end
            state.onenter(inst, data)
        end
    end
    master(inst)
    return inst
end

-- The attacker's x stands in for its bearing from the player.
local function Enemy(angle, tags)
    local enemy = { prefab = "enemy", tags = tags or {}, bonus = {} }
    enemy.IsValid = function() return true end
    enemy.IsInLimbo = function() return false end
    enemy.HasTag = function(_, tag) return enemy.tags[tag] == true end
    enemy.HasAnyTag = function(_, ...)
        for _, tag in ipairs({ ... }) do
            if enemy.tags[tag] then return true end
        end
        return false
    end
    enemy.Transform = { GetWorldPosition = function() return angle, 0, 0 end }
    enemy.components = {
        health = { IsDead = function() return enemy.dead == true end },
        combat = { GetAttacked = function(_, _, damage) enemy.bonus[#enemy.bonus + 1] = damage end },
    }
    return enemy
end

local function Hit(player, attacker, damage, spdamage)
    return player:InterceptHit(attacker, damage, nil, nil, spdamage)
end

-- Pressing opens a half second stance; only a catch or a whiff starts the cooldown.
local player = Player()
assert(player:StartCounter())
assert(player.sg.currentstate == stance and player.animation == "kiritzuka_guard_pre" and player.queued == "kiritzuka_guard_loop")
assert(player.queued_loop == true and player.sg.timeout == 0.5)
assert(player.cooldown == nil)

-- Caught from the front: no damage, no retreat, a short cooldown, gauge, and the swing.
local enemy = Enemy(30)
assert(Hit(player, enemy, 100, { planar = 20 }), "The hit is blocked")
assert(player.task == nil, "Nothing is left pending")
assert(player.sg.currentstate == swing and player.sg.statemem.target == enemy)
assert(player.sg.statemem.blocked == 120 and player.sg.statemem.signature_crit == true, "Swing always crits")
assert(player.cooldown == 2 and player.gained == 15)
assert(player.animation == "atk_pre" and player.queued == "atk" and player.faced[1] == 30)
assert(player.anim_speed == 8 / 5 and player.sg:HasStateTag("nointerrupt"))

-- The swing lands the weapon's hit, then a share of what was blocked.
spawned = {}
assert(swing.timeline[1].time == 5 * FRAMES)
swing.timeline[1].fn(player)
assert(#player.hits == 1 and player.hits[1].target == enemy and player.hits[1].mult == 2)
assert(enemy.bonus[1] == 60, "Half the blocked damage comes back")
assert(player.components.combat.ignorehitrange == false)
assert(spawned[1].name == "rocky_snip_fx" and spawned[1].build == "rocky_boss_shadow_build" and spawned[1].x == 30)
assert(not player.sg:HasStateTag("nointerrupt"))
swing.events[1].fn(player)
assert(player.sg.currentstate.name == "idle" and player.anim_speed == 1)

-- A knockback that follows its own hit changes nothing, and arriving first it still triggers.
player = Player()
player:StartCounter()
enemy = Enemy(0)
Hit(player, enemy, 50)
assert(not player:ParryKnockback({ knocker = enemy }), "Mid-swing the native handler ignores it")
assert(player.sg.currentstate == swing, "No retreat")

player = Player()
player:StartCounter()
enemy = Enemy(0)
assert(player:ParryKnockback({ knocker = enemy }), "A leading knockback triggers it")
assert(player.sg.currentstate == swing and player.sg.statemem.blocked == 0)
assert(Hit(player, enemy, 50), "Its damage this tick is blocked too")
swing.timeline[1].fn(player)
assert(#enemy.bonus == 0, "Nothing blocked yet, so no share to return")
tick = tick + 1

-- Leaving early: the stance is open to the native movement and action handlers, and costs nothing.
player = Player()
player:StartCounter()
assert(not player.sg:HasStateTag("busy") and not player.sg:HasStateTag("nopredict"))
player.sg:GoToState("run_start")
assert(player.cooldown == nil, "Walking away costs nothing")

player = Player()
player:StartCounter()
assert(player:StartCounter(), "A second press drops the stance")
assert(player.sg.currentstate.name == "idle" and player.cooldown == nil)
assert(player:StartCounter() and player.sg.currentstate == stance, "And the stance can be raised again at once")

player = Player()
player:StartCounter()
stance.ontimeout(player)
assert(not player:StartCounter() and player.sg.currentstate == stance, "A whiff cannot be dropped")
stance.ontimeout(player)
assert(player.cooldown == 8, "And keeps the long cooldown")

-- A whiff: stance comes down and leaves an open half second, with the long cooldown.
player = Player()
player:StartCounter()
stance.ontimeout(player)
assert(player.sg.currentstate == stance and player.animation == "kiritzuka_guard_pst" and player.sg.timeout == 0.5)
assert(player.sg:HasStateTag("busy"), "No acting during the recovery")
assert(player.cooldown == 8)
enemy = Enemy(0)
Hit(player, enemy, 50)
assert(player.sg.currentstate == stance, "Too late to catch anything")
stance.ontimeout(player)
assert(player.sg.currentstate.name == "idle")

-- From behind the stance catches nothing.
player = Player()
player:StartCounter()
assert(not Hit(player, Enemy(135), 50), "The hit lands")
assert(player.sg.currentstate == stance and player.cooldown == nil)

-- Things that cannot be struck back fall through to the ordinary guard.
player = Player()
player:StartCounter()
local friend = Enemy(0, { companion = true })
Hit(player, friend, 50)
assert(player.sg.currentstate == stance, "Allies are not countered")
local burning = Enemy(0)
burning.sg = { HasStateTag = function(_, tag) return tag == "supernovaburning" end }
Hit(player, burning, 50)
assert(player.sg.currentstate ~= swing, "A supernova is not countered")
player = Player()
player:StartCounter()
local beam = Enemy(0)
beam.prefab = "wagboss_beam_fx"
beam.components = { combat = {} }
beam.kiritzuka_source_x, beam.kiritzuka_source_z = 0, 0
assert(Hit(player, beam, 50), "A beam is still blocked")
assert(player.sg.currentstate ~= swing, "But it is not countered")

-- A dashing Rock Master is judged by where it came from, as the guard does.
player = Player()
player:StartCounter()
local rock = Enemy(135)
rock.prefab = "rocky_boss"
rock.sg = {
    currentstate = { name = "dash_attack" },
    statemem = { dx = 6, dz = 0 },
    HasStateTag = function() return false end,
}
assert(Hit(player, rock, 100))
assert(player.sg.currentstate == swing and player.sg.statemem.target == rock)

-- A target that died before the swing lands takes nothing.
player = Player()
player:StartCounter()
enemy = Enemy(0)
Hit(player, enemy, 50)
enemy.dead = true
swing.timeline[1].fn(player)
assert(#player.hits == 0 and #enemy.bonus == 0)

-- Refusals: the cooldown line, other weapons, and states that cannot act.
player = Player()
player.cooldown = 3
assert(not player:StartCounter() and player.said == STRINGS.SKILL.KIRITZUKA_COUNTER_COOLDOWN)
assert(player.sg.currentstate.name == "idle")
for _, prefab in ipairs({ "pickaxe", "spear" }) do
    player = Player()
    player.weapon.prefab = prefab
    assert(not player:StartCounter(), prefab)
    local matched = false
    for _, line in ipairs(STRINGS.SKILL.KIRITZUKA_WEAPON_REFUSE) do
        matched = matched or line == player.said
    end
    assert(matched, "Says a weapon line")
    assert(player.cooldown == nil, "Refusing costs nothing")
end
player = Player()
player.weapon = nil
assert(not player:StartCounter(), "Unarmed")
for _, flag in ipairs({ "dead", "riding", "heavy", "disabled" }) do
    player = Player()
    player.flags[flag] = true
    assert(not player:StartCounter(), flag)
end
player = Player()
player.sg.tags.busy = true
assert(not player:StartCounter(), "Busy")
player = Player()
player.tags.playerghost = true
assert(not player:StartCounter(), "Ghost")

-- A readied skill is put away.
player = Player()
player:ToggleDash()
assert(player:IsDashArmed())
assert(player:StartCounter())
assert(not player:IsDashArmed() and player.components.combat.attackrange == 2)

print("kiritzuka_counter: checks passed")
