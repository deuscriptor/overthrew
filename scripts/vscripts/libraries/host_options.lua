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

local HOST_CLAIM_FALLBACK_DELAY = 10
local HOST_CLAIM_MAX_FAILURES = 5

function HostOptions:Init()
	HostOptions.options = {}
	HostOptions.available_options = {
		[HOST_OPTION.BOTS] = true,
	}
	HostOptions.host = nil
	HostOptions.locked = false
	HostOptions:InitHostClaim()
	if UsesHostRules() then
		HostOptions.available_options.kill_goal = true
		HostOptions.options.kill_goal = 50
		for _, name in ipairs(MATCH_FLAGS) do
			HostOptions.available_options[name] = true
			HostOptions.options[name] = DEFAULT_ON_FLAGS[name] or false
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
		if not HostOptions:IsHost(player) then return end

		HostOptions:SetOptionState(event.name, event.name == "kill_goal" and event.state or toboolean(event.state))
	end)

	EventDriver:Listen("Events:state_changed", function(event)
		if event.state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
			HostOptions:UpdateHostPlayer()
			HostOptions:ScheduleClaimFallback()
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

-- Scripts cannot see the lobby owner, and on Local Host both native host privileges
-- and GetListenServerHost() follow client connection order (the first client to load).
-- The lobby owner's client runs inside the server process and shares its convars, so
-- only its client VM can read this random token and claim host (libraries/host_claim).
function HostOptions:InitHostClaim()
	-- Keep an accepted claim across script reloads; the owner's client claims only once.
	if IsDedicatedServer() or self.claim_token then return end
	if Convars:GetStr(HOST_CLAIM_CONVAR) == nil then
		Convars:RegisterConvar(HOST_CLAIM_CONVAR, "0", "Local Host owner verification token", 0)
	end
	if not self.claim_command_registered then
		self.claim_command_registered = true
		Convars:RegisterCommand(HOST_CLAIM_COMMAND, function(_, token)
			local pawn = Convars:GetCommandClient()
			local player = IsValidEntity(pawn) and pawn:GetController() or nil
			if IsValidEntity(player) then HostOptions:ClaimHost(player, tonumber(token)) end
		end, "Local Host owner verification", 0)
	end
	self.claim_token = RandomInt(1, 0x3FFFFFFF)
	self.claim_failures = {}
	self.claim_fallback = false
	self.owner_id = nil
	Convars:SetInt(HOST_CLAIM_CONVAR, self.claim_token)
end

function HostOptions:ClaimHost(player, token)
	if not self.claim_token or self.owner_id or self.locked then return false end
	local id = player:GetPlayerID()
	if not PlayerResource:IsValidPlayerID(id) then return false end
	local failures = self.claim_failures[id] or 0
	if failures >= HOST_CLAIM_MAX_FAILURES then return false end
	if token ~= self.claim_token then
		self.claim_failures[id] = failures + 1
		return false
	end
	self.owner_id = id
	self:UpdateHostPlayer()
	if UsesHostRules() then self:PublishRules() end
	return true
end

function HostOptions:ScheduleClaimFallback()
	if not self.claim_token or self.owner_id then return end
	Timers:CreateTimer({useGameTime = false, endTime = HOST_CLAIM_FALLBACK_DELAY, callback = function()
		if self.owner_id or self.locked then return end
		-- Never leave setup without a host if the owner's client could not claim.
		print("[Host Options] no Local Host owner claim received, using native host privileges")
		self.claim_fallback = true
		self:UpdateHostPlayer()
	end})
end

function HostOptions:ResolveHost()
	if self.owner_id then
		local player = PlayerResource:GetPlayer(self.owner_id)
		return IsValidEntity(player) and player or nil
	end
	-- Wait for the Local Host owner's claim instead of trusting connection order.
	if self.claim_token and not self.claim_fallback then return nil end
	for id = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		local player = PlayerResource:GetPlayer(id)
		if IsValidEntity(player) and GameRules:PlayerHasCustomGameHostPrivileges(player) then
			return player
		end
	end
end

function HostOptions:IsHost(player)
	return IsValidEntity(player) and player == self:ResolveHost()
end

function HostOptions:PublishRules()
	self.host = self:ResolveHost()
	local host_id = IsValidEntity(self.host) and self.host:GetPlayerID() or -1
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
	self.host = self:ResolveHost()
	if IsValidEntity(self.host) then
		CustomGameEventManager:Send_ServerToPlayer(self.host, "HostOptions:show", {
			available_options = self.available_options,
		})
	end
end


HostOptions:Init()
