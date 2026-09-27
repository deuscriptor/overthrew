local output = print
dofile("tools/epic_only/test_orbs.lua")
local map = "ot3_necropolis_ffa"
GetMapName = function() return map end
DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP = 2
local state = DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP
local host = 0
local finished, initialized, bans = 0, 0, nil
local fogDisabled
GameRules.GetGameModeEntity = function() return {
    SetFogOfWarDisabled = function(_, value) fogDisabled = value end,
} end
local players = {{id = 0}, {id = 1}}
for _, player in ipairs(players) do player.GetPlayerID = function(self) return self.id end end
local dedicated = true
IsDedicatedServer = function() return dedicated end
-- Connection-order signals must not decide the host.
GetListenServerHost = function() return {GetController = function() return players[1] end} end
local convars, commands, commandClient = {}, {}, nil
Convars = {
    GetStr = function(_, name) return convars[name] end,
    RegisterConvar = function(_, name, value) convars[name] = value end,
    SetInt = function(_, name, value) convars[name] = tostring(value) end,
    RegisterCommand = function(_, name, callback) commands[name] = callback end,
    GetCommandClient = function() return commandClient end,
}
RandomInt = function() return 123456 end
local fallback
Timers = {CreateTimer = function(_, args) fallback = args end}
PlayerResource.IsValidPlayerID = function(_, id) return id == 0 or id == 1 end
PlayerResource.GetPlayer = function(_, id) return players[id + 1] end
IsValidEntity = function(p) return p ~= nil end
GameRules.State_Get = function() return state end
GameRules.PlayerHasCustomGameHostPrivileges = function(_, p) return p.id == host end
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
IsClient = function() return false end
dofile("scripts/vscripts/libraries/host_claim.lua")
dofile("scripts/vscripts/libraries/host_options.lua")
GameLoop.current_layout = TEAMS_LAYOUTS.ot3_necropolis_ffa
for draft = 0, 1 do for epic = 0, 1 do for turbo = 0, 1 do
    HostOptions:Init()
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
    assert(HostOptions:ApplyRules({PlayerID=0, single_draft=0, epic_orbs=0, turbo=0, backpack_items=0, kill_goal=goal,
        infinite_rerolls=0, all_vision=0, invincible_wards=0, longer_wards=1, divine_rapier=0, dagon=0}))
    assert(GameLoop.current_layout.game_base_duration == DEFAULT_MATCH_LENGTH * (goal / 30))
    assert(publishedGoal.goal == goal and publishedGoal.limit == GameLoop.current_layout.game_base_duration,
        "HUD and server must receive the same scaled limit")
end
for _, name in ipairs({"backpack_items", "infinite_rerolls", "all_vision", "invincible_wards", "longer_wards", "divine_rapier", "dagon"}) do
    HostOptions:Init()
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
HostOptions:Init()
host = 1
assert(not HostOptions:ApplyRules({PlayerID=0, infinite_rerolls=0, all_vision=0, invincible_wards=0, longer_wards=1, divine_rapier=0, dagon=0, single_draft=0, epic_orbs=0, turbo=0, backpack_items=0, kill_goal=30}))
for _, invalid in ipairs({0, -1, 1.5, "30", false, math.huge, 2147483648}) do
    assert(not HostOptions:ApplyRules({PlayerID=1, infinite_rerolls=0, all_vision=0, invincible_wards=0, longer_wards=1, divine_rapier=0, dagon=0, single_draft=0, epic_orbs=0, turbo=0, backpack_items=0, kill_goal=invalid}))
    HostOptions:SetOptionState("kill_goal", invalid)
    assert(HostOptions.options.kill_goal == 50)
end
assert(HostOptions:ApplyRules({PlayerID=1, infinite_rerolls=0, all_vision=0, invincible_wards=0, longer_wards=1, divine_rapier=0, dagon=0, single_draft=0, epic_orbs=0, turbo=0, backpack_items=0, kill_goal=30}))
HostOptions:Init()
state = DOTA_GAMERULES_STATE_HERO_SELECTION
assert(not HostOptions:ApplyRules({PlayerID=1, infinite_rerolls=0, all_vision=0, invincible_wards=0, longer_wards=1, divine_rapier=0, dagon=0, single_draft=1, epic_orbs=1, turbo=1, backpack_items=0, kill_goal=30}))
-- First loader owns native privileges and the listen-server slot, but only the client
-- that reads the server's convar token (the Local Host lobby owner) may edit/start.
state = DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP
-- Valve servers have no game client in the process: native privileges, no waiting.
HostOptions:Init()
HostOptions:PublishRules()
assert(HostOptions.claim_token == nil and publishedRules.host_id == host, "server without a local client must not wait for a claim")
-- Local Host lobbies can report a dedicated server; the in-process client is what counts.
dedicated, host = true, 0
convars.dota_camera_distance = "1200"
HostOptions:Init()
assert(convars[HOST_CLAIM_CONVAR] == "123456", "claim token must be published in a server convar")
HostOptions:PublishRules()
assert(publishedRules.host_id == -1, "must wait for local owner, not fall back to first loader")
assert(not HostOptions:IsHost(players[1]))
-- The engine attributes the claim command to the issuing client's pawn.
local function claim(id, token)
    commandClient = {GetController = function() return players[id + 1] end}
    commands[HOST_CLAIM_COMMAND](HOST_CLAIM_COMMAND, tostring(token))
