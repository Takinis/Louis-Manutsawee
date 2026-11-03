local AddPlayerPostInit = AddPlayerPostInit
local Cursable = require("components/cursable")
local curse_monkey = require("curse_monkey_util")
GLOBAL.setfenv(1, GLOBAL)

-- These characters are out of the monkey curse altogether: nothing below may touch them.
local function IsImmune(inst)
    return inst:HasTag("monkeycurse_immune")
end

-- Set after the character's own postinit runs, so it can only be refused from here.
AddPlayerPostInit(function(inst)
    if inst.ChangeToMonkey ~= nil and IsImmune(inst) then
        inst.ChangeToMonkey = function() end
    end
end)

local _IsCursable = Cursable.IsCursable
function Cursable:IsCursable(item, ...)
    if IsImmune(self.inst) then
        return false
    end
    return _IsCursable(self, item, ...)
end

local _ApplyCurse = Cursable.ApplyCurse
function Cursable:ApplyCurse(...)
    if IsImmune(self.inst) then
        return
    end
    return _ApplyCurse(self, ...)
end

-- A token already bound to them, from before this or an old save, lets go instead of clinging on.
local _ForceOntoOwner = Cursable.ForceOntoOwner
function Cursable:ForceOntoOwner(item, ...)
    if IsImmune(self.inst) then
        local curseditem = item.components.curseditem
        if curseditem ~= nil and curseditem.cursed_target == self.inst then
            curseditem.cursed_target = nil
        end
        item:RemoveTag("applied_curse")
        return
    end
    return _ForceOntoOwner(self, item, ...)
end

local _docurse = curse_monkey.docurse
curse_monkey.docurse = function(owner, ...)
    if IsImmune(owner) then
        return
    end
    return _docurse(owner, ...)
end
