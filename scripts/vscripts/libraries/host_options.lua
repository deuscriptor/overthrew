HostOptions = HostOptions or {}

local MATCH_FLAGS = {"single_draft", "epic_orbs", "turbo", "backpack_items", "infinite_rerolls", "all_vision", "invincible_wards", "longer_wards", "divine_rapier", "dagon"}
-- Flags absent here default off.
local DEFAULT_ON_FLAGS = {
	single_draft = true, turbo = true, infinite_rerolls = true, all_vision = true,
	invincible_wards = true, longer_wards = true, divine_rapier = true, dagon = true,
}

--- Known host option types
---@type table<string, string>
HOST_OPTION = {
	TOURNAMENT = "tournament_mode",
	BOTS = "fill_with_bots"
}

-- Stop waiting for players who never finish loading, so setup cannot stall.
local HOST_LOADING_MAX_WAIT = 120
-- The loading screen stops updating once hero selection begins, so it frees its art when the locked rules
-- arrive; setup ends this many seconds later (see "Texture memory" in tools/README.md).
local LOADING_SCREEN_RELEASE_TIME = 0.5

function HostOptions:Init()
	HostOptions.options = {}
	HostOptions.available_options = {
		[HOST_OPTION.BOTS] = true,
	}
	HostOptions.host = nil
	HostOptions.host_id = nil
	HostOptions.locked = false
	HostOptions.players_ready = false
	HostOptions.loading_wait_expired = false
	HostOptions.available_options.kill_goal = true
	HostOptions.options.kill_goal = 50
	for _, name in ipairs(MATCH_FLAGS) do
		HostOptions.available_options[name] = true
		HostOptions.options[name] = DEFAULT_ON_FLAGS[name] or false
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
		if not HostOptions:IsHost(player) then return end

		HostOptions:SetOptionState(event.name, event.name == "kill_goal" and event.state or toboolean(event.state))
	end)

	EventStream:Listen("HostOptions:claim_host", function(event, user_id)
		local sender = EntIndexToHScript(user_id)
		if not IsValidEntity(sender) or sender:GetPlayerID() ~= event.PlayerID then return end
		HostOptions:ClaimHost(event.PlayerID)
	end)

	EventDriver:Listen("Events:state_changed", function(event)
		if event.state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
			HostOptions:UpdateHostPlayer()
			HostOptions:WatchLoading()
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
	self:PublishRules()
end

-- Scripts get no lobby owner from the engine, and native host privileges and
-- GetListenServerHost() follow connection order. On configurable FFA, any player may claim
-- the host role instead, once everyone has loaded. Other maps keep native privileges.
function HostOptions:IsRealPlayerID(id)
	return type(id) == "number" and PlayerResource:IsValidPlayerID(id) and not PlayerResource:IsFakeClient(id)
end

-- Settings stay hidden and closed until setup has begun and every player has loaded, so
-- nobody edits them before the rest arrive. Latches once true.
function HostOptions:ArePlayersReady()
	if self.players_ready then return true end
	if GameRules:State_Get() ~= DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then return false end
	if not self.loading_wait_expired then
		for id = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
			if self:IsRealPlayerID(id)
				and PlayerResource:GetConnectionState(id) == DOTA_CONNECTION_STATE_NOT_YET_CONNECTED then
				return false
			end
		end
	end
	self.players_ready = true
	print("[Host Options] all players loaded, host can be claimed")
	return true
end

function HostOptions:WatchLoading()
	Timers:CreateTimer({useGameTime = false, endTime = HOST_LOADING_MAX_WAIT, callback = function()
		if self.locked or GameRules:State_Get() ~= DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then return end
		self.loading_wait_expired = true
		self:PublishRules()
	end})
end

function HostOptions:ClaimHost(player_id)
	if self.locked or not self:ArePlayersReady() then return false end
	if self:ResolveHost() or not self:IsRealPlayerID(player_id) then return false end
	if PlayerResource:GetConnectionState(player_id) ~= DOTA_CONNECTION_STATE_CONNECTED then return false end
	self.host_id = player_id
	print("[Host Options] player", player_id, PlayerResource:GetPlayerName(player_id), "claimed host")
	self:UpdateHostPlayer()
	self:PublishRules()
	return true
end

function HostOptions:ResolveHost()
	if not self.host_id then return nil end
	local player = PlayerResource:GetPlayer(self.host_id)
	-- A host who leaves before starting frees the role for anyone to claim.
	if not self.locked and (not IsValidEntity(player)
		or PlayerResource:GetConnectionState(self.host_id) ~= DOTA_CONNECTION_STATE_CONNECTED) then
		print("[Host Options] host player", self.host_id, "left, host can be claimed again")
		self.host_id = nil
		return nil
	end
	return IsValidEntity(player) and player or nil
end

function HostOptions:IsHost(player)
	return IsValidEntity(player) and player == self:ResolveHost()
end

function HostOptions:PublishRules()
	local previous = self.host
	self.host = self:ResolveHost()
	if self.host ~= previous and IsValidEntity(self.host) then
		CustomGameEventManager:Send_ServerToPlayer(self.host, "HostOptions:show", {available_options = self.available_options})
	end
	local host_id = IsValidEntity(self.host) and self.host:GetPlayerID() or -1
	local rules = {
		host_id = host_id, locked = self.locked and 1 or 0,
		ready = (self.locked or self:ArePlayersReady()) and 1 or 0,
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
	if self.locked or GameRules:State_Get() ~= DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then return false end
	local id = event.PlayerID
	if type(id) ~= "number" or not PlayerResource:IsValidPlayerID(id) then return false end
	local player = PlayerResource:GetPlayer(id)
	if not self:IsHost(player) then return false end
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
	GameLoop.current_layout.game_base_duration = DEFAULT_MATCH_LENGTH * (event.kill_goal / 30)
	GameLoop:UpdateScoreGoal()
	-- Configure selection before allowing the engine to leave setup.
	GameRules:SetCustomGameBansPerTeam(IsSingleDraftMap() and 0 or TEAMS_LAYOUTS[GetMapName()].player_count)
	SingleDraft:Init()
	self.locked = true
	GameRules:GetGameModeEntity():SetFogOfWarDisabled(self:GetOption("all_vision"))
	HostItems:ApplyRules()
	BackpackItems:ApplyRules()
	CustomNetTables:SetTableValue("game_options", "host_options", self.options)
	self:PublishRules()
	Timers:CreateTimer({useGameTime = false, endTime = LOADING_SCREEN_RELEASE_TIME, callback = function()
		if GameRules:State_Get() == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then GameRules:FinishCustomGameSetup() end
	end})
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
	self.host = self:ResolveHost()
	if IsValidEntity(self.host) then
		CustomGameEventManager:Send_ServerToPlayer(self.host, "HostOptions:show", {
			available_options = self.available_options,
		})
	end
end


HostOptions:Init()
