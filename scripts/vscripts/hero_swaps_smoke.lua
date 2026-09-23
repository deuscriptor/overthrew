-- Disposable local Tools session only; no online lobby is involved.
assert(IsInToolsMode() and UsesHostRules())
if GameRules:State_Get() == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
	for id, callback in pairs(EventDriver.serverside_events["Events:npc_spawned"] or {}) do
		if callback[1] == OT3Demo.OnNPCSpawned then EventDriver:CancelListener("Events:npc_spawned", id) end
	end
	PlayerDC.CheckEndGame = function() end
	GameRules:SetPreGameTime(600)
	assert(HostOptions:ApplyRules({PlayerID=0, infinite_rerolls=0, longer_wards=1, divine_rapier=0, dagon=0, epic_orbs=0, single_draft=0, turbo=0, kill_goal=30}))
	print("HERO_SWAPS_SMOKE_SETUP")
	return
end
local a = PlayerResource:GetSelectedHeroEntity(0)
assert(IsValidEntity(a) and a.initialized, "Select a hero and wait for preparation")
if not _G.hero_swaps_smoke_bot then
	local team = PlayerResource:GetTeam(0) == DOTA_TEAM_BADGUYS and DOTA_TEAM_GOODGUYS or DOTA_TEAM_BADGUYS
	_G.hero_swaps_smoke_bot = GameRules:AddBotPlayerWithEntityScript("npc_dota_hero_lina", "Swap Test", team, "", false)
	print("HERO_SWAPS_SMOKE_BOT_CREATED")
	return
end
local b = _G.hero_swaps_smoke_bot
local id = b:GetPlayerOwnerID()
assert(a ~= b and b.initialized)
-- The synthetic local bot has no network connection. Simulate only that flag;
-- every hero, inventory, resource and upgrade operation below uses the engine.
local get_connection = PlayerResource.GetConnectionState
PlayerResource.GetConnectionState = function(self, player_id)
	if player_id == id then return DOTA_CONNECTION_STATE_CONNECTED end
	return get_connection(self, player_id)
end
local ok, err = pcall(function()
assert(HeroSwaps:IsPlayerReady(0) and HeroSwaps:IsPlayerReady(id), "Both players must be ready")
local team_a, team_b = a:GetTeam(), b:GetTeam()
assert(team_a ~= team_b)
local gold_a, gold_b = a:GetGold(), b:GetGold()
local facet_a, facet_b = a:GetHeroFacetID(), b:GetHeroFacetID()
local item_a, item_b = a:AddItemByName("item_branches"), b:AddItemByName("item_circlet")
local slot_a, slot_b = item_a:GetItemSlot(), item_b:GetItemSlot()
UpgradeRerolls.current_free_rerolls[0], UpgradeRerolls.current_free_rerolls[id] = 23, 17
Upgrades.queued_selection[0], Upgrades.pending_selection[0] = {}, nil
Upgrades.queued_selection[id], Upgrades.pending_selection[id] = {}, nil
-- Apply through the real selection pipeline, including the spent-orb ledger.
Upgrades:QueueSelection(a, UPGRADE_RARITY_RARE)
local pending = Upgrades.pending_selection[0]
local choice = pending.choices[1]
Upgrades:UpgradeSelected({PlayerID=0, ability_name=choice.ability_name, upgrade_name=choice.upgrade_name, selection_id=pending.selection_id})
assert(#HeroSwaps.spent_orbs[0] == 1)
for _, reward in ipairs({{4, "generic_auto_rune"}, {2, "generic_rare_stat_boost"}}) do
	Upgrades:QueueSelection(a, reward[1])
	local offer = Upgrades.pending_selection[0]
	offer.choices = {{type=UPGRADE_TYPE.GENERIC, ability_name="generic", upgrade_name=reward[2]}}
	Upgrades:UpgradeSelected({PlayerID=0, ability_name="generic", upgrade_name=reward[2], selection_id=offer.selection_id})
end
assert(a:HasModifier("modifier_rune_arcane") and a:HasModifier("modifier_generic_rare_stat_boost_upgrade_handler"))
assert(#HeroSwaps.spent_orbs[0] == 3)
-- Receiving the other hero must work even with native per-player availability
-- restricted to the original hero, as it is during Single Draft.
GameRules:GetGameModeEntity():SetPlayerHeroAvailabilityFiltered(true)
for _, player_id in ipairs({0, id}) do
	GameRules:ClearPlayerHeroAvailability(player_id)
	GameRules:AddHeroToPlayerAvailability(player_id, PlayerResource:GetSelectedHeroID(player_id))
end
assert(HeroSwaps:Handle("request", 0, {target=id}))
local request = HeroSwaps.next_id
assert(not HeroSwaps:Handle("accept", 0, {request_id=request}), "Sender cannot accept own request")
assert(HeroSwaps:Handle("accept", id, {request_id=request}))
assert(PlayerResource:GetSelectedHeroEntity(0) == b and PlayerResource:GetSelectedHeroEntity(id) == a)
assert(PlayerResource:GetSelectedHeroName(0) == b:GetUnitName() and PlayerResource:GetSelectedHeroName(id) == a:GetUnitName())
assert(b:GetPlayerOwnerID() == 0 and a:GetPlayerOwnerID() == id)
assert(b:GetTeam() == team_a and a:GetTeam() == team_b)
assert(PlayerResource:GetTeam(0) == team_a and PlayerResource:GetTeam(id) == team_b)
assert(b:GetHeroFacetID() == facet_b and a:GetHeroFacetID() == facet_a)
assert(b:GetGold() == gold_a and a:GetGold() == gold_b, "Gold moved between players")
assert(b:GetItemInSlot(slot_a) == item_a and a:GetItemInSlot(slot_b) == item_b, "Inventory moved between players")
assert(UpgradeRerolls.current_free_rerolls[0] == 23 and UpgradeRerolls.current_free_rerolls[id] == 17)
assert(#Upgrades.queued_selection[0] == 3)
assert(Upgrades.queued_selection[0][1].rarity == 2 and Upgrades.queued_selection[0][2].rarity == 4 and Upgrades.queued_selection[0][3].rarity == 2)
assert(#Upgrades.queued_selection[id] == 0 and #HeroSwaps.spent_orbs[0] == 0)
assert(not next(a.upgrades), "Spent upgrade remained on original hero")
assert(not a:HasModifier("modifier_rune_arcane") and not a:HasModifier("modifier_generic_rare_stat_boost_upgrade_handler"), "Residual upgrade buff survived reset")
assert(choice.count == 0, "Hero upgrade pool still contains the old displayed level")
assert(GameLoop.hero_by_player_id[0] == b and GameLoop.heroes_by_team[team_a][1] == b)
assert(GameLoop.hero_by_player_id[id] == a and GameLoop.heroes_by_team[team_b][1] == a)
assert(not next(HeroSwaps.requests) and not next(HeroSwaps.accepted))
print("HERO_SWAPS_SMOKE_PASS cross-team ownership, facets, teams, items, gold, rerolls, mixed-rarity refunds, buff reset, filtered hero availability and caches")
end)
PlayerResource.GetConnectionState = get_connection
assert(ok, err)
