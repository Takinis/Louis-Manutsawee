-- Run from the mod directory: lua tests/monkey_curse.lua
package.path = "scripts/?.lua;" .. package.path
GLOBAL = _G
GLOBAL.setfenv = function() end

local function Character(immune)
    local inst = { tasks = {} }
    inst.HasTag = function(_, tag) return tag == "monkeycurse_immune" and immune end
    inst.DoTaskInTime = function(self, _, fn, ...)
        local args = { ... }
        table.insert(self.tasks, function() fn(self, unpack(args)) end)
    end
    inst.components = { inventory = { DropItem = function(_, item, whole, random) inst.dropped = { item, whole, random } end } }
    return inst
end

local function Item()
    local item = { components = { curseditem = {}, inventoryitem = {} } }
    item.IsValid = function() return true end
    item.RemoveTag = function(self, tag) self.removed = tag end
    item.components.inventoryitem.IsHeldBy = function() return true end
    return item
end

-- Cursable: every way in is shut for them, and open for everyone else.
local native = {}
local Cursable = {
    IsCursable = function() native.iscursable = true; return true end,
    ApplyCurse = function() native.apply = true end,
    ForceOntoOwner = function() native.force = true end,
}
local util = { docurse = function() native.docurse = true end }
package.loaded["components/cursable"] = Cursable
package.loaded["curse_monkey_util"] = util
local player_postinit
AddPlayerPostInit = function(fn) player_postinit = fn end
dofile("postinit/components/cursable.lua")

-- The transformation itself is refused, for them only.
local turned = false
local function Morpher(immune)
    local player = Character(immune)
    player.ChangeToMonkey = function() turned = true end
    player_postinit(player)
    return player
end
Morpher(true):ChangeToMonkey()
assert(not turned, "They cannot be turned")
Morpher(false):ChangeToMonkey()
assert(turned, "Others still can")
player_postinit(Character(true))

local function Cursed(inst)
    return setmetatable({ inst = inst }, { __index = Cursable })
end

local immune = Cursed(Character(true))
assert(immune:IsCursable(Item()) == false)
immune:ApplyCurse(Item())
util.docurse(immune.inst, 3)
assert(native.apply == nil and native.docurse == nil and native.iscursable == nil, "Refused for them")

local token = Item()
token.components.curseditem.cursed_target = immune.inst
immune:ForceOntoOwner(token)
assert(native.force == nil and token.components.curseditem.cursed_target == nil, "A bound token lets go")
assert(token.removed == "applied_curse")

local other = Cursed(Character(false))
assert(other:IsCursable(Item()) == true)
other:ApplyCurse(Item())
other:ForceOntoOwner(Item())
util.docurse(other.inst, 3)
assert(native.apply and native.force and native.docurse, "Everyone else keeps the native curse")

-- Curseditem: they can hold a token, and it does nothing to them.
local Curseditem = { Given = function() native.given = true end }
package.loaded["components/curseditem"] = Curseditem
dofile("postinit/components/curseditem.lua")
local given = setmetatable({ target = "someone" }, { __index = Curseditem })
local owner = Character(true)
owner.components.cursable = {}
given:Given(Item(), { owner = owner })
assert(native.given == nil and given.target == nil, "Held, with no curse")
assert(#owner.tasks == 0 and owner.dropped == nil, "And it stays in the inventory")
owner = Character(false)
owner.components.cursable = {}
given:Given(Item(), { owner = owner })
assert(native.given, "Native for everyone else")

-- The search passes over immune players and goes on to whoever is next.
local function Player(distance, immune, dead)
    local player = Character(immune)
    player.dead = dead
    player.entity = { IsVisible = function() return player.hidden ~= true end }
    player.GetDistanceSqToPoint = function() return distance * distance end
    player.components.cursable = { IsCursable = function() return true end }
    player.components.debuffable = { HasDebuff = function() return false end }
    return player
end
IsEntityDeadOrGhost = function(player) return player.dead == true end
GetTime = function() return 7 end
Vector3 = function(x, y, z) return { x = x, y = y, z = z } end

local function Search(players, has_space)
    AllPlayers = players
    local tick
    local cursed = setmetatable({
        inst = {
            Transform = { GetWorldPosition = function() return 0, 0, 0 end },
            DoPeriodicTask = function(_, _, fn)
                tick = fn
                return { Cancel = function() end }
            end,
        },
        checkplayersinventoryforspace = function() return has_space ~= false end,
    }, { __index = Curseditem })
    cursed:lookforplayer()
    tick()
    return cursed.target
end

local near_immune, farther = Player(3, true), Player(8, false)
assert(Search({ near_immune, farther }) == farther, "Goes past the immune player")
assert(Search({ farther, near_immune }) == farther, "Whatever the order")
assert(Search({ near_immune }) == nil, "Nobody to curse")
assert(Search({ Player(5, false), Player(2, false) }).GetDistanceSqToPoint() == 4, "The closest still comes first")
assert(Search({ Player(11, false) }) == nil, "Native range")
assert(Search({ Player(3, false, true) }) == nil, "Not the dead")
local hidden = Player(3, false)
hidden.hidden = true
assert(Search({ hidden }) == nil, "Not the unseen")
assert(Search({ Player(3, false) }, false) == nil, "Needs room in the inventory")
local protected = Player(3, false)
protected.components.debuffable.HasDebuff = function() return true end
assert(Search({ protected }) == nil, "Not the protected")

print("PASS: immune players hold tokens uncursed and the curse moves on to others")
