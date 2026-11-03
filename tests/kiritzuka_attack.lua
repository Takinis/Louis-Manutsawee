-- Run from the mod directory: lua tests/kiritzuka_attack.lua
package.path = "scripts/?.lua;" .. package.path
FRAMES = 1 / 30
State = function(state) return state end
TimeEvent = function(time, fn) return { time = time, fn = fn } end
EventHandler = function(name, fn) return { name = name, fn = fn } end
local now = 0
GetTime = function() return now end

GLOBAL = _G
GLOBAL.setfenv = function() end
TUNING = { KIRITZUKA_BOSS_SLAM = { HITS = 5 } }
ACTIONS = { ATTACK = {}, MDODGE = {}, LIFT_DUMBBELL = {} }
local registered, postinits = {}, {}
AddStategraphState = function(name, state)
    registered[name] = registered[name] or {}
    registered[name][state.name] = state
end
AddStategraphPostInit = function(name, fn)
    postinits[name] = postinits[name] or {}
    table.insert(postinits[name], fn)
end
dofile("postinit/stategraphs/SGkiritzuka.lua")
local server = registered.wilson.kiritzuka_attack
local client = registered.wilson_client.kiritzuka_attack
local checked = 0
local function Check(value, message)
    assert(value, message)
    checked = checked + 1
end

local function NewWeapon(tags)
    return {
        HasTag = function(_, tag)
            return tags[tag] == true
        end,
    }
end

-- Runs the server route on its own, over a native handler that returns the given destination.
local function Route(weapon, rider, destination, prefab)
    local graph = {
        actionhandlers = {
            [ACTIONS.ATTACK] = { deststate = function() return destination end },
            [ACTIONS.LIFT_DUMBBELL] = { deststate = function() end },
        },
        events = { knockback = { fn = function() end } },
    }
    postinits.wilson[1](graph)
    return graph.actionhandlers[ACTIONS.ATTACK].deststate({
        prefab = prefab or "kiritzuka",
        IsSlamArmed = function() return false end,
        IsDashArmed = function() return false end,
        IsFlurryArmed = function() return false end,
        components = { rider = rider, combat = { GetWeapon = function() return weapon end } },
    }, {})
end

local weapon = NewWeapon({ weapon = true })
local rider = { IsRiding = function() return false end }
Check(Route(weapon, rider, "attack") == server.name, "Route melee attacks")
Check(Route(weapon, rider, "attack", "wilson") == "attack", "Leave other characters to the native route")
Check(Route(nil, rider, "attack") == "attack", "Preserve unarmed attacks")
Check(Route(weapon, rider, nil) == nil, "Preserve rejected attacks")
Check(Route(weapon, rider, "throw") == "throw", "Preserve special attack states")
Check(Route(NewWeapon({ light = true }), rider, "attack") == "attack", "Preserve non-weapons")
Check(Route(weapon, { IsRiding = function() return true end }, "attack") == "attack",
    "Preserve mounted attacks")
for _, tag in ipairs({
    "rangedweapon", "projectile", "complexprojectile", "whip", "pocketwatch",
    "book", "toolpunch", "lancejab", "chop_attack", "punch",
}) do
    Check(Route(NewWeapon({ weapon = true, [tag] = true }), rider, "attack") == "attack",
        "Preserve " .. tag .. " attacks")
end

