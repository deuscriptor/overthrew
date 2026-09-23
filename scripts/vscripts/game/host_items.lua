HostItems = HostItems or {}

function HostItems:OptionForItem(name)
	if name == "item_rapier" or name == "item_recipe_rapier" then return "divine_rapier" end
	if name == "item_dagon" or name == "item_recipe_dagon" or name:match("^item_dagon_[1-5]$") then return "dagon" end
end

function HostItems:IsDisabled(name)
	local option = self:OptionForItem(name or "")
	return option ~= nil and not (UsesHostRules() and HostOptions.locked and HostOptions:GetOption(option))
end

function HostItems:ApplyRules()
	-- Native whitelists do not recognize the addon's custom replacement items.
	GameRules:SetWhiteListEnabled(false)
end

function HostItems:CheckAssembly(item, inventory)
	local name = item:GetName()
	if name:find("^item_recipe_") or not self:IsDisabled(name) or item.host_disassembly_pending then return end
	item.host_disassembly_pending = true
	-- The inventory filter runs before insertion; disassemble on the next frame.
	-- Native disassembly returns the recipe/components and locks their combining,
	-- including on items which cannot normally be manually disassembled.
	Timers:CreateTimer(0, function()
		if not IsValidEntity(item) then return end
		local holder = item:GetCaster()
		if not IsValidEntity(holder) then holder = inventory end
		if not IsValidEntity(holder) then return end
		holder:DisassembleItem(item)
		local id = holder:GetPlayerOwnerID()
		if id and id >= 0 then DisplayError(id, "#host_rules_item_disabled") end
	end)
end

function HostItems:QueueInventoryCheck(inventory)
	if not IsValidEntity(inventory) or inventory.host_item_check_pending then return end
	inventory.host_item_check_pending = true
	Timers:CreateTimer(0, function()
		if not IsValidEntity(inventory) then return end
		inventory.host_item_check_pending = nil
		for slot = 0, 20 do
			local item = inventory:GetItemInSlot(slot)
			if IsValidEntity(item) then self:CheckAssembly(item, inventory) end
		end
	end)
end

function HostItems:ExtendWardLifetime(unit, name)
	if name ~= "npc_dota_observer_wards" and name ~= "npc_dota_sentry_wards" then return end
	if not UsesHostRules() or not HostOptions.locked or not HostOptions:GetOption("longer_wards") then return end
	if unit.host_lifetime_extended then return end
	local lifetime = unit:FindModifierByName("modifier_item_buff_ward")
	if lifetime and lifetime:GetDuration() > 0 then
		-- Preserve the time elapsed since creation rather than restarting the clock.
		lifetime:SetDuration(lifetime:GetRemainingTime() + 2 * lifetime:GetDuration(), true)
		local sight = unit:FindModifierByName("modifier_item_ward_true_sight")
		if sight and sight:GetDuration() > 0 then
			sight:SetDuration(sight:GetRemainingTime() + 2 * sight:GetDuration(), true)
		end
		unit.host_lifetime_extended = true
	end
end
