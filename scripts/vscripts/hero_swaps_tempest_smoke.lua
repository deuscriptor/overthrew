-- Issue #26: Tempest Double cast by a swapped Arc Warden. Player 0 takes Sven, a bot takes Arc Warden (precached for
-- the bot, as a pick does), they swap, and player 0's Arc Warden casts Tempest Double. The double wears its owner's
-- cosmetics: without the swap's precache for the new owner, an account with Arc Warden cosmetics equipped crashed
-- here. Rerun until "SWAPTD DONE"; the finished run prints its log again. Then check console.log after
-- "SWAPTD mark cast" for "requested is not loaded" errors. Use a fresh Tools session (precached resources stay loaded).
if not PlayerResource or not HostOptions then print("SWAPTD waiting for the map") return end
assert(IsInToolsMode(), "requires tools mode")
local state = GameRules:State_Get()
if state < DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP or not PlayerResource:GetPlayer(0) then print("SWAPTD waiting for the player") return end
if state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
	for id, callback in pairs(EventDriver.serverside_events["Events:npc_spawned"] or {}) do
		if callback[1] == OT3Demo.OnNPCSpawned then EventDriver:CancelListener("Events:npc_spawned", id) end
	end
	PlayerDC.CheckEndGame = function() end
	GameRules:SetPreGameTime(600) -- swaps are only open before the horn
	HostOptions:ClaimHost(0)
	assert(HostOptions:ApplyRules({PlayerID=0, single_draft=0, epic_orbs=0, turbo=0, backpack_items=0, fountain_sloth=1,
		kill_goal=50, infinite_rerolls=0, all_vision=1, invincible_wards=1, longer_wards=1, divine_rapier=1, dagon=1, aeon_disk=1}))
	print("SWAPTD setup applied")
	return
end
if _G.swaptd_status then
	for _, line in ipairs(_G.swaptd_log or {}) do print(line) end
	print("SWAPTD " .. _G.swaptd_status)
	return
end
local hero = _G.swaptd_sven or PlayerResource:GetSelectedHeroEntity(0)
if not IsValidEntity(hero) then
	PlayerResource:GetPlayer(0):SetSelectedHero("npc_dota_hero_sven")
	print("SWAPTD selecting hero, state " .. state)
	return
end
if not hero.initialized or state < DOTA_GAMERULES_STATE_PRE_GAME then print("SWAPTD waiting for hero, state " .. state) return end
_G.swaptd_sven = hero
local ARC = "npc_dota_hero_arc_warden"
if not _G.swaptd_bot then
	local team = PlayerResource:GetTeam(0) == DOTA_TEAM_BADGUYS and DOTA_TEAM_GOODGUYS or DOTA_TEAM_BADGUYS
	_G.swaptd_bot = GameRules:AddBotPlayerWithEntityScript(ARC, "Swap Warden", team, "", false)
	print("SWAPTD bot created")
	return
end
local arc = _G.swaptd_bot
if not IsValidEntity(arc) or not arc.initialized then print("SWAPTD waiting for bot") return end
local bot_id = arc:GetPlayerOwnerID()
-- a pick precaches the hero for its player; bots added by script skip that
if not _G.swaptd_bot_precached then
	if not _G.swaptd_bot_precaching then
		_G.swaptd_bot_precaching = true
		PrecacheUnitByNameAsync(ARC, function() _G.swaptd_bot_precached = true end, bot_id)
	end
	print("SWAPTD precaching Arc Warden for the bot")
	return
end

_G.swaptd_log = _G.swaptd_log or {}
local function out(line) table.insert(_G.swaptd_log, line) print(line) end
local function describe(label, unit)
	local id = unit:GetPlayerOwnerID()
	out(string.format("SWAPTD info %s: %s entindex %d owner %d team %d; player %d selected %s (id %s), team %d",
		label, unit:GetUnitName(), unit:entindex(), id, unit:GetTeam(),
		id, PlayerResource:GetSelectedHeroName(id), tostring(PlayerResource:GetSelectedHeroID(id)), PlayerResource:GetTeam(id)))
end

if not _G.swaptd_request then
	describe("before swap, bot's Arc Warden", arc)
	-- the synthetic bot has no network connection; simulate only that flag, until the swap is done
	_G.swaptd_get_connection = PlayerResource.GetConnectionState
	PlayerResource.GetConnectionState = function(self, player_id)
		if player_id == bot_id then return DOTA_CONNECTION_STATE_CONNECTED end
		return _G.swaptd_get_connection(self, player_id)
	end
	local ok, err = pcall(function()
		assert(HeroSwaps:Handle("request", 0, {target = bot_id}), "request")
		assert(HeroSwaps:Handle("accept", bot_id, {request_id = HeroSwaps.next_id}), "accept")
	end)
	if not ok then
		PlayerResource.GetConnectionState = _G.swaptd_get_connection
		_G.swaptd_status = "FAILED swap: " .. tostring(err)
		out("SWAPTD " .. _G.swaptd_status)
		return
	end
	_G.swaptd_request = HeroSwaps.next_id
	print("SWAPTD swap accepted, rerun")
	return
end
-- the swap waits until each hero is precached with its new owner's cosmetics
if HeroSwaps.accepted[_G.swaptd_request] then print("SWAPTD waiting for the swap (precache)") return end
PlayerResource.GetConnectionState = _G.swaptd_get_connection
describe("after swap, player 0's Arc Warden", arc)
if arc:GetPlayerOwnerID() ~= 0 then
	_G.swaptd_status = "FAILED the swap did not run"
	out("SWAPTD " .. _G.swaptd_status)
	return
end

_G.swaptd_status = "running"
for _ = arc:GetLevel(), 5 do arc:HeroLevelUp(false) end
local ability = arc:FindAbilityByName("arc_warden_tempest_double")
ability:SetLevel(1)
ability:EndCooldown()
arc:SetMana(arc:GetMaxMana())
arc:RemoveModifierByName("modifier_pregame_stunned")
arc:SetIdleAcquire(false)
print("SWAPTD mark cast")
arc:CastAbilityNoTarget(ability, 0)
Timers:CreateTimer(2, function()
	local double
	for _, unit in ipairs(HeroList:GetAllHeroes()) do
		if unit:IsTempestDouble() then double = unit end
	end
	if not double then
		_G.swaptd_status = "FAILED no Tempest Double spawned"
		out("SWAPTD " .. _G.swaptd_status)
		return
	end
	describe("Tempest Double", double)
	_G.swaptd_status = "DONE"
	out("SWAPTD DONE")
end)
