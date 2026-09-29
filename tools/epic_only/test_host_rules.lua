local output = print
dofile("tools/epic_only/test_orbs.lua")
local map = "ot3_necropolis_ffa"
GetMapName = function() return map end
DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP = 2
local state = DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP
local finished, initialized, bans = 0, 0, nil
local fogDisabled
GameRules.GetGameModeEntity = function() return {
    SetFogOfWarDisabled = function(_, value) fogDisabled = value end,
} end
local players = {{id = 0}, {id = 1}}
for _, player in ipairs(players) do player.GetPlayerID = function(self) return self.id end end
-- Connection-order signals must not decide the host: players claim it.
GetListenServerHost = function() return {GetController = function() return players[2] end} end
local fallback
Timers = {CreateTimer = function(_, args) fallback = args end}
PlayerResource.IsValidPlayerID = function(_, id) return id == 0 or id == 1 end
PlayerResource.GetPlayer = function(_, id) return players[id + 1] end
IsValidEntity = function(p) return p ~= nil end
GameRules.State_Get = function() return state end
-- Native privileges follow load order; player 1 loaded first. Only other maps use them.
GameRules.PlayerHasCustomGameHostPrivileges = function(_, p) return p.id == 1 end
local now, connection, fake = 0, {}, {}
Time = function() return now end
DOTA_CONNECTION_STATE_NOT_YET_CONNECTED, DOTA_CONNECTION_STATE_CONNECTED = 1, 2
DOTA_CONNECTION_STATE_DISCONNECTED, DOTA_CONNECTION_STATE_ABANDONED = 3, 4
PlayerResource.GetConnectionState = function(_, id) return connection[id] or DOTA_CONNECTION_STATE_CONNECTED end
PlayerResource.IsFakeClient = function(_, id) return fake[id] == true end
PlayerResource.GetPlayerName = function(_, id) return "player" .. id end
PlayerResource.GetSteamAccountID = function(_, id) return 1000 + id end
GameRules.SetCustomGameBansPerTeam = function(_, n) bans = n end
GameRules.FinishCustomGameSetup = function() finished = finished + 1 end
local listeners = {}
EventStream = {Listen = function(_, name, callback) listeners[name] = callback end}
EntIndexToHScript = function(id) return players[id + 1] end
EventDriver = {Listen = function() end}
local publishedGoal, publishedRules
CustomNetTables = {SetTableValue = function(_, tableName, key, value)
    if tableName == "game_options" and key == "score_goal" then publishedGoal = value end
    if tableName == "game_options" and key == "match_rules" then publishedRules = value end
end}
SingleDraft.Init = function() if IsSingleDraftMap() then initialized = initialized + 1 end end
HostItems = {ApplyRules = function() end}
local backpackApplied = 0
BackpackItems = {ApplyRules = function() backpackApplied = backpackApplied + 1 end}
dofile("scripts/vscripts/libraries/host_options.lua")
GameLoop.current_layout = TEAMS_LAYOUTS.ot3_necropolis_ffa
for draft = 0, 1 do for epic = 0, 1 do for turbo = 0, 1 do
    HostOptions:Init()
    assert(HostOptions:ClaimHost(0))
    assert(not HostOptions:GetOption("epic_orbs"), "Epic Orbs must default off")
    assert(not HostOptions:GetOption("backpack_items"), "Backpack Items must default off")
    for _, on in ipairs({"single_draft", "turbo", "infinite_rerolls", "all_vision",
        "invincible_wards", "longer_wards", "divine_rapier", "dagon"}) do
        assert(HostOptions:GetOption(on), on .. " must default on")
    end
    assert(HostOptions.options.kill_goal == 50)
    local event = {PlayerID = 1, infinite_rerolls=0, all_vision=0, invincible_wards=0, longer_wards=1, divine_rapier=0, dagon=0, single_draft = draft, epic_orbs = epic, turbo = turbo, backpack_items = 0, kill_goal = 45}
    assert(not HostOptions:ApplyRules(event), "non-host accepted")
    event.PlayerID = 0
    event.epic_orbs = "true"
    assert(not HostOptions:ApplyRules(event), "invalid value accepted")
    event.epic_orbs = epic
    HostOptions:SetOptionState("flat_rerolls", epic == 0)
    assert(not HostOptions:GetOption("flat_rerolls"), "removed standalone option accepted")
    local before = finished
    assert(HostOptions:ApplyRules(event))
    assert(finished == before + 1)
    assert(bans == (draft == 1 and 0 or 1))
    assert(IsSingleDraftMap() == (draft == 1))
    assert(IsTurboMode() == (turbo == 1))
    assert(GameLoop.target_kill_goal == 45)
    assert(GameLoop.current_layout.game_base_duration == DEFAULT_MATCH_LENGTH * 1.5)
    HostOptions:SetOptionState("kill_goal", 90)
    assert(HostOptions.options.kill_goal == 45, "locked goal changed")
    GameLoop:DecreaseScoreByPlayerDisconnect(0)
    GameLoop:IncreaseScoreByPlayerDisconnect(0, 10)
    GameLoop:IncreaseTimeAndGoal(10)
    EarlyConsumables = {RegisterScoreVoteForPlayer = function() end}
    EXTRA_SCORE_VOTE_TYPE = {DEFAULT=0}
    GameLoop:IncreaseScoreByVote(0)
    assert(GameLoop.target_kill_goal == 45, "fixed goal changed during match")
    for _, rarity in ipairs({1, 2, 4}) do
        assert(ResolveOrbRarity(rarity) == (epic == 1 and 4 or rarity))
        assert(Upgrades:GetRerollPrice(rarity) == (epic == 1 and 1 or rarity))
    end
    assert(not HostOptions:ApplyRules(event), "duplicate start accepted")
    HostOptions:SetOptionState("epic_orbs", epic == 0)
    assert(IsEpicOnlyMap() == (epic == 1), "locked rule changed")
