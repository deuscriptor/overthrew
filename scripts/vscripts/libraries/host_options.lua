HostOptions = HostOptions or {}

local MATCH_FLAGS = {"single_draft", "epic_orbs", "turbo", "infinite_rerolls", "longer_wards", "divine_rapier", "dagon"}

--- Known host option types
---@type table<string, string>
HOST_OPTION = {
	TOURNAMENT = "tournament_mode",
	BOTS = "fill_with_bots"
}


function HostOptions:Init()
	HostOptions.options = {}
	HostOptions.available_options = {
		[HOST_OPTION.BOTS] = true,
	}
	HostOptions.host = nil
	HostOptions.locked = false
	if UsesHostRules() then
		HostOptions.available_options.kill_goal = true
		HostOptions.options.kill_goal = 30
		for _, name in ipairs(MATCH_FLAGS) do
			HostOptions.available_options[name] = true
			HostOptions.options[name] = name == "longer_wards"
		end
	end
	EventStream:Listen("HostOptions:apply_rules", function(event, user_id)
		local sender = EntIndexToHScript(user_id)
		if not IsValidEntity(sender) or sender:GetPlayerID() ~= event.PlayerID then return end
		HostOptions:ApplyRules(event)
	end)

	EventStream:Listen("HostOptions:set_option_state", function(event, user_id)
		local sender = EntIndexToHScript(user_id)
		if not IsValidEntity(sender) or sender:GetPlayerID() ~= event.PlayerID then return end
		local player_id = event.PlayerID
		if not player_id or not PlayerResource:IsValidPlayerID(player_id) then return end

		local player = PlayerResource:GetPlayer(player_id)
		if not IsValidEntity(player) or not GameRules:PlayerHasCustomGameHostPrivileges(player) then return end

		HostOptions:SetOptionState(event.name, event.name == "kill_goal" and event.state or toboolean(event.state))
	end)

	EventDriver:Listen("Events:state_changed", function(event)
		if event.state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
			HostOptions:UpdateHostPlayer()
		end

		if event.state == DOTA_GAMERULES_STATE_HERO_SELECTION then
			if HostOptions:GetOption(HOST_OPTION.TOURNAMENT) then
				-- delay is needed otherwise it sends to team select chat
				-- state is not yet switched to hero selection on client
				Timers:CreateTimer(1, function()
					GameRules:SendCustomMessage("#tournament_mode_note", HostOptions.host:GetPlayerID(), 1)
				end)
			end

			if HostOptions:GetOption(HOST_OPTION.BOTS) then
				print("filling with bots")
				SendToServerConsole("dota_bot_populate")
			end
		end
	end)
end


function HostOptions:IsValidKillGoal(value)
	return type(value) == "number" and value >= 1 and value <= 2147483647 and value == math.floor(value)
end

function HostOptions:SetOptionState(option_name, state)
	if self.locked or GameRules:State_Get() > DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then return end
	if option_name == "kill_goal" and not self:IsValidKillGoal(state) then return end
	if not HostOptions:IsOptionAvailable(option_name) then
		print("[Host Options] attempted to change state of unavailable host option!\nHINT: use SetOptionAvailable or edit available_options to enable by default")
		return
	end

	HostOptions.options[option_name] = state

	CustomNetTables:SetTableValue("game_options", "host_options", HostOptions.options)
	if UsesHostRules() then self:PublishRules() end
end

function HostOptions:PublishRules()
	local host_id = -1
	for id = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		local player = PlayerResource:GetPlayer(id)
		if IsValidEntity(player) and GameRules:PlayerHasCustomGameHostPrivileges(player) then
			host_id = id
			self.host = player
			break
		end
	end
	local rules = {
		host_id = host_id, locked = self.locked and 1 or 0,
		kill_goal = self.options.kill_goal,
	}
	for _, name in ipairs(MATCH_FLAGS) do rules[name] = self:GetOption(name) and 1 or 0 end
	CustomNetTables:SetTableValue("game_options", "match_rules", rules)
end

function HostOptions:HoldSetup()
	GameRules:EnableCustomGameSetupAutoLaunch(false)
	GameRules:SetCustomGameSetupTimeout(-1)
	GameRules:GetGameModeEntity():SetContextThink("host_rules_sync", function()
		self:PublishRules()
		if GameRules:State_Get() > DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then return end
		return 0.5
	end, 0)
end

function HostOptions:ApplyRules(event)
	if not UsesHostRules() or self.locked or GameRules:State_Get() ~= DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then return false end
	local id = event.PlayerID
	if type(id) ~= "number" or not PlayerResource:IsValidPlayerID(id) then return false end
	local player = PlayerResource:GetPlayer(id)
	if not IsValidEntity(player) or not GameRules:PlayerHasCustomGameHostPrivileges(player) then return false end
	if not self:IsValidKillGoal(event.kill_goal) then return false end
	local rules = {}
	for _, name in ipairs(MATCH_FLAGS) do
		local value = event[name]
		if value ~= 0 and value ~= 1 and value ~= false and value ~= true then return false end
		rules[name] = value == 1 or value == true
	end
	for name, value in pairs(rules) do self.options[name] = value end
	self.options.kill_goal = event.kill_goal
	GameLoop.target_kill_goal = event.kill_goal
	GameLoop:UpdateScoreGoal()
	-- Configure selection before allowing the engine to leave setup.
	GameRules:SetCustomGameBansPerTeam(IsSingleDraftMap() and 0 or TEAMS_LAYOUTS[GetMapName()].player_count)
	SingleDraft:Init()
	self.locked = true
	HostItems:ApplyRules()
	CustomNetTables:SetTableValue("game_options", "host_options", self.options)
	self:PublishRules()
	GameRules:FinishCustomGameSetup()
	return true
end


function HostOptions:GetOption(option_name)
	return HostOptions.options[option_name] or false
end


function HostOptions:SetOptionAvailable(option_name, state)
	HostOptions.available_options[option_name] = state

	if IsValidEntity(HostOptions.host) then
		CustomGameEventManager:Send_ServerToPlayer(HostOptions.host, "HostOptions:show", {
			available_options = HostOptions.available_options,
		})
	end
end


function HostOptions:IsOptionAvailable(option_name)
	return HostOptions.available_options[option_name] or false
end


function HostOptions:UpdateHostPlayer()
	for i = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		local player = PlayerResource:GetPlayer(i)
		if player and GameRules:PlayerHasCustomGameHostPrivileges(player) then
			HostOptions.host = player
			CustomGameEventManager:Send_ServerToPlayer(player, "HostOptions:show", {
				available_options = HostOptions.available_options,
			})
		end
	end
end


HostOptions:Init()
