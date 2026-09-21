require("game/upgrades/generic_upgrades/modifier_base_generic_upgrade")
modifier_generic_slow_resistance_upgrade = modifier_generic_slow_resistance_upgrade or class(modifier_base_generic_upgrade)


function modifier_generic_slow_resistance_upgrade:RecalculateBonusPerUpgrade()
	self:CalculateBonusPerUpgrade("slow_res")
end

function modifier_generic_slow_resistance_upgrade:OnCreated()
	self:RecalculateBonusPerUpgrade()
end

function modifier_generic_slow_resistance_upgrade:OnRefresh(old_stack_count)
	self:RecalculateBonusPerUpgrade()
end


function modifier_generic_slow_resistance_upgrade:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_SLOW_RESISTANCE_STACKING, -- GetModifierSlowResistance_Stacking
	}
end


function modifier_generic_slow_resistance_upgrade:GetModifierSlowResistance_Stacking()
	return self.bonus
end
