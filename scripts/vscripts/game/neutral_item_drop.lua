NeutralItemDrop = NeutralItemDrop or {
	neutral_item_list = {},
	craft_costs = {},
	drop_period = {
		ot3_necropolis_ffa = {
			120,
			270,
			420,
			570,
			900,
		},
	},
}


ListenToGameEvent("game_rules_state_change",
	function()
		local new_state = GameRules:State_Get()
		if new_state == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
			NeutralItemDrop:Activate()
		end
	end,
nil)


function NeutralItemDrop:Activate()
	self.neutral_items_kv = LoadKeyValues("scripts/npc/neutral_items.txt")

	for tier, tier_content in pairs(self.neutral_items_kv.neutral_tiers) do
		for item_name, _ in pairs(tier_content.items or {}) do
			self.neutral_item_list[item_name] = tier
		end

		self.craft_costs[tonumber(tier)] = tonumber(tier_content.craft_cost)
	end

	for i = 1, 5 do
		Timers:CreateTimer(self:GetTierTime(i) + 1, function() return self:Drop(i) end)
	end
end

function NeutralItemDrop:GetTierTime(tier)
	return self.drop_period[GetMapName()][tier]
end

function NeutralItemDrop:Drop(tier)
	local madstone_count = self.craft_costs[tier]

	for team = DOTA_TEAM_FIRST,DOTA_TEAM_CUSTOM_MAX do
		for _, hero in pairs(GameLoop.heroes_by_team[team] or {}) do

			hero:QueueMadstones(madstone_count)
		end
	end
end
