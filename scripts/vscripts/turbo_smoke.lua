-- Local tools-mode check. Run in setup, then again after selecting a hero.
assert(IsInToolsMode() and UsesHostRules(), "Turbo smoke requires local FFA tools mode")
if GameRules:State_Get() == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
	-- Tools mode normally injects 99,999 demo gold and ends pregame after 5s.
	-- Disable that test-only interference so real starting gold can be checked.
	for id, callback in pairs(EventDriver.serverside_events["Events:npc_spawned"] or {}) do
		if callback[1] == OT3Demo.OnNPCSpawned then EventDriver:CancelListener("Events:npc_spawned", id) end
	end
	GameRules:SetPreGameTime(300)
	PlayerDC.CheckEndGame = function() end -- keep the single-player test alive
	assert(HostOptions:ApplyRules({PlayerID=0, infinite_rerolls=0, all_vision=0, invincible_wards=0, longer_wards=1, divine_rapier=0, dagon=0, epic_orbs=0, single_draft=0, turbo=1, backpack_items=0, kill_goal=30}))
	print("TURBO_SMOKE_SETUP_PASS")
	return
end
assert(IsTurboMode(), "Turbo was not applied")
local hero = PlayerResource:GetSelectedHeroEntity(0)
assert(IsValidEntity(hero), "Select a hero first")
assert(GameRules:State_Get() == DOTA_GAMERULES_STATE_PRE_GAME, "Run during the extended pregame")
if GameRules:State_Get() == DOTA_GAMERULES_STATE_PRE_GAME then
	assert(hero:GetGold() == 700, "Starting gold changed: " .. hero:GetGold())
	print("TURBO_SMOKE_STARTING_GOLD_PASS 700")
end
local function gold(reason, expected)
	local before = hero:GetGold()
	hero:ModifyGold(101, false, reason)
	assert(hero:GetGold() - before == expected, "Gold reason " .. reason .. " changed by " .. (hero:GetGold() - before))
end
for _, reason in ipairs({DOTA_ModifyGold_GameTick, DOTA_ModifyGold_HeroKill, DOTA_ModifyGold_CreepKill, DOTA_ModifyGold_Unspecified}) do gold(reason, 202) end
for _, reason in ipairs({DOTA_ModifyGold_SellItem, DOTA_ModifyGold_PurchaseItem, DOTA_ModifyGold_AbandonedRedistribute}) do gold(reason, 101) end
local before_gold = hero:GetGold()
PlayerResource:ModifyGold(0,101,true,DOTA_ModifyGold_Unspecified)
assert(hero:GetGold() == before_gold + 202, "PlayerResource grant did not double")
before_gold = hero:GetGold()
hero:ModifyGold(-101, false, DOTA_ModifyGold_PurchaseItem)
assert(hero:GetGold() == before_gold - 101, "Spending doubled")
local item = CreateItem("item_branches", hero, hero)
local cost = item:GetCost()
before_gold = hero:GetGold()
hero:RefundItem(item)
assert(hero:GetGold() == before_gold + cost, "Custom refund doubled")
local before_xp = hero:GetCurrentXP()
hero:AddExperience(101, DOTA_ModifyXP_Unspecified, false, true)
assert(hero:GetCurrentXP() - before_xp == 202, "XP did not double exactly once")
print("TURBO_SMOKE_PASS actual engine gold/XP filters, spending, refund, sale and redistribution")
local creep = CreateUnitByName("npc_dota_neutral_kobold", hero:GetAbsOrigin() + Vector(160,0,0), true, nil, nil, DOTA_TEAM_NEUTRALS)
creep:SetMinimumGoldBounty(101)
creep:SetMaximumGoldBounty(101)
creep:SetDeathXP(101)
local kill_gold, kill_xp = hero:GetGold(), hero:GetCurrentXP()
ApplyDamage({victim=creep, attacker=hero, damage=100000, damage_type=DAMAGE_TYPE_PURE})
Timers:CreateTimer(0.3, function()
	assert(hero:GetGold() - kill_gold == 202, "Native creep gold did not double: " .. (hero:GetGold() - kill_gold))
	assert(hero:GetCurrentXP() - kill_xp == 202, "Native creep XP did not double: " .. (hero:GetCurrentXP() - kill_xp))
	print("TURBO_SMOKE_NATIVE_KILL_PASS gold=202 xp=202")
end)
