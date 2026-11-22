-- Run from the mod directory: lua tests/kiritzuka_pounce.lua
package.path = "scripts/?.lua;" .. package.path
TUNING = {
    GAMEMODE_STARTING_ITEMS = { DEFAULT = { KIRITZUKA = {} } },
    KIRITZUKA_PARRY_ALL = true,
    KIRITZUKA_PARRY_RETREAT = 2.5,
    KIRITZUKA_POUNCE_REPEL = { RANGE = 1, RADIUS = 3, STRENGTH = 1.5 },
    KIRITZUKA_COUNTER = { MOMENTUM_GAIN = 15 },
}
FRAMES = 1 / 30
TheNet = { GetServerGameMode = function() return "default" end }
FlattenTree = function(tree) return tree[1] end
Asset = function() end
package.loaded["prefabs/player_common_extensions"] = {}
package.loaded["components/spdamageutil"] = {
    CalcTotalDamage = function(tbl)
        local total = 0
        for _, value in pairs(tbl or {}) do total = total + value end
        return total
    end,
}
local tick = 100
GetTick = function() return tick end
GetTime = function() return 0 end
DiffAngle = function(a, b)
    local diff = math.abs(a - b) % 360
    return diff > 180 and 360 - diff or diff
end
local spawned = {}
SpawnPrefab = function(name)
    local fx = { name = name, Transform = { SetPosition = function() end } }
    spawned[#spawned + 1] = fx
    return fx
end

local master
package.loaded["prefabs/player_common"] = function(_, _, _, _, master_fn) master = master_fn end
dofile("scripts/prefabs/kiritzuka.lua")

-- The pouncer's x stands in for its bearing from the player.
local function Pouncer(prefab, angle, equipped)
    local pouncer = {
        prefab = prefab,
        pushed = {},
        bearing = angle,
        sg = { mem = {}, HasStateTag = function() return false end },
        IsValid = function() return true end,
        IsInLimbo = function() return false end,
        HasTag = function() return false end,
        HasAnyTag = function() return false end,
        PushEventImmediate = function(self, event, data) self.pushed[#self.pushed + 1] = { event = event, data = data } end,
    }
    pouncer.Transform = { GetWorldPosition = function() return pouncer.bearing, 0, 0 end }
    pouncer.components = {
        equippable = { IsEquipped = function() return equipped == true end },
        combat = {},
        health = { IsDead = function() return false end },
    }
    return pouncer
end

local function Player()
    local player = {
        AddComponent = function() end,
        ListenForEvent = function() end,
        AnimState = { SetScale = function() end },
        Transform = {
            GetRotation = function() return 0 end,
            GetWorldPosition = function() return 0, 0, 0 end,
        },
        SoundEmitter = { PlaySound = function(self, sound) self.played = sound end },
        GetAngleToPoint = function(_, x) return x end,
        IsValid = function() return true end,
        sg = {
            currentstate = { name = "idle" },
            statemem = {},
            HasStateTag = function() return false end,
            HasAnyStateTag = function() return false end,
            GoToState = function(self, name, data) self.destination, self.data = name, data end,
        },
    }
    player.components = {
        combat = {
            GetWeapon = function() return player.weapon end,
            CanTarget = function() return true end,
            IsAlly = function() return false end,
        },
        health = { SetMaxHealth = function() end, IsDead = function() return false end },
        hunger = { SetMax = function() end },
        sanity = { SetMax = function() end },
        rider = { IsRiding = function() return false end },
        inventory = {
            IsHeavyLifting = function() return false end,
            EquipHasTag = function() return false end,
        },
    }
    player.weapon = { prefab = "baseballbat" }
    master(player)
    return player
end

-- A faced pounce is swatted back: no damage, and a swing rather than a guard.
for _, prefab in ipairs({ "slurper", "bat_boss", "bat_boss_shadow" }) do
    tick = tick + 1
    local player = Player()
    local pouncer = Pouncer(prefab, 30)
    spawned = {}
    assert(player:InterceptHit(pouncer, 50), prefab .. " is stopped")
    assert(player.sg.destination == "kiritzuka_pounce_swat" and player.sg.data == pouncer, prefab .. " is swatted")
    assert(#pouncer.pushed == 1 and pouncer.pushed[1].event == "knockback", prefab .. " is thrown back")
    local data = pouncer.pushed[1].data
    assert(data.knocker == player and data.radius == 3 and data.strengthmult == 1.5 and data.kiritzuka_repel)
    assert(spawned[1].name == "kiritzuka_hit_fx_impact" and player.SoundEmitter.played ~= nil, "And marks the hit")
end

-- The hit and the hat test of one pounce land together: thrown back once, and the bite stays stopped.
do
    tick = tick + 1
    local player = Player()
    local pouncer = Pouncer("slurper", 30)
    assert(player:InterceptHit(pouncer, 30))
    assert(player:RepelPounce(pouncer) and player:InterceptHit(pouncer, 30))
    assert(#pouncer.pushed == 1, "Only once a tick")
    tick = tick + 1
    assert(player:RepelPounce(pouncer) and #pouncer.pushed == 2, "A later pounce is its own")
end

-- It is still thrown back when she can't swing: a swing of her own carries on, and so does anything uninterruptible.
do
    tick = tick + 1
    local player = Player()
    player.sg.currentstate = { name = "kiritzuka_attack" }
    player.sg.HasStateTag = function(_, tag) return tag == "abouttoattack" end
    local pouncer = Pouncer("bat_boss", 30)
    assert(player:RepelPounce(pouncer) and #pouncer.pushed == 1 and player.sg.destination == nil)
    tick = tick + 1
    player = Player()
    player.sg.HasAnyStateTag = function() return true end
    pouncer = Pouncer("bat_boss", 30)
    assert(player:RepelPounce(pouncer) and #pouncer.pushed == 1 and player.sg.destination == nil)
end

-- From behind, or without an exclusive weapon, it is all native.
do
    local player = Player()
    local behind = Pouncer("bat_boss", 135)
    assert(not player:InterceptHit(behind, 50) and not player:RepelPounce(behind))
    assert(#behind.pushed == 0 and player.sg.destination == nil)
    player = Player()
    player.weapon = nil
    local unarmed = Pouncer("bat_boss", 30)
    assert(not player:RepelPounce(unarmed) and #unarmed.pushed == 0)
end

-- Prediction: seen coming at any point, it is thrown back wherever it is by contact.
do
    tick = tick + 1
    local player = Player()
    local pouncer = Pouncer("bat_boss", 30)
    player:ReadPounce(pouncer)
    pouncer.bearing = 135
    assert(player:RepelPounce(pouncer) and #pouncer.pushed == 1, "Read at the start, behind her at contact")

    tick = tick + 1
    local unseen = Pouncer("bat_boss", 135)
    player:ReadPounce(unseen)
    assert(not player:RepelPounce(unseen) and #unseen.pushed == 0, "Never seen is never read")

    -- Her weapon still has to be up at contact, and another player's read is not hers.
    local read = Pouncer("bat_boss", 30)
    player:ReadPounce(read)
    player.weapon = nil
    assert(not player:RepelPounce(read) and #read.pushed == 0)
    player = Player()
    local others = Pouncer("bat_boss", 135)
    others.sg.mem.kiritzuka_pounce_reader = {}
    assert(not player:RepelPounce(others))
end

-- Already on her head, the bites land with no guard however she is facing: that was the endless block.
do
    tick = tick + 1
    local player = Player()
    local latched = Pouncer("bat_boss", 0, true)
    assert(not player:InterceptHit(latched, 5), "The bite lands")
    assert(player.sg.destination == nil and #latched.pushed == 0)
    player.sg.currentstate = { name = "kiritzuka_counter" }
    assert(not player:InterceptHit(latched, 5) and player.sg.destination == nil, "Nor does it set off a counter")
end

-- A counter stance still takes its swing, and keeps the pouncer off the head while it does.
do
    tick = tick + 1
    local player = Player()
    local pouncer = Pouncer("bat_boss", 30)
    player.sg.currentstate = { name = "kiritzuka_counter" }
    assert(player:InterceptHit(pouncer, 40))
    assert(player.sg.destination == "kiritzuka_counter_swing" and player.sg.data.blocked == 40)
    assert(#pouncer.pushed == 0, "The swing is the answer")
    assert(player:RepelPounce(pouncer), "Same tick, still refused")
end

-- Everything else keeps the guard.
do
    tick = tick + 1
    local player = Player()
    local other = Pouncer("hound", 30)
    assert(player:InterceptHit(other, 20) and player.sg.destination == "kiritzuka_guard_hit")
    assert(#other.pushed == 0)
end

-- The hooks that get in before the native latch, which knocks her hat off and equips in one step.
GLOBAL = _G
GLOBAL.setfenv = function() end
local stategraph_postinit, prefab_postinit = {}, nil
local added_states = {}
State = function(def) return def end
AddStategraphState = function(name, state)
    added_states[state.name] = state
end
AddStategraphPostInit = function(name, fn)
    stategraph_postinit[name] = fn
end
AddPrefabPostInit = function(name, fn)
    assert(name == "slurper")
    prefab_postinit = fn
end
TimeEvent = function(time, fn) return { time = time, fn = fn } end
EventHandler = function(name, fn) return { name = name, fn = fn } end
STRINGS = dofile("strings/common.lua")
TUNING.KIRITZUKA_BOSS_SLAM = { HITS = 5, ARMED_ATTACK_RANGE = 16 }
TUNING.KIRITZUKA_DASH = { ARMED_ATTACK_RANGE = 12 }
TUNING.KIRITZUKA_COUNTER.WINDOW = 1
dofile("postinit/stategraphs/SGkiritzuka.lua")
dofile("postinit/stategraphs/SGbat.lua")
dofile("postinit/stategraphs/SGslurper.lua")
dofile("postinit/prefabs/slurper.lua")

local function Registered(group, name)
    local file = assert(io.open("main/postinit.lua"))
    local source = file:read("*a")
    file:close()
    return source:find(group .. " = {.-\"" .. name .. "\"") ~= nil
end
assert(Registered("prefabs", "slurper") and Registered("stategraphs", "SGbat") and Registered("stategraphs", "SGslurper"), "All hooks are loaded")

-- The swat: straight into the strike, turned to the pouncer, and back to idle with the speed restored.
do
    local swat = assert(added_states.kiritzuka_pounce_swat)
    local player = {
        ClearBufferedAction = function(self) self.cleared = true end,
        ForceFacePoint = function(self, x, _, z) self.faced = { x, z } end,
        SoundEmitter = { PlaySound = function(self, sound) self.played = sound end },
        components = { locomotor = { Stop = function(self) self.stopped = true end } },
        AnimState = {
            SetDeltaTimeMultiplier = function(self, speed) self.speed = speed end,
            PlayAnimation = function(self, anim) self.played = anim end,
            AnimDone = function() return true end,
        },
        sg = { GoToState = function(self, name) self.destination = name end },
    }
    local pouncer = { Transform = { GetWorldPosition = function() return 3, 0, 4 end } }
    swat.onenter(player, pouncer)
    assert(player.AnimState.played == "atk" and player.AnimState.speed > 1)
    assert(player.faced[1] == 3 and player.faced[2] == 4)
    assert(player.components.locomotor.stopped and player.cleared)
    assert(player.SoundEmitter.played == "dontstarve/wilson/attack_weapon")
    swat.events[1].fn(player)
    assert(player.sg.destination == "idle")
    swat.onexit(player)
    assert(player.AnimState.speed == 1)
end

-- Hound Batilisk: within reach once it can attach, and at any time while failing past her.
do
    local native_calls = 0
    local function Native() native_calls = native_calls + 1 end
    local entered = 0
    local function NativeEnter() entered = entered + 1 end
    local native_knockbacks = 0
    local sg = {
        states = {
            attack = { onenter = NativeEnter },
            chomp_attack = { onenter = NativeEnter, onupdate = Native },
            chomp_fail = { onupdate = Native },
        },
        events = { knockback = { fn = function() native_knockbacks = native_knockbacks + 1 end } },
    }
    stategraph_postinit.bat(sg)

    -- Native refuses the Hound Batilisk a knockback because its bank has no such animation.
    local function KnockbackBat(tags, dead)
        local bat = {
            sg = {
                statemem = {},
                HasAnyStateTag = function(_, ...)
                    for _, tag in ipairs({ ... }) do
                        if tags[tag] then return true end
                    end
                    return false
                end,
                GoToState = function(self, name, data) self.destination, self.data = name, data end,
            },
            components = { health = { IsDead = function() return dead == true end } },
        }
        return bat
    end
    local repel = { kiritzuka_repel = true, knocker = {}, strengthmult = 1.5 }
    local boss = KnockbackBat({})
    sg.events.knockback.fn(boss, repel)
    assert(boss.sg.destination == "kiritzuka_repelled" and boss.sg.data == repel and native_knockbacks == 0)
    boss = KnockbackBat({})
    sg.events.knockback.fn(boss, {})
    assert(boss.sg.destination == nil and native_knockbacks == 1, "Everything else still gets native's refusal")
    sg.events.knockback.fn(boss)
    assert(boss.sg.destination == nil and native_knockbacks == 2, "Native can push it with no data at all")
    for _, refused in ipairs({
        KnockbackBat({ nointerrupt = true }),
        KnockbackBat({ noknockback = true }),
        KnockbackBat({}, true),
    }) do
        sg.events.knockback.fn(refused, repel)
        assert(refused.sg.destination == nil and native_knockbacks == 2)
    end

    -- The slide: pushed straight back from her, wearing off into idle, with the motor released.
    local slide = assert(added_states.kiritzuka_repelled)
    local bat = KnockbackBat({})
    bat.components.locomotor = { StopMoving = function(self) self.stopped = true end }
    bat.AnimState = {
        PlayAnimation = function(self, anim) self.played = anim end,
        PushAnimation = function(self, anim, loop) self.pushed, self.loop = anim, loop end,
    }
    bat.ForceFacePoint = function(self, x, _, z) self.faced = { x, z } end
    bat.Physics = {
        SetMotorVelOverride = function(self, speed) self.speed = speed end,
        ClearMotorVelOverride = function(self) self.cleared = true end,
        Stop = function(self) self.halted = true end,
    }
    slide.onenter(bat, {
        strengthmult = 1.5,
        knocker = { Transform = { GetWorldPosition = function() return 3, 0, 4 end } },
    })
    assert(bat.AnimState.played == "hit" and bat.AnimState.pushed == "fly_loop" and bat.AnimState.loop)
    assert(bat.faced[1] == 3 and bat.faced[2] == 4 and bat.components.locomotor.stopped)
    assert(bat.Physics.speed == -15, "Backward, as hard as the native state would")
    local updates, last = 0, bat.Physics.speed
    while bat.sg.destination == nil do
        slide.onupdate(bat)
        updates = updates + 1
        assert(updates < 60, "It has to end")
        assert(bat.Physics.speed >= last, "Only ever slowing")
        last = bat.Physics.speed
    end
    assert(bat.sg.destination == "idle" and updates > 10)
    slide.onexit(bat)
    assert(bat.Physics.cleared and bat.Physics.halted)

    local function Bat(target, near, statemem)
        statemem.target = target
        return {
            sg = { statemem = statemem, mem = {} },
            IsNear = function(_, other, range)
                assert(other == target and range == 1)
                return near
            end,
        }
    end
    local function Run(state, bat, dt)
        native_calls = 0
        state.onupdate(bat, dt or 1 / 30)
        return native_calls == 1
    end
    local function Target(repels)
        return {
            repelled = 0,
            reads = 0,
            IsValid = function() return true end,
            ReadPounce = function(self) self.reads = self.reads + 1 end,
            RepelPounce = function(self, pouncer)
                self.repelled = self.repelled + 1
                self.pouncer = pouncer
                return repels
            end,
        }
    end

    local target = Target(true)
    local attach_ready = Bat(target, true, { canattach = true })
    assert(not Run(sg.states.chomp_attack, attach_ready), "Refused before the native latch")
    assert(target.repelled == 1 and target.pouncer == attach_ready)
    target = Target(true)
    assert(Run(sg.states.chomp_attack, Bat(target, true, {})) and target.repelled == 0, "Not before it can attach")
    assert(Run(sg.states.chomp_attack, Bat(target, false, { canattach = true })) and target.repelled == 0, "Nor out of reach")
    assert(Run(sg.states.chomp_attack, attach_ready, 0), "A paused update is left to native")
    assert(not Run(sg.states.chomp_fail, Bat(target, true, {})) and target.repelled == 1, "A miss can still latch on")

    assert(Run(sg.states.chomp_fail, Bat(Target(false), true, {})), "Her back turned: the native latch goes ahead")
    assert(Run(sg.states.chomp_attack, Bat({ IsValid = function() return true end }, true, { canattach = true })), "Others are untouched")
    assert(Run(sg.states.chomp_fail, { sg = { statemem = {} } }), "No target left")

    -- Read from the very start of the pounce, well before it can attach or reach her.
    target = Target(true)
    assert(Run(sg.states.chomp_attack, Bat(target, false, {})) and target.reads == 1 and target.repelled == 0)
    assert(Run(sg.states.chomp_attack, Bat(target, false, {}), 0) and target.reads == 1, "But not on a paused update")

    -- Each new attack starts unseen.
    for _, state in ipairs({ sg.states.attack, sg.states.chomp_attack }) do
        local bat = Bat(target, false, {})
        bat.sg.mem.kiritzuka_pounce_reader = target
        entered = 0
        state.onenter(bat)
        assert(bat.sg.mem.kiritzuka_pounce_reader == nil and entered == 1)
    end
end

-- Slurper: read through the rush and the leap, and each attack starts unseen.
do
    local entered = 0
    local sg = { states = { attack = { onenter = function() entered = entered + 1 end }, headslurp = {} } }
    stategraph_postinit.slurper(sg)
    local reads = 0
    local target = {
        IsValid = function() return true end,
        ReadPounce = function() reads = reads + 1 end,
    }
    local slurper = {
        sg = { mem = { kiritzuka_pounce_reader = target } },
        components = { combat = { target = target } },
    }
    sg.states.attack.onenter(slurper)
    assert(slurper.sg.mem.kiritzuka_pounce_reader == nil and entered == 1)
    sg.states.attack.onupdate(slurper)
    sg.states.headslurp.onupdate(slurper)
    assert(reads == 2)
    slurper.components.combat.target = nil
    sg.states.attack.onupdate(slurper)
    slurper.components.combat.target = { IsValid = function() return true end }
    sg.states.headslurp.onupdate(slurper)
    assert(reads == 2, "No target, or one that is not her, reads nothing")
end

-- Slurper: failing the test keeps it off, and only up close.
do
    local client = {}
    prefab_postinit(client)
    assert(client.HatTest == nil, "Clients have nothing to wrap")

    local function Slurper(near)
        local slurper = {
            native_calls = 0,
            HatTest = function(self)
                self.native_calls = self.native_calls + 1
                return true
            end,
            IsNear = function(_, _, range)
                assert(range == 2)
                return near
            end,
        }
        prefab_postinit(slurper)
        return slurper
    end
    local repelled = 0
    local function RepelPounce()
        repelled = repelled + 1
        return true
    end

    local slurper = Slurper(true)
    assert(slurper:HatTest({ RepelPounce = RepelPounce }) == false and repelled == 1 and slurper.native_calls == 0)
    slurper = Slurper(false)
    assert(slurper:HatTest({ RepelPounce = RepelPounce }) == true and repelled == 1, "Out of reach it still leaps")
    slurper = Slurper(true)
    assert(slurper:HatTest({ RepelPounce = function() return false end }) == true, "Her back turned: native")
    assert(slurper:HatTest({}) == true and slurper.native_calls == 2, "Others are untouched")
end

print("kiritzuka_pounce: checks passed")
