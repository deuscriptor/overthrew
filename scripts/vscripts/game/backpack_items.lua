BackpackItems = BackpackItems or {}

-- Items that stay fully inert in the backpack: no stats, passives or actives.
local EXCLUDED_ITEMS = {
	item_sphere = true,
	item_aeon_disk = true,
}
-- Swapping one of these between main slots and the backpack puts both swapped
-- items on this cooldown, so their protection cannot be swapped in instantly.
local SWAP_PENALTY_ITEMS = EXCLUDED_ITEMS
local SWAP_PENALTY_COOLDOWN = 6
local RECONCILE_INTERVAL = 1 / 30 -- every server tick
local CAST_ORDERS = {
	[DOTA_UNIT_ORDER_CAST_POSITION] = true,
	[DOTA_UNIT_ORDER_CAST_TARGET] = true,
	[DOTA_UNIT_ORDER_CAST_TARGET_TREE] = true,
	[DOTA_UNIT_ORDER_CAST_NO_TARGET] = true,
	[DOTA_UNIT_ORDER_CAST_TOGGLE] = true,
}

function BackpackItems:IsEnabled()
	return HostOptions.locked and HostOptions:GetOption("backpack_items")
end

function BackpackItems:ApplyRules()
	if not self:IsEnabled() then return end
	local game_mode = GameRules:GetGameModeEntity()
	-- Backpack items work, so moving them into main slots needs no reactivation delay,
	-- and their cooldowns recover at the normal rate.
	game_mode:SetCustomBackpackSwapCooldown(0)
	game_mode:SetCustomBackpackCooldownPercent(1)
	if self.reconcile_started then return end
	self.reconcile_started = true
	Timers:CreateTimer(0, function()
		for _, hero in pairs(HeroList:GetAllHeroes()) do
			if IsValidEntity(hero) and not hero.backpack_reconciled and hero:HasInventory() then
				self:Reconcile(hero)
				-- An illusion's inventory never changes after it spawns, so one pass is enough; the list holds
				-- every illusion (killed ones too, for a while). Monkey King soldiers are reused.
				if hero:IsIllusion() and not hero:IsMonkeyKingSoldier() then hero.backpack_reconciled = true end
			end
		end
		return RECONCILE_INTERVAL
	end)
end

function BackpackItems:IsEligible(item)
	local name = item:GetAbilityName()
	if EXCLUDED_ITEMS[name] or name:find("^item_recipe_") then return false end
	-- Neutral items keep their dedicated slots.
	if tonumber(GetItemKV(name, "ItemIsNeutralActiveDrop")) == 1 then return false end
	if tonumber(GetItemKV(name, "ItemIsNeutralPassiveDrop")) == 1 then return false end
	return true
end

--- Backpack items that function: the first eligible copy of each item name.
function BackpackItems:GetActiveItems(unit)
	local active, seen = {}, {}
	for slot = DOTA_ITEM_SLOT_7, DOTA_ITEM_SLOT_9 do
		local item = unit:GetItemInSlot(slot)
		if item and self:IsEligible(item) then
			local name = item:GetAbilityName()
			if not seen[name] then
				seen[name] = true
				active[item] = true
			end
		end
	end
	return active
end

--- Lets the engine cast an item from the backpack. Only flags set here are cleared,
--- once the item stops being an active backpack item (moved, duplicated or excluded).
local function SetUsable(item, usable)
	if usable then
		if not item:CanBeUsedOutOfInventory() then item:SetCanBeUsedOutOfInventory(true) end
		item.backpack_usable = true
	elseif item.backpack_usable then
		item:SetCanBeUsedOutOfInventory(false)
		item.backpack_usable = nil
	end
end

