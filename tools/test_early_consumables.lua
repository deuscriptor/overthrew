GAME_DURATION_OPTIONAL_EARLY_CONSUMABLES_TIME = 20
EventStream = {Listen = function() end}
local dota_time, fixed = 5, true
GameRules = {GetDOTATime = function() return dota_time end}
PlayerResource = {
	IsValidPlayerID = function(_, id) return id == 0 or id == 1 end,
	GetPlayer = function(_, id) return {id = id} end,
}
local sent, votes = {}, {}
CustomGameEventManager = {Send_ServerToPlayer = function(_, player, event, data) table.insert(sent, {player.id, event, data}) end}
GameLoop = {
	HasFixedKillGoal = function() return fixed end,
	IncreaseScoreByVote = function(_, player_id)
		table.insert(votes, player_id)
		EarlyConsumables:RegisterScoreVoteForPlayer(player_id, EXTRA_SCORE_VOTE_TYPE.DEFAULT)
	end,
}

dofile("scripts/vscripts/libraries/early_consumables.lua")

-- Host-fixed kill goal: the menu state is never sent (so it never shows) and votes change nothing.
EarlyConsumables:SendEarlyConsumablesState(0)
EarlyConsumables:PlayerVoteAdditionalGoal(0)
assert(#sent == 0 and #votes == 0 and not EarlyConsumables:IsPlayerVotedForExtraGoal(0))

-- Other maps keep the original early vote.
fixed = false
EarlyConsumables:SendEarlyConsumablesState(1)
assert(#sent == 1 and sent[1][2] == "early_consumables:update_state" and sent[1][3].player_vote_kl == 0)
EarlyConsumables:PlayerVoteAdditionalGoal(1)
EarlyConsumables:PlayerVoteAdditionalGoal(1)
assert(#votes == 1 and votes[1] == 1 and sent[#sent][3].player_vote_kl == EXTRA_SCORE_VOTE_TYPE.DEFAULT)
dota_time = 20
EarlyConsumables:PlayerVoteAdditionalGoal(0)
assert(#votes == 1, "votes close after the early window")
print("PASS early consumables: hidden and inert with a host-fixed kill goal, original vote elsewhere")
