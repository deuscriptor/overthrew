-- Disposable local engine check; run during setup, then after choosing a hero.
assert(IsInToolsMode())
if GameRules:State_Get() == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
	assert(HostOptions:GetOption("longer_wards"))
	assert(not HostOptions:GetOption("infinite_rerolls"))
	assert(HostItems:IsDisabled("item_rapier"))
	assert(HostItems:IsDisabled("item_dagon"))
	for id, callback in pairs(EventDriver.serverside_events["Events:npc_spawned"] or {}) do
		if callback[1] == OT3Demo.OnNPCSpawned then EventDriver:CancelListener("Events:npc_spawned", id) end
	end
	GameRules:SetPreGameTime(600)
	PlayerDC.CheckEndGame = function() end
	HostOptions:ClaimHost(0) -- no automatic host: claim it as a player would
	assert(HostOptions:ApplyRules({PlayerID=0, epic_orbs=0, single_draft=0, turbo=0, backpack_items=0, kill_goal=60,
		infinite_rerolls=1, all_vision=0, invincible_wards=0, longer_wards=1, divine_rapier=1, dagon=1}))
	assert(GameLoop.current_layout.game_base_duration == DEFAULT_MATCH_LENGTH * 2)
	assert(CustomNetTables:GetTableValue("game_options", "score_goal").limit == DEFAULT_MATCH_LENGTH * 2)
	print("HOST_SETTINGS_SETUP_PASS")
	return
end
local hero = PlayerResource:GetSelectedHeroEntity(0)
assert(IsValidEntity(hero), "Choose a hero first")
assert(UpgradeRerolls.current_free_rerolls[0] == 999)
for _, team in ipairs(TEAMS_LAYOUTS[GetMapName()].teamlist) do
	assert(GameRules:GetItemStockCount(team, "item_ward_observer", -1) == 4, "Initial Observer stock must be four")
end
for _, name in ipairs({"item_rapier", "item_recipe_rapier", "item_dagon", "item_dagon_2", "item_dagon_3", "item_dagon_4", "item_dagon_5", "item_recipe_dagon", "item_branches"}) do
	assert(not HostItems:IsDisabled(name), name .. " not enabled")
end
hero:ModifyGold(50000, true, DOTA_ModifyGold_CheatCommand)
for _, name in ipairs({"item_rapier", "item_dagon"}) do
	local item = CreateItem(name, hero, hero)
	assert(IsValidEntity(item) and item:IsPurchasable(), name .. " not restored")
	UTIL_Remove(item)
end
local ward = hero:AddItemByName("item_ward_observer")
hero:SetCursorPosition(hero:GetAbsOrigin() + Vector(250, 0, 0))
ward:OnSpellStart()
hero:TakeItem(ward)
UTIL_Remove(ward)
for slot = 0, 16 do
	local item = hero:GetItemInSlot(slot)
	if item and item:GetAbilityName():find("item_ward_") then hero:TakeItem(item); UTIL_Remove(item) end
end
local sentry = hero:AddItemByName("item_ward_sentry")
hero:SetCursorPosition(hero:GetAbsOrigin() + Vector(350, 0, 0))
sentry:OnSpellStart()
Timers:CreateTimer(0.5, function()
	for _, name in ipairs({"npc_dota_observer_wards", "npc_dota_sentry_wards"}) do
		local found = false
		local class = name == "npc_dota_sentry_wards" and "npc_dota_ward_base_truesight" or "npc_dota_ward_base"
		for _, unit in ipairs(Entities:FindAllByClassname(class)) do
			if unit:GetUnitName() == name and unit.host_lifetime_extended then
			found = true
			for _, modifier in ipairs(unit:FindAllModifiers()) do
				print("HOST_SETTINGS_WARD", name, modifier:GetName(), modifier:GetDuration(), modifier:GetRemainingTime())
				if modifier:GetName() == "modifier_item_buff_ward" or modifier:GetName() == "modifier_item_ward_true_sight" then
					local expected = 3600
					assert(math.abs(modifier:GetDuration() - expected) < 0.2, "Ward lifetime/detection mismatch")
				end
			end
			assert(unit.host_lifetime_extended, name .. " lifetime not extended")
			end
		end
		assert(found, name .. " not extended")
	end
	print("HOST_SETTINGS_ENGINE_PASS rerolls, restored native items, placed wards")
end)
