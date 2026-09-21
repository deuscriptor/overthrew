SingleDraft = SingleDraft or {}

-- Availability is enforced by the engine as well as the custom random buttons.
-- Pools use the installed game's attributes and the addon's enabled hero list.
SingleDraft.attributes = {
	"DOTA_ATTRIBUTE_STRENGTH", "DOTA_ATTRIBUTE_AGILITY",
	"DOTA_ATTRIBUTE_INTELLECT", "DOTA_ATTRIBUTE_ALL",
}

function SingleDraft:Init()
	if not IsSingleDraftMap() then return end
	self.offers = {}
	self.pools = {}
	for _, attribute in ipairs(self.attributes) do self.pools[attribute] = {} end
	for name, enabled in pairs(LoadKeyValues("scripts/npc/herolist.txt")) do
		if tonumber(enabled) and tonumber(enabled) ~= 0 then
			local attribute = GetUnitKV(name, "AttributePrimary")
			local hero_id = DOTAGameManager:GetHeroIDByName(name)
			if self.pools[attribute] and hero_id and hero_id > 0 then
				table.insert(self.pools[attribute], { name = name, id = hero_id })
			end
		end
	end
	for _, attribute in ipairs(self.attributes) do
		assert(#self.pools[attribute] >= #GameLoop.current_layout.teamlist,
			"Single Draft requires at least eight enabled heroes for " .. attribute)
	end

	local mode = GameRules:GetGameModeEntity()
	mode:SetPlayerHeroAvailabilityFiltered(true)
	mode:SetDraftingBanningTimeOverride(0)
	GameRules:SetCustomGameBansPerTeam(0)
	EventDriver:Listen("Events:state_changed", self.OnStateChanged, self)
	self:PreparePlayers()
	-- Include players joining during setup; existing offers survive reconnects.
	mode:SetContextThink("single_draft_prepare_players", function()
		if GameRules:State_Get() > DOTA_GAMERULES_STATE_HERO_SELECTION then return end
		self:PreparePlayers()
		return 0.25
	end, 0)
end

function SingleDraft:PreparePlayer(player_id)
	if self.offers[player_id] then return self.offers[player_id] end
	local offers = {}
	-- Validate before removing anything, so a failed allocation cannot be partial.
	for _, attribute in ipairs(self.attributes) do
		assert(#self.pools[attribute] > 0, "Single Draft exhausted " .. attribute)
	end
	for _, attribute in ipairs(self.attributes) do
		local pool = self.pools[attribute]
		table.insert(offers, table.remove(pool, RandomInt(1, #pool)))
	end
	self.offers[player_id] = offers
	GameRules:ClearPlayerHeroAvailability(player_id)
	for _, hero in ipairs(offers) do
		GameRules:AddHeroToPlayerAvailability(player_id, hero.id)
	end
	return offers
end

function SingleDraft:PreparePlayers()
	for player_id = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if PlayerResource:IsValidPlayerID(player_id) then
			local team = PlayerResource:GetTeam(player_id)
			for _, playing_team in ipairs(GameLoop.current_layout.teamlist) do
				if team == playing_team then self:PreparePlayer(player_id); break end
			end
		end
	end
end

function SingleDraft:OnStateChanged(event)
	if event.state <= DOTA_GAMERULES_STATE_HERO_SELECTION then self:PreparePlayers() end
end

function SingleDraft:PickRandomHero(player_id)
	if GameRules:State_Get() ~= DOTA_GAMERULES_STATE_HERO_SELECTION then return end
	if not player_id or not PlayerResource:IsValidPlayerID(player_id) then return end
	if PlayerResource:HasSelectedHero(player_id) then return end
	local player = PlayerResource:GetPlayer(player_id)
	local offers = self.offers[player_id]
	if not player or not offers then return end
	player:SetSelectedHero(offers[RandomInt(1, #offers)].name)
	PlayerResource:SetHasRandomed(player_id)
end
