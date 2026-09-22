local output = print
dofile("tools/epic_only/test_orbs.lua")
local map = "ot3_necropolis_ffa"
GetMapName = function() return map end
DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP = 2
local state = DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP
local host = 0
local finished, initialized, bans = 0, 0, nil
local players = {{id = 0}, {id = 1}}
PlayerResource.IsValidPlayerID = function(_, id) return id == 0 or id == 1 end
PlayerResource.GetPlayer = function(_, id) return players[id + 1] end
IsValidEntity = function(p) return p ~= nil end
GameRules.State_Get = function() return state end
GameRules.PlayerHasCustomGameHostPrivileges = function(_, p) return p.id == host end
GameRules.SetCustomGameBansPerTeam = function(_, n) bans = n end
GameRules.FinishCustomGameSetup = function() finished = finished + 1 end
EventStream = {Listen = function() end}
EventDriver = {Listen = function() end}
CustomNetTables = {SetTableValue = function() end}
SingleDraft.Init = function() if IsSingleDraftMap() then initialized = initialized + 1 end end
dofile("scripts/vscripts/libraries/host_options.lua")
for draft = 0, 1 do for epic = 0, 1 do for turbo = 0, 1 do
    HostOptions:Init()
    assert(not HostOptions:GetOption("turbo"), "Turbo must default off")
    local event = {PlayerID = 1, single_draft = draft, epic_orbs = epic, turbo = turbo}
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
    for _, rarity in ipairs({1, 2, 4}) do
        assert(ResolveOrbRarity(rarity) == (epic == 1 and 4 or rarity))
        assert(Upgrades:GetRerollPrice(rarity) == (epic == 1 and 1 or rarity))
    end
    assert(not HostOptions:ApplyRules(event), "duplicate start accepted")
    HostOptions:SetOptionState("epic_orbs", epic == 0)
    assert(IsEpicOnlyMap() == (epic == 1), "locked rule changed")
end end end
assert(initialized == 4)
HostOptions:Init()
host = 1
assert(not HostOptions:ApplyRules({PlayerID=0, single_draft=0, epic_orbs=0, turbo=0}))
assert(HostOptions:ApplyRules({PlayerID=1, single_draft=0, epic_orbs=0, turbo=0}))
HostOptions:Init()
state = DOTA_GAMERULES_STATE_HERO_SELECTION
assert(not HostOptions:ApplyRules({PlayerID=1, single_draft=1, epic_orbs=1, turbo=1}))
map = "ot3_gardens_duo"
assert(not IsEpicOnlyMap() and not IsSingleDraftMap() and not IsFlatRerollMap())
dofile("tools/epic_only/test_turbo.lua")
output("PASS host rules: all eight combinations, Epic-linked rerolls, host authorization, migration, validation, locking and one-time start")
