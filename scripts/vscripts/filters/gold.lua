function Filters:ModifyGoldFilter(event)
	if TurboRewards and TurboRewards.gold then return true end
	-- Starting gold and selection/setup adjustments are not earned income.
	if not IsTurboMode() or GameRules:State_Get() < DOTA_GAMERULES_STATE_PRE_GAME then return true end
	if not event.gold or event.gold <= 0 then return true end
	local reason = event.reason_const
	-- Positive refunds and transfers must not create extra gold.
	if reason == DOTA_ModifyGold_SellItem
		or reason == DOTA_ModifyGold_PurchaseItem
		or reason == DOTA_ModifyGold_PurchaseConsumable
		or reason == DOTA_ModifyGold_AbandonedRedistribute
		or reason == DOTA_ModifyGold_AbilityCost
		or reason == DOTA_ModifyGold_Buyback
		or reason == DOTA_ModifyGold_SelectionPenalty
		or reason == DOTA_ModifyGold_CheatCommand then return true end
	event.gold = event.gold * 2
	return true
end
