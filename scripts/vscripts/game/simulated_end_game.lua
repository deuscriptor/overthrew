SimulatedEndGame = SimulatedEndGame or {}


function SimulatedEndGame:Init()
	EventStream:Listen("EndScreen:check_state", SimulatedEndGame.SendStateEvent, SimulatedEndGame)
end


function SimulatedEndGame:SendStateEvent(event)
	if not GameLoop.game_over then return end

	local player_id = event.PlayerID
	if not IsValidPlayerID(player_id) then return end

	SimulatedEndGame:SendState(player_id)
end


function SimulatedEndGame:SendState(player_id)
	local player = PlayerResource:GetPlayer(player_id)
	if not IsValidEntity(player) then return end

	CustomGameEventManager:Send_ServerToPlayer(player, "EndScreen:start", {
		players_stats = EndGameStats.stats,
		mvp = MVPController:GetMVPData(),
		sorted_teams = SimulatedEndGame.sorted_teams,
		orbs_collected = EndGameStats.orbs_collected,

		-- data local to player who requested them
		winner_team = self.winner_team,
		player_mvp_categories = MVPController:GetPlayerMVPCategories(player_id), -- categories that desired player is MVP in
	})
end


function SimulatedEndGame:EndWithWinner(team_id)
	ErrorTracking.Try(SimulatedEndGame._EndWithWinner, SimulatedEndGame, team_id)
end


function SimulatedEndGame:_EndWithWinner(team_id)
	DebugMessage("[Simulated End Game] setting winner to team", team_id)

	self.winner_team = team_id

	SimulatedEndGame.sorted_teams = GameLoop:GetSortedTeams()
	EndGameStats:FinalizeStats()
	MVPController:FinalizeStats(self.winner_team)

	local entities = FindUnitsInRadius(
		team_id,
		Vector(0, 0, 0),
		nil,
		FIND_UNITS_EVERYWHERE,
		DOTA_UNIT_TARGET_TEAM_BOTH,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_CREEP + DOTA_UNIT_TARGET_BUILDING,
		DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_OUT_OF_WORLD + DOTA_UNIT_TARGET_FLAG_INVULNERABLE,
		FIND_ANY_ORDER,
		false
	)

	for _, entity in pairs(entities or {}) do
		if IsValidEntity(entity) and entity.AddNewModifier and entity.GetUnitName and entity:GetUnitName() ~= "npc_dota_thinker" then

			entity:AddNewModifier(entity, nil, "modifier_simulated_end_game", {duration = -1})
			entity:Stop()
			entity:InterruptMotionControllers(true)
			entity:InterruptChannel()
			entity:Interrupt()
			entity:Purge(true, true, false, true, true)

			ProjectileManager:ProjectileDodge(entity)
		end
	end

	DebugMessage("[Simulated End Game] accounted entities: ", #entities)

	for player_id, hero in pairs(GameLoop.hero_by_player_id or {}) do
		if IsValidEntity(hero) and IsValidPlayerID(player_id) then
			hero:StartGesture(team_id == PlayerResource:GetTeam(player_id) and ACT_DOTA_VICTORY or ACT_DOTA_DEFEAT)

			for _, team in pairs(GameLoop.current_layout.teamlist or {}) do
				hero:MakeVisibleToTeam(team, SIMULATED_END_GAME_DELAY)
			end

			SimulatedEndGame:SendState(player_id)
		end
	end

	local time = 0

	-- actually end the game after 10 minutes (safe guard) or if no players are connected
	self._final_timer = Timers:CreateTimer(1, function()
		time = time + 1

		local any_connected = false
		for player_id, _ in pairs(GameLoop.hero_by_player_id or {}) do
			if PlayerResource:GetConnectionState(player_id) == DOTA_CONNECTION_STATE_CONNECTED then any_connected = true end
		end

		if time >= SIMULATED_END_GAME_DELAY or not any_connected then
			DebugMessage("[Simulated End Game] ending the game", time, tonumber(any_connected))
			GameRules:SetGameWinner(team_id)
			return
		end

		return 1
	end)
end


SimulatedEndGame:Init()
