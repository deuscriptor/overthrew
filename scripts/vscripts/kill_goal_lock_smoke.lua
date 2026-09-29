-- Local tools-mode check that a host-fixed Kill Goal cannot be moved by the early vote or a GG token.
-- Rerun until "KGLOCK PASS" (setup, hero pick, then checks).
if not PlayerResource or not HostOptions then print("KGLOCK waiting for the map") return end
assert(IsInToolsMode(), "requires tools mode")
local state = GameRules:State_Get()
if state < DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP or not PlayerResource:GetPlayer(0) then print("KGLOCK waiting for the player") return end
if state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
	HostOptions:ClaimHost(0) -- no automatic host: claim it as a player would
	assert(HostOptions:ApplyRules({PlayerID=0, single_draft=0, epic_orbs=0, turbo=0, backpack_items=0,
		kill_goal=40, infinite_rerolls=0, all_vision=0, invincible_wards=1, longer_wards=1, divine_rapier=1, dagon=1}))
	print("KGLOCK setup applied")
	return
end
if not IsValidEntity(PlayerResource:GetSelectedHeroEntity(0)) then
	PlayerResource:GetPlayer(0):SetSelectedHero("npc_dota_hero_sven")
	print("KGLOCK selecting hero, state " .. state)
	return
end
if state < DOTA_GAMERULES_STATE_PRE_GAME then print("KGLOCK waiting, state " .. state) return end

assert(GameLoop:HasFixedKillGoal(), "kill goal must be host-fixed")
local goal, duration = GameLoop.target_kill_goal, GameLoop.current_layout.game_base_duration
local sent = {}
local original_send = CustomGameEventManager.Send_ServerToPlayer
CustomGameEventManager.Send_ServerToPlayer = function(self, player, event, data)
	table.insert(sent, event)
	return original_send(self, player, event, data)
end
EarlyConsumables:SendEarlyConsumablesState(0)
EarlyConsumables:PlayerVoteAdditionalGoal(0)
WebInventory:ItemConsumeEvent({PlayerID = 0, item_name = "bp_gg_token"})
CustomGameEventManager.Send_ServerToPlayer = original_send

local menu_state = false
for _, event in ipairs(sent) do if event == "early_consumables:update_state" then menu_state = true end end
assert(not menu_state, "early consumables menu state must not be sent")
assert(GameLoop.target_kill_goal == goal and goal == 40, "kill goal unchanged: " .. tostring(GameLoop.target_kill_goal))
assert(GameLoop.current_layout.game_base_duration == duration, "time limit unchanged")
assert(not EarlyConsumables:IsPlayerVotedForExtraGoal(0), "no vote or token registered")
print("KGLOCK PASS goal " .. goal .. ", time limit " .. duration)
