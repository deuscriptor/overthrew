-- Local tools-mode visual harness for the hero swap menu: player 0 plus three bot players showing
-- every row state (incoming request, sent request, plain). Rerun until "SWAPLOOK READY"; each
-- later rerun refreshes the requests (they expire after 30 seconds).
if not PlayerResource or not HostOptions then print("SWAPLOOK waiting for the map") return end
assert(IsInToolsMode() and UsesHostRules(), "requires local FFA tools mode")
local state = GameRules:State_Get()
if state < DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP or not PlayerResource:GetPlayer(0) then print("SWAPLOOK waiting for the player") return end
if state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
	for id, callback in pairs(EventDriver.serverside_events["Events:npc_spawned"] or {}) do
		if callback[1] == OT3Demo.OnNPCSpawned then EventDriver:CancelListener("Events:npc_spawned", id) end
	end
	PlayerDC.CheckEndGame = function() end
	GameRules:SetPreGameTime(600) -- swaps are only open before the horn
	assert(HostOptions:ApplyRules({PlayerID=0, single_draft=0, epic_orbs=0, turbo=0, backpack_items=0,
		kill_goal=50, infinite_rerolls=0, all_vision=1, invincible_wards=1, longer_wards=1, divine_rapier=1, dagon=1}))
	print("SWAPLOOK setup applied")
	return
end
local hero = PlayerResource:GetSelectedHeroEntity(0)
if not IsValidEntity(hero) then
	PlayerResource:GetPlayer(0):SetSelectedHero("npc_dota_hero_sven")
	print("SWAPLOOK selecting hero, state " .. state)
	return
end
if not hero.initialized or state < DOTA_GAMERULES_STATE_PRE_GAME then print("SWAPLOOK waiting for hero, state " .. state) return end
if not _G.swaplook_bots then
	_G.swaplook_bots = {}
	local names = {"npc_dota_hero_lina", "npc_dota_hero_pudge", "npc_dota_hero_crystal_maiden"}
	local index = 1
	for _, team in ipairs(GameLoop.current_layout.teamlist) do
		if team ~= hero:GetTeam() and names[index] then
			table.insert(_G.swaplook_bots, GameRules:AddBotPlayerWithEntityScript(names[index], "Swap Bot " .. index, team, "", false))
			index = index + 1
		end
	end
	print("SWAPLOOK bots created")
	return
end
local ids = {}
for _, bot in ipairs(_G.swaplook_bots) do
	if not IsValidEntity(bot) or not bot.initialized then print("SWAPLOOK waiting for bots") return end
	ids[bot:GetPlayerOwnerID()] = true
end
-- Synthetic bots have no network connection; only that flag is simulated so they are listed.
if not _G.swaplook_connection then
	_G.swaplook_connection = PlayerResource.GetConnectionState
	PlayerResource.GetConnectionState = function(self, player_id)
		if ids[player_id] then return DOTA_CONNECTION_STATE_CONNECTED end
		return _G.swaplook_connection(self, player_id)
	end
end
local first, second = _G.swaplook_bots[1]:GetPlayerOwnerID(), _G.swaplook_bots[2]:GetPlayerOwnerID()
HeroSwaps.cooldowns[0], HeroSwaps.cooldowns[first] = nil, nil
local incoming = HeroSwaps:Handle("request", first, {target = 0})
local outgoing = HeroSwaps:Handle("request", 0, {target = second})
print("SWAPLOOK READY incoming " .. tostring(incoming) .. ", outgoing " .. tostring(outgoing))
