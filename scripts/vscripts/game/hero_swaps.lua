HeroSwaps = HeroSwaps or {}

function HeroSwaps:Init()
	self.requests, self.accepted, self.cooldowns = {}, {}, {}
	self.spent_orbs, self.base_generics = {}, {}
	self.next_id = 0
	for _, action in ipairs({"request", "accept", "decline", "cancel"}) do
		EventStream:Listen("HeroSwaps:" .. action, function(event, source)
			local sender = EntIndexToHScript(source)
			if not IsValidEntity(sender) or sender:GetPlayerID() ~= event.PlayerID then return end
			self:Handle(action, event.PlayerID, event)
		end)
	end
	GameRules:GetGameModeEntity():SetContextThink("hero_swaps", function()
		self:Tick()
		if GameRules:State_Get() >= DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then return end
		return 0.2
	end, 0)
end

function HeroSwaps:IsOpen()
	local state = GameRules:State_Get()
	return state >= DOTA_GAMERULES_STATE_HERO_SELECTION
		and state < DOTA_GAMERULES_STATE_GAME_IN_PROGRESS and not GameRules:IsInBanPhase()
end

function HeroSwaps:IsPlayerReady(id)
	if type(id) ~= "number" or id % 1 ~= 0 or not PlayerResource:IsValidPlayerID(id) then return false end
	if PlayerResource:GetConnectionState(id) ~= DOTA_CONNECTION_STATE_CONNECTED then return false end
	if not IsValidEntity(PlayerResource:GetPlayer(id)) then return false end
	local team = PlayerResource:GetTeam(id)
	for _, playing_team in ipairs(GameLoop.current_layout.teamlist) do
		if team == playing_team then return PlayerResource:GetSelectedHeroName(id) ~= "" end
	end
	return false
end

function HeroSwaps:IsBusy(id)
	for _, request in pairs(self.accepted) do
		if request.from == id or request.to == id then return true end
	end
	return false
end

function HeroSwaps:IsCurrent(request)
	return self:IsPlayerReady(request.from) and self:IsPlayerReady(request.to)
		and PlayerResource:GetSelectedHeroName(request.from) == request.from_hero
		and PlayerResource:GetSelectedHeroName(request.to) == request.to_hero
end

function HeroSwaps:Notify(id, status)
	local player = PlayerResource:GetPlayer(id)
	if IsValidEntity(player) then
		CustomGameEventManager:Send_ServerToPlayer(player, "HeroSwaps:status", {status = status})
	end
end

function HeroSwaps:ClearRequests(a, b)
	for id, request in pairs(self.requests) do
		if request.from == a or request.to == a or request.from == b or request.to == b then
			self.requests[id] = nil
		end
	end
end

function HeroSwaps:Handle(action, id, event)
	if not self:IsOpen() or not self:IsPlayerReady(id) then return false end
	local now = GameRules:GetGameTime()
	if action == "request" then
		local target = event.target
		if target == id or not self:IsPlayerReady(target) or self:IsBusy(id) or self:IsBusy(target) then return false end
		if PlayerResource:GetSelectedHeroName(id) == PlayerResource:GetSelectedHeroName(target) then return false end
		if (self.cooldowns[id] or -math.huge) > now then return false end
		self.cooldowns[id] = now + 2
		-- At most one outgoing request per player.
		for key, request in pairs(self.requests) do
			if request.from == id then self.requests[key] = nil end
		end
		self.next_id = self.next_id + 1
		self.requests[self.next_id] = {id = self.next_id, from = id, to = target,
			from_hero = PlayerResource:GetSelectedHeroName(id), to_hero = PlayerResource:GetSelectedHeroName(target), expires = now + 30}
	elseif action == "accept" or action == "decline" or action == "cancel" then
		local request = self.requests[event.request_id]
		if not request or request.expires <= now or not self:IsCurrent(request) then return false end
		if action == "cancel" then
			if request.from ~= id then return false end
		else
			if request.to ~= id then return false end
		end
		if action == "accept" then
			if self:IsBusy(request.from) or self:IsBusy(request.to) then return false end
			self:ClearRequests(request.from, request.to)
			self.accepted[request.id] = request
			self:Notify(request.from, "accepted")
			self:Notify(request.to, "accepted")
		else
			self.requests[request.id] = nil
			self:Notify(action == "decline" and request.from or request.to, action == "decline" and "declined" or "cancelled")
		end
	else
		return false
	end
	self:Tick()
	return true
end