local function NewPlayer(state, is_client, animation)
    local inst = {
        components = {}, replica = {}, performed = 0, previewed = 0, cleared = 0,
        started = 0, cancelled = 0, multiplier = 1, animation = animation,
    }
    local target = { valid = true }
    function target:IsValid() return self.valid end
    function target:GetPosition() return {} end
    inst.action = { target = target }
    function inst:GetBufferedAction() return self.action end
    function inst:ClearBufferedAction()
        self.cleared = self.cleared + 1
        self.action = nil
    end
    function inst:PerformBufferedAction()
        self.performed = self.performed + 1
        self.action = nil
    end
    function inst:PerformPreviewBufferedAction() self.previewed = self.previewed + 1 end
    function inst:FacePoint() self.faced = true end
    inst.AnimState = {
        IsCurrentAnimation = function(_, name) return inst.animation == name end,
        PlayAnimation = function(_, name)
            inst.animation = name
            inst.queued = nil
        end,
        PushAnimation = function(_, name, loop)
            inst.queued = name
            Check(loop == false, "Attack animations must not loop")
        end,
        SetDeltaTimeMultiplier = function(_, value) inst.multiplier = value end,
        AnimDone = function() return inst.done == true end,
    }
    inst.SoundEmitter = { PlaySound = function() end }
    local combat = {
        min_attack_period = .5,
        GetWeapon = function() return inst.weapon end,
        InCooldown = function() return inst.in_cooldown == true end,
        MinAttackPeriod = function() return inst.period or .5 end,
        StartAttack = function() inst.started = inst.started + 1 end,
        CancelAttack = function() inst.cancelled = inst.cancelled + 1 end,
        SetTarget = function(_, value) inst.combat_target = value end,
        BattleCry = function() inst.battle_cry = true end,
    }
    if is_client then
        inst.replica.combat = combat
    else
        inst.components.combat = combat
    end
    inst.components.locomotor = { Stop = function() inst.stopped = true end }
    inst.sg = { statemem = {}, mem = {}, tags = {} }
    for _, tag in ipairs(state.tags) do inst.sg.tags[tag] = true end
    function inst.sg:HasStateTag(tag) return self.tags[tag] == true end
    function inst.sg:RemoveStateTag(tag) self.tags[tag] = nil end
    function inst.sg:AddStateTag(tag) self.tags[tag] = true end
    function inst.sg:SetTimeout(value) self.timeout = value end
    function inst.sg:GoToState(name)
        self.destination = name
        state.onexit(inst)
    end
    return inst, target
end

