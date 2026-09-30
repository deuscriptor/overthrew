-- Disposable tools game only. Run after the map finishes loading.
assert(IsInToolsMode())
local mode = GameRules:GetGameModeEntity()
mode:SetFogOfWarDisabled(true)
local target = CreateUnitByName("npc_dota_hero_axe", Vector(4000, 4000, 128), true, nil, nil, DOTA_TEAM_BADGUYS)
local viewers = {}
for _, team in ipairs(TEAMS_LAYOUTS[GetMapName()].teamlist) do
	if team ~= DOTA_TEAM_BADGUYS then
		table.insert(viewers, CreateUnitByName("npc_dota_hero_axe", Vector(-4000, -4000, 128), true, nil, nil, team))
	end
end
Timers:CreateTimer(1, function()
	for _, viewer in ipairs(viewers) do
		assert(viewer:CanEntityBeSeenByMyTeam(target), "All Vision did not reveal distant enemy")
	end
	target:AddNewModifier(target, nil, "modifier_invisible", {})
	Timers:CreateTimer(1, function()
		assert(target:IsInvisible())
		for _, viewer in ipairs(viewers) do
			assert(not viewer:CanEntityBeSeenByMyTeam(target), "All Vision revealed invisible enemy")
		end
		print("ALL_VISION_PASS distant enemy visible to all opposing teams; invisible enemy hidden")
		UTIL_Remove(target)
		for _, viewer in ipairs(viewers) do UTIL_Remove(viewer) end
		mode:SetFogOfWarDisabled(HostOptions.locked and HostOptions:GetOption("all_vision"))
	end)
end)
