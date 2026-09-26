-- Local Host owner verification, shared by both VMs (see HostOptions:InitHostClaim).
-- The server stores a random token in this convar. Only the lobby owner's client runs
-- inside the server process, so only its client VM can read the token and send it back
-- through the claim command, which the server attributes to the issuing player.
HOST_CLAIM_CONVAR = "overthrew_host_claim"
HOST_CLAIM_COMMAND = "overthrew_claim_host"

if not IsClient() then return end

-- The client VM does not define the DOTA_GAMERULES_STATE_* constants.
local CUSTOM_GAME_SETUP = DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP or 2

local function ClaimHost()
	if GameRules:State_Get() ~= CUSTOM_GAME_SETUP then return end
	local token = Convars:GetStr(HOST_CLAIM_CONVAR)
	if token and token ~= "0" then SendToConsole(HOST_CLAIM_COMMAND .. " " .. token) end
end

-- Setup begins once every client has loaded, so the owner's player can issue commands.
ListenToGameEvent("game_rules_state_change", ClaimHost, nil)
ClaimHost()
