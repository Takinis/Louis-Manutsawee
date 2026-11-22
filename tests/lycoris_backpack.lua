-- Run from the mod directory: lua tests/lycoris_backpack.lua
local NAME = "lycoris_backpack"
local BUILD = "swap_" .. NAME
local ATLAS = "images/hud/" .. NAME .. ".xml"

GLOBAL = _G
GLOBAL.setfenv = function() end
Vector3 = function(x, y, z) return {x, y, z} end
EQUIPSLOTS = {BODY = "body"}
TheWorld = {ismastersim = false}
Asset = function(kind, file, param) return {kind, file, param} end
Prefab = function(name, fn, assets, dependencies)
    return {name = name, fn = fn, assets = assets, dependencies = dependencies}
end

local function SetField(field)
    return function(self, value) self[field] = value end
end

local atlases = {}
resolvefilepath = function(file) return file end
hash = function(text)
    local value = 0
    for i = 1, #text do
        value = (value * 65599 + text:byte(i)) % 4294967296
    end
    return value
end
RegisterInventoryItemAtlas = function(atlas, image) atlases[image] = atlas end
GetInventoryItemAtlas = function(image) return atlases[image] end
GlassicAPI = {InitMinimapAtlas = function() end}
package.path = "scripts/?.lua;" .. package.path
dofile("main/assets.lua")

-- UI and minisigns resolve the registered icon without constructing the item.
assert(GetInventoryItemAtlas(NAME .. ".tex") == ATLAS)
assert(GetInventoryItemAtlas(hash(NAME .. ".tex")) == ATLAS)
assert(GetInventoryItemAtlas("harakiri.tex") == "images/hud/m_inventoryimages.xml")
local icon_assets = {}
for _, asset in ipairs(Assets) do
    if asset[2] == ATLAS or asset[2] == "images/hud/" .. NAME .. ".tex" then
        icon_assets[asset[1]] = asset
    end
end
assert(icon_assets.IMAGE and icon_assets.ATLAS and icon_assets.ATLAS_BUILD)
assert(icon_assets.ATLAS_BUILD[3] == 64)
local texture = assert(io.open("images/hud/" .. NAME .. ".tex", "rb"))
local header = texture:read(12)
texture:close()
assert(header:sub(1, 4) == "KTEX")
local w0, w1, h0, h1 = header:byte(9, 12)
assert(w0 + w1 * 256 == 64 and h0 + h1 * 256 == 64, "HUD texture must be 64 x 64")

local nativepack = {widget = {slotpos = {1, 2, 3, 4, 5, 6, 7, 8}}, type = "pack", issidewidget = true}
local params = {backpack = nativepack}
package.loaded.containers = {params = params}
dofile("main/containers.lua")
assert(params[NAME] == nativepack, "Client replica resolves the widget by prefab name")

CreateEntity = function()
    local inst = {
        prefab = NAME,
        entity = {},
        AnimState = {SetBank = SetField("bank"), SetBuild = SetField("build"), PlayAnimation = SetField("anim")},
        MiniMapEntity = {SetIcon = SetField("icon")},
        Transform = {GetWorldPosition = function() return 1, 2, 3 end},
        components = {},
        tags = {},
    }
    for _, name in ipairs({"AddTransform", "AddAnimState", "AddSoundEmitter", "AddMiniMapEntity", "AddNetwork"}) do
        inst.entity[name] = function() end
    end
    inst.entity.SetPristine = function() inst.pristine = true end
    inst.Remove = function() inst.removed = true end
    function inst:AddTag(tag) self.tags[tag] = true end
    function inst:AddComponent(name)
        assert(TheWorld.ismastersim and self.pristine)
        local factories = {
            equippable = function()
                return {
                    SetOnEquip = SetField("onequip"),
                    SetOnUnequip = SetField("onunequip"),
                    SetOnEquipToModel = SetField("onequiptomodel"),
                }
            end,
            container = function()
                return {
                    canbeopened = true,
                    Open = SetField("opener"),
                    Close = function(self, owner)
                        assert(owner == nil or self.opener == owner)
                        self.opener = nil
                    end,
                    DropEverything = function(self) self.dropped = true end,
                    WidgetSetup = function(self, prefab) self.numslots = #params[prefab].widget.slotpos end,
                }
            end,
        }
        self.components[name] = factories[name] and factories[name]() or {}
    end
    return inst