function BackpackItems:Reconcile(unit)
	local active = self:GetActiveItems(unit)
	-- Illusions never use items, from any slot.
	local can_cast = not unit:IsIllusion()
	for slot = DOTA_ITEM_SLOT_1, DOTA_STASH_SLOT_6 do
		local item = unit:GetItemInSlot(slot)
		if item then
			if slot >= DOTA_ITEM_SLOT_7 and slot <= DOTA_ITEM_SLOT_9 then
				-- The engine unequips items moved into the backpack; equipping applies
				-- their native stats and passives while they stay in place.
				local equipped = item:GetItemState() == 1
				if active[item] and not equipped then
					item:OnEquip()
				elseif not active[item] and equipped then
					item:OnUnequip()
				end
			end
			SetUsable(item, active[item] and can_cast)
		end
	end
end

function BackpackItems:IsInBackpack(unit, item)
	local slot = item:GetItemSlot()
	return slot >= DOTA_ITEM_SLOT_7 and slot <= DOTA_ITEM_SLOT_9 and unit:GetItemInSlot(slot) == item
end

--- Returns false to consume the order, or nil to let other filters and the engine decide.
--- Active backpack items are cast natively, like main slot items.
function BackpackItems:FilterOrder(event, unit, ability)
	if not self:IsEnabled() or not IsValidEntity(unit) then return end
	local order_type = event.order_type
	if order_type == DOTA_UNIT_ORDER_MOVE_ITEM then return self:MoveItem(unit, ability, event.entindex_target) end
	if not CAST_ORDERS[order_type] or not ability or not ability.IsItem or not ability:IsItem() then return end
	if not unit:IsHero() or not self:IsInBackpack(unit, ability) then return end
	local error
	if not self:GetActiveItems(unit)[ability] then
		error = "#backpack_items_error_inactive"
	elseif ability:IsToggle() then
		-- Toggling works in the backpack, but toggled effects (Armlet) need a main slot.
		error = "#backpack_items_error_unsupported"
	end
	if error then
		DisplayError(event.issuer_player_id_const, error)
		return false
	end
end

local function IsInventorySlot(slot)
	return slot >= DOTA_ITEM_SLOT_1 and slot <= DOTA_ITEM_SLOT_9
end

local function IsBackpackSlot(slot)
	return slot >= DOTA_ITEM_SLOT_7 and slot <= DOTA_ITEM_SLOT_9
end

--- Moves between main slots and the backpack, keeping backpack items active throughout.
function BackpackItems:MoveItem(unit, item, slot)
	if not unit:IsHero() or not item or not item.IsItem or not item:IsItem() or type(slot) ~= "number" then return end
	local from = item:GetItemSlot()
	if unit:GetItemInSlot(from) ~= item or not IsInventorySlot(from) or not IsInventorySlot(slot) then return end
	-- Moves within main slots or within the backpack never deactivate items.
	if IsBackpackSlot(from) == IsBackpackSlot(slot) then return end
	local other = unit:GetItemInSlot(slot)
	-- SwapItems unequips both items; the engine re-equips the main slot one only a
	-- moment later. Equip both again in the same server step so their stats and
	-- passives never lapse (health and mana keep their percentages).
	unit:SwapItems(from, slot)
	for _, moved_slot in ipairs({from, slot}) do
		local moved = unit:GetItemInSlot(moved_slot)
		if moved and not IsBackpackSlot(moved_slot) and moved:GetItemState() ~= 1 then moved:OnEquip() end
	end
	self:Reconcile(unit)
	-- The engine refused the swap (e.g. Divine Rapier or Gem are not allowed in the
	-- backpack): leave the order to it, so the player gets the native response.
	if unit:GetItemInSlot(slot) ~= item then return end
	if SWAP_PENALTY_ITEMS[item:GetAbilityName()] or (other and SWAP_PENALTY_ITEMS[other:GetAbilityName()]) then
		for _, swapped in ipairs({item, other}) do
			-- Never shortens a longer cooldown already running.
			if swapped:GetCooldownTimeRemaining() < SWAP_PENALTY_COOLDOWN then swapped:StartCooldown(SWAP_PENALTY_COOLDOWN) end
		end
	end
	return false
end
