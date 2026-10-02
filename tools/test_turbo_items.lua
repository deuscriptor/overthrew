local turbo = false
IsTurboMode = function() return turbo end
GetMapName = function() return "ot3_necropolis_ffa" end
ListenToGameEvent = function() end
local timers, stateListener, stocks = {}, nil, {}
Timers = {CreateTimer = function(_, delay, callback) table.insert(timers, {delay, callback}) end}
LoadKeyValues = function(path)
    assert(path == "scripts/npc/neutral_items.txt")
    local tiers = {}
    for tier, time in ipairs({"2:00","4:30","7:00","9:30","15:00"}) do
        tiers[tostring(tier)] = {craft_cost=tier == 1 and "6" or "10", start_time=time}
    end
    return {neutral_tiers=tiers}
end
EventDriver = {Listen = function(_, _, callback) stateListener = callback end}
DOTA_GAMERULES_STATE_HERO_SELECTION = 4
DOTA_GAMERULES_STATE_GAME_IN_PROGRESS = 7
TEAMS_LAYOUTS = {ot3_necropolis_ffa={teamlist={2,3,6,7,8,9,10,11}}}
GameRules = {SetWhiteListEnabled = function() end,
    IncreaseItemStock = function(_, team, item, count, player)
        assert(item == "item_aghanims_shard" and count == 1 and player == -1)
        stocks[team] = (stocks[team] or 0) + count
    end,
}
GetAbilityKeyValuesByName = function(name)
    assert(name == "item_aghanims_shard")
    return {ItemInitialStockTime = "120"}
end
dofile("scripts/vscripts/game/neutral_item_drop.lua")
dofile("scripts/vscripts/game/host_items.lua")
HostItems:Init()
for _, enabled in ipairs({false,true}) do
    turbo = enabled
    timers = {}
    NeutralItemDrop:Activate()
    for tier, base in ipairs({120,270,420,570,900}) do
        assert(timers[tier][1] == base + 1)
    end
    timers = {}
    stateListener({state=DOTA_GAMERULES_STATE_GAME_IN_PROGRESS})
    assert(#timers == (enabled and 1 or 0))
    if enabled then
        assert(timers[1][1] == 60)
        timers[1][2]()
        for _,team in ipairs(TEAMS_LAYOUTS.ot3_necropolis_ffa.teamlist) do assert(stocks[team] == 1) end
    end
end
print("PASS Turbo items: normal scheduled grants in both modes and early Turbo Shard stock for every team")