end end end
assert(initialized == 4)
for _, goal in ipairs({1, 15, 30, 45, 60, 90}) do
    HostOptions:Init()
    assert(HostOptions:ClaimHost(0))
    assert(HostOptions:ApplyRules({PlayerID=0, single_draft=0, epic_orbs=0, turbo=0, backpack_items=0, kill_goal=goal,
        infinite_rerolls=0, all_vision=0, invincible_wards=0, longer_wards=1, divine_rapier=0, dagon=0}))
    assert(GameLoop.current_layout.game_base_duration == DEFAULT_MATCH_LENGTH * (goal / 30))
    assert(publishedGoal.goal == goal and publishedGoal.limit == GameLoop.current_layout.game_base_duration,
        "HUD and server must receive the same scaled limit")
end
for _, name in ipairs({"backpack_items", "infinite_rerolls", "all_vision", "invincible_wards", "longer_wards", "divine_rapier", "dagon"}) do
    HostOptions:Init()
    assert(HostOptions:ClaimHost(0))
    assert(HostOptions:GetOption(name) == (name ~= "backpack_items"), name .. " default")
    local event = {PlayerID=0, single_draft=0, epic_orbs=0, turbo=0, backpack_items=1, kill_goal=30,
        infinite_rerolls=1, all_vision=1, invincible_wards=1, longer_wards=0, divine_rapier=1, dagon=1}
    local value = event[name]
    event[name] = "true"
    assert(not HostOptions:ApplyRules(event), "invalid new flag accepted")
    assert(not HostOptions.locked)
    event[name] = value
    assert(HostOptions:ApplyRules(event))
    assert(HostOptions:GetOption(name) == (value == 1))
    assert(fogDisabled == (event.all_vision == 1), "All Vision must configure native fog")
    HostOptions:SetOptionState(name, value == 0)
    assert(HostOptions:GetOption(name) == (value == 1), "locked new flag changed")
end
assert(backpackApplied > 0, "Applying rules must configure Backpack Items")
-- Kill goal validation, with player 1 as host.
HostOptions:Init()
assert(HostOptions:ClaimHost(1))
assert(not HostOptions:ApplyRules({PlayerID=0, infinite_rerolls=0, all_vision=0, invincible_wards=0, longer_wards=1, divine_rapier=0, dagon=0, single_draft=0, epic_orbs=0, turbo=0, backpack_items=0, kill_goal=30}))
for _, invalid in ipairs({0, -1, 1.5, "30", false, math.huge, 2147483648}) do
    assert(not HostOptions:ApplyRules({PlayerID=1, infinite_rerolls=0, all_vision=0, invincible_wards=0, longer_wards=1, divine_rapier=0, dagon=0, single_draft=0, epic_orbs=0, turbo=0, backpack_items=0, kill_goal=invalid}))
    HostOptions:SetOptionState("kill_goal", invalid)
    assert(HostOptions.options.kill_goal == 50)