for _, is_client in ipairs({ false, true }) do
    local state = is_client and client or server
    Check(state.name == "kiritzuka_attack", "Use matching server and client state names")
    local animations = { "idle", "atk", "spearjab", "scythe_loop" }
    local expected = { "atk", "atk", "atk", "atk" }
    for index, animation in ipairs(animations) do
        local inst, target = NewPlayer(state, is_client, animation)
        state.onenter(inst)
        Check(inst.queued == expected[index], "Other weapons use the plain swing")
        Check(inst.started == 1 and inst.stopped and inst.faced, "Start and face the attack")
        Check(inst.sg.timeout == .5, "Preserve slower attack cooldowns")
        Check(inst.sg.statemem.attacktarget == target and inst.sg.statemem.retarget == target,
            "Preserve target tracking")
        Check(inst.performed == 0, "Do not deal damage on entry")
        Check(inst.previewed == (is_client and 1 or 0), "Only preview on the client")
        Check(state.timeline[2].time == 8 * FRAMES, "Other weapons keep their commit frame")
        state.timeline[1].fn(inst)
        Check(inst.performed == 0 and inst.sg:HasStateTag("abouttoattack"), "Other weapons ignore the fast frame")
        state.timeline[2].fn(inst)
        Check(inst.performed == (is_client and 0 or 1), "Commit damage only on the server")
        Check(not inst.sg:HasStateTag("abouttoattack"), "End the wind-up after impact")
        state.ontimeout(inst)
        Check(not inst.sg:HasStateTag("attack") and inst.sg:HasStateTag("idle"),
            "Allow chaining after the attack cooldown")
        state.onexit(inst)
        Check(inst.multiplier == 1 and inst.cancelled == 0, "Restore playback after a completed attack")
        Check(inst.combat_target == nil, "Clear the server combat target")
    end

    local inst = NewPlayer(state, is_client, "spearjab")
    state.onenter(inst)
    state.onexit(inst)
    Check(inst.multiplier == 1 and inst.cancelled == 1 and inst.performed == 0,
        "Cancel interrupted wind-ups and restore playback")

    -- Signature weapons: swing, scythe, both landing on frame seven.
    local signature = NewWeapon({ weapon = true })
    signature.prefab = "baseballbat"
    Check(Route(signature, rider, "attack") == server.name, "Route signature weapons")
    local signature_player = NewPlayer(state, is_client, "idle")
    signature_player.weapon = signature
    local swings = {
        { pre = "atk_pre", loop = "atk", speed = 8 / 7 },
        { pre = "scythe_pre", loop = "scythe_loop", speed = 15 / 7 },
        { pre = "atk_pre", loop = "atk", speed = 8 / 7 },
    }
    Check(state.timeline[1].time == 7 * FRAMES, "Signature swings land earlier")
    for _, swing in ipairs(swings) do
        signature_player.sg.statemem = {}
        signature_player.sg.tags.abouttoattack = true
        signature_player.action = { target = {
            IsValid = function() return true end,
            GetPosition = function() return {} end,
        } }
        signature_player.performed = 0
        state.onenter(signature_player)
        Check(signature_player.animation == swing.pre and signature_player.queued == swing.loop,
            "Cycle signature animations")
        Check(signature_player.multiplier == swing.speed, "Speed up to the shared hit frame")
        state.timeline[1].fn(signature_player)
        Check(signature_player.performed == (is_client and 0 or 1), "Signature swing commits on frame seven")
        state.timeline[2].fn(signature_player)
        Check(signature_player.performed == (is_client and 0 or 1), "Signature swing commits only once")
        state.onexit(signature_player)
        Check(signature_player.multiplier == 1, "Restore playback after a signature swing")
    end

    -- The list is by prefab: each of these gets the combo, anything else the plain swing.
    for prefab, listed_signature in pairs({
        baseballbat = true, crowbar = true, rebar = true, pickaxe = true, goldenpickaxe = true,
        glasscutter = true, nightsword = true, spear = false, hambat = false,
    }) do
        local listed = NewPlayer(state, is_client, "idle")
        listed.weapon = NewWeapon({ weapon = true })
        listed.weapon.prefab = prefab
        state.onenter(listed)
        Check((listed.sg.statemem.signature_step ~= nil) == listed_signature, "Pick the attack set for " .. prefab)
    end

    -- Current step is now the swing; a pause past the window starts over.
    signature_player.sg.statemem = {}
    now = now + 2
    state.onenter(signature_player)
    Check(signature_player.animation == "atk_pre", "A pause restarts the combo")
    state.onexit(signature_player)

    -- A preview cancelled before impact does not advance the combo.
    signature_player.sg.statemem = {}
    state.onenter(signature_player)
    state.onexit(signature_player)
    signature_player.sg.statemem = {}
    state.onenter(signature_player)
    Check(signature_player.animation == "atk_pre", "Cancelled swings keep the combo step")
    state.onexit(signature_player)

    inst = NewPlayer(state, is_client)
    inst.in_cooldown = true
    state.onenter(inst)
    Check(inst.sg.destination == "idle" and inst.cleared == 1 and inst.started == 0,
        "Reject attacks during cooldown without starting another attack")

    inst = NewPlayer(state, is_client)
    if is_client then
        inst.period = .1
    else
        inst.components.combat.min_attack_period = .1
    end
    state.onenter(inst)
    Check(inst.sg.timeout == 13 * FRAMES, "Keep a minimum melee animation cooldown")

    inst = NewPlayer(state, is_client)
    state.onenter(inst)
    for _, event in ipairs(state.events) do
        if event.name == "animqueueover" then
            event.fn(inst)
            Check(inst.sg.destination == nil, "Ignore premature animation events")
            inst.done = true
            event.fn(inst)
            Check(inst.sg.destination == "idle", "Return to idle when the animation ends")
        end
    end

    for _, name in ipairs({ "equip", "unequip" }) do
        inst = NewPlayer(state, is_client, "spearjab")
        state.onenter(inst)
        for _, event in ipairs(state.events) do
            if event.name == name then event.fn(inst) end
        end
        Check(inst.sg.destination == "idle" and inst.cancelled == 1 and inst.multiplier == 1,
            "Interrupt safely on " .. name)
    end
end

local inst, target = NewPlayer(server, false)
server.onenter(inst)
target.valid = false
server.timeline[2].fn(inst)
Check(inst.performed == 0 and inst.cleared == 1, "Discard attacks whose target was removed")

local first = NewPlayer(server, false, "atk")
local second = NewPlayer(server, false, "idle")
server.onenter(first)
server.onenter(second)
first.weapon = NewWeapon({ weapon = true })
first.weapon.prefab = "baseballbat"
server.onenter(first)
server.timeline[1].fn(first)
server.onexit(first)
first.sg.statemem = {}
server.onenter(first)
Check(first.animation == "scythe_pre" and second.animation == "atk_pre", "Keep each player's combo independent")

MODROOT = "./"
EQUIPSLOTS = { HANDS = "hands" }
ActionHandler = function(action, destination) return { action = action, deststate = destination } end
package.loaded["utils/skillutil"] = {}
for _, name in ipairs({
    "heavenlystrike", "blockparry", "start_counter_attack",
    "counter_attack", "monemind", "quicksheath", "ryusen", "soryuha", "flip",
    "thrust", "ichimonji", "habakiri",
}) do
    package.loaded["postinit/stategraphs/skills/" .. name] = {}
