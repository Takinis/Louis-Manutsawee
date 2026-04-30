local Glasses = Class(function(self, inst)

    self.inst = inst

    self.is_puted = false

    self.glasses = {}
end)

function Glasses:UpdateGlass(puted)
    local build = self.glasses[self.inst.AnimState:GetBuild()]
    local symbol = build ~= nil and build or "eyeglasses"
    if puted and not self.inst.AnimState:GetSymbolOverride("swap_face") then
        self.inst.AnimState:OverrideSymbol("swap_face", symbol, "swap_face")
    else
        self.inst.AnimState:ClearOverrideSymbol("swap_face")
    end
    self.is_puted = puted
end

function Glasses:IsPuted()
    return self.is_puted
end

function Glasses:AddGlass(build, glass_build)
    self.glasses[build] = glass_build
end

function Glasses:OnSave()
    local data = {}
    data.is_puted = self.is_puted
    return data
end

function Glasses:OnLoad(data)
    if data ~= nil then
        if data.is_puted then
            self:UpdateGlass(data.is_puted)
        end
    end
end

function Glasses:GetDebugString()
    return string.format("Is Puted Glass: %s", tostring(self.is_puted))
end

return Glasses
