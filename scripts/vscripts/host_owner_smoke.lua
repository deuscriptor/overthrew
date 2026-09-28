-- Tools session in CUSTOM_GAME_SETUP: the host is the lowest real (non-bot) player ID,
-- the lobby's first member, and the published rules name that player.
assert(IsInToolsMode())
local expected
for id = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
	if PlayerResource:IsValidPlayerID(id) and not PlayerResource:IsFakeClient(id) then expected = id break end
end
local host = HostOptions:ResolveHost()
assert(host and host:GetPlayerID() == expected, "host is not the lowest real player ID")
local rules = CustomNetTables:GetTableValue("game_options", "match_rules")
assert(not UsesHostRules() or rules.host_id == expected)
print("HOST_OWNER_PASS host", expected)
