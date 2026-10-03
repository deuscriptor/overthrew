WebInventory = WebInventory or {}
-- The collection is local and free: every player owns every item in ITEM_DEFINITIONS (all of them cosmetics).
require("libraries/webapi/inventory/equipment")


function WebInventory:Init()
	EventStream:Listen("WebInventory:get_items", WebInventory.GetItems, WebInventory)

	WebInventory:ValidateDefinitions()
end


function WebInventory:ValidateDefinitions()
	for item_name, item_definition in pairs(ITEM_DEFINITIONS or {}) do
		for _, field in ipairs({"slot", "type", "rarity"}) do
			if not item_definition[field] then
				error("[WebInventory] item is missing required `" .. field .. "` param: " .. item_name)
			end
		end
	end
end


function WebInventory:GetItemSlot(item_name)
	local definition = WebInventory:GetItemDefinition(item_name)
	if not definition then return end
	return definition.slot
end


function WebInventory:HasItem(player_id, item_name)
	return ITEM_DEFINITIONS[item_name] ~= nil
end


function WebInventory:GetItemDefinition(item_name)
	local definition = ITEM_DEFINITIONS[item_name]
	if not definition then
		print("[WebInventory] no definition for item", item_name)
		return
	end
	return definition
end


function WebInventory:GetItems(event)
	local player_id = event.PlayerID
	if not player_id or not PlayerResource:IsValidPlayerID(player_id) then return end

	WebInventory:UpdateClient(player_id)
end


function WebInventory:UpdateClient(player_id)
	local player = PlayerResource:GetPlayer(player_id)
	if not IsValidEntity(player) then return end

	local items = {}
	for name in pairs(ITEM_DEFINITIONS) do items[name] = {count = 1} end
	CustomGameEventManager:Send_ServerToPlayer(player, "WebInventory:update", {
		items = items
	})
end


WebInventory:Init()
