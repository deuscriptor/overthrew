-- Fresh Local Host tools session, in CUSTOM_GAME_SETUP after the fallback delay. The
-- local client VM must have claimed host (libraries/host_claim.lua) by
-- reading the server convar token, not through the native-privileges fallback.
assert(IsInToolsMode() and not IsDedicatedServer())
assert(HostOptions.claim_token and Convars:GetInt(HOST_CLAIM_CONVAR) == HostOptions.claim_token, "claim token not published")
assert(HostOptions.owner_id ~= nil and not HostOptions.claim_fallback, "client VM did not claim host with the convar token")
local host = HostOptions:ResolveHost()
assert(host and host:GetPlayerID() == HostOptions.owner_id)
local rules = CustomNetTables:GetTableValue("game_options", "match_rules")
assert(not UsesHostRules() or rules.host_id == HostOptions.owner_id)
print("HOST_CLAIM_PASS owner", HostOptions.owner_id)
