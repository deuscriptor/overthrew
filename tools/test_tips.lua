IsInToolsMode = function() return true end
class = function(t) return t end
EventStream = {Listen = function() end}
EventDriver = {Listen = function() end}
local now = 100
GameRules = {GetGameTime = function() return now end}
local players = {[0] = {}, [1] = {}, [2] = {}, [3] = {}}
PlayerResource = {
	GetPlayer = function(_, id) return players[id] end,
	IsValidPlayerID = function(_, id) return players[id] ~= nil end,
}
IsValidPlayerID = function(id) return id ~= nil and PlayerResource:IsValidPlayerID(id) end
IsValidEntity = function(v) return v ~= nil end
CreateHTTPRequest = function() error("Tips must not reach the backend") end
local errors, to_player, to_all = {}, {}, {}
DisplayError = function(player_id, message) table.insert(errors, {player_id, message}) end
CustomGameEventManager = {
	Send_ServerToPlayer = function(_, player, event, data) table.insert(to_player, {player, event, data}) end,
	Send_ServerToAllClients = function(_, event, data) table.insert(to_all, {event, data}) end,
}

dofile("scripts/vscripts/libraries/webapi/declarations.lua")
dofile("scripts/vscripts/libraries/custom_chat.lua")
dofile("scripts/vscripts/libraries/toasts.lua")
dofile("scripts/vscripts/game/end_game_stats.lua")
dofile("scripts/vscripts/libraries/webapi/tips.lua")

local function tip(source, target)
	errors, to_player, to_all = {}, {}, {}
	Tips:Tip({PlayerID = source, target_player_id = target})
end

-- A tip is announced to everyone (toast + chat), counted for the target and credits nothing.
tip(0, "1")
assert(#errors == 0 and #to_all == 2)
local toast, chat = to_all[1], to_all[2]
assert(toast[1] == "Toasts:new" and toast[2].toast_type == "player_tip")
assert(toast[2].data.source_player_id == 0 and toast[2].data.target_player_id == 1)
assert(toast[2].data.currency == TIPS_CURRENCY_PER_TIP)
assert(chat[1] == "custom_chat:message" and chat[2].sender_id == -1)
assert(chat[2].main_token == "custom_chat_player_tip")
assert(chat[2].tokens.players[0].player_name_1 == C_CHAT_ENUM.PLAYER_NAME)
assert(chat[2].tokens.players[1].player_color_2 == C_CHAT_ENUM.PLAYER_COLOR_READABLE)
assert(chat[2].tokens.players[0].player_color_1 == C_CHAT_ENUM.PLAYER_COLOR_READABLE and chat[2].tokens.players[1].player_name_2 == C_CHAT_ENUM.PLAYER_NAME)
assert(chat[2].tokens.hard_replace["%s3"] == tostring(TIPS_CURRENCY_PER_TIP))
assert(EndGameStats:GetStats(1).tips_received == 1 and EndGameStats:GetStats(0).tips_received == 0)
local update = to_player[1]
assert(update[1] == players[0] and update[2] == "Tips:update")
assert(update[3].used_this_game == 1 and update[3].max_this_game == 3)
assert(update[3].cooldown == 100 and update[3].cooldown_duration == 30)

-- Cooldown applies to the tipper only; other players can still tip.
now = 129.9
tip(0, 2)
assert(#to_all == 0 and errors[1][1] == 0 and errors[1][2] == "#dota_hud_error_tip_is_on_cooldown")
tip(2, 1)
assert(#to_all == 2 and EndGameStats:GetStats(1).tips_received == 2)

-- Three tips per game, then the cap holds after the cooldown.
now = 130
tip(0, 2)
assert(#to_all == 2)
now = 160
tip(0, 3)
assert(#to_all == 2 and to_player[1][3].used_this_game == 3)
now = 1000
tip(0, 1)
assert(#to_all == 0 and errors[1][2] == "#dota_hud_error_used_all_tips_for_this_game")
assert(EndGameStats:GetStats(1).tips_received == 2)

-- Self tips, unknown players and missing targets are ignored silently.
tip(3, 3)
tip(3, 7)
tip(3, nil)
tip(9, 1)
assert(#to_all == 0 and #errors == 0 and #to_player == 0)

Tips:GetData({PlayerID = 3})
assert(to_player[1][3].used_this_game == 0 and to_player[1][3].cooldown == -10000)
print("PASS tips: local broadcast, chat line, end-screen tally, 3 per game, 30s cooldown, no backend")
