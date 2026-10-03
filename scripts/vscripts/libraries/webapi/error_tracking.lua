ErrorTracking = ErrorTracking or {}


local function handle_error(error)
	local error_text = error:gsub(": at 0x%x+", ": at 0x")
	print(error_text)

	for player_id = 0, 23 do
		if PlayerResource:IsValidPlayerID(player_id) and GameMode:IsDeveloper(player_id) then
			local player = PlayerResource:GetPlayer(player_id)
			if player then
				CustomGameEventManager:Send_ServerToPlayer(player, "server_print", { message = error_text })
			end
		end
	end

	return error_text
end


--- Calls `callback`, printing any error it raises (and showing it to developers) instead of propagating it
---@param callback function
function ErrorTracking.Try(callback, ...)
	return xpcall(callback, handle_error, ...)
end
