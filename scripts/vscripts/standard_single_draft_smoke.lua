-- Disposable Tools-mode game started with Single Draft on and Epic-Only orbs off, after selecting a hero:
-- script_reload_code standard_single_draft_smoke
assert(IsInToolsMode() and HostOptions.locked)
assert(IsSingleDraftMap() and not IsEpicOnlyMap())
local hero = PlayerResource:GetSelectedHeroEntity(0)
assert(IsValidEntity(hero) and hero.upgrades, "Wait for hero initialization")
-- Exercise real item creation and inventory filtering. Shop files use repeated
-- item keys, so LoadKeyValues cannot be used to enumerate their full contents.
for _, source in ipairs({ {"common", 1, 2000}, {"rare", 2, 4000}, {"epic", 4, 8000} }) do
	local item = CreateItem("item_" .. source[1] .. "_orb_ffa", hero, hero)
	assert(IsValidEntity(item))
	assert(tonumber(item:GetAbilityKeyValues().ItemCost) == source[3])
	hero:AddItem(item)
	local queue = Upgrades.queued_selection[0]
	assert(queue and queue[#queue].rarity == source[2], "Incorrect shop reward rarity")
	print("STANDARD_SD_ITEM PASS rarity=" .. source[2] .. " price=" .. source[3])
end

-- Spend real rerolls against real selections, preserving each reward rarity.
local remaining = HostOptions:GetOption("infinite_rerolls") and 999 or 30
assert(UpgradeRerolls.current_free_rerolls[0] == remaining, "Expected a fresh reroll allowance")
for _, rarity in ipairs({1, 2, 4}) do
	Upgrades:ShowSelection(hero, rarity, 0)
	local selection_id = Upgrades.pending_selection[0].selection_id
	Upgrades:Reroll({ PlayerID = 0, selection_id = selection_id })
	remaining = remaining - rarity
	assert(UpgradeRerolls.current_free_rerolls[0] == remaining)
	assert(Upgrades.pending_selection[0].upgrade_rarity == rarity)
	assert(Upgrades.pending_selection[0].selection_id ~= selection_id)
	assert(CustomNetTables:GetTableValue("rerolls", "0").count == remaining)
	print("STANDARD_SD_REROLL PASS rarity=" .. rarity .. " remaining=" .. remaining)
end
print("STANDARD_SD_SMOKE PASS map=" .. GetMapName() .. " items=normal rerolls=1/2/4")
