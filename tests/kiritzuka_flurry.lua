-- Run from the mod directory: lua tests/kiritzuka_flurry.lua
package.path = "scripts/?.lua;" .. package.path
FRAMES = 1 / 30
TUNING = {
    GAMEMODE_STARTING_ITEMS = { DEFAULT = { KIRITZUKA = {} } },
    KIRITZUKA_BOSS_SLAM = { HITS = 5 },
    KIRITZUKA_FLURRY = { DAMAGE_MULT = 0.4, IMAGE_DISTANCE = 1.2, IMAGE_ARC = 180 },
}
STRINGS = dofile("strings/common.lua")
TheNet = { GetServerGameMode = function() return "default" end, IsDedicated = function() return false end }
TheWorld = { ismastersim = true }
FlattenTree = function(tree) return tree[1] end
Asset = function() end
State = function(def) return def end
TimeEvent = function(time, fn) return { time = time, fn = fn } end
EventHandler = function(name, fn) return { name = name, fn = fn } end
package.loaded["prefabs/player_common_extensions"] = { SetupBaseSymbolVisibility = function() end }
package.loaded["components/spdamageutil"] = {}
local now = 0
GetTick = function() return 1 end
GetTime = function() return now end

GLOBAL = _G
GLOBAL.setfenv = function() end
local states = {}
AddStategraphState = function(name, state)
    if name == "wilson" then states[state.name] = state end
end
AddStategraphPostInit = function() end
dofile("postinit/stategraphs/SGkiritzuka.lua")
local state = assert(states.kiritzuka_flurry, "The flurry is registered")

local master
package.loaded["prefabs/player_common"] = function(_, _, _, _, master_fn) master = master_fn end
dofile("scripts/prefabs/kiritzuka.lua")