end
AddStategraphEvent = function() end
AddStategraphActionHandler = function() end
-- Same load order as main/postinit.lua.
registered, postinits = {}, {}
dofile("postinit/stategraphs/SGwilson.lua")
dofile("postinit/stategraphs/SGwilson_client.lua")
dofile("postinit/stategraphs/SGkiritzuka.lua")

for _, name in ipairs({ "wilson", "wilson_client" }) do
    Check(registered[name].kiritzuka_attack ~= nil, "Register the attack in " .. name)
    local native_destination = "attack"
    local native_calls = 0
    local graph = {
        actionhandlers = {
            [ACTIONS.ATTACK] = {
                deststate = function()
                    native_calls = native_calls + 1
                    return native_destination
                end,
            },
            [ACTIONS.LIFT_DUMBBELL] = { deststate = function() end },
        },
        states = { wes_funnyidle = {} },
        events = { knockback = { fn = function() end } },
    }
    for _, postinit in ipairs(postinits[name]) do
        postinit(graph)
    end
    local is_client = name == "wilson_client"
    local player = NewPlayer(is_client and client or server, is_client)
    player.prefab = "kiritzuka"
    function player:IsSlamArmed() return self.slam_armed end
    function player:IsDashArmed() return self.dash_armed end
    function player:IsFlurryArmed() return self.flurry_armed end
    local combat = is_client and player.replica.combat or player.components.combat
    combat.GetWeapon = function() return weapon end
    local source = is_client and player.replica or player.components
    source.rider = rider
    local route = graph.actionhandlers[ACTIONS.ATTACK].deststate
    Check(route(player, {}) == "kiritzuka_attack" and native_calls == 1,
        "Route through the native handler once in " .. name)
    native_destination = nil
    Check(route(player, {}) == nil, "Keep the native attack guard in " .. name)
    native_destination = "throw"
    Check(route(player, {}) == "throw", "Keep specialized native states in " .. name)
    native_destination = "attack"
    combat.GetWeapon = function() return nil end
    Check(route(player, {}) == "attack", "Handle unarmed Kiritzuka in " .. name)
    if not is_client then
        player.slam_armed = true
        Check(route(player, {}) == "kiritzuka_boss_slam", "A readied slam takes the next attack")
        player.slam_armed = nil
        player.dash_armed = true
        Check(route(player, {}) == "kiritzuka_dash", "A readied dash takes the next attack")
        player.dash_armed = nil
        player.flurry_armed = true
        Check(route(player, {}) == "kiritzuka_flurry", "A readied flurry takes the next attack")
        player.flurry_armed = nil
    end
end

-- A hit blocked during the wind-up shows its guard right after the swing lands, once.
do
    local swinger = NewPlayer(server, false)
    local guards = {}
    function swinger:PlayBlockGuard(attacker) guards[#guards + 1] = attacker end
    server.onenter(swinger)
    local blocker = { IsValid = function() return true end }
    swinger.sg.statemem.block_attacker = blocker
    server.timeline[1].fn(swinger)
    Check(#guards == 0, "Not on the wrong commit frame")
    server.timeline[2].fn(swinger)
    Check(#guards == 1 and guards[1] == blocker, "Shown after the swing")
    Check(swinger.sg.statemem.block_attacker == nil, "Once")

    swinger = NewPlayer(server, false)
    guards = {}
    function swinger:PlayBlockGuard(attacker) guards[#guards + 1] = attacker end
    server.onenter(swinger)
    swinger.sg.statemem.block_attacker = { IsValid = function() return false end }
    server.timeline[2].fn(swinger)
    Check(#guards == 0, "Not for an attacker that has gone")
end

-- The knockback event asks the character first and otherwise stays native.
local native_knockbacks = 0
local graph = {
    actionhandlers = {
        [ACTIONS.ATTACK] = { deststate = function() end },
        [ACTIONS.LIFT_DUMBBELL] = { deststate = function() end },
    },
    events = { knockback = { fn = function() native_knockbacks = native_knockbacks + 1 end } },
}
postinits.wilson[#postinits.wilson](graph)
local knockback = graph.events.knockback.fn
knockback({ ParryKnockback = function() return true end }, {})
Check(native_knockbacks == 0, "A parried knockback skips the native handler")
knockback({ ParryKnockback = function() return false end }, {})
Check(native_knockbacks == 1, "An unparried knockback stays native")
knockback({}, {})
Check(native_knockbacks == 2, "Other characters stay native")

print("kiritzuka_attack: " .. checked .. " checks passed")
