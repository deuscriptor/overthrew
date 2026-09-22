local output = print
dofile("tools/epic_only/test_orbs.lua")
local map = "ot3_necropolis_ffa"
GetMapName = function() return map end
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
for draft = 0, 1 do for epic = 0, 1 do for flat = 0, 1 do
    HostOptions:Init()
    local event = {PlayerID = 1, single_draft = draft, epic_orbs = epic, flat_rerolls = flat}
    assert(not HostOptions:ApplyRules(event), "non-host accepted")
    event.PlayerID = 0
    event.flat_rerolls = "true"
    assert(not HostOptions:ApplyRules(event), "invalid value accepted")
    event.flat_rerolls = flat
    local before = finished
    assert(HostOptions:ApplyRules(event))
    assert(finished == before + 1)
    assert(bans == (draft == 1 and 0 or 1))
    assert(IsSingleDraftMap() == (draft == 1))
    for _, rarity in ipairs({1, 2, 4}) do
        assert(ResolveOrbRarity(rarity) == (epic == 1 and 4 or rarity))
        assert(Upgrades:GetRerollPrice(rarity) == (flat == 1 and 1 or rarity))
    end
    assert(not HostOptions:ApplyRules(event), "duplicate start accepted")
    HostOptions:SetOptionState("epic_orbs", epic == 0)
    assert(IsEpicOnlyMap() == (epic == 1), "locked rule changed")
end end end
assert(initialized == 4)
HostOptions:Init()
host = 1
assert(not HostOptions:ApplyRules({PlayerID=0, single_draft=0, epic_orbs=0, flat_rerolls=0}))
assert(HostOptions:ApplyRules({PlayerID=1, single_draft=0, epic_orbs=0, flat_rerolls=0}))
HostOptions:Init()
state = DOTA_GAMERULES_STATE_HERO_SELECTION
assert(not HostOptions:ApplyRules({PlayerID=1, single_draft=1, epic_orbs=1, flat_rerolls=1}))
map = "ot3_gardens_duo"
assert(not IsEpicOnlyMap() and not IsSingleDraftMap() and not IsFlatRerollMap())
output("PASS host rules: all eight combinations, host authorization, migration, validation, locking and one-time start")
