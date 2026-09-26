-- Uses the production rule predicate and filters, with engine events simulated.
local saved_map, saved_state = GetMapName, GameRules.State_Get
local map, phase = "ot3_necropolis_ffa", 7
GetMapName = function() return map end
GameRules.State_Get = function() return phase end
DOTA_GAMERULES_STATE_PRE_GAME = 6
local reasons = {"Unspecified", "Death", "Buyback", "PurchaseConsumable", "PurchaseItem",
    "AbandonedRedistribute", "SellItem", "AbilityCost", "CheatCommand", "SelectionPenalty",
    "GameTick", "Building", "HeroKill", "CreepKill", "RoshanKill", "CourierKill", "SharedGold"}
for id, name in ipairs(reasons) do _G["DOTA_ModifyGold_" .. name] = id - 1 end
dofile("scripts/vscripts/filters/gold.lua")
dofile("scripts/vscripts/filters/experience.lua")
local function gold(amount, reason, expected)
    local event = {gold=amount, player_id_const=0, reason_const=_G["DOTA_ModifyGold_" .. reason]}
    assert(Filters:ModifyGoldFilter(event))
    assert(event.gold == expected, reason .. ": wrong gold amount " .. event.gold)
end
local function xp(amount, expected)
    local event = {experience=amount, player_id_const=0}
    assert(Filters:FilterModifyExperience(event))
    assert(event.experience == expected, "wrong XP amount")
end
HostOptions.locked = true
for _, enabled in ipairs({false, true}) do
    HostOptions.options.turbo = enabled
    local multiplier = enabled and 2 or 1
    for _, reason in ipairs({"Unspecified", "GameTick", "Building", "HeroKill", "CreepKill", "RoshanKill", "CourierKill", "SharedGold"}) do
        gold(101, reason, 101 * multiplier)
        gold(-101, reason, -101)
        gold(0, reason, 0)
    end
    for _, reason in ipairs({"SellItem", "PurchaseItem", "PurchaseConsumable", "AbandonedRedistribute", "AbilityCost", "Buyback", "SelectionPenalty", "CheatCommand"}) do
        gold(101, reason, 101)
    end
    xp(101, 101 * multiplier)
    xp(0, 0)
    xp(-101, -101)
end
phase = 3 -- starting gold during hero selection
gold(700, "Unspecified", 700)
phase = 6 -- pregame earnings
gold(100, "HeroKill", 200)
xp(100, 200)
HostOptions.locked = false
gold(100, "GameTick", 100)
xp(100, 100)
HostOptions.locked = true
map = "ot3_gardens_duo"
gold(100, "GameTick", 100)
xp(100, 100)
map, phase = "ot3_necropolis_ffa", DOTA_GAMERULES_STATE_PRE_GAME
local original_hero_class, original_player_class = CDOTA_BaseNPC_Hero, CDOTA_PlayerResource
local balance, experience, native_filters, fail = 0, 0, false, false
CDOTA_PlayerResource = {ModifyGold = function(_, id, amount, reliable, reason)
    if fail then error("simulated native failure") end
    local event = {gold=amount, reason_const=reason}
    if native_filters then assert(Filters:ModifyGoldFilter(event)) end
    balance = balance + event.gold
    return event.gold
end}
CDOTA_BaseNPC_Hero = {
    ModifyGold = function(_, amount, reliable, reason)
        return CDOTA_PlayerResource:ModifyGold(0, amount, reliable, reason)
    end,
    AddExperience = function(_, amount)
        local event = {experience=amount}
        if native_filters then assert(Filters:FilterModifyExperience(event)) end
        experience = experience + event.experience
        return true
    end,
}
dofile("scripts/vscripts/game/turbo_rewards.lua")
for _, enabled in ipairs({false, true}) do
    HostOptions.options.turbo = enabled
    for _, callback in ipairs({false, true}) do
        native_filters = callback
        balance, experience = 0, 0
        local multiplier = enabled and 2 or 1
        assert(CDOTA_BaseNPC_Hero:ModifyGold(101, false, DOTA_ModifyGold_GameTick) == 101 * multiplier)
        assert(balance == 101 * multiplier, "nested hero/player call scaled twice")
        CDOTA_PlayerResource:ModifyGold(0,101,true,DOTA_ModifyGold_Unspecified)
        assert(balance == 202 * multiplier)
        assert(CDOTA_BaseNPC_Hero:AddExperience(101,0,false,true))
        assert(experience == 101 * multiplier, "engine callback scaled XP twice")
        CDOTA_BaseNPC_Hero:ModifyGold(101,false,DOTA_ModifyGold_PurchaseItem)
        assert(balance == 202 * multiplier + 101, "script refund scaled")
    end
end
fail = true
assert(not pcall(function() CDOTA_BaseNPC_Hero:ModifyGold(10,false,0) end))
assert(not TurboRewards.gold, "suppression flag leaked after native error")
CDOTA_BaseNPC_Hero, CDOTA_PlayerResource = original_hero_class, original_player_class
GetMapName, GameRules.State_Get = saved_map, saved_state
io.write("PASS Turbo: native/script grants doubled once, nested callbacks guarded; starting gold, spending, sales, refunds, transfers and other maps unchanged\n")
