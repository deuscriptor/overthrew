WebPlayer = WebPlayer or {}

-- Every player gets the premium benefits of the top subscription tier, locally and for free.
local LOCAL_SUBSCRIPTION = {tier = 2, type = "local", metadata = {}}

function WebPlayer:Init()
	EventStream:Listen("WebPlayer:get_data", WebPlayer.GetData, WebPlayer)

	WebPlayer.players_data = {}
end


--- Returns player current subscription tier
---@param player_id number
---@return number
function WebPlayer:GetSubscriptionTier(player_id)
	return WebPlayer:GetSubscriptionData(player_id).tier
end


--- Returns player subscription data
--- Data contains tier, type and metadata
---@param player_id number
---@return table
function WebPlayer:GetSubscriptionData(player_id)
	return LOCAL_SUBSCRIPTION
end


function WebPlayer:GetData(event)
	local player_id = event.PlayerID
	if not player_id or not PlayerResource:IsValidPlayerID(player_id) then return end

	WebPlayer:UpdateClient(player_id)
end


function WebPlayer:UpdateClient(player_id)
	local player = PlayerResource:GetPlayer(player_id)
	if not IsValidEntity(player) then return end

	CustomGameEventManager:Send_ServerToPlayer(player, "WebPlayer:update", {
		player_data = {
			subscription = WebPlayer:GetSubscriptionData(player_id),
			settings = WebSettings:GetSettings(player_id),
		}
	})
end


WebPlayer:Init()
