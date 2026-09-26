assert(IsInToolsMode() and LOCAL_FREE_COLLECTION)
local id = HostOptions:ResolveHost():GetPlayerID()
assert(WebPlayer:GetSubscriptionTier(id) == 2)
local count = 0
for name in pairs(ITEM_DEFINITIONS) do
	assert(WebInventory:HasItem(id, name) and WebInventory:GetItemCount(id, name) > 0)
	assert(WebInventory:GetItemCost(name) == 0)
	count = count + 1
end
WebInventory:UpdateClient(id)
WebPlayer:UpdateClient(id)
assert(Equipment._backend_request_timer == nil)
print("FREE_COLLECTION_ACCESS_PASS " .. count .. " items; premium tier 2; no equipment backend timer")
if GameRules:State_Get() == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
	GameRules:SetPreGameTime(600)
	PlayerDC.CheckEndGame = function() end
	local options = {PlayerID=id}
	for name, value in pairs(HostOptions.options) do options[name] = value end
	assert(HostOptions:ApplyRules(options))
	return
end
assert(IsValidEntity(PlayerResource:GetSelectedHeroEntity(id)), "Choose a hero first")
for name, definition in pairs(ITEM_DEFINITIONS) do
	if definition.slot == INVENTORY_SLOTS.HIGH_FIVE then
		assert(Equipment:Equip(id, name))
		Timers:CreateTimer(1, function()
			assert(Equipment:GetItemInSlot(id, INVENTORY_SLOTS.HIGH_FIVE).name == name)
			print("FREE_COLLECTION_EQUIP_PASS " .. name)
		end)
		break
	end
end