end
claim(0, 1)
commandClient = nil
commands[HOST_CLAIM_COMMAND](HOST_CLAIM_COMMAND, "123456")
assert(publishedRules.host_id == -1, "wrong or unattributed claim accepted")
claim(1, 123456)
assert(publishedRules.host_id == 1 and HostOptions.host == players[2])
claim(0, 123456)
assert(publishedRules.host_id == 1, "owner claim must survive later failed claims")
HostOptions:Init()
HostOptions:PublishRules()
assert(publishedRules.host_id == 1, "script reload lost the owner claim")
local edits = listeners["HostOptions:set_option_state"]
edits({PlayerID=0, name="kill_goal", state=70}, 0)
edits({PlayerID=1, name="kill_goal", state=70}, 0)
assert(HostOptions.options.kill_goal == 50, "non-owner or forged edit accepted")
edits({PlayerID=1, name="kill_goal", state=60}, 1)
assert(HostOptions.options.kill_goal == 60)
local apply = listeners["HostOptions:apply_rules"]
local event = {PlayerID=0, infinite_rerolls=0, all_vision=0, invincible_wards=0, longer_wards=1, divine_rapier=0, dagon=0, single_draft=0, epic_orbs=0, turbo=0, backpack_items=0, kill_goal=60}
apply(event, 0)
assert(not HostOptions.locked, "first loader started match")
event.PlayerID = 1
apply(event, 0)
assert(not HostOptions.locked, "forged owner started match")
apply(event, 1)
assert(HostOptions.locked, "actual local owner could not start match")
local owner = players[2]
players[2] = nil
HostOptions:PublishRules()
assert(publishedRules.host_id == -1 and HostOptions.host == nil, "stale owner retained")
players[2] = owner
-- Guessing is capped per player.
HostOptions.claim_token = nil
HostOptions:Init()
for token = 1, 5 do claim(0, token) end
claim(0, 123456)
HostOptions:PublishRules()
assert(publishedRules.host_id == -1, "claim accepted after repeated wrong tokens")
-- Without any claim, setup falls back to native privileges instead of stalling, but only
-- after everyone has loaded: a still-loading owner must not lose host to the first loader.
local now, connection = 0, {}
Time = function() return now end
DOTA_CONNECTION_STATE_NOT_YET_CONNECTED = DOTA_CONNECTION_STATE_NOT_YET_CONNECTED or 1
PlayerResource.GetConnectionState = function(_, id) return connection[id] or 2 end
HostOptions.claim_token = nil
HostOptions:Init()
fallback = nil
connection[1] = DOTA_CONNECTION_STATE_NOT_YET_CONNECTED
HostOptions:ScheduleClaimFallback()
assert(fallback and fallback.useGameTime == false)
now = 10
assert(fallback.callback() == 1, "fell back while a player was still loading")
connection[1] = nil
assert(fallback.callback() == 1)
now = 39
assert(fallback.callback() == 1)
HostOptions:PublishRules()
assert(publishedRules.host_id == -1)
now = 40
assert(fallback.callback() == nil)
HostOptions:PublishRules()
assert(publishedRules.host_id == 0, "fallback must use native host privileges")
claim(1, 123456)
assert(publishedRules.host_id == 1, "late owner claim must replace the fallback host")
-- A player stuck loading cannot stall setup forever.
HostOptions.claim_token = nil
HostOptions:Init()
now = 0
connection[1] = DOTA_CONNECTION_STATE_NOT_YET_CONNECTED
HostOptions:ScheduleClaimFallback()
now = 119
assert(fallback.callback() == 1)
now = 120
assert(fallback.callback() == nil)
HostOptions:PublishRules()
assert(publishedRules.host_id == 0, "stuck loader stalled the fallback")
connection[1] = nil
dedicated = true
map = "ot3_gardens_duo"
assert(not IsEpicOnlyMap() and not IsSingleDraftMap() and not IsFlatRerollMap())
-- Client VM: only a client that can read the server's token convar sends the claim.
local sent, stateListener = {}, nil
IsClient = function() return true end
-- The real client VM lacks the DOTA_GAMERULES_STATE_* constants.
local setupState = DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP
DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP = nil
SendToConsole = function(command) table.insert(sent, command) end
ListenToGameEvent = function(name, callback) if name == "game_rules_state_change" then stateListener = callback end end
convars[HOST_CLAIM_CONVAR] = nil
state = setupState
dofile("scripts/vscripts/libraries/host_claim.lua")
assert(#sent == 0, "remote clients cannot read the server token")
convars[HOST_CLAIM_CONVAR] = "0"
stateListener()
assert(#sent == 0, "unset token claimed")
convars[HOST_CLAIM_CONVAR] = "123456"
state = setupState + 1
stateListener()
assert(#sent == 0, "claim sent outside setup")
state = setupState
stateListener()
assert(sent[1] == HOST_CLAIM_COMMAND .. " 123456", "setup did not trigger the claim")
dofile("scripts/vscripts/libraries/host_claim.lua")
assert(sent[2] == HOST_CLAIM_COMMAND .. " 123456", "client VM loaded during setup did not claim")
DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP = setupState
IsClient = function() return false end
dofile("tools/epic_only/test_turbo.lua")
output("PASS host rules: all eight combinations, Epic-linked rerolls, host authorization, migration, validation, locking and one-time start")
