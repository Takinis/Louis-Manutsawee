local BUILD = "voidcloth_scythe_death"
local DEFAULT_BUILD = "scythe_voidcloth"
local function DisableFx(inst)
    local fx = inst.fx
    if fx == nil or inst._death_sickle_fx ~= nil then
        return
    end
    local saved = {fx = fx, toggle = fx.ToggleEquipped, show = fx.Show}
    inst._death_sickle_fx = saved
    fx:ToggleEquipped(false)
    fx:Hide()
    -- Native equip and repair callbacks still call these methods.
    fx.ToggleEquipped = function(self)
        saved.toggle(self, false)
    end
    fx.Show = fx.Hide
end

local function RestoreFx(inst)
    local saved = inst._death_sickle_fx
    if saved == nil then
        return
    end
    local fx = saved.fx
    fx.ToggleEquipped = saved.toggle
    fx.Show = saved.show
    inst._death_sickle_fx = nil
    fx:ToggleEquipped(inst._fxowner ~= nil)
    if inst.isbroken:value() then
        fx:Hide()
    else
        fx:Show()
    end
end

local function RefreshHeld(inst, build)
    local owner = inst._fxowner
    if owner ~= nil then
        if build ~= nil then
            owner.AnimState:OverrideItemSkinSymbol("swap_object", build, "swap_scythe", inst.GUID, DEFAULT_BUILD)
        else
            owner.AnimState:OverrideSymbol("swap_object", DEFAULT_BUILD, "swap_scythe")
        end
    end
end

local function Init(inst)
    if not TheWorld.ismastersim then
        return
    end

    inst._death_sickle_skin = true
    inst.skin_build_name = BUILD
    basic_init_fn(inst, BUILD, DEFAULT_BUILD)
    DisableFx(inst)
    RefreshHeld(inst, BUILD)
end

local function Clear(inst)
    if not TheWorld.ismastersim then
        return
    end

    local applied = inst._death_sickle_skin
    inst._death_sickle_skin = nil
    inst.skin_build_name = nil
    basic_clear_fn(inst, DEFAULT_BUILD)
    if applied then
        RestoreFx(inst)
        RefreshHeld(inst)
        -- Clear can run before the engine changes skinname.
        local floater = inst.components.floater
        if floater ~= nil and floater:IsFloating() then
            inst.AnimState:OverrideSymbol(
                "swap_spear", DEFAULT_BUILD,
                inst.isbroken:value() and "scythe_base_broken_float" or "swap_scythe"
            )
        end
    end
    inst.skin_build_name = nil
end

return {
    Init = Init,
    Clear = Clear,
}
