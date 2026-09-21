-- Manual Tools-mode check: script_reload_code epic_only_smoke
-- Run in a disposable test session after addon initialization.
assert(IsInToolsMode(), "The epic-only smoke check requires Tools mode")
assert(GetBaseMapName() == "ot3_necropolis_ffa", "Load an FFA map first")
assert(GameLoop.current_layout == TEAMS_LAYOUTS[GetMapName()], "Wrong map layout")
assert(#GameLoop.current_layout.teamlist == 8, "Expected eight FFA teams")
assert(GameMode.do_double_orb_drops, "FFA paired drops are disabled")
assert(Entities:FindByName(nil, "@overboss"), "Missing Necropolis world entities")

local epic_only = IsEpicOnlyMap()
local captures = {}
local ok, failure = pcall(function()
	for _, source in ipairs({UPGRADE_RARITY_COMMON, UPGRADE_RARITY_RARE, UPGRADE_RARITY_EPIC}) do
		local expected = epic_only and UPGRADE_RARITY_EPIC or source
		assert(ResolveOrbRarity(source) == expected, "Incorrect rarity policy")
		local capture = GameMode:SpawnOrbDrop(Vector(600, 0, 128), source, false)
		table.insert(captures, capture)
		local modifier = capture:FindModifierByName("capture_point_area")
		assert(modifier and modifier.orb_type == expected, "Incorrect physical orb rarity")
		assert(modifier.source_orb_type == source, "Original orb source was lost")
	end
end)
for _, capture in ipairs(captures) do
	if IsValidEntity(capture) then UTIL_Remove(capture) end
end
assert(ok, failure)
print("EPIC_ONLY_SMOKE PASS map=" .. GetMapName() .. " paired_drops=true sources=3")

-- Exercise the real selection renderer once a hero is available. These rewards
-- are intentionally left queued in this disposable Tools-mode test session.
local hero = PlayerResource:GetSelectedHeroEntity(0)
if IsValidEntity(hero) and hero.upgrades then
	for _, source in ipairs({UPGRADE_RARITY_COMMON, UPGRADE_RARITY_RARE, UPGRADE_RARITY_EPIC}) do
		Upgrades:QueueSelection(hero, source)
		local queue = Upgrades.queued_selection[0]
		assert(queue and queue[#queue].rarity == (epic_only and UPGRADE_RARITY_EPIC or source),
			"Incorrect queued reward rarity")
	end
	print("EPIC_ONLY_REWARDS PASS map=" .. GetMapName() .. " hero=" .. hero:GetUnitName())
else
	print("EPIC_ONLY_REWARDS WAIT select a hero and run this check again")
end
