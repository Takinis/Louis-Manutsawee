local AddClassPostConstruct = AddClassPostConstruct
local AddComponentPostInit = AddComponentPostInit
GLOBAL.setfenv(1, GLOBAL)

local function GetBanknotes(inventory)
    local notes = {}
    local total = 0
    local function Count(item)
        if item and item.prefab == "oinc1000000" and not notes[item] and not item:HasTag("nocrafting") then
            notes[item] = item._balance:value()
            total = total + notes[item]
        end
    end

    Count(inventory:GetActiveItem())
    for _, item in pairs(inventory:GetItems()) do
        Count(item)
    end
    local backpack = inventory:GetOverflowContainer()
    if backpack then
        for _, item in pairs(backpack:GetItems()) do
            Count(item)
        end
    end
    return total, notes
end

AddComponentPostInit("shopper", function(self)
    local GetCoinValue = self.GetMoney
    local PayCoins = self.PayMoney

    function self:GetMoney()
        return GetCoinValue(self) + GetBanknotes(self.inst.replica.inventory)
    end

    function self:PayMoney(cost)
        local coins = GetCoinValue(self)
        if coins >= cost then
            return PayCoins(self, cost)
        end

        local remaining = cost - coins
        local balance, notes = GetBanknotes(self.inst.replica.inventory)
        if remaining > balance then
            return false
        end
        if coins > 0 then
            PayCoins(self, coins)
        end
        for note, value in pairs(notes) do
            if value > remaining then
                note._balance:set(value - remaining)
                break
            end
            remaining = remaining - value
            note:Remove()
            if remaining == 0 then
                break
            end
        end
    end
end)

AddClassPostConstruct("components/inventory_replica", function(self)
    local Has = self.Has
    function self:Has(prefab, amount, ...)
        if self.check_all_oincs and prefab == "oinc" then
            local _, coins = Has(self, prefab, amount, ...)
            local total = coins + GetBanknotes(self)
            return total >= amount, total
        end
        return Has(self, prefab, amount, ...)
    end
end)
