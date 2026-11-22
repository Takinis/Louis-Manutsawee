-- Run from the mod directory: lua tests/death_sickle.lua
package.path = "scripts/?.lua;" .. package.path
local function Equal(actual, expected)
    assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
end

local function LoadGameScript(path)
    local process = assert(io.popen("unzip -p ../../data/databundles/scripts.zip scripts/" .. path, "r"))
    local source = process:read("*a")
    process:close()
    assert(#source > 0, "Missing installed game script: " .. path)
    return assert(loadstring(source, "@installed_game/" .. path))()
end

local guid = 0
local dedicated = false
local entities = {}
TheWorld = {ismastersim = true}
TheNet = {IsDedicated = function() return dedicated end}
EQUIPSLOTS = {HEAD = "head"}
ACTIONS = {SCYTHE = "scythe"}
FORGEMATERIALS = {VOIDCLOTH = "voidcloth"}
TUNING = {
    DAPPERNESS_MED = 1,
    VOIDCLOTH_SCYTHE_DAMAGE = 38,
    VOIDCLOTH_SCYTHE_USES = 200,
    VOIDCLOTH_SCYTHE_PLANAR_DAMAGE = 30,
    VOIDCLOTH_SCYTHE_SHADOW_LEVEL = 3,
    WEAPONS_VOIDCLOTH_VS_LUNAR_BONUS = 1.1,
    WEAPONS_VOIDCLOTH_SETBONUS_DAMAGE_MULT = 1.1,
}
STRINGS = {VOIDCLOTH_SCYTHE_TALK = {}}
Assets = {}
CAN_USE_DBUI = false
TALKINGFONT = "talkingfont"
Asset = function(kind, file) return {kind, file} end
Prefab = function(name, fn, assets, deps)
    return {name = name, fn = fn, assets = assets, deps = deps}
end
Vector3 = function(x, y, z) return {x, y, z} end
shallowcopy = function(t)
    local result = {}
    for k, v in pairs(t) do result[k] = v end
    return result
end

net_bool = function(id)
    assert(not entities[id].pristine, "Netvar declared after SetPristine")
    return {
        current = false,
        set = function(self, value) self.current = value end,
        value = function(self) return self.current end,
    }
end

CreateEntity = function()
    guid = guid + 1
    local inst = {GUID = guid, components = {}, tags = {}, events = {}, overrides = {}, children = {}}
    entities[guid] = inst
    inst.entity = {inst = inst}
    for _, method in ipairs({"AddTransform", "AddAnimState", "AddNetwork", "AddFollower", "AddSoundEmitter"}) do
        inst.entity[method] = function() end
    end
    function inst.entity:SetParent(parent)
        self.parent = parent.inst
    end
    function inst.entity:GetParent() return self.parent end
    function inst.entity:SetPristine() inst.pristine = true end
    inst.AnimState = {frame = 0}
    function inst.AnimState:SetBank(value) inst.bank = value end
    function inst.AnimState:SetBuild(value) inst.build = value end
    function inst.AnimState:SetSkin(value) inst.build = value end
    function inst.AnimState:PlayAnimation(value) inst.animation = value end
    function inst.AnimState:PushAnimation(value) inst.animation = value end
    function inst.AnimState:SetFrame(value) self.frame = value end
    function inst.AnimState:GetCurrentAnimationFrame() return self.frame end
    function inst.AnimState:GetCurrentAnimationNumFrames() return 30 end
    function inst.AnimState:Show(name) inst.tags[name] = true end
    function inst.AnimState:Hide(name) inst.tags[name] = nil end
    function inst.AnimState:OverrideSymbol(name, build, symbol)
        inst.overrides[name] = {build, symbol, false}
    end
    function inst.AnimState:OverrideItemSkinSymbol(name, build, symbol, id, fallback)
        inst.overrides[name] = {build, symbol, true, id, fallback}
    end
    function inst.AnimState:SetAddColour(r, g, b, a) inst.colour = {r, g, b, a} end
    inst.Follower = {FollowSymbol = function(_, ...) inst.follow = {...} end}
    inst.SoundEmitter = {KillSound = function() end, PlaySound = function() end}
    function inst:AddTag(tag) self.tags[tag] = true end
    function inst:RemoveTag(tag) self.tags[tag] = nil end
    function inst:HasTag(tag) return self.tags[tag] == true end
    function inst:GetSkinName() return self.skinname end
    function inst:GetSkinBuild()
        self.skin_build_name = self.skin_build_name or self.skinname
        return self.skin_build_name
    end
    function inst:ListenForEvent(event, callback, source)
        local target = source or self
        target.events[event] = target.events[event] or {}
        table.insert(target.events[event], {listener = self, callback = callback})
    end
    function inst:RemoveEventCallback(event, callback, source)
        local target = source or self
        for i = #(target.events[event] or {}), 1, -1 do
            if target.events[event][i].callback == callback then
                table.remove(target.events[event], i)
            end
        end
    end
    function inst:PushEvent(event, data)
        for _, entry in ipairs(self.events[event] or {}) do
            entry.callback(entry.listener, data)
        end
    end
    function inst:DoTaskInTime(_, fn)
        fn(self)
        return {Cancel = function() end}
    end
    function inst:Hide() self.hidden = true end
    function inst:Show() self.hidden = false end
    function inst:Remove()
        assert(not self.removed, "Entity removed twice")
        if self.OnRemoveEntity ~= nil then self:OnRemoveEntity() end
        self.removed = true
    end
    function inst:RemoveComponent(name) self.components[name] = nil end
    function inst:AddComponent(name)
        local component = {}
        self.components[name] = component
        if name == "floater" then
            function component:IsFloating() return self.floating == true end
            function component:SetBankSwapOnFloat(enabled, index, data)
                self.index, self.swap_data = index, data
            end
            function component:SetSize(size) self.size = size end
            function component:SetVerticalOffset(value) self.offset = value end
            function component:SetScale(value) self.scale = value end
            function component:SwitchToDefaultAnim() end
            function component:SwitchToFloatAnim()
                local build = inst:GetSkinBuild()
                if build ~= nil then
                    inst.AnimState:OverrideItemSkinSymbol(
                        "swap_spear", build, self.swap_data.sym_name, inst.GUID, self.swap_data.sym_build
                    )
                end
            end
        elseif name == "highlightchild" then
            function component:SetOwner(owner) self.owner = owner end
        elseif name == "colouraddersync" then
            function component:SetColourChangedFn(callback) self.callback = callback end
        elseif name == "inventoryitem" then
            function component:ChangeImageName(value) self.imagename = value end
        elseif name == "equippable" then
            function component:SetOnEquip(callback) self.onequip = callback end
            function component:SetOnUnequip(callback) self.onunequip = callback end
        elseif name == "weapon" then
            function component:SetDamage(value) self.damage = value end
            function component:SetOnAttack(callback) self.onattack = callback end
        elseif name == "tool" then
            function component:SetAction(action) self.action = action end
        elseif name == "finiteuses" then
            function component:SetMaxUses(value) self.total = value end
            function component:SetUses(value) self.current = value end
            function component:GetUses() return self.current end
            function component:SetConsumption() end
        elseif name == "planardamage" then
            function component:SetBaseDamage(value) self.damage = value end
            function component:AddBonus() self.bonus = true end
            function component:RemoveBonus() self.bonus = nil end
        elseif name == "damagetypebonus" then
            function component:AddBonus() end
        elseif name == "shadowlevel" then
            function component:SetDefaultLevel(value) self.level = value end
        end
        return component
    end
    return inst
end

MakeInventoryPhysics = function() end
MakeHauntableLaunch = function() end
MakeForgeRepairable = function(inst, _, onbroken, onrepaired)
    inst.test_broken, inst.test_repaired = onbroken, onrepaired
end
package.loaded.class = true
package.loaded.prefabs = true
LoadGameScript("prefabskin.lua")
LoadGameScript("strict.lua")

local item_prefab, vanilla_fx = LoadGameScript("prefabs/voidcloth_scythe.lua")
local skin_util = require("utils/deathsickleskin")
SpawnPrefab = function(name)
    local inst
    if name == vanilla_fx.name then
        inst = vanilla_fx.fn()
    elseif name == "voidcloth_scythe_classified" then
        inst = CreateEntity()
        inst.SetTarget = function() end
    else
        error("Unexpected spawn: " .. name)
    end
    inst.prefab = name
    return inst
end

local function Owner()
    local owner = CreateEntity()
    owner.components.inventory = {GetEquippedItem = function() end}
    owner.components.colouradder = {
        attached = {},
        AttachChild = function(self, child) self.attached[child] = true end,
        DetachChild = function(self, child) self.attached[child] = nil end,
    }
    return owner
end

local function Apply(inst)
    inst.skinname = "voidcloth_scythe_death"
    skin_util.Init(inst)
end

for _, isdedicated in ipairs({false, true}) do
    dedicated = isdedicated
    TheWorld.ismastersim = true
    local inst = item_prefab.fn()
    local owner = Owner()
    local damage = inst.components.weapon.damage
    local planar = inst.components.planardamage.damage
    local attack = inst.components.weapon.onattack
    local harvest = inst.DoScythe
    local starting_fx = inst.fx
    local original_toggle = inst.fx.ToggleEquipped
    local original_show = inst.fx.Show
    Apply(inst)
    Equal(inst.fx, starting_fx)
    assert(inst.fx.hidden and not inst.fx.removed)
    Equal(inst.build, "voidcloth_scythe_death")
    Equal(inst.components.inventoryitem.imagename, inst.build)
    Equal(inst.fx.prefab, "voidcloth_scythe_fx")
    Equal(inst.components.weapon.damage, damage)
    Equal(inst.components.weapon.onattack, attack)
    Equal(inst.components.planardamage.damage, planar)
    Equal(inst.DoScythe, harvest)
    Equal(inst.components.tool.action, ACTIONS.SCYTHE)
    Equal(inst.fx.follow[2], "swap_spear")
    local custom_fx = inst.fx
    Apply(inst)
    Equal(inst.fx, custom_fx)
    for _ = 1, 3 do
        inst.components.equippable.onequip(inst, owner)
        Equal(inst.fx.entity:GetParent(), owner)
        Equal(inst.fx.follow[2], "swap_object")
        Equal(owner.overrides.swap_object[1], "voidcloth_scythe_death")
        Equal(inst.fx.equiptoggle:value(), false)
        Equal(inst.fx.fx, nil)
        assert(inst.fx.hidden)
        inst.components.equippable.onunequip(inst, owner)
        Equal(inst.fx.entity:GetParent(), inst)
        Equal(inst.fx.equiptoggle:value(), false)
    end

    inst.components.finiteuses:SetUses(0)
    inst:test_broken()
    assert(inst:HasTag("broken") and inst.fx.hidden)
    Equal(inst.components.weapon, nil)
    Equal(inst.components.tool, nil)
    Equal(inst.animation, "broken")
    Equal(inst.components.floater.swap_data.sym_name, "scythe_base_broken_float")
    inst.components.finiteuses:SetUses(200)
    inst:test_repaired()
    assert(not inst:HasTag("broken") and inst.fx.hidden)
    Equal(inst.components.weapon.damage, damage)
    Equal(inst.components.weapon.onattack, attack)
    Equal(inst.components.tool.action, ACTIONS.SCYTHE)
    Equal(inst.fx.prefab, "voidcloth_scythe_fx")
    Equal(inst.animation, "idle")

    inst.components.equippable.onequip(inst, owner)
    local children = shallowcopy(inst.fx.fx or {})
    local previous = inst.fx
    skin_util.Clear(inst)
    Equal(inst.fx, previous)
    assert(not previous.removed and not previous.hidden)
    Equal(inst.build, "scythe_voidcloth")
    Equal(inst.fx.prefab, "voidcloth_scythe_fx")
    Equal(owner.overrides.swap_object[1], "scythe_voidcloth")
    Equal(inst.components.inventoryitem.imagename, nil)
    Equal(inst.skin_build_name, nil)
    Equal(inst._death_sickle_fx, nil)
    Equal(inst.fx.equiptoggle:value(), true)
    Equal(inst.fx.ToggleEquipped, original_toggle)
    Equal(inst.fx.Show, original_show)
    if not isdedicated then Equal(#inst.fx.fx, 4) end
    inst.skinname = nil
    children = shallowcopy(inst.fx.fx or {})
    Apply(inst)
    for _, child in ipairs(children) do assert(child.removed) end
    Equal(inst.fx.prefab, "voidcloth_scythe_fx")
    Equal(inst.fx.equiptoggle:value(), false)
    assert(inst.fx.hidden)
    inst.components.equippable.onunequip(inst, owner)

    for _, broken in ipairs({false, true}) do
        if broken then
            inst.components.finiteuses:SetUses(0)
            inst:test_broken()
        end
        inst.components.floater.floating = true
        Apply(inst)
        Equal(inst.overrides.swap_spear[1], "voidcloth_scythe_death")
        assert(inst.fx.hidden)
        skin_util.Clear(inst)
        Equal(inst.fx.hidden == true, broken)
        Equal(inst.overrides.swap_spear[1], "scythe_voidcloth")
        Equal(inst.overrides.swap_spear[2], broken and "scythe_base_broken_float" or "swap_scythe")
        Equal(inst.skin_build_name, nil)
    end
    print("death_sickle: native construction, equip, break/repair, reskin and float passed; dedicated=" .. tostring(isdedicated))
end

dedicated = false
TheWorld.ismastersim = false
local client = vanilla_fx.fn()
Equal(client.ToggleEquipped, nil)
local owner = Owner()
client.entity:SetParent(owner.entity)
client.equiptoggle:set(true)
client:PushEvent("equiptoggledirty")
Equal(#client.fx, 4)
for _, child in ipairs(client.fx) do Equal(child.build, "scythe_voidcloth") end
local previous = shallowcopy(client.fx)
client.equiptoggle:set(false)
client:PushEvent("equiptoggledirty")
Equal(#client.fx, 0)
for _, child in ipairs(previous) do assert(child.removed) end
local untouched = CreateEntity()
skin_util.Init(untouched)
skin_util.Clear(untouched)
Equal(untouched.build, nil)
print("death_sickle: native FX enable/disable replication and client authority guards passed")

GLOBAL = _G
local registered
GlassicAPI = {SkinHandler = {
    AddModSkin = function() end,
    SetCharacterExclusiveSkin = function() end,
    AddModSkins = function(skins) registered = skins end,
}}
dofile("main/prefabskin.lua")
Equal(registered.voidcloth_scythe[1], "voidcloth_scythe_death")
Equal(voidcloth_scythe_clear_fn, skin_util.Clear)
local common = dofile("strings/common.lua")
Equal(common.SKIN_NAMES.voidcloth_scythe_death, "Death Sickle")
print("death_sickle: Glassic skin registration and strings passed")

local metadata
for _, prefab in ipairs({dofile("scripts/prefabs/manutsawee_none.lua")}) do
    if prefab.name == "voidcloth_scythe_death" then
        metadata = prefab
        break
    end
end
assert(metadata ~= nil)
Equal(metadata.base_prefab, "voidcloth_scythe")
Equal(metadata.clear_fn, skin_util.Clear)
Equal(metadata.init_fn, skin_util.Init)
Equal(metadata.is_skin, true)
print("death_sickle: native skin metadata and explicit clear function passed")
