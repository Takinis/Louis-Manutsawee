-- Run from the mod directory: lua tests/kiritzuka_parry.lua
package.path = "scripts/?.lua;" .. package.path
TUNING = { GAMEMODE_STARTING_ITEMS = { DEFAULT = { KIRITZUKA = {} } }, KIRITZUKA_PARRY_RETREAT = 2.5, }
TheNet = { GetServerGameMode = function() return "default" end }
FlattenTree = function(tree) return tree[1] end
Asset = function() end
package.loaded["components/spdamageutil"] = {}
local tick, now = 100, 0
GetTick = function() return tick end
GetTime = function() return now end
DiffAngle = function(a, b)
    local diff = math.abs(a - b) % 360
    return diff > 180 and 360 - diff or diff
end

local master
package.loaded["prefabs/player_common"] = function(_, _, _, _, master_fn) master = master_fn end
dofile("scripts/prefabs/kiritzuka.lua")

local function Attacker(angle)
    return {
        angle = angle,
        IsValid = function() return true end,
        Transform = { GetWorldPosition = function(_) return angle, 0, 0 end },
    }
end

-- The attacker's x stands in for its bearing from the player.
local function Player()
    local tags, flags, tasks, hits = {}, {}, {}, {}
    local player = {
        AddComponent = function() end,
        ListenForEvent = function() end,
        AnimState = { SetScale = function() end },
        Transform = { GetRotation = function() return 0 end },
        GetAngleToPoint = function(_, x) return x end,
        ForceFacePoint = function(self, x, _, z) self.faced = { x, z } end,
        DoTaskInTime = function(_, _, fn) tasks[#tasks + 1] = fn end,
        sg = {
            currentstate = { name = "idle" },
            statemem = {},
            HasStateTag = function(_, tag) return tags[tag] == true end,
            HasAnyStateTag = function(_, ...)
                for _, tag in ipairs({ ... }) do
                    if tags[tag] then return true end
                end
                return false
            end,
            GoToState = function(self, name, data) self.destination, self.data = name, data end,
        },
    }
    player.components = {
        combat = {
            GetWeapon = function() return player.weapon end,
            GetAttacked_Internal = function(_, attacker, damage, _, _, _, from_doattack)
                if player:InterceptHit(attacker, damage) then return end
                hits[#hits + 1] = { attacker = attacker, damage = damage, from_doattack = from_doattack }
            end,
        },
        health = { SetMaxHealth = function() end, IsDead = function() return flags.dead == true end },
        hunger = { SetMax = function() end },
        sanity = { SetMax = function() end },
        rider = { IsRiding = function() return flags.riding == true end },
        inventory = {
            IsHeavyLifting = function() return flags.heavy == true end,
            EquipHasTag = function(_, tag) return flags[tag] == true end,
        },
    }
    player.weapon = { prefab = "baseballbat" }
    master(player)
    return player, tags, flags, tasks, hits
end

local function RunTasks(tasks, player)
    for i = #tasks, 1, -1 do
        table.remove(tasks, i)(player)
    end
end

-- Facing: the knockback becomes a parry and its hit never lands.
for _, prefab in ipairs({ "baseballbat", "crowbar", "rebar" }) do
    local player, _, _, tasks, hits = Player()
    player.weapon.prefab = prefab
    local knocker = Attacker(30)
    local knock = { knocker = knocker, radius = 5, strengthmult = 2 }
    player.components.combat:GetAttacked_Internal(knocker, 50, nil, nil, nil, true)
    assert(#hits == 0, "The hit waits out the tick")
    assert(player:ParryKnockback(knock), "Parry with " .. prefab)
    local retreat = player.sg.data.knockbackdata
    assert(player.sg.destination == "kiritzuka_guard_hit" and retreat.knocker == knocker and retreat.radius == 5)
    assert(retreat.strengthmult == 5, "The retreat is scaled up, keeping the blow's own strength")
    assert(knock.strengthmult == 2, "Without touching the event others also read")
    assert(player.sg.data.timeleft == 0.75, "Hold the guard a little after the retreat")
    RunTasks(tasks, player)
    assert(#hits == 0, "A parried knockback takes no damage")
end

-- A knockback that names no strength still gets the scaled retreat.
do
    local player = Player()
    assert(player:ParryKnockback({ knocker = Attacker(0) }))
    assert(player.sg.data.knockbackdata.strengthmult == 2.5)
end

-- A knockback pushed ahead of its damage blocks it too, but only that tick.
do
    local player, _, _, tasks, hits = Player()
    local knocker = Attacker(0)
    assert(player:ParryKnockback({ knocker = knocker }))
    player.components.combat:GetAttacked_Internal(knocker, 50)
    assert(#tasks == 0 and #hits == 0, "The same tick's hit is parried")
    tick = tick + 1
    player.components.combat:GetAttacked_Internal(knocker, 50)
    RunTasks(tasks, player)
    assert(#hits == 1 and hits[1].damage == 50, "A later hit lands")
end

-- Facing an attack with no knockback: it lands once the tick is over, with all its arguments.
do
    local player, _, _, tasks, hits = Player()
    local attacker = Attacker(0)
    player.components.combat:GetAttacked_Internal(attacker, 20, nil, nil, nil, true)
    player.components.combat:GetAttacked_Internal(attacker, 30, nil, nil, nil, true)
    assert(#tasks == 1, "Several hits share one task")
    RunTasks(tasks, player)
    assert(#hits == 2 and hits[1].damage == 20 and hits[2].damage == 30)
    assert(player.sg.destination == nil, "No parry without a knockback")
    assert(not player.kiritzuka_resolving_hit and player.kiritzuka_pending_hits == nil)
    -- One knocker's parry leaves another attacker's hit alone.
    local other = Attacker(10)
    player.components.combat:GetAttacked_Internal(other, 15)
    assert(player:ParryKnockback({ knocker = attacker }))
    RunTasks(tasks, player)
    assert(#hits == 3 and hits[3].attacker == other)
end

-- Back to the target: damage and knockback both stay native.
do
    local player, _, _, tasks, hits = Player()
    local behind = Attacker(135)
    player.components.combat:GetAttacked_Internal(behind, 50)
    assert(#hits == 1 and #tasks == 0, "Hits from behind land at once")
    assert(not player:ParryKnockback({ knocker = behind }), "Knockback from behind stays native")
    assert(player.sg.destination == nil)
    assert(player:ParryKnockback({ knocker = Attacker(90) }), "The side still counts as facing")
    assert(player:ParryKnockback({ knocker = Attacker(-90) }), "Both sides do")
end

-- Everything else stays native.
local function CheckNative(player, label)
    local attacker = Attacker(0)
    assert(not player:ParryKnockback({ knocker = attacker }), label)
    assert(not player:InterceptHit(attacker, 50), label .. " takes the hit")
end
for _, prefab in ipairs({ "pickaxe", "goldenpickaxe", "glasscutter", "nightsword", "spear" }) do
    local player = Player()
    player.weapon.prefab = prefab
    CheckNative(player, prefab)
end
do
    local player = Player()
    player.weapon = nil
    CheckNative(player, "Unarmed")
end
for _, flag in ipairs({ "dead", "riding", "heavy", "superheavyarmor" }) do
    local player, _, flags = Player()
    flags[flag] = true
    CheckNative(player, flag)
end
do
    local player, tags = Player()
    tags.nointerrupt = true
    CheckNative(player, "nointerrupt")
    player = Player()
    player.components.combat.redirectdamagefn = function() end
    CheckNative(player, "A real parry")
    player = Player()
    player.components.freezable = { IsFrozen = function() return true end }
    CheckNative(player, "Frozen")
    player = Player()
    player.components.pinnable = { IsStuck = function() return true end }
    CheckNative(player, "Pinned")
    player = Player()
    assert(not player:ParryKnockback(nil) and not player:ParryKnockback({}), "No knocker stays native")
    assert(not player:InterceptHit(nil, 50), "No attacker takes the hit")
    assert(not player:InterceptHit(player, 50), "Self damage lands")
end

-- The Scion's supernova: its first hit and its burn are blocked only while facing it.
do
    local player, tags, _, tasks, hits = Player()
    local scion = Attacker(0)
    scion.sg = { HasStateTag = function(_, tag) return tag == "supernovaburning" end }
    player.components.combat:GetAttacked_Internal(scion, 50)
    assert(#hits == 0 and #tasks == 0, "The first hit is blocked outright")
    assert(player.sg.destination == "kiritzuka_sustained_parry", "And raises the held guard")

    -- Once held, each tick refreshes the same guard and keeps it turned to the source.
    player.sg.destination = nil
    player.sg.currentstate = { name = "kiritzuka_sustained_parry" }
    player.sg.statemem = {}
    now = 20
    assert(player:ParrySustained(30, 0), "The burn is blocked")
    assert(player.sg.destination == nil, "The guard is not restarted")
    assert(player.sg.statemem.parry_time == 20 and player.faced[1] == 30)

    -- A moving player is turned into the guard; a busy one waits.
    player.sg.currentstate = { name = "run" }
    assert(player:ParrySustained(0, 0) and player.sg.destination == "kiritzuka_sustained_parry")
    player.sg.destination = nil
    tags.busy = true
    assert(player:ParrySustained(0, 0), "Still blocked while busy")
    assert(player.sg.destination == nil, "The busy state finishes first")
    tags.busy = nil

    player.sg.currentstate = { name = "idle" }
    local behind = Attacker(135)
    behind.sg = scion.sg
    assert(not player:ParrySustained(135, 0), "The burn lands from behind")
    player.components.combat:GetAttacked_Internal(behind, 50)
    assert(#hits == 1, "So does the first hit")
end

-- The held guard plays continuously, backs away slowly and ends when the attack stops.
do
    FRAMES = 1 / 30
    TUNING.KIRITZUKA_BOSS_SLAM = { HITS = 5 }
    State = function(def) return def end
    TimeEvent = function(time, fn) return { time = time, fn = fn } end
    EventHandler = function(name, fn) return { name = name, fn = fn } end
    GLOBAL = _G
    local real_setfenv = setfenv
    GLOBAL.setfenv = function() end
    local states = {}
    AddStategraphState = function(name, state)
        if name == "wilson" then states[state.name] = state end
    end
    AddStategraphPostInit = function() end
    dofile("postinit/stategraphs/SGkiritzuka.lua")
    GLOBAL.setfenv = real_setfenv

    local state = states.kiritzuka_sustained_parry
    assert(state ~= nil, "The server graph has the held guard")
    for _, tag in ipairs(state.tags) do
        assert(tag ~= "nointerrupt", "The guard must keep passing its own check")
    end

    local player = { sg = { statemem = {} }, animations = {} }
    player.components = { locomotor = { Stop = function() player.stopped = true end } }
    player.ClearBufferedAction = function() player.cleared = true end
    player.ForceFacePoint = function(_, x, _, z) player.faced = { x, z } end
    player.AnimState = {
        PlayAnimation = function(_, name) player.animations[#player.animations + 1] = name end,
        PushAnimation = function(_, name, loop) player.looped = loop and name or nil end,
    }
    player.SoundEmitter = { PlaySound = function() end }
    player.Physics = {
        SetMotorVel = function(_, x) player.motor = x end,
        Stop = function() player.motor = 0 end,
    }
    player.sg.GoToState = function(self, name, data) self.destination, self.data = name, data end

    now = 30
    state.onenter(player, { x = 5, z = 6 })
    assert(player.stopped and player.cleared and player.faced[1] == 5 and player.faced[2] == 6)
    assert(player.animations[1] == "kiritzuka_guard_pre" and player.looped == "kiritzuka_guard_loop", "The stance loops")

    state.onupdate(player)
    assert(player.motor == -1, "Backs away slowly")
    now = 30.2
    state.onupdate(player)
    assert(player.sg.destination == nil, "A short gap keeps the guard")
    now = 30.3
    state.onupdate(player)
    assert(player.sg.destination == "idle", "Then it comes down")
    state.onexit(player)
    assert(player.motor == 0, "Backing away stops with the state")

    player.sg.destination = nil
    for _, event in ipairs(state.events) do
        if event.name == "unequip" then event.fn(player) end
    end
    assert(player.sg.destination == "idle", "Losing the weapon drops the guard")
end

-- The burn keeps running with its fx, but while guarded it cannot hurt the player.
do
    GLOBAL = _G
    local real_setfenv = setfenv
    GLOBAL.setfenv = function() end
    local burn_postinit
    AddComponentPostInit = function(name, fn)
        assert(name == "lunarsupernovaburning")
        burn_postinit = fn
    end
    dofile("postinit/components/lunarsupernovaburning.lua")
    GLOBAL.setfenv = real_setfenv

    local function Source(angle)
        local source = Attacker(angle)
        source.sg = { HasStateTag = function(_, tag) return tag == "supernovaburning" end }
        return source
    end

    local function Burn(player, ...)
        local grogginess = {}
        function grogginess:MaximizeGrogginess() self.maxed = true end
        setmetatable(grogginess, { __index = { MaximizeGrogginess = grogginess.MaximizeGrogginess } })
        grogginess.MaximizeGrogginess = nil
        player.components.grogginess = grogginess
        local health = player.components.health
        health.dealt = 0
        function health:DoDelta(amount)
            if self.redirect ~= nil and self.redirect(player, amount) then return 0 end
            self.dealt = self.dealt - amount
        end
        local burn = { sources = {}, updates = 0 }
        for _, source in ipairs({ ... }) do burn.sources[source] = {} end
        function burn:OnUpdate()
            self.updates = self.updates + 1
            health:DoDelta(-10)
            grogginess:MaximizeGrogginess()
        end
        burn_postinit(burn, player)
        return burn, health, grogginess
    end

    local player = Player()
    local burn, health, grogginess = Burn(player, Source(0))
    local redirect = function() return false end
    health.redirect = redirect
    burn:OnUpdate(0)
    assert(burn.updates == 1, "The burn itself still runs, so its fx stay on")
    assert(health.dealt == 0 and not grogginess.maxed, "No damage or grogginess while guarded")
    assert(player.sg.destination == "kiritzuka_sustained_parry", "And the guard goes up")
    assert(health.redirect == redirect, "The health hook is put back")
    grogginess:MaximizeGrogginess()
    assert(grogginess.maxed, "Grogginess works again afterwards")

    player = Player()
    burn, health, grogginess = Burn(player, Source(135))
    burn:OnUpdate(0)
    assert(health.dealt == 10 and grogginess.maxed, "Facing away burns as usual")

    player = Player()
    burn, health = Burn(player, Source(0), Source(135))
    burn:OnUpdate(0)
    assert(health.dealt == 10, "A source behind still burns")

    player = Player()
    local ended = Source(0)
    ended.sg = { HasStateTag = function() return false end }
    burn, health = Burn(player, ended)
    burn:OnUpdate(0)
    assert(health.dealt == 10 and burn.updates == 1, "A finished source is left to the native cleanup")

    local bystander = { OnUpdate = function() end }
    local update = bystander.OnUpdate
    burn_postinit(bystander, {})
    assert(bystander.OnUpdate == update, "Other entities keep the native burn")
end

-- The W.A.R.B.O.T. beam: blocked only by facing the robot, wherever the beam itself lands.
do
    local function Beam(source_angle, beam_angle)
        local beam = Attacker(beam_angle or 0)
        beam.prefab = "wagboss_beam_fx"
        beam.kiritzuka_source_x, beam.kiritzuka_source_z = source_angle, 0
        return beam
    end

    local player, _, _, tasks, hits = Player()
    player.components.combat:GetAttacked_Internal(Beam(30), 50)
    assert(#hits == 0 and #tasks == 0, "The first hit is blocked outright")
    assert(player.sg.destination == "kiritzuka_sustained_parry", "And raises the held guard")
    assert(player.kiritzuka_guard_tick == tick, "This tick's grogginess is skipped")

    local redirect = player.components.health.redirect
    assert(redirect(player, -5, true, "wagboss_beam_fx", nil, Beam(30)), "The burn is blocked")
    assert(redirect(player, -5, true, "wagboss_beam_fx", nil, Beam(30, 135)), "A beam landing behind is still blocked facing the robot")
    assert(not redirect(player, -5, true, "wagboss_beam_fx", nil, Beam(135, 0)), "Back to the robot, a beam in front still burns")
    assert(not redirect(player, -5, true, "other", nil, Attacker(30)), "Other damage lands")
    assert(not redirect(player, 5, true, "wagboss_beam_fx", nil, Beam(30)), "Healing passes")
    assert(not redirect(player, -5, true, "hunger"), "Damage with no source lands")

    local behind = Player()
    behind.components.combat:GetAttacked_Internal(Beam(135), 50)
    assert(behind.kiritzuka_guard_tick == nil, "Facing away keeps the grogginess")

    local unknown = Attacker(0)
    unknown.prefab = "wagboss_beam_fx"
    assert(not Player():InterceptHit(unknown, 50), "A beam with no known source is not guarded")

    GLOBAL = _G
    local real_setfenv = setfenv
    GLOBAL.setfenv = function() end
    local beam_postinit
    AddPrefabPostInit = function(name, fn)
        assert(name == "wagboss_beam_fx")
        beam_postinit = fn
    end
    dofile("postinit/prefabs/wagboss_beam_fx.lua")
    GLOBAL.setfenv = real_setfenv
    local tracked
    local beam = { TrackTarget = function(_, target, x0, z0) tracked = { target, x0, z0 } end }
    beam_postinit(beam)
    beam:TrackTarget("target", 7, 9)
    assert(beam.kiritzuka_source_x == 7 and beam.kiritzuka_source_z == 9, "Remembers where the robot stood")
    assert(tracked[1] == "target" and tracked[2] == 7 and tracked[3] == 9, "Native tracking still runs")
    beam_postinit({})
end

-- Rock Masters never push, so facing one blocks the cut outright and supplies the retreat.
do
    for _, prefab in ipairs({ "rocky_boss", "rocky_boss_shadow" }) do
        local player, _, _, tasks, hits = Player()
        local boss = Attacker(30)
        boss.prefab = prefab
        player.components.combat:GetAttacked_Internal(boss, 100)
        assert(#hits == 0 and #tasks == 0, "The cut is blocked at once, with nothing left pending")
        assert(player.sg.destination == "kiritzuka_guard_hit", "Shows the guard")
        assert(player.sg.data.timeleft == 0.75 and player.sg.data.knockbackdata.knocker == boss)
        assert(player.sg.data.knockbackdata.strengthmult == 2.5, "Rock Masters push her back as far")

        player, _, _, tasks, hits = Player()
        boss = Attacker(135)
        boss.prefab = prefab
        player.components.combat:GetAttacked_Internal(boss, 100)
        assert(#hits == 1 and player.sg.destination == nil, "From behind it lands")

        -- A dashing boss has already passed the player; the guard faces where it came from.
        player, _, _, tasks, hits = Player()
        boss = Attacker(135)
        boss.prefab = prefab
        boss.sg = { currentstate = { name = "dash_attack" }, statemem = { dx = 6, dz = 0 }, HasStateTag = function() return false end }
        player.components.combat:GetAttacked_Internal(boss, 100)
        assert(#hits == 0 and player.sg.destination == "kiritzuka_guard_hit", "Facing the dash blocks it")

        player, _, _, tasks, hits = Player()
        boss = Attacker(30)
        boss.prefab = prefab
        boss.sg = { currentstate = { name = "dash_attack" }, statemem = { dx = -6, dz = 0 }, HasStateTag = function() return false end }
        player.components.combat:GetAttacked_Internal(boss, 100)
        assert(#hits == 1, "Back to the dash it lands, even with the boss now in front")
    end

    -- A plain Rocky is not a Rock Master and keeps the usual handling.
    local player, _, _, tasks, hits = Player()
    local rocky = Attacker(30)
    rocky.prefab = "rocky"
    player.components.combat:GetAttacked_Internal(rocky, 75)
    assert(#tasks == 1)
    RunTasks(tasks, player)
    assert(#hits == 1, "Plain Rocky hits land")
end

-- With the setting on, every attack faced is stopped without being waited on; behind is as usual.
do
    TUNING.KIRITZUKA_PARRY_ALL = true
    local spawned = {}
    SpawnPrefab = function(name)
        local fx = { name = name }
        fx.Transform = { SetPosition = function(_, x, y) fx.x, fx.y = x, y end }
        spawned[#spawned + 1] = fx
        return fx
    end
    local function Blocker()
        local player, tags, flags, tasks, hits = Player()
        player.x, player.z = 0, 0
        player.Transform.GetWorldPosition = function() return player.x, 0, player.z end
        player.SoundEmitter = { PlaySound = function(_, sound) player.sound = sound end }
        return player, tags, flags, tasks, hits
    end

    local player, tags, flags, tasks, hits = Blocker()
    player.components.combat:GetAttacked_Internal(Attacker(30), 50)
    assert(#hits == 0 and #tasks == 0, "A faced hit stops at once, with nothing left pending")
    assert(player.sg.destination == "kiritzuka_guard_hit" and player.sg.data.timeleft == 0.75, "Idle shows the guard")
    assert(player.sg.data.knockbackdata.strengthmult == nil, "With a smaller step back than a real knockback")
    assert(player.sg.data.knockbackdata.radius ~= nil)
    assert(spawned[1].name == "kiritzuka_hit_fx_impact" and player.sound ~= nil, "And marks the block")
    assert(player:InterceptHit(Attacker(90), 50), "The same facing as every other guard")

    player, tags, flags, tasks, hits = Blocker()
    player.components.combat:GetAttacked_Internal(Attacker(135), 50)
    assert(#hits == 1 and player.sg.destination == nil, "From behind it lands")

    -- Blocked while attacking, the guard shows once the swing is safely away.
    player, tags = Blocker()
    local striker = Attacker(30)
    player.sg.currentstate = { name = "kiritzuka_attack" }
    tags.attack, tags.abouttoattack = true, true
    assert(player:InterceptHit(striker, 50))
    assert(player.sg.destination == nil and player.sg.statemem.block_attacker == striker, "The wind-up is not cut off")
    tags.abouttoattack = nil
    player.sg.statemem.block_attacker = nil
    assert(player:InterceptHit(striker, 50))
    assert(player.sg.destination == "kiritzuka_guard_hit", "After the swing it shows at once")
    assert(player.sg.data.knockbackdata.knocker == striker)
    player:PlayBlockGuard(striker)

    -- Whatever the player is doing, a faced hit shows the guard.
    for state, state_tags in pairs({
        talk = { "idle", "talking" },
        run = { "moving", "running" },
        dolongaction = { "doing", "busy" },
        kiritzuka_guard_hit = { "busy" },
        kiritzuka_guard_hold = { "idle", "notalking" },
    }) do
        player, tags = Blocker()
        player.sg.currentstate = { name = state }
        for _, tag in ipairs(state_tags) do tags[tag] = true end
        assert(player:InterceptHit(Attacker(30), 50), state)
        assert(player.sg.destination == "kiritzuka_guard_hit", state .. " shows the guard")
        player.sg.destination = nil
        assert(not player:InterceptHit(Attacker(135), 50), state .. " still needs facing")
        assert(player.sg.destination == nil)
    end

    -- Except where even a native hit would not interrupt: the hit is stopped and that carries on.
    for _, tag in ipairs({ "nointerrupt", "transform", "dismounting", "drowning", "falling", "electrocute", "shell" }) do
        player, tags = Blocker()
        player.sg.currentstate = { name = "busy_state" }
        tags[tag] = true
        assert(player:InterceptHit(Attacker(30), 50), tag)
        assert(player.sg.destination == nil, tag .. " carries on")
    end

    -- Knockbacks retreat only when faced, and leave unstoppable skills alone.
    player, tags = Blocker()
    assert(player:ParryKnockback({ knocker = Attacker(30) }))
    assert(player.sg.destination == "kiritzuka_guard_hit")
    player = Blocker()
    assert(not player:ParryKnockback({ knocker = Attacker(135) }), "Behind is the native knockback")
    player, tags = Blocker()
    tags.nointerrupt = true
    player.sg.currentstate = { name = "kiritzuka_boss_slam" }
    assert(not player:ParryKnockback({ knocker = Attacker(30) }))
    assert(player.sg.destination == nil)
    assert(player:InterceptHit(Attacker(30), 50), "But the hit itself is still stopped")
    assert(player.sg.destination == nil)

    -- Rock Masters push when faced, and their dash is judged by where it came from.
    player = Blocker()
    local rock = Attacker(30)
    rock.prefab = "rocky_boss"
    assert(player:InterceptHit(rock, 100) and player.sg.destination == "kiritzuka_guard_hit")
    assert(player.sg.data.knockbackdata.knocker == rock, "Rock Masters still push")
    player, tags = Blocker()
    player.sg.currentstate = { name = "kiritzuka_boss_slam" }
    tags.nointerrupt = true
    assert(player:InterceptHit(rock, 100), "Even mid-skill, without the retreat")
    assert(player.sg.destination == nil)
    local behind_rock = Attacker(135)
    behind_rock.prefab = "rocky_boss"
    assert(not Blocker():InterceptHit(behind_rock, 100), "Behind it lands")
    local dashing = Attacker(135)
    dashing.prefab = "rocky_boss"
    dashing.sg = { currentstate = { name = "dash_attack" }, statemem = { dx = 6, dz = 0 }, HasStateTag = function() return false end }
    player, tags = Blocker()
    player.sg.currentstate = { name = "kiritzuka_boss_slam" }
    tags.nointerrupt = true
    assert(player:InterceptHit(dashing, 100), "A dash faced as it came, even mid-skill")

    player = Blocker()
    assert(player:ParrySustained(30, 0), "Burns when faced")
    assert(not Blocker():ParrySustained(135, 0), "Burns from behind land")

    -- It still needs an exclusive weapon and a player able to guard, and only stops attacks.
    player, tags, flags = Blocker()
    player.weapon.prefab = "spear"
    assert(not player:InterceptHit(Attacker(0), 50), "Not with other weapons")
    player = Blocker()
    player.weapon = nil
    assert(not player:InterceptHit(Attacker(0), 50), "Not unarmed")
    for _, flag in ipairs({ "dead", "riding", "heavy", "superheavyarmor" }) do
        player, tags, flags = Blocker()
        flags[flag] = true
        assert(not player:InterceptHit(Attacker(0), 50), flag)
    end
    player = Blocker()
    assert(not player:InterceptHit(nil, 50), "No attacker, no block")
    assert(not player:InterceptHit(player, 50), "Self damage lands")
    TUNING.KIRITZUKA_PARRY_ALL = nil
end

-- The guard's own hit and hold, which replace the native parry states and their pose.
do
    local states = {}
    FRAMES = 1 / 30
    State = function(def) return def end
    TimeEvent = function(time, fn) return { time = time, fn = fn } end
    EventHandler = function(name, fn) return { name = name, fn = fn } end
    TUNING.KIRITZUKA_BOSS_SLAM = { HITS = 5 }
    GLOBAL = _G
    local real_setfenv = setfenv
    GLOBAL.setfenv = function() end
    AddStategraphState = function(name, state) if name == "wilson" then states[state.name] = state end end
    AddStategraphPostInit = function() end
    dofile("postinit/stategraphs/SGkiritzuka.lua")
    GLOBAL.setfenv = real_setfenv
    local hit, hold = assert(states.kiritzuka_guard_hit), assert(states.kiritzuka_guard_hold)

    local function Guard()
        local inst = { sg = { statemem = {}, tags = {} }, played = {} }
        function inst.sg:SetTimeout(value) self.timeout = value end
        function inst.sg:GoToState(name, data) self.destination, self.data = name, data end
        inst.components = { locomotor = { Stop = function() end } }
        inst.ClearBufferedAction = function() end
        inst.ForceFacePoint = function(self, x) self.faced = x end
        inst.GetDistanceSqToPoint = function(self) return self.distsq or 0 end
        inst.AnimState = {
            PlayAnimation = function(_, name) inst.played[#inst.played + 1] = name end,
            PushAnimation = function(_, name, loop) inst.queued, inst.queued_loop = name, loop end,
        }
        inst.SoundEmitter = { PlaySound = function() end }
        inst.Physics = {
            SetMotorVel = function(_, value) inst.motor = value end,
            Stop = function() inst.motor = 0 end,
        }
        return inst
    end

    local guard = Guard()
    local knocker = Attacker(30)
    hit.onenter(guard, { timeleft = 0.75, knockbackdata = { knocker = knocker, radius = 3, strengthmult = 2.5 } })
    assert(guard.played[1] == "kiritzuka_guard_block", "Takes the blow on the guard")
    assert(guard.queued == "kiritzuka_guard_loop" and guard.queued_loop == true, "Stays up after it")
    assert(guard.faced == 30, "Turned to whatever hit her")
    assert(guard.motor == 2.5 * 12 * -1, "Backwards, hardest up close")
    assert(guard.sg.timeout == 6 * FRAMES)
    hit.onupdate(guard)
    assert(guard.motor == 0.75 * 2.5 * 12 * -1, "Fading each frame")
    hit.ontimeout(guard)
    assert(guard.sg.destination == "kiritzuka_guard_hold" and guard.sg.data == 0.75, "Then holds the guard")
    hit.onexit(guard)
    assert(guard.motor == 0)

    guard = Guard()
    guard.distsq = 100
    hit.onenter(guard, { timeleft = 0.75, knockbackdata = { knocker = knocker, radius = 3 } })
    assert(math.abs(guard.motor - 12 * -0.7) < 0.0001, "Out of range is the native minimum")
    hit.events[1].fn(guard)
    hit.ontimeout(guard)
    assert(guard.sg.destination == "idle" and not guard.sg.data, "Losing the weapon skips the hold and the pose")

    guard = Guard()
    hold.onenter(guard, 0.75)
    assert(#guard.played == 0, "Leaves the blow's animation playing into the loop")
    assert(guard.sg.timeout == 0.75)
    local has_idle = false
    for _, tag in ipairs(hold.tags) do has_idle = has_idle or tag == "idle" end
    assert(has_idle, "Walking or attacking drops it")
    hold.ontimeout(guard)
    assert(guard.played[1] == "kiritzuka_guard_pst" and guard.sg.destination == "idle" and guard.sg.data == true)
    guard.sg.destination = nil
    hold.events[1].fn(guard)
    assert(guard.sg.destination == "idle")
end

print("kiritzuka_parry: checks passed")
