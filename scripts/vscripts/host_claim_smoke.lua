-- Fresh tools session in CUSTOM_GAME_SETUP, before anyone has claimed host: settings are
-- open once everyone has loaded, nobody is host until claimed, and the first claim wins.
assert(IsInToolsMode() and UsesHostRules())
assert(GameRules:State_Get() == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP and not HostOptions.locked)
assert(HostOptions:ArePlayersReady(), "players not ready in a loaded tools session")
local rules = CustomNetTables:GetTableValue("game_options", "match_rules")
assert(rules.ready == 1, "settings still hidden")
assert(rules.host_id == -1 and not HostOptions:ResolveHost(), "host picked without a claim")
assert(HostOptions:ClaimHost(0), "claim refused")
assert(not HostOptions:ClaimHost(0), "second claim accepted")
assert(HostOptions:ResolveHost():GetPlayerID() == 0)
assert(CustomNetTables:GetTableValue("game_options", "match_rules").host_id == 0)
print("HOST_CLAIM_PASS host 0")