end
assert(HostOptions:ApplyRules({PlayerID=1, infinite_rerolls=0, all_vision=0, invincible_wards=0, longer_wards=1, divine_rapier=0, dagon=0, single_draft=0, epic_orbs=0, turbo=0, backpack_items=0, kill_goal=30}))
-- Claim host: nobody is host until a player claims it, and only once setup has begun and
-- every player has loaded. Load order and native privileges (player 1) play no part.
local claim = listeners["HostOptions:claim_host"]
HostOptions:Init()
state = DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP - 1
HostOptions:PublishRules()
assert(publishedRules.ready == 0 and publishedRules.host_id == -1, "settings open before setup")
claim({PlayerID=1}, 1)
assert(publishedRules.host_id == -1, "claim accepted before setup")
state = DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP
connection[0] = DOTA_CONNECTION_STATE_NOT_YET_CONNECTED
HostOptions:PublishRules()
assert(publishedRules.ready == 0, "settings open while a player is loading")
claim({PlayerID=1}, 1)
assert(publishedRules.host_id == -1, "claim accepted while a player was loading")
connection[0] = nil
HostOptions:PublishRules()
assert(publishedRules.ready == 1 and publishedRules.host_id == -1, "host picked automatically")
connection[0] = DOTA_CONNECTION_STATE_NOT_YET_CONNECTED
HostOptions:PublishRules()
assert(publishedRules.ready == 1, "open settings closed again")
connection[0] = nil
claim({PlayerID=0}, 1)
fake[0] = true
claim({PlayerID=0}, 0)
fake[0] = nil
assert(publishedRules.host_id == -1, "forged or bot claim accepted")
claim({PlayerID=0}, 0)
assert(publishedRules.host_id == 0 and HostOptions.host == players[1], "first claim did not win")
claim({PlayerID=1}, 1)
assert(publishedRules.host_id == 0, "host taken from another player")
local edits = listeners["HostOptions:set_option_state"]
edits({PlayerID=1, name="kill_goal", state=70}, 1)
edits({PlayerID=0, name="kill_goal", state=70}, 1)
assert(HostOptions.options.kill_goal == 50, "non-host or forged edit accepted")
edits({PlayerID=0, name="kill_goal", state=60}, 0)
assert(HostOptions.options.kill_goal == 60)
-- A host who leaves before starting frees the role for anyone; returning does not restore it.
connection[0] = DOTA_CONNECTION_STATE_DISCONNECTED
HostOptions:PublishRules()
assert(publishedRules.host_id == -1, "departed host kept the role")
claim({PlayerID=1}, 1)
assert(publishedRules.host_id == 1, "role not claimable after the host left")
connection[0] = nil
HostOptions:PublishRules()
assert(publishedRules.host_id == 1 and HostOptions.options.kill_goal == 60, "returning player took host or settings reset")
local apply = listeners["HostOptions:apply_rules"]
local event = {PlayerID=0, infinite_rerolls=0, all_vision=0, invincible_wards=0, longer_wards=1, divine_rapier=0, dagon=0, single_draft=0, epic_orbs=0, turbo=0, backpack_items=0, kill_goal=60}
apply(event, 0)
assert(not HostOptions.locked, "non-host started match")
event.PlayerID = 1
apply(event, 0)
assert(not HostOptions.locked, "forged host started match")
apply(event, 1)
assert(HostOptions.locked, "host could not start match")
connection[1] = DOTA_CONNECTION_STATE_DISCONNECTED
claim({PlayerID=0}, 0)
assert(HostOptions.host_id == 1, "host changed after the rules locked")
connection[1] = nil
-- A player who never finishes loading cannot keep the settings closed.
HostOptions:Init()
connection[1] = DOTA_CONNECTION_STATE_NOT_YET_CONNECTED
fallback = nil
HostOptions:WatchLoading()
assert(fallback and fallback.useGameTime == false and fallback.endTime == 120)
HostOptions:PublishRules()
assert(publishedRules.ready == 0)
fallback.callback()
assert(publishedRules.ready == 1, "stuck loader kept the settings closed")
assert(HostOptions:ClaimHost(0))
connection[1] = nil
HostOptions:Init()
HostOptions:PublishRules()
assert(publishedRules.host_id == -1, "script reload must clear the host")
-- Other maps keep native host privileges and have no claims.
map = "ot3_gardens_duo"
assert(not IsEpicOnlyMap() and not IsSingleDraftMap() and not IsFlatRerollMap())
assert(HostOptions:ResolveHost() == players[2], "other maps must keep native host privileges")
assert(not HostOptions:ClaimHost(0), "claims accepted on another map")
dofile("tools/epic_only/test_turbo.lua")
output("PASS host rules: all eight combinations, Epic-linked rerolls, host authorization, migration, validation, locking and one-time start")
