Tips = Tips or {}


function Tips:Init()
	Tips.used_this_game = {}
	Tips.last_tip_time = {}

	EventStream:Listen("Tips:tip", Tips.Tip, Tips)
	EventStream:Listen("Tips:get_data", Tips.GetData, Tips)
end


--- Tips targeted player on behalf of requestor.
--- Local only, like Dota Plus tipping without the currency: nothing is credited or sent to WebApi,
--- the tip is announced to everyone (toast + chat) and counted for the end screen.
---@param event table
function Tips:Tip(event)
	local source_player_id = event.PlayerID
	if not IsValidPlayerID(source_player_id) then return end

	local target_player_id = tonumber(event.target_player_id)
	if not IsValidPlayerID(target_player_id) then return end

	if source_player_id == target_player_id then return end

	local used_this_game = Tips.used_this_game[source_player_id] or 0
	if used_this_game >= TIPS_PER_GAME_MAX then
		DisplayError(source_player_id, "#dota_hud_error_used_all_tips_for_this_game")
		return
	end

	local last_tip_time = Tips.last_tip_time[source_player_id]
	if last_tip_time and (GameRules:GetGameTime() - last_tip_time) < TIPS_COOLDOWN then
		DisplayError(source_player_id, "#dota_hud_error_tip_is_on_cooldown")
		return
	end

	Tips.used_this_game[source_player_id] = used_this_game + 1
	Tips.last_tip_time[source_player_id] = GameRules:GetGameTime()

	Tips:UpdateClient(source_player_id)

	EndGameStats:Add_TipReceived(target_player_id)

	Toasts:NewForAll("player_tip", {
		source_player_id = source_player_id,
		target_player_id = target_player_id,
		currency = TIPS_CURRENCY_PER_TIP
	})

	CustomChat:MessageToAll(-1, "custom_chat_player_tip", {
		hard_replace = {
			["%s1"] = "<font color='{s:player_color_1}'>{s:player_name_1}</font>",
			["%s2"] = "<font color='{s:player_color_2}'>{s:player_name_2}</font>",
			["%s3"] = tostring(TIPS_CURRENCY_PER_TIP),
		},
		players = {
			[source_player_id] = {player_name_1 = C_CHAT_ENUM.PLAYER_NAME, player_color_1 = C_CHAT_ENUM.PLAYER_COLOR_READABLE},
			[target_player_id] = {player_name_2 = C_CHAT_ENUM.PLAYER_NAME, player_color_2 = C_CHAT_ENUM.PLAYER_COLOR_READABLE},
		},
	})
end


--- Sends player tips data to requestor client (max this game, used this game, cooldown)
---@param event table
function Tips:GetData(event)
	local player_id = event.PlayerID
	if not IsValidPlayerID(player_id) then return end

	Tips:UpdateClient(player_id)
end


--- Updates client data regarding tips
--- Sends max this game, used this game, last tip time and cooldown duration
---@param player_id number
function Tips:UpdateClient(player_id)
	if not IsValidPlayerID(player_id) then return end
	local player = PlayerResource:GetPlayer(player_id)
	if not IsValidEntity(player) then return end

	CustomGameEventManager:Send_ServerToPlayer(player, "Tips:update", {
		max_this_game = TIPS_PER_GAME_MAX,
		used_this_game = Tips.used_this_game[player_id] or 0,
		cooldown = Tips.last_tip_time[player_id] or -10000,
		cooldown_duration = TIPS_COOLDOWN,
	})
end


Tips:Init()