local images, blinks = {}, 0
SpawnPrefab = function(name)
    if name == "kiritzuka_hit_fx_puff" then
        blinks = blinks + 1
        return { Transform = { SetPosition = function() end } }
    end
    assert(name == "kiritzuka_flurry_image")
    local image = {}
    image.Transform = { SetPosition = function(_, x, y, z) image.x, image.y, image.z = x, y, z end }
    image.ForceFacePoint = function(_, x, _, z) image.faced = { x, z } end
    image.Setup = function(_, owner, weapon, anim) image.owner, image.weapon, image.anim = owner, weapon, anim end
    images[#images + 1] = image
    return image
end

local function Player()
    local timers = {}
    local player = {
        AddComponent = function() end,
        ListenForEvent = function() end,
        AnimState = {
            SetScale = function() end,
            PlayAnimation = function(self, anim) self.played = anim end,
            PushAnimation = function(self, anim) self.pushed = anim end,
            SetMultColour = function(self, r, g, b, a) self.mult = { r, g, b, a } end,
        },
        Transform = { GetWorldPosition = function() return -5, 0, 0 end },
        GetPosition = function() return { x = -5, y = 0, z = 0 } end,
        DynamicShadow = { Enable = function(self, enabled) self.enabled = enabled end },
        Physics = { Teleport = function(self, x, _, z) self.teleported = { x, z } end },
        SoundEmitter = { PlaySound = function(self) self.plays = (self.plays or 0) + 1 end },
        HasTag = function() return false end,
        ForceFacePoint = function(self, x, _, z) self.faced = { x, z } end,
        ClearBufferedAction = function(self) self.action = nil end,
        GetBufferedAction = function(self) return self.action end,
        hits = {},
        sg = {
            statemem = {},
            tags = {},
            HasStateTag = function() return false end,
            AddStateTag = function(self, tag) self.tags[tag] = true end,
            SetTimeout = function(self, time) self.timeout = time end,
            GoToState = function(self, name, data) self.destination, self.data = name, data end,
        },
    }
    player.weapon = { prefab = "baseballbat" }
    player.components = {
        combat = {
            attackrange = 2, hitrange = 3,
            GetWeapon = function() return player.weapon end,
            SetRange = function(self, attack, hit) self.attackrange, self.hitrange = attack, hit end,
            CanTarget = function() return true end,
            IsAlly = function() return false end,
            DoAttack = function(self, target, _, _, _, mult)
                assert(self.ignorehitrange, "A swing away from the images still lands")
                player.hits[#player.hits + 1] = { target = target, mult = mult }
            end,
        },
        health = {
            SetMaxHealth = function() end,
            IsDead = function() return false end,
            SetInvincible = function(self, invincible) self.invincible = invincible end,
        },
        hunger = { SetMax = function() end },
        sanity = { SetMax = function() end },
        rider = { IsRiding = function() return false end },
        inventory = { IsHeavyLifting = function() return false end },
        locomotor = { Stop = function(self) self.stopped = true end },
        playercontroller = { IsEnabled = function() return true end },
        talker = { Say = function(self, line) self.line = line end },
        timer = {
            TimerExists = function(_, name) return timers[name] ~= nil end,
            StartTimer = function(_, name, duration) timers[name] = duration end,
        },
    }
    player.timers = timers
    master(player)
    player.IsSlamPointSafe = function() return not player.landing_unsafe end
    return player
end

local function Target()
    local target = {
        dead = false,
        IsValid = function() return true end,
        IsInLimbo = function() return false end,
        HasTag = function() return false end,
        HasAnyTag = function() return false end,
        GetPhysicsRadius = function() return 0.8 end,
        Transform = { GetWorldPosition = function() return 0, 0, 0 end },
    }
    target.components = { combat = {}, health = { IsDead = function() return target.dead end } }
    return target
end

local function InPool(line, pool)
    if type(pool) ~= "table" then return line == pool end
    for _, entry in ipairs(pool) do
        if entry == line then return true end
    end
    return false
end

local function Enter(player, target)
    player.action = { target = target }
    state.onenter(player)
end

-- Armed like the other skills, but with her normal reach; with no second tier, a second press stands down.
local player = Player()
assert(player:ToggleFlurry() and player:IsFlurryArmed())
assert(player.components.combat.attackrange == 2)
assert(InPool(player.components.talker.line, STRINGS.SKILL.KIRITZUKA_FLURRY_READY))
assert(player:ToggleFlurry() and not player:IsFlurryArmed() and player.components.combat.attackrange == 2)
player.weapon = { prefab = "spear" }
assert(not player:ToggleFlurry() and not player:IsFlurryArmed(), "Ordinary weapons can't")

-- The attack spends it: she swings once at normal speed, with no cooldown after.
player = Player()
local target = Target()
player:ToggleFlurry()
Enter(player, target)
assert(not player:IsFlurryArmed() and player.components.combat.attackrange == 2)
assert(next(player.timers) == nil)
assert(player.sg.destination == nil and player.sg.statemem.target == target)
assert(player.components.locomotor.stopped and player.faced ~= nil and player.action == nil)
assert(player.AnimState.played == "atk_pre" and player.AnimState.pushed == "atk")

-- Ten hits: her own swing, then nine images.
local function FirstHit(player)
    assert(#state.timeline == 1)
    state.timeline[1].fn(player)
end
local function NextHit(player)
    player.sg.timeout = nil
    state.ontimeout(player)
end
local function Faded(player)
    local mult = player.AnimState.mult
    return mult ~= nil and mult[4] == 0
end
local function Solid(player)
    local mult = player.AnimState.mult
    return mult[1] == 1 and mult[2] == 1 and mult[3] == 1 and mult[4] == 1
end
images, blinks = {}, 0
FirstHit(player)
assert(#player.hits == 1 and #images == 0, "The first hit is her own")
assert(Faded(player) and player.DynamicShadow.enabled == false, "Then she is gone, shadow and all")
assert(player.components.health.invincible and player.sg.tags.noattack, "And too fast to touch")
assert(player.sg.tags.iframeskeepaggro, "Without what she is fighting losing interest")
assert(player.Hide == nil, "Faded, not hidden: a hidden entity stops being a valid target")
assert(blinks == 1)
assert(player.sg.timeout ~= nil, "The next hit is queued")
for _ = 2, 10 do
    NextHit(player)
    assert(player.sg.timeout ~= nil and player.sg.destination == nil, "Nothing cuts the sequence short")
end
assert(#player.hits == 10 and #images == 9)
assert(player.components.combat.ignorehitrange == false)
assert(player.SoundEmitter.plays == 10)
local anims, sides = {}, { [true] = 0, [false] = 0 }
for i, image in ipairs(images) do
    assert(player.hits[i + 1].target == target and player.hits[i + 1].mult == 0.4)
    assert(image.owner == player and image.weapon == player.weapon)
    assert(image.faced[1] == 0 and image.faced[2] == 0, "Every image swings at the target")
    local distance = math.sqrt(image.x * image.x + image.z * image.z)
    assert(math.abs(distance - 2) < 0.001, "At the target's body plus the image distance")
    anims[image.anim] = true
    sides[image.z > 0] = sides[image.z > 0] + 1
end
assert(anims.atk and anims.scythe_loop, "Both swings are shown")
assert(sides[true] > 0 and sides[false] > 0, "Spread to both sides")

-- She comes back where the last image stood, facing the target, and is free at once.
local last = images[#images]
assert(Faded(player), "Still gone until the last hit is done")
player.faced = nil
NextHit(player)
assert(#player.hits == 10, "Never an eleventh")
assert(player.sg.timeout == nil)
assert(player.Physics.teleported[1] == last.x and player.Physics.teleported[2] == last.z)
assert(player.faced[1] == 0 and player.faced[2] == 0)
assert(blinks == 2)
assert(player.sg.destination == "idle" and player.sg.data == nil, "Into a plain idle")
assert(player.AnimState.played == "atk_pre", "With no animation of its own")
state.onexit(player)
assert(Solid(player) and player.DynamicShadow.enabled == true)
assert(player.components.health.invincible == nil, "Back to what it was")

-- The gaps are one, two or three frames, and every one of them turns up.
do
    local seen = {}
    for _ = 1, 20 do
        player = Player()
        player:ToggleFlurry()
        Enter(player, Target())
        FirstHit(player)
        for _ = 1, 10 do
            local frames = player.sg.timeout / FRAMES
            local rounded = math.floor(frames + 0.5)
            assert(math.abs(frames - rounded) < 0.0001 and rounded >= 1 and rounded <= 3, frames)
            seen[rounded] = true
            NextHit(player)
        end
    end
    assert(seen[1] and seen[2] and seen[3])
end

-- Unsafe ground under the last image: she comes back where she started.
player = Player()
target = Target()
player:ToggleFlurry()
Enter(player, target)
FirstHit(player)
for _ = 2, 10 do NextHit(player) end
player.landing_unsafe = true
NextHit(player)
assert(player.Physics.teleported == nil and player.sg.destination == "idle")

-- Invincible already: leaving does not take that away. Any way out of the state restores her.
player = Player()
target = Target()
player:ToggleFlurry()
Enter(player, target)
player.components.health.invincible = true
FirstHit(player)
state.onexit(player)
assert(player.components.health.invincible == true and Solid(player))

-- A target that dies part way ends it there: she comes back at once.
player = Player()
target = Target()
player:ToggleFlurry()
Enter(player, target)
images = {}
FirstHit(player)
NextHit(player)
target.dead = true
NextHit(player)
assert(#player.hits == 2 and #images == 1 and player.sg.timeout == nil)
assert(player.sg.destination == "idle" and player.sg.data == nil)
assert(player.Physics.teleported[1] == images[1].x)
state.onexit(player)
assert(Solid(player))

-- With nothing to hit on the very first one she never vanishes, and her swing just plays out.
player = Player()
target = Target()
player:ToggleFlurry()
Enter(player, target)
images = {}
target.dead = true
FirstHit(player)
assert(not Faded(player) and #player.hits == 0 and player.AnimState.played == "atk_pre")
assert(player.sg.destination == "idle" and player.sg.data == true and player.Physics.teleported == nil)
assert(player.sg.timeout == nil)
state.onexit(player)
assert(player.AnimState.mult == nil and player.DynamicShadow.enabled == nil, "Nothing to restore")

-- So does losing the weapon: nothing left for the images to hold.
player = Player()
target = Target()
player:ToggleFlurry()
Enter(player, target)
images = {}
player.weapon = nil
FirstHit(player)
assert(#player.hits == 0 and #images == 0 and player.sg.destination == "idle")

-- Refused releases cost nothing.
player = Player()
player:ToggleFlurry()
Enter(player, nil)
assert(player.sg.destination == "idle" and player.timers.kiritzuka_flurry == nil)
assert(InPool(player.components.talker.line, STRINGS.SKILL.REFUSE_RELEASE))
player = Player()
player:ToggleFlurry()
player.weapon = { prefab = "spear" }
Enter(player, Target())
assert(player.sg.destination == "idle" and player.timers.kiritzuka_flurry == nil)
assert(InPool(player.components.talker.line, STRINGS.SKILL.KIRITZUKA_WEAPON_REFUSE), "The weapon's own refusal")

-- The image itself: holds her weapon, fades on every machine that draws it, removes itself on the server.
do
    local Prefab_ = Prefab
    local fns = {}
    Prefab = function(name, fn) fns[name] = fn end
    -- Only the flurry's image lives in this file.
    dofile("scripts/prefabs/kiritzuka_flurry_image.lua")
    Prefab = Prefab_
    local image_fn = fns.kiritzuka_flurry_image

    local function NewImage(fn)
        local periodic, delayed = {}, {}
        local anim = {
            mult = {}, add = {}, shown = {}, hidden = {},
            SetBank = function() end,
            SetBuild = function(self, build) self.build = build end,
            SetScale = function() end,
            Show = function(self, layer) self.shown[layer] = true end,
            Hide = function(self, layer) self.hidden[layer] = true end,
            SetMultColour = function(self, r, g, b, a) self.mult = { r, g, b, a } end,
            SetAddColour = function(self, r, g, b, a) self.add = { r, g, b, a } end,
            OverrideSymbol = function(self, symbol, build, source) self.override = { symbol, build, source } end,
            OverrideItemSkinSymbol = function(self, symbol, build, source, guid, fallback)
                self.skin_override = { symbol, build, source, guid, fallback }
            end,
            SetDeltaTimeMultiplier = function(self, mult) self.speed = mult end,
            PlayAnimation = function(self, name) self.played = name end,
        }
        local entity = {
            AddTransform = function() end,
            AddAnimState = function() end,
            AddNetwork = function() end,
            SetPristine = function() end,
        }
        CreateEntity = function()
            return {
                entity = entity,
                AnimState = anim,
                Transform = { SetFourFaced = function() end },
                AddTag = function() end,
                Remove = "remove",
                DoPeriodicTask = function(_, _, fn) periodic[#periodic + 1] = fn end,
                DoTaskInTime = function(_, time, fn) delayed[#delayed + 1] = { time = time, fn = fn } end,
            }
        end
        return (fn or image_fn)(), anim, periodic, delayed
    end

    now = 10
    local image, anim, periodic, delayed = NewImage()
    assert(anim.shown.ARM_carry and anim.hidden.ARM_normal, "The arm that holds a weapon")
    assert(image.persists == false and delayed[1].fn == "remove")
    assert(anim.mult[4] == 0.8, "Starts at full strength")
    now = 10 + delayed[1].time / 2
    periodic[1](image)
    assert(math.abs(anim.mult[4] - 0.2) < 0.001, "Fades")
    now = 10 + delayed[1].time + 1
    periodic[1](image)
    assert(anim.mult[4] == 0 and anim.add[1] == 0, "Gone by the end, tint included")

    local owner = { AnimState = { GetBuild = function() return "kiritzuka" end } }
    image:Setup(owner, { prefab = "crowbar", GetSkinBuild = function() end }, "atk")
    assert(anim.build == "kiritzuka" and anim.played == "atk" and anim.speed == 3)
    assert(anim.override[1] == "swap_object" and anim.override[2] == "swap_crowbar" and anim.override[3] == "swap_crowbar")
    image:Setup(owner, { prefab = "rebar", GUID = 7, GetSkinBuild = function() return "rebar_skin" end }, "atk")
    assert(anim.skin_override[2] == "rebar_skin" and anim.skin_override[4] == 7 and anim.skin_override[5] == "swap_rebar")

    -- A client has no Setup or removal of its own, and a dedicated server has nothing to fade.
    TheWorld.ismastersim = false
    local client, _, client_periodic, client_delayed = NewImage()
    assert(client.Setup == nil and #client_delayed == 0 and #client_periodic == 1)
    TheWorld.ismastersim = true
    TheNet.IsDedicated = function() return true end
    local _, dedicated_anim, dedicated_periodic = NewImage()
    assert(#dedicated_periodic == 0 and dedicated_anim.mult[4] == nil)
end

-- Reachable: the key, its setting, its RPC, and the image's prefab file.
local function Source(path)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    return source
end
assert(Source("scripts/utils/keybinds.lua"):find('name = "kiritzuka_flurry"', 1, true))
assert(Source("main/RPC.lua"):find("KiritzukaFlurry = function", 1, true))
assert(Source("main/assets.lua"):find('"kiritzuka_flurry_image"', 1, true))
for _, po in ipairs({ "chinese_s.po", "chinese_t.po", "strings.pot" }) do
    local source = Source("scripts/languages/" .. po)
    assert(source:find('msgctxt "STRINGS.SKILL.KIRITZUKA_FLURRY_READY.1"', 1, true), po)
    assert(not source:find("KIRITZUKA_FLURRY_COOLDOWN", 1, true), po)
end

print("kiritzuka_flurry: checks passed")
