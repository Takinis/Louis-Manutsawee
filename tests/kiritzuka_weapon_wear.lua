-- Run from the mod directory: lua tests/kiritzuka_weapon_wear.lua
package.path = "scripts/?.lua;" .. package.path
FRAMES = 1 / 30
TUNING = {
    GAMEMODE_STARTING_ITEMS = { DEFAULT = { KIRITZUKA = {} } },
    KIRITZUKA_BOSS_SLAM = { HITS = 5 },
    KIRITZUKA_FLURRY = {},
    KIRITZUKA_ARMOR_BREAK = { STEP = 0.05, MAX_STACKS = 10, WINDOW = 5 },
    KIRITZUKA_CRIT = { CHANCE = { 0 }, MULTIPLIER = { 2 }, CHANCE_STEP = 0 },
    KIRITZUKA_WEAPON_WEAR = { ATTACK_MULT = 2, SKILL_USES = 3 },
    SMALL_ANIMALS = { TAGS = { "prey", "bird", "butterfly" }, HUNGER = 0.1, DAMAGE_MULT = 0.1 },
}
STRINGS = dofile("strings/common.lua")
EQUIPSLOTS = { HANDS = "hands", BODY = "body" }
TheNet = { GetServerGameMode = function() return "default" end }
FlattenTree = function(tree) return tree[1] end
Asset = function() end
package.loaded["components/spdamageutil"] = {}
GetTime = function() return 0 end
math.random = function(a) return a or 1 end -- never crits

local master
package.loaded["prefabs/player_common"] = function(_, _, _, _, master_fn) master = master_fn end
dofile("scripts/prefabs/kiritzuka.lua")

local function Player()
    local listeners = {}
    local player = { listeners = listeners, hunger = 1 }
    player.AddComponent = function() end
    player.HasTag = function() return false end
    player.ListenForEvent = function(_, event, fn)
        listeners[event] = listeners[event] or {}
        table.insert(listeners[event], fn)
    end
    player.AnimState = { SetScale = function() end }
    player.sg = { statemem = {}, HasStateTag = function() return false end }
    player.components = {
        combat = {
            attackrange = 2, hitrange = 3,
            GetWeapon = function() return player.weapon end,
            SetRange = function() end,
            CanTarget = function() return true end,
            IsAlly = function() return false end,
        },
        health = { SetMaxHealth = function() end, IsDead = function() return false end },
        hunger = { SetMax = function() end, GetPercent = function() return player.hunger end },
        sanity = { SetMax = function() end },
        rider = { IsRiding = function() return false end },
        inventory = { IsHeavyLifting = function() return false end },
        playercontroller = { IsEnabled = function() return true end },
        talker = { Say = function(self, line) self.line = line end },
    }
    master(player)
    return player
end

local function Push(player, event, data)
    for _, fn in ipairs(player.listeners[event]) do
        fn(player, data)
    end
end

local function Weapon(prefab, durability)
    local modifiers = {}
    local weapon = { prefab = prefab, valid = true }
    weapon.IsValid = function(self) return self.valid end
    weapon.components = {
        weapon = {
            attackwearmultipliers = {
                SetModifier = function(_, source, value) modifiers[source] = value end,
                RemoveModifier = function(_, source) modifiers[source] = nil end,
            },
        },
    }
    if durability == "fuel" then
        weapon.components.fueled = {
            maxfuel = 100, current = 100,
            DoDelta = function(self, delta) self.current = self.current + delta end,
        }
    else
        weapon.components.finiteuses = {
            total = 100, current = 100,
            Use = function(self, num) self.current = self.current - num end,
        }
    end
    weapon.modifiers = modifiers
    return weapon
end

-- Any weapon in her hands wears twice as fast, until she puts it down.
do
    local player = Player()
    local spear = Weapon("spear")
    Push(player, "equip", { eslot = EQUIPSLOTS.HANDS, item = spear })
    assert(spear.modifiers[player] == 2)
    Push(player, "unequip", { eslot = EQUIPSLOTS.HANDS, item = spear })
    assert(spear.modifiers[player] == nil, "Back to normal for whoever picks it up next")
    local armor = Weapon("armorwood")
    Push(player, "equip", { eslot = EQUIPSLOTS.BODY, item = armor })
    assert(armor.modifiers[player] == nil, "Only what she swings")
end

-- Advanced weapons can carry her skills, ordinary ones still can't.
do
    local player = Player()
    player.weapon = Weapon("spear")
    assert(not player:ToggleFlurry() and not player:IsFlurryArmed())
    for _, prefab in ipairs({ "nightsword", "ruins_bat", "glasscutter", "sword_lunarplant", "shadow_battleaxe", "batbat", "nightstick" }) do
        player = Player()
        player.weapon = Weapon(prefab)
        assert(player:ToggleFlurry() and player:IsFlurryArmed(), prefab .. " carries skills")
    end
