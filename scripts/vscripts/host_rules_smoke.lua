assert(IsInToolsMode() and UsesHostRules())
print("HOST_RULES_STATE", GameRules:State_Get(), HostOptions.locked)
DeepPrintTable(CustomNetTables:GetTableValue("game_options", "match_rules") or {})
if HostOptions.locked then
	local rules = CustomNetTables:GetTableValue("game_options", "match_rules")
	assert(IsSingleDraftMap() == (rules.single_draft == 1))
	assert(IsEpicOnlyMap() == (rules.epic_orbs == 1))
	assert(IsFlatRerollMap() == (rules.epic_orbs == 1))
	for _, rarity in ipairs({1, 2, 4}) do
		assert(ResolveOrbRarity(rarity) == (IsEpicOnlyMap() and 4 or rarity))
		assert(Upgrades:GetRerollPrice(rarity) == (IsFlatRerollMap() and 1 or rarity))
	end
	if IsSingleDraftMap() then
		assert(#SingleDraft.offers[0] == 4)
		print("HOST_RULES_PASS four native Single Draft offers")
	end
	print("HOST_RULES_PASS locked rules, orb rewards and Epic-linked reroll price")
end
