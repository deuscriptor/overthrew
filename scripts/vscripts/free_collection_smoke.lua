assert(IsInToolsMode())
local id = 0 -- the only human player in a tools session
assert(WebPlayer:GetSubscriptionTier(id) == 2)
local count = 0
for name, definition in pairs(ITEM_DEFINITIONS) do
	assert(definition.type == ITEM_TYPES.EQUIPMENT and WebInventory:HasItem(id, name), name)
	count = count + 1
end
assert(not WebInventory:HasItem(id, "bp_reroll"), "Misc boosts are gone")
WebInventory:UpdateClient(id)
WebPlayer:UpdateClient(id)
assert(rawget(_G, "WebApi") == nil, "the backend client is removed")
print("FREE_COLLECTION_ACCESS_PASS " .. count .. " items; premium tier 2; no backend client")
if GameRules:State_Get() == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
	GameRules:SetPreGameTime(600)
	PlayerDC.CheckEndGame = function() end
	local options = {PlayerID=id}
	for name, value in pairs(HostOptions.options) do options[name] = value end
	HostOptions:ClaimHost(0) -- no automatic host: claim it as a player would
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
