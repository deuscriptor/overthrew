-- Local tools-mode check for fountain smoke (All Vision on): units on their own fountain are hidden from
-- enemies, including true sight, and visible again after leaving. Player 0 plus one bot on another FFA team.
-- Rerun until "FSMOKE DONE"; later reruns print the log again.
if not PlayerResource or not HostOptions then print("FSMOKE waiting for the map") return end
assert(IsInToolsMode(), "requires tools mode")
local state = GameRules:State_Get()
if state < DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP or not PlayerResource:GetPlayer(0) then print("FSMOKE waiting for the player") return end
if state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
	for id, callback in pairs(EventDriver.serverside_events["Events:npc_spawned"] or {}) do
		if callback[1] == OT3Demo.OnNPCSpawned then EventDriver:CancelListener("Events:npc_spawned", id) end
	end
	PlayerDC.CheckEndGame = function() end
	HostOptions:ClaimHost(0) -- no automatic host: claim it as a player would
	assert(HostOptions:ApplyRules({PlayerID=0, single_draft=0, epic_orbs=0, turbo=0, backpack_items=0,
		kill_goal=50, infinite_rerolls=0, all_vision=1, invincible_wards=1, longer_wards=1, divine_rapier=1, dagon=1}))
	print("FSMOKE setup applied")
	return
end
local sven = PlayerResource:GetSelectedHeroEntity(0)
if not IsValidEntity(sven) then
	PlayerResource:GetPlayer(0):SetSelectedHero("npc_dota_hero_sven")
	print("FSMOKE selecting hero, state " .. state)
	return
end
if not sven.initialized or state < DOTA_GAMERULES_STATE_PRE_GAME then print("FSMOKE waiting for hero, state " .. state) return end
if not _G.fsmoke_bot then
	for _, team in ipairs(GameLoop.current_layout.teamlist) do
		if team ~= sven:GetTeam() then
			_G.fsmoke_bot = GameRules:AddBotPlayerWithEntityScript("npc_dota_hero_pudge", "Smoke Bot", team, "", false)
			break
		end
	end
	print("FSMOKE bot created")
	return
end
local pudge = _G.fsmoke_bot
if not IsValidEntity(pudge) or not pudge.initialized then print("FSMOKE waiting for bot") return end
pudge:SetIdleAcquire(false)

_G.fsmoke_log = _G.fsmoke_log or {}
local function out(line) table.insert(_G.fsmoke_log, line) print(line) end
local function check(condition, message)
	if not condition then _G.fsmoke_failures = (_G.fsmoke_failures or 0) + 1 end
	out("FSMOKE " .. (condition and "ok " or "CHECKFAIL ") .. message)
end
local EFFECT = "modifier_fountain_rejuvenation_effect_lua"
local function smoked(unit)
	local modifier = unit:FindModifierByName(EFFECT)
	return modifier ~= nil and modifier:GetStackCount() == 1
end

local stage = _G.fsmoke_stage or 0
if stage == 0 then
	-- bot players added mid-game spawn at the map centre, not on their fountain
	FindClearSpaceForUnit(pudge, GameLoop.towers[pudge:GetTeam()]:GetAbsOrigin() + Vector(0, 0, 0), true)
	_G.fsmoke_stage = 1
	out("FSMOKE bot moved to its fountain, rerun")
	return
elseif stage == 1 then
	check(HostOptions:GetOption("all_vision") == true, "All Vision on")
	check(smoked(sven) and sven:IsInvisible(), "Sven smoked on own fountain")
	check(smoked(pudge) and pudge:IsInvisible(), "Pudge smoked on own fountain")
	check(not pudge:CanEntityBeSeenByMyTeam(sven), "enemy cannot see Sven in his fountain")
	check(not sven:CanEntityBeSeenByMyTeam(pudge), "Sven cannot see Pudge in his fountain")
	-- true sight right next to the enemy fountain must not reveal the smoke
	_G.fsmoke_sentry = CreateUnitByName("npc_dota_sentry_wards", pudge:GetAbsOrigin() + Vector(150, 0, 0), false, sven, sven, sven:GetTeam())
	_G.fsmoke_sentry:AddNewModifier(sven, nil, "modifier_item_ward_true_sight", {true_sight_range = 1000, duration = 60})
	-- move Sven to the map centre; the aura lingers briefly, so the next run checks
	FindClearSpaceForUnit(sven, Vector(0, 0, 0) + RandomVector(600), true)
	_G.fsmoke_stage = 2
	out("FSMOKE stage 1 done, rerun")
	return
elseif stage == 2 then
	check(not sven:CanEntityBeSeenByMyTeam(pudge), "sentry true sight next to Pudge does not reveal him")
	check(not smoked(sven) and not sven:IsInvisible(), "Sven visible again after leaving the fountain")
	check(pudge:CanEntityBeSeenByMyTeam(sven), "enemy sees Sven outside the fountain")
	if IsValidEntity(_G.fsmoke_sentry) then _G.fsmoke_sentry:ForceKill(false) end
	FindClearSpaceForUnit(sven, GameLoop.towers[sven:GetTeam()]:GetAbsOrigin() + Vector(0, 0, 0), true)
	_G.fsmoke_stage = 3
	out("FSMOKE stage 2 done, rerun")
	return
elseif stage == 3 then
	check(smoked(sven) and sven:IsInvisible(), "Sven smoked again after returning")
	_G.fsmoke_stage = 4
	_G.fsmoke_status = (_G.fsmoke_failures or 0) == 0 and "DONE" or ("FAILED " .. _G.fsmoke_failures)
end
for _, line in ipairs(_G.fsmoke_log) do print(line) end
print("FSMOKE " .. _G.fsmoke_status)
