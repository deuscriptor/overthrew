modifier_bat_handler = class({})

function modifier_bat_handler:IsHidden()
	return true
end

function modifier_bat_handler:IsPermanent()
	return true
end

function modifier_bat_handler:IsPurgable()
	return false
end

function modifier_bat_handler:OnCreated()
	if IsServer() then
		self.herobat = self:GetParent():GetBaseAttackTime(false)
		-- Every hero and illusion has a handler, so it only hears about modifiers added to its own parent
		-- (libraries/unit_events.lua) instead of declaring MODIFIER_EVENT_ON_MODIFIER_ADDED.
		UnitEvents:Register(self, "OnModifierAdded")
	end
	self.original_herobat = self:GetParent():GetBaseAttackTime(false)
	self:SetStackCount(self:GetParent():GetBaseAttackTime(false) * 100)
end

function modifier_bat_handler:OnDestroy()
	if IsServer() then UnitEvents:Unregister(self) end
end

function modifier_bat_handler:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_BASE_ATTACK_TIME_CONSTANT, -- GetModifierBaseAttackTimeConstant
	}
end

function modifier_bat_handler:GetModifierBaseAttackTimeConstant()
	-- This modifier must be created first before later modifiers that use this function
	-- Logic shows that the base attack time change will occur only at the first modifier that has this function
	return self:GetStackCount() * 0.01
end

function modifier_bat_handler:GetOriginalBaseAttackTime()
	return self.original_herobat
end

function modifier_bat_handler:OnModifierAdded()
	self:RecalculateBAT()
end

function modifier_bat_handler:RecalculateBAT()
	if IsClient() then return end
	if not self or self:IsNull() then return end

	-- Solution:
	-- Set a base-line for the final BAT buff (unit's BAT)
	-- Iterate through the modifier table and find those that mod base attack time
	-- Find the lowest one
	local final_bat = self.herobat
	local final_modifier
	local direct_bonus = 0
	for _, mod in pairs(self:GetParent():FindAllModifiers()) do
		local name = mod:GetName()
		if name ~= "modifier_bat_handler" then
			local modBAT = self:CalculateBAT(mod, name)
			if modBAT < final_bat then
				final_bat = modBAT
				final_modifier = mod
			end

			if mod.GetBaseAttackTimeDirectBonus then
				direct_bonus = direct_bonus + mod:GetBaseAttackTimeDirectBonus()
			end
		end
	end

	self:WatchExpiry(final_modifier)

	final_bat = final_bat + direct_bonus

	-- All heroes have different BAT and some can change their own,
	-- I've capped it at 0.1 BAT right now
	self:SetStackCount(math.max(final_bat * 100, 0.1))
end

-- Workaround for early expiry bug, not the prettiest: a timed modifier setting the BAT adds nothing when it ends,
-- so its end is polled to restore the BAT. One watch per handler, on the modifier that sets the BAT now.
function modifier_bat_handler:WatchExpiry(mod)
	local duration = mod and mod:GetRemainingTime()
	self.expiring_modifier = duration and duration > 0 and mod or nil
	if not self.expiring_modifier or self.expiry_timer then return end

	self.expiry_timer = Timers:CreateTimer(0, function()
		if self:IsNull() then return end
		local watched = self.expiring_modifier
		if watched and not watched:IsNull() then return 0 end
		self.expiry_timer = nil
		if watched then self:RecalculateBAT() end
	end)
end

-- modifiers that reduce BAT without going through lua
modifier_bat_handler.vanillaBATmodifiers = {
	modifier_alchemist_chemical_rage = true,
	modifier_snapfire_lil_shredder_buff = true,
	modifier_troll_warlord_berserkers_rage = true,
	modifier_lone_druid_true_form = true,
	modifier_broodmother_insatiable_hunger = true,
}

function modifier_bat_handler:CalculateBAT(selectedModifier, name)
	-- If this is a lua modifier that is reducing base attack time
	if selectedModifier.GetModifierBaseAttackTimeConstant ~= nil then
		local bat = selectedModifier:GetModifierBaseAttackTimeConstant()
		if bat ~= nil then return bat end
	end

	-- If this is a non-lua modifier (reduces BAT without going through lua :/)
	if self.vanillaBATmodifiers[name or selectedModifier:GetName()] then
		local modifier_ability = selectedModifier:GetAbility()
		if modifier_ability and not modifier_ability:IsNull() then
			return modifier_ability:GetSpecialValueFor("base_attack_time")
		end
	end

	return self.herobat
end