end

-- A third of a full weapon per skill, taken only once she has left every state of it.
local function Target()
    return {
        IsValid = function() return true end,
        IsInLimbo = function() return false end,
        HasTag = function() return false end,
        HasAnyTag = function() return false end,
        Transform = {},
        components = { combat = {}, health = { IsDead = function() return false end } },
    }
end
do
    local player = Player()
    local sword = Weapon("nightsword")
    player.weapon = sword
    assert(player:TryReleaseFlurry(Target()))
    Push(player, "newstate", { statename = "kiritzuka_flurry" })
    assert(sword.components.finiteuses.current == 100, "Not while the flurry is going")
    Push(player, "newstate", { statename = "idle" })
    assert(sword.components.finiteuses.current == 66)
    Push(player, "newstate", { statename = "idle" })
    assert(sword.components.finiteuses.current == 66, "Once per skill")
    for _ = 1, 2 do
        assert(player:TryReleaseFlurry(Target()))
        Push(player, "newstate", { statename = "idle" })
    end
    assert(sword.components.finiteuses.current <= 0, "Three from full and it's gone")

    local star = Weapon("nightstick", "fuel")
    player.weapon = star
    assert(player:TryReleaseFlurry(Target()))
    Push(player, "newstate", { statename = "idle" })
    assert(star.components.fueled.current == 66, "Charge goes the same way")

    local lost = Weapon("glasscutter")
    player.weapon = lost
    assert(player:TryReleaseFlurry(Target()))
    lost.valid = false
    Push(player, "newstate", { statename = "idle" })
    assert(player.kiritzuka_skill_wear == nil, "A weapon already gone is let go")

    local bat = Weapon("baseballbat")
    player.weapon = bat
    assert(player:TryReleaseFlurry(Target()))
    assert(player.kiritzuka_skill_wear == nil, "Her own never wear")
end

-- Small animals: nothing from her own swings until she is starving, and little even then.
do
    local player = Player()
    local rabbit = Target()
    rabbit.HasAnyTag = function(_, ...)
        for _, tag in ipairs({ ... }) do
            if tag == "prey" then return true end
        end
        return false
    end
    local mult = player.components.combat.customdamagemultfn
    assert(mult(player, Target()) == 1)
    assert(mult(player, rabbit) == 0)
    player.hunger = 0.1
    assert(mult(player, rabbit) == 0, "Not until below a tenth")
    player.hunger = 0.09
    assert(mult(player, rabbit) == 0.1)
    player.hunger = 1
    local frog = Target()
    frog.HasAnyTag = rabbit.HasAnyTag
    frog.HasTag = function(_, tag) return tag == "hostile" end
    assert(mult(player, frog) == 1, "Frogs come at her, so they take the full blow")
end

-- The client side refuses to target them the same way, so the attack is never offered.
do
    GLOBAL = _G
    GLOBAL.setfenv = function() end
    local Combat = { CanTarget = function() return true end }
    package.loaded["components/combat_replica"] = Combat
    dofile("postinit/components/combat_replica.lua")
    local hunger = 1
    local function Replica(prefab)
        return {
            inst = { prefab = prefab, replica = { hunger = { GetPercent = function() return hunger end } } },
            CanTarget = Combat.CanTarget,
        }
    end
    local rabbit = { HasAnyTag = function() return true end, HasTag = function() return false end }
    local hound = { HasAnyTag = function() return false end }
    local frog = { HasAnyTag = function() return true end, HasTag = function(_, tag) return tag == "hostile" end }
    local her = Replica("kiritzuka")
    assert(not her:CanTarget(rabbit) and her:CanTarget(hound))
    assert(Replica("wilson"):CanTarget(rabbit), "Others hunt as usual")
    assert(her:CanTarget(frog), "A frog can always be fought back")
    assert(not Replica("manutsawee"):CanTarget(rabbit) and Replica("manutsawee"):CanTarget(hound), "Manutsawee spares them too")
    hunger = 0.05
    assert(her:CanTarget(rabbit), "Hunger drives her to it")
end

-- Manutsawee's own swings follow the same damage rule.
do
    local file = assert(io.open("scripts/prefabs/manutsawee.lua"))
    local source = file:read("*a")
    file:close()
    assert(source:find("customdamagemultfn = SmallAnimalUtil.GetDamageMult", 1, true))
end

print("kiritzuka_weapon_wear: checks passed")
