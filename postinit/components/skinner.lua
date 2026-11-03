local does_character_have_skin = GlassicAPI.SkinHandler.DoesCharacterHaveSkin
GLOBAL.setfenv(1, GLOBAL)

local function filter_character_clothing(character, skins)
	for slot, skin in pairs(skins) do
		if CLOTHING[skin] and not does_character_have_skin(skin, character) then
			skins[slot] = nil
		end
	end
end

local validate_items_local = ValidateItemsLocal
ValidateItemsLocal = function(character, skins, ...)
	filter_character_clothing(character, skins)
	return validate_items_local(character, skins, ...)
end

local validate_preview_items = ValidatePreviewItems
ValidatePreviewItems = function(character, skins, ...)
	filter_character_clothing(character, skins)
	return validate_preview_items(character, skins, ...)
end

local Skinner = require("components/skinner")
local set_clothing = Skinner.SetClothing
function Skinner:SetClothing(name, ...)
	if not does_character_have_skin(name, self.inst.prefab) then
		return
	end
	return set_clothing(self, name, ...)
end

local set_skin_mode = Skinner.SetSkinMode
function Skinner:SetSkinMode(...)
	-- Load and copy paths assign clothing directly instead of calling SetClothing.
	for slot, skin in pairs(self.clothing) do
		if not does_character_have_skin(skin, self.inst.prefab) then
			self.clothing[slot] = ""
			self.inst:PushEvent("unequipskinneditem", skin)
		end
	end
	return set_skin_mode(self, ...)
end

local ClothingExplorerPanel = require("widgets/redux/clothingexplorerpanel")
local build_item_explorer = ClothingExplorerPanel._BuildItemExplorer
function ClothingExplorerPanel:_BuildItemExplorer(...)
	local picker = build_item_explorer(self, ...)
	local refresh_items = picker.RefreshItems
	local item_filter_fn = picker.item_filter_fn
	local function character_filter(name)
		return does_character_have_skin(name, self.npccharacter or self.owner.currentcharacter)
			and (item_filter_fn == nil or item_filter_fn(name))
	end

	-- Keep the character restriction when the filter bar replaces its predicate.
	function picker:RefreshItems(new_item_filter_fn, ...)
		if new_item_filter_fn ~= nil and new_item_filter_fn ~= character_filter then
			item_filter_fn = new_item_filter_fn
		end
		return refresh_items(self, character_filter, ...)
	end
	picker:RefreshItems()
	return picker
end