end

MakeInventoryPhysics = function(inst) inst.physics = true end
MakeInventoryFloatable = function(inst, _, _, _, _, _, swap_data) inst.float = swap_data end
MakeSmallBurnable = function(inst)
    inst.components.burnable = {
        SetOnBurntFn = SetField("onburnt"),
        SetOnIgniteFn = SetField("onignite"),
        SetOnExtinguishFn = SetField("onextinguish"),
    }
end
MakeSmallPropagator = function(inst) inst.propagates = true end
MakeHauntableLaunchAndDropFirstItem = function(inst) inst.hauntable = true end

local ash_position
SpawnPrefab = function(name)
    assert(name == "ash")
    return {Transform = {SetPosition = function(_, ...) ash_position = {...} end}}
end

local prefab = dofile("scripts/prefabs/" .. NAME .. ".lua")
assert(prefab.name == NAME and prefab.dependencies[1] == "ash")
local client = prefab.fn()
assert(client.pristine and client.tags.backpack and client.physics)
assert(next(client.components) == nil)
assert(client.AnimState.build == BUILD and client.AnimState.anim == "anim")
assert(client.AnimState.bank == "backpack1" and client.float.bank == client.AnimState.bank)

TheWorld.ismastersim = true
local item = prefab.fn()
local container, equip, burnable = item.components.container, item.components.equippable, item.components.burnable
assert(container.numslots == 8 and equip.equipslot == EQUIPSLOTS.BODY)
assert(item.components.inventoryitem.atlasname == nil and item.components.inventoryitem.imagename == nil)
assert(not item.components.inventoryitem.cangoincontainer)
assert(GetInventoryItemAtlas(item.prefab .. ".tex") == ATLAS)
assert(item.components.inspectable and item.hauntable and item.propagates)

local owner = {AnimState = {
    OverrideSymbol = function(self, layer, build, symbol)
        assert(layer == "swap_body" and build == BUILD and layer == symbol)
        self[layer] = build
    end,
    ClearOverrideSymbol = function(self, layer)
        assert(layer == "swap_body")
        self[layer] = nil
    end,
}}
equip.onequip(item, owner)
assert(owner.AnimState.swap_body == BUILD and container.opener == owner)
equip.onunequip(item, owner)
assert(owner.AnimState.swap_body == nil and container.opener == nil)
equip.onequip(item, owner)
equip.onequiptomodel(item, owner)
assert(container.opener == nil)

burnable.onignite(item)
assert(not container.canbeopened)
burnable.onextinguish(item)
assert(container.canbeopened)
equip.onequip(item, owner)
burnable.onburnt(item)
assert(container.dropped and container.opener == nil and item.removed)
assert(table.concat(ash_position, ",") == "1,2,3")

TECH = {NONE = 0, SCIENCE_ONE = 1, SCIENCE_TWO = 2, ANCIENT_FOUR = 4, LOST = 99}
Ingredient = function(name, amount) return {name, amount} end
GlassicAPI = {RecipeSortBefore = function() end, RecipeSortAfter = function() end}
local recipe
AddRecipe2 = function(name, ...)
    if name == NAME then recipe = {...} end
end
dofile("main/recipes.lua")
assert(recipe and #recipe[1] == 3 and recipe[2] == TECH.SCIENCE_ONE)
assert(recipe[3] == nil, "Recipe uses the globally registered product icon")
assert(GetInventoryItemAtlas(NAME .. ".tex") == ATLAS)
assert(recipe[4][1] == "CONTAINERS" and recipe[4][2] == "CLOTHING")
print("lycoris_backpack: global string/hash atlas lookup and minisign asset registration passed")
print("lycoris_backpack: 64 x 64 HUD texture passed")
print("lycoris_backpack: client widget, server lifecycle, equipment, and recipe passed")
