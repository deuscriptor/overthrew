-- Run after test_orbs.lua, reusing the engine-free production module harness.
dofile("scripts/vscripts/game/single_draft.lua")
dofile("scripts/vscripts/libraries/smart_random.lua")
local report = io.write
local attributes = SingleDraft.attributes
local enabled, metadata, players, availability = {}, {}, {}, {}
local state, filtered, ban_time, bans = 2, false, nil, nil
local callback
local function equal(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
for a, attribute in ipairs(attributes) do
    for i = 1, 10 do
        local name = "npc_dota_hero_test_" .. a .. "_" .. i
        enabled[name] = "1"
        metadata[name] = { AttributePrimary = attribute, id = a * 100 + i }
    end
end
enabled.npc_dota_hero_disabled = "0"
metadata.npc_dota_hero_disabled = { AttributePrimary = attributes[1], id = 999 }
enabled.npc_dota_hero_invalid = "1"
metadata.npc_dota_hero_invalid = { AttributePrimary = "bad", id = 998 }
LoadKeyValues = function() return enabled end
GetUnitKV = function(name, key) return metadata[name][key] end
DOTAGameManager = { GetHeroIDByName = function(_, name) return metadata[name].id end }
RandomInt = function(low, high) return high end
DOTA_MAX_TEAM_PLAYERS = 24
DOTA_GAMERULES_STATE_HERO_SELECTION = 3
local mode = {
    SetPlayerHeroAvailabilityFiltered = function(_, value) filtered = value end,
    SetDraftingBanningTimeOverride = function(_, value) ban_time = value end,
    SetContextThink = function(_, name, fn) callback = fn end,
}
GameRules.GetGameModeEntity = function() return mode end
GameRules.State_Get = function() return state end
GameRules.SetCustomGameBansPerTeam = function(_, value) bans = value end
GameRules.ClearPlayerHeroAvailability = function(_, id) availability[id] = {} end
GameRules.AddHeroToPlayerAvailability = function(_, id, hero) table.insert(availability[id], hero) end
PlayerResource.IsValidPlayerID = function(_, id) return players[id] ~= nil end
PlayerResource.GetTeam = function(_, id) return players[id].team end
PlayerResource.GetPlayer = function(_, id) return players[id] end
PlayerResource.HasSelectedHero = function(_, id) return players[id].selected ~= nil end
PlayerResource.SetHasRandomed = function(_, id) players[id].randomed = true end
for id = 0, 8 do
    players[id] = { team = id == 8 and 1 or TEAMS_LAYOUTS.ot3_necropolis_ffa.teamlist[id + 1] }
    players[id].SetSelectedHero = function(self, name) self.selected = name end
end

GetMapName = function() return EPIC_ONLY_MAP_NAME end
SingleDraft:Init()
equal(filtered, false)
GetMapName = function() return EPIC_ONLY_SINGLE_DRAFT_MAP_NAME end
GameLoop.current_layout = TEAMS_LAYOUTS[GetMapName()]
equal(GetBaseMapName(), "ot3_necropolis_ffa")
equal(IsEpicOnlyMap(), true)
equal(Upgrades:GetRerollPrice(4), 1)
for _, rarity in ipairs({1, 2, 4}) do equal(ResolveOrbRarity(rarity), 4) end
SingleDraft:Init()
equal(filtered, true)
equal(bans, 0)
equal(ban_time, 0)
equal(SingleDraft.offers[8], nil) -- spectator
local seen = {}
for id = 0, 7 do
    local offers = SingleDraft.offers[id]
    equal(#offers, 4)
    equal(#availability[id], 4)
    for index, hero in ipairs(offers) do
        equal(metadata[hero.name].AttributePrimary, attributes[index])
        assert(not seen[hero.name], "overlapping offers")
        seen[hero.name] = true
        equal(availability[id][index], hero.id)
    end
    equal(SingleDraft:PreparePlayer(id), offers) -- reconnect preserves offers
end
equal(callback(), 0.25)
state = 3
for id = 0, 7 do
    if id % 2 == 0 then GameLoop:PickRandomHero(id)
    else SmartRandom:PickRandomHero({ PlayerID = id }) end
    equal(players[id].selected, SingleDraft.offers[id][4].name)
    equal(players[id].randomed, true)
    SingleDraft:PickRandomHero(id) -- cannot change a locked pick
    equal(players[id].selected, SingleDraft.offers[id][4].name)
end
SingleDraft:PickRandomHero(8) -- spectator cannot random
SingleDraft:PickRandomHero(99)
equal(players[8].selected, nil)
state = 4
players[0].selected = nil
SingleDraft:PickRandomHero(0)
equal(players[0].selected, nil)
equal(callback(), nil)
report("PASS Single Draft: four attributes, 32 distinct offers, native availability, no bans, reconnects, spectators, both random routes, map inheritance\n")
