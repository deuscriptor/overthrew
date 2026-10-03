WebSettings = WebSettings or {}

-- Player settings toggled from the upgrades panel. They last for the match and reach the client with the player data.
-- The defaults name the accepted settings and their types; the client starts from the same values.
WebSettings.known_defaults = {
	generic_from_subscription = false,
	auto_select_favorites = false,
	auto_select_favorites_delay = 0,
}


function WebSettings:Init()
	EventStream:Listen("WebSettings:set_setting_value", WebSettings.SetSettingValueEvent, WebSettings)
end


function WebSettings:SetSettingValueEvent(event)
	local player_id = event.PlayerID
	if not IsValidPlayerID(player_id) then return end

	local setting_name = event.setting_name
	local setting_value = event.setting_value
	if not setting_name or setting_value == nil then return end

	local default = WebSettings.known_defaults[setting_name]
	if default == nil then
		return DisplayError(player_id, "#dota_hud_error_invalid_setting")
	end

	-- Dota networking converts booleans to 0 / 1, and lua considers both to be TRUE in conditionals
	if type(default) == "boolean" and type(setting_value) ~= "boolean" then setting_value = toboolean(setting_value) end

	WebSettings:SetSettingValue(player_id, setting_name, setting_value)
end


--- Sets settings value of `name` to `value` and updates the player's client.
---@param player_id number
---@param name string
---@param value any
function WebSettings:SetSettingValue(player_id, name, value)
	WebPlayer.players_data[player_id] = WebPlayer.players_data[player_id] or {}
	local player = WebPlayer.players_data[player_id]

	player.settings = player.settings or {}
	player.settings[name] = value

	WebPlayer:UpdateClient(player_id)
end


--- Returns table of player settings
---@param player_id number
---@return table
function WebSettings:GetSettings(player_id)
	return (WebPlayer.players_data[player_id] or {}).settings or {}
end


--- Returns value of setting at `name` for a given player, or `default` if player doesn't have setting
---@param player_id number
---@param name string
---@return any
function WebSettings:GetSettingValue(player_id, name, default)
	if WebSettings:GetSettings(player_id)[name] ~= nil then
		return WebSettings:GetSettings(player_id)[name]
	end
	return default
end


WebSettings:Init()
