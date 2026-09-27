-- Local tools-mode check: heroes swapped before the horn must stay stunned like everyone else.
-- Tools mode skips the production pre-game stun, so this applies it the same way GameLoop does.
-- Rerun until "SWAPSTUN DONE".
if not PlayerResource or not HostOptions then print("SWAPSTUN waiting for the map") return end
assert(IsInToolsMode() and UsesHostRules(), "requires local FFA tools mode")
local state = GameRules:State_Get()
if state < DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP or not PlayerResource:GetPlayer(0) then print("SWAPSTUN waiting for the player") return end
if state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
	for id, callback in pairs(EventDriver.serverside_events["Events:npc_spawned"] or {}) do
		if callback[1] == OT3Demo.OnNPCSpawned then EventDriver:CancelListener("Events:npc_spawned", id) end
	end
	PlayerDC.CheckEndGame = function() end
	GameRules:SetPreGameTime(600)
	assert(HostOptions:ApplyRules({PlayerID=0, single_draft=0, epic_orbs=0, turbo=0, backpack_items=0,
		kill_goal=50, infinite_rerolls=0, all_vision=1, invincible_wards=1, longer_wards=1, divine_rapier=1, dagon=1}))
	print("SWAPSTUN setup applied")
	return
end
local sven = PlayerResource:GetSelectedHeroEntity(0)
if not IsValidEntity(sven) then
	PlayerResource:GetPlayer(0):SetSelectedHero("npc_dota_hero_sven")
	print("SWAPSTUN selecting hero, state " .. state)
	return
end
if not sven.initialized or state < DOTA_GAMERULES_STATE_PRE_GAME then print("SWAPSTUN waiting for hero, state " .. state) return end
if not _G.swapstun_bot then
	for _, team in ipairs(GameLoop.current_layout.teamlist) do
		if team ~= sven:GetTeam() then
			_G.swapstun_bot = GameRules:AddBotPlayerWithEntityScript("npc_dota_hero_lina", "Swap Stun Bot", team, "", false)
			break
		end
	end
	print("SWAPSTUN bot created")
	return
end
local lina = _G.swapstun_bot
if not IsValidEntity(lina) or not lina.initialized then print("SWAPSTUN waiting for bot") return end
local bot_id = lina:GetPlayerOwnerID()

_G.swapstun_log = _G.swapstun_log or {}
local function out(line) table.insert(_G.swapstun_log, line) print(line) end
local function check(condition, message)
	if not condition then _G.swapstun_failures = (_G.swapstun_failures or 0) + 1 end
	out("SWAPSTUN " .. (condition and "ok " or "CHECKFAIL ") .. message)
end
local function describe(label, hero)
	local modifier = hero:FindModifierByName("modifier_pregame_stunned")
	out(string.format("SWAPSTUN info %s (player %d, team %d): stun modifier %s, remaining %.1f, IsStunned %s",
		label, hero:GetPlayerOwnerID(), hero:GetTeam(), tostring(modifier ~= nil), modifier and modifier:GetRemainingTime() or -1, tostring(hero:IsStunned())))
end

local stage = _G.swapstun_stage or 0
if stage == 0 then
	-- bot players added mid-game spawn at the map centre; production heroes start on their fountain
	FindClearSpaceForUnit(lina, GameLoop.towers[lina:GetTeam()]:GetAbsOrigin(), true)
	-- longer than PREGAME_TIME so the checks below finish while the stun is still running
	for _, hero in ipairs({sven, lina}) do
		hero:AddNewModifier(hero, nil, "modifier_pregame_stunned", {duration = 120})
	end
	_G.swapstun_heroes = {sven = sven, lina = lina}
	_G.swapstun_stage = 1
	out("SWAPSTUN stunned both heroes, rerun")
	return
elseif stage == 1 then
	describe("Sven before swap", sven)
	describe("Lina before swap", lina)
	check(sven:IsStunned() and lina:IsStunned(), "both heroes stunned before the swap")
	-- the synthetic bot has no network connection; only that flag is simulated
	local get_connection = PlayerResource.GetConnectionState
	PlayerResource.GetConnectionState = function(self, player_id)
		if player_id == bot_id then return DOTA_CONNECTION_STATE_CONNECTED end
		return get_connection(self, player_id)
	end
	local ok, err = pcall(function()
		check(HeroSwaps:Execute({from = 0, to = bot_id, from_hero = sven:GetUnitName(), to_hero = lina:GetUnitName()}), "swap executed")
	end)
	PlayerResource.GetConnectionState = get_connection
	if not ok then out("SWAPSTUN CHECKFAIL swap error " .. tostring(err)) _G.swapstun_failures = (_G.swapstun_failures or 0) + 1 end
	describe("Lina right after swap", lina)
	describe("Sven right after swap", sven)
	_G.swapstun_stage = 2
	out("SWAPSTUN swapped, rerun after a second")
	return
elseif stage == 2 then
	local heroes = _G.swapstun_heroes
	describe("Lina 1s after swap (now player 0)", heroes.lina)
	describe("Sven 1s after swap (now bot)", heroes.sven)
	check(heroes.lina:IsStunned(), "hero received by player 0 stunned on its new fountain")
	check(heroes.sven:IsStunned(), "hero received by the bot stunned on its new fountain")
	-- outside the fountain (no debuff immunity) the stun must hold too
	FindClearSpaceForUnit(heroes.lina, RandomVector(700), true)
	_G.swapstun_stage = 3
	out("SWAPSTUN moved Lina out of the fountain, rerun")
	return
elseif stage == 3 then
	local heroes = _G.swapstun_heroes
	describe("Lina outside the fountain", heroes.lina)
	check(heroes.lina:IsStunned() and not heroes.lina:HasModifier("modifier_fountain_rejuvenation_effect_lua"), "hero stunned outside the fountain")
	_G.swapstun_stage = 4
	_G.swapstun_status = (_G.swapstun_failures or 0) == 0 and "DONE" or ("FAILED " .. _G.swapstun_failures)
end
for _, line in ipairs(_G.swapstun_log) do print(line) end
print("SWAPSTUN " .. _G.swapstun_status)
