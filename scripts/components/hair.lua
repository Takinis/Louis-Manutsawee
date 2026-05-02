local Hair_Growth_Lengths = {
    short  = { days = 3,  bits = 2 },
    medium = { days = 7,  bits = 5 },
    long   = { days = 16, bits = 9 },
}

local Hair_Lengths = {"cut", "short", "medium", "long"}
local Hair_Styles  = {"", "_yoto", "_ronin", "_pony", "_twin", "_htwin", "_ball" }
local Hair_Symbols = {"hairpigtails", "hair", "hair_hat", "headbase", "headbase_hat"}

local function GetHairLengthIndex(length)
    for i, v in ipairs(Hair_Lengths) do
        if v == length then
            return i
        end
    end
    return nil
end

local function OnEquip(inst, data)
    local eslot = data.eslot
    if eslot ~= nil and eslot == EQUIPSLOTS.HEAD then
        inst.components.hair:ChangeHairOverrideSymbol()
    end
end

local Hair = Class(function(self, inst)
    self.inst = inst

    self.hair_length = 1
    self.hair_style  = 1

    local beard = self.inst:AddComponent("beard")
    beard.insulation_factor = 1
    beard.onreset = self.OnResetHair
    beard.prize = "beardhair"
    beard.is_skinnable = false

    beard:AddCallback(Hair_Growth_Lengths.short.days,  function() self:ChangeHairGrowthLength("short")  end)
    beard:AddCallback(Hair_Growth_Lengths.medium.days, function() self:ChangeHairGrowthLength("medium") end)
    beard:AddCallback(Hair_Growth_Lengths.long.days,   function() self:ChangeHairGrowthLength("long")   end)

    inst:ListenForEvent("equip", OnEquip)
    inst:ListenForEvent("death", function()
        self:ChangeCutOverrideSymbol()
    end)
end)

function Hair:ChangeCutOverrideSymbol()
    self.hair_length = 1
    self.hair_style  = 1
    for i = 1, #Hair_Symbols do
        self.inst.AnimState:ClearOverrideSymbol(Hair_Symbols[i])
    end
end

function Hair:ChangeHairOverrideSymbol()
    local atlas = "hair_" .. Hair_Lengths[self.hair_length] .. Hair_Styles[self.hair_style]
    for i = 1, #Hair_Symbols do
        self.inst.AnimState:OverrideSymbol(Hair_Symbols[i], atlas, Hair_Symbols[i])
    end

    self.inst.components.beard.insulation_factor = (self.hair_style <= 2) and 1 or 0.1
end

function Hair:ChangeHairGrowthLength(inst, length)
    self.hair_length = GetHairLengthIndex(length) or 1
    inst.components.beard.bits = Hair_Growth_Lengths[length].bits
    self:ChangeHairOverrideSymbol()
end

function Hair:OnResetHair(inst)
    if self.hair_length > 2 then
        self.hair_length = self.hair_length - 1
        local length = Hair_Lengths[self.hair_length]
        inst.components.beard.daysgrowth = Hair_Growth_Lengths[length].days
        self:ChangeHairGrowthLength()
    else
        self:ChangeCutOverrideSymbol()
    end
end

function Hair:ChangeHairStyle()
    self.hair_style = self.hair_style % #Hair_Styles + 1
    self:ChangeHairOverrideSymbol()
end

function Hair:GetHairLength()
    return Hair_Lengths[self.hair_length]
end

function Hair:GetHairStyle()
    return Hair_Styles[self.hair_style]
end

function Hair:GetDebugString()
    local hair_style = self:GetHairStyle()
    return string.format("Hair Length: %s, Hair Style: %s",
        tostring(self:GetHairLength()),
        tostring(hair_style == "" and "None" or hair_style)
    )
end

function Hair:OnSave()
    return {
        hair_length = self.hair_length,
        hair_style  = self.hair_style,
    }
end

function Hair:OnLoad(data)
    if data ~= nil then
        self.hair_length = data.hair_length or 1
        self.hair_style  = data.hair_style  or 1
        self:ChangeHairOverrideSymbol()
    end
end

return Hair
