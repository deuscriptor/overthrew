-- Local tools-mode check for player tips: player 0 plus two bot players on separate FFA teams.
-- Rerun until "TIPTEST DONE" (setup, hero pick, bots, then tips); the next three runs each send a
-- visible bot tip to screenshot ("TIPTEST SHOWN"), the one after ends the match ("TIPTEST ENDED").
if not PlayerResource or not HostOptions then print("TIPTEST waiting for the map") return end
assert(IsInToolsMode(), "requires tools mode")
local state = GameRules:State_Get()
if state < DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP or not PlayerResource:GetPlayer(0) then print("TIPTEST waiting for the player") return end
if state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
	for id, callback in pairs(EventDriver.serverside_events["Events:npc_spawned"] or {}) do
		if callback[1] == OT3Demo.OnNPCSpawned then EventDriver:CancelListener("Events:npc_spawned", id) end
	end
	PlayerDC.CheckEndGame = function() end
	HostOptions:ClaimHost(0) -- no automatic host: claim it as a player would
	assert(HostOptions:ApplyRules({PlayerID=0, single_draft=0, epic_orbs=0, turbo=0, backpack_items=0,
		kill_goal=50, infinite_rerolls=0, all_vision=0, invincible_wards=1, longer_wards=1, divine_rapier=1, dagon=1}))
	print("TIPTEST setup applied")
	return
end
local hero = PlayerResource:GetSelectedHeroEntity(0)
if not IsValidEntity(hero) then
	PlayerResource:GetPlayer(0):SetSelectedHero("npc_dota_hero_sven")
	print("TIPTEST selecting hero, state " .. state)
	return
end
if not hero.initialized or state < DOTA_GAMERULES_STATE_PRE_GAME then print("TIPTEST waiting for hero, state " .. state) return end

if not _G.tips_bots then
	_G.tips_bots = {}
	local teams = {}
	for _, team in ipairs(GameLoop.current_layout.teamlist) do
		if team ~= hero:GetTeam() then table.insert(teams, team) end
	end
	for index, name in ipairs({"npc_dota_hero_pudge", "npc_dota_hero_techies"}) do
		_G.tips_bots[index] = GameRules:AddBotPlayerWithEntityScript(name, "Tip Bot " .. index, teams[index], "", false)
	end
	print("TIPTEST bots created")
	return
end
for _, bot in ipairs(_G.tips_bots) do
	if not IsValidEntity(bot) or not bot.initialized then print("TIPTEST waiting for bots") return end
end

_G.tips_shows = _G.tips_shows or 0
if (_G.tips_status == "DONE" or _G.tips_status == "SHOWN") and _G.tips_shows < 3 then
	-- visible bot tips for screenshots: alternately to player 0 (tipped-you style) and to the other bot
	local techies = _G.tips_bots[2]:GetPlayerOwnerID()
	local target = _G.tips_shows % 2 == 0 and 0 or _G.tips_bots[1]:GetPlayerOwnerID()
	Tips.last_tip_time[techies] = nil
	Tips.used_this_game[techies] = 0
	Tips:Tip({PlayerID = techies, target_player_id = target})
	_G.tips_shows = _G.tips_shows + 1
	_G.tips_status = "SHOWN"
elseif _G.tips_status == "SHOWN" then
	SimulatedEndGame:EndWithWinner(hero:GetTeam())
	_G.tips_status = "ENDED"
end
-- The console keeps little backlog, so a finished run prints its whole log again.
if _G.tips_status then
	for _, line in ipairs(_G.tips_log or {}) do print(line) end
	print("TIPTEST " .. _G.tips_status)
	return
end
_G.tips_log = {}
local function out(line) table.insert(_G.tips_log, line) print(line) end
local failures = 0
local function check(condition, message)
	if condition then out("TIPTEST ok " .. message) else failures = failures + 1 out("TIPTEST CHECKFAIL " .. message) end
end

local pudge = _G.tips_bots[1]:GetPlayerOwnerID()
local techies = _G.tips_bots[2]:GetPlayerOwnerID()
local function received(player_id) return EndGameStats:GetStats(player_id).tips_received or 0 end
local function used(player_id) return Tips.used_this_game[player_id] or 0 end
local function skip_cooldown(player_id) Tips.last_tip_time[player_id] = GameRules:GetGameTime() - TIPS_COOLDOWN end
local base = {[0] = received(0), [pudge] = received(pudge), [techies] = received(techies)}
local http_requests = 0
local original_http = CreateHTTPRequest
CreateHTTPRequest = function(...) http_requests = http_requests + 1 return original_http(...) end

Tips:Tip({PlayerID = 0, target_player_id = pudge})
check(used(0) == 1 and received(pudge) == base[pudge] + 1, "first tip counted for the enemy target")
Tips:Tip({PlayerID = 0, target_player_id = techies})
check(used(0) == 1 and received(techies) == base[techies], "second tip inside 30s rejected")
skip_cooldown(0)
Tips:Tip({PlayerID = 0, target_player_id = techies})
skip_cooldown(0)
Tips:Tip({PlayerID = 0, target_player_id = pudge})
check(used(0) == 3 and received(pudge) == base[pudge] + 2 and received(techies) == base[techies] + 1, "three tips per game")
skip_cooldown(0)
Tips:Tip({PlayerID = 0, target_player_id = techies})
check(used(0) == 3 and received(techies) == base[techies] + 1, "fourth tip rejected after the cooldown")
Tips:Tip({PlayerID = 0, target_player_id = 0})
check(received(0) == base[0], "self tip ignored")
Tips:Tip({PlayerID = pudge, target_player_id = 0})
check(used(pudge) == 1 and received(0) == base[0] + 1, "bot tips player 0 (toast and chat visible now)")
CreateHTTPRequest = original_http
check(http_requests == 0, "no backend requests")

_G.tips_status = failures == 0 and "DONE" or ("FAILED " .. failures)
print("TIPTEST " .. _G.tips_status)
