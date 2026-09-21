-- Disposable Tools session: script_reload_code single_draft_smoke
assert(IsInToolsMode() and IsSingleDraftMap(), "Load the Single Draft map in Tools mode")
for _, rarity in ipairs({1, 2, 4}) do
	assert(ResolveOrbRarity(rarity) == (IsEpicOnlyMap() and 4 or rarity))
	assert(Upgrades:GetRerollPrice(rarity) == (IsEpicOnlyMap() and 1 or rarity))
end
assert(not GameRules:IsInBanPhase(), "Unexpected ban phase")
local seen, count = {}, 0
for player_id, offers in pairs(SingleDraft.offers) do
	assert(#offers == 4)
	for index, hero in ipairs(offers) do
		assert(GetUnitKV(hero.name, "AttributePrimary") == SingleDraft.attributes[index])
		assert(not seen[hero.name], "Overlapping hero offers")
		seen[hero.name] = true
		print("SINGLE_DRAFT_OFFER player=" .. player_id .. " hero=" .. hero.name .. " id=" .. hero.id)
	end
	local selected = PlayerResource:GetSelectedHeroName(player_id)
	if selected and selected ~= "" then
		local legal = false
		for _, hero in ipairs(offers) do if hero.name == selected then legal = true end end
		assert(legal, "Selected a hero outside this player's offers")
	end
	print("SINGLE_DRAFT_SELECTED player=" .. player_id .. " hero=" .. tostring(selected))
	count = count + 1
end
assert(count > 0, "No player offers")
print("SINGLE_DRAFT_SMOKE PASS players=" .. count .. " state=" .. GameRules:State_Get())