-- Store actual consumed orbs, rather than reconstructing rarities from upgrade levels.
function HeroSwaps:RecordOrbSelection(hero, selection)
	if not self:IsOpen() or not self.spent_orbs then return end
	local id = hero:GetPlayerOwnerID()
	self.spent_orbs[id] = self.spent_orbs[id] or {}
	table.insert(self.spent_orbs[id], {rarity = selection.upgrade_rarity, is_lucky_trinket_proc = selection.is_lucky_trinket_proc})
end

function HeroSwaps:CaptureBaseUpgrades(hero)
	if not self.base_generics then return end
	self.base_generics[hero:GetPlayerOwnerID()] = table.deepcopy((hero.upgrades or {}).generic or {})
end

function HeroSwaps:ResetUpgrades(hero)
	local previous = hero.upgrades or {}
	hero.upgrades = {}
	-- Ability upgrade entries also reference the shared per-hero KV pool.
	-- Clear its displayed levels as well as the hero's live lookup.
	for _, upgrades in pairs(previous) do
		for _, data in pairs(upgrades) do data.count = 0 end
	end
	local auto_rune = hero:FindModifierByName("modifier_generic_auto_rune_upgrade")
	if auto_rune then
		for _, modifier in pairs(auto_rune.granted_runes or {}) do
			if not modifier:IsNull() then modifier:Destroy() end
		end
	end
	for name in pairs(previous.generic or {}) do
		hero:RemoveModifierByName("modifier_" .. name .. "_upgrade")
	end
	for _, name in ipairs({"modifier_generic_common_stat_boost_upgrade_handler", "modifier_generic_rare_stat_boost_upgrade_handler", "modifier_generic_status_res_on_disable_bonus"}) do
		hero:RemoveModifierByName(name)
	end
	local controller = hero:FindModifierByName("modifier_ability_upgrades_controller")
	if controller then controller:ForceRefresh() end
	for name in pairs(previous) do
		if name ~= "generic" then Upgrades:RefreshIntrinsicModifierByName(hero, name) end
	end
	if hero.CalculateStatBonus then hero:CalculateStatBonus(true) end
end

function HeroSwaps:GetOwnedUnits(hero)
	local id = hero:GetPlayerOwnerID()
	local units = {}
	for _, unit in pairs(FindUnitsInRadius(hero:GetTeam(), hero:GetAbsOrigin(), nil, FIND_UNITS_EVERYWHERE,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_ALL,
		DOTA_UNIT_TARGET_FLAG_INVULNERABLE + DOTA_UNIT_TARGET_FLAG_OUT_OF_WORLD, FIND_ANY_ORDER, false)) do
		if unit ~= hero and unit:GetPlayerOwnerID() == id and not unit:IsCourier() and unit ~= GetDummyInventory(id) then
			table.insert(units, {unit = unit, controllable = unit:IsControllableByAnyPlayer()})
		end
	end
	return units
end

function HeroSwaps:ReassignOwnedUnits(units, hero)
	for _, data in ipairs(units) do
		local unit = data.unit
		if IsValidEntity(unit) then
			self:ResetUpgrades(unit)
			unit:SetOwner(hero)
			if unit.SetPlayerID then unit:SetPlayerID(hero:GetPlayerOwnerID()) end
			unit:SetTeam(hero:GetTeam())
			if data.controllable then unit:SetControllableByPlayer(hero:GetPlayerOwnerID(), true) end
			FindClearSpaceForUnit(unit, hero:GetAbsOrigin(), true)
			if unit:IsHero() then Upgrades:ProcessClone(unit, hero) else Upgrades:ApplySummonUpgrades(unit, unit:GetUnitName(), hero) end
		end
	end
end

local function take_items(hero)
	local items = {}
	for slot = 0, 20 do
		local item = hero:GetItemInSlot(slot)
		if IsValidEntity(item) then
			items[slot] = item
			hero:TakeItem(item)
		end
	end
	return items
end

local function restore_items(hero, items)
	-- Retain the actual handles, charges, purchaser, cooldowns, and inventory slots.
	for slot = 0, 20 do
		local item = items[slot]
		if item then
			hero:AddItem(item)
			if item:GetItemSlot() ~= slot then hero:SwapItems(item:GetItemSlot(), slot) end
		end
	end
end

function HeroSwaps:Assign(hero, player_id, position)
	local player = PlayerResource:GetPlayer(player_id)
	hero:SetOwner(player)
	hero:SetPlayerID(player_id)
	hero:SetTeam(PlayerResource:GetTeam(player_id))
	-- The pre-game stun still counts as coming from the old team, so the new fountain's debuff
	-- immunity suppresses it (the hero could walk until it left the fountain). Re-create it.
	local stun = hero:FindModifierByName("modifier_pregame_stunned")
	if stun then
		local remaining = stun:GetRemainingTime()
		stun:Destroy()
		hero:AddNewModifier(hero, nil, "modifier_pregame_stunned", {duration = remaining})
	end
	hero:SetControllableByPlayer(player_id, true)
	player:SetAssignedHeroEntity(hero)
	hero:SetRespawnPosition(position)
	FindClearSpaceForUnit(hero, position, true)
	GameLoop.hero_by_player_id[player_id] = hero
	local inventory = GetDummyInventory(player_id)
	if IsValidEntity(inventory) then inventory:SetOwner(hero) end
end

function HeroSwaps:RefreshPlayer(id, hero)
	Upgrades.disabled_upgrades_per_player[id] = {}
	Upgrades.pending_selection[id] = nil
	Upgrades.favorites_upgrades[id] = {generic = (Upgrades.favorites_upgrades[id] or {}).generic or {}}
	-- Non-orb account bonuses remain with their player; spent orb choices are reset.
	for name, data in pairs(self.base_generics[id] or {}) do Upgrades:SetGenericUpgrade(hero, name, data.count) end
	local controller = hero:FindModifierByName("modifier_ability_upgrades_controller")
	if controller then controller:ForceRefresh() end
	CustomNetTables:SetTableValue("ability_upgrades", tostring(id), hero.upgrades)
	local queue = Upgrades.queued_selection[id] or {}
	for _, orb in ipairs(self.spent_orbs[id] or {}) do table.insert(queue, orb) end
	self.spent_orbs[id] = {}
	Upgrades.queued_selection[id] = queue
	Upgrades:SendUpgradesData(id)
	Upgrades:SendPendingFavorites({PlayerID = id})
	CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(id), "HeroSwaps:reset_upgrades", {})
	if queue[1] then Upgrades:ShowSelection(hero, queue[1].rarity, id, false, queue[1].is_lucky_trinket_proc) end
	HeroChallenges.active_challenges[id] = nil
	HeroChallenges:OnHeroInitFinished({player_id = id, hero = hero})
	HeroChallenges:SetClientChallenges(id)
end

function HeroSwaps:Execute(request)
	local a, b = request.from, request.to
	local hero_a, hero_b = PlayerResource:GetSelectedHeroEntity(a), PlayerResource:GetSelectedHeroEntity(b)
	-- Native hero entities do not exist during selection/strategy. Hold accepted
	-- requests until both spawn, then reassign the actual heroes (including facets).
	if not IsValidEntity(hero_a) or not IsValidEntity(hero_b) or not hero_a.initialized or not hero_b.initialized then return false end
	local pos_a, pos_b = hero_a:GetAbsOrigin(), hero_b:GetAbsOrigin()
	local units_a, units_b = self:GetOwnedUnits(hero_a), self:GetOwnedUnits(hero_b)
	local items_a, items_b = take_items(hero_a), take_items(hero_b)
	self:ResetUpgrades(hero_a)
	self:ResetUpgrades(hero_b)
	self:Assign(hero_b, a, pos_a)
	self:Assign(hero_a, b, pos_b)
	for _, heroes in pairs(GameLoop.heroes_by_team) do
		for index, hero in ipairs(heroes) do
			if hero == hero_a then heroes[index] = hero_b elseif hero == hero_b then heroes[index] = hero_a end
		end
	end
	restore_items(hero_b, items_a)
	restore_items(hero_a, items_b)
	self:RefreshPlayer(a, hero_b)
	self:RefreshPlayer(b, hero_a)
	Upgrades.summon_list[a], Upgrades.summon_list[b] = Upgrades.summon_list[b], Upgrades.summon_list[a]
	self:ReassignOwnedUnits(units_a, hero_a)
	self:ReassignOwnedUnits(units_b, hero_b)
	self:Notify(a, "completed")
	self:Notify(b, "completed")
	return true
end

function HeroSwaps:Tick()
	local now = GameRules:GetGameTime()
	for id, request in pairs(self.requests) do
		if not self:IsOpen() or request.expires <= now or not self:IsCurrent(request) then self.requests[id] = nil end
	end
	for id, request in pairs(self.accepted) do
		if not self:IsOpen() or not self:IsCurrent(request) then
			self.accepted[id] = nil
			self:Notify(request.from, "cancelled")
			self:Notify(request.to, "cancelled")
		elseif self:Execute(request) then
			self.accepted[id] = nil
		end
	end
	local players = {}
	if self:IsOpen() then
		for id = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
			if self:IsPlayerReady(id) then players[tostring(id)] = {hero = PlayerResource:GetSelectedHeroName(id), busy = self:IsBusy(id) and 1 or 0} end
		end
	end
	CustomNetTables:SetTableValue("game_options", "hero_swaps", {open = self:IsOpen() and 1 or 0, players = players, requests = self.requests, accepted = self.accepted})
end
