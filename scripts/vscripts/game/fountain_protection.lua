-- Fountain protection on the configurable FFA map; the zone and the 1 second linger are modifier_fountain_protection_lua.
-- Protected units deal no damage and apply no debuffs to enemies. They take no damage either, unless they try to harm
-- an enemy while lingering after leaving the fountain: that exposes them until they return or the effect ends.
-- Passive sources (auras, reactive damage) are blocked the same way but never expose.
FountainProtection = FountainProtection or {}

FountainProtection.EFFECT = "modifier_fountain_protection_effect_lua"

-- Abilities with an active part, whose harm to enemies here comes from their passive aura.
FountainProtection.PASSIVE_INFLICTORS = {
	item_radiance = true,
}
FountainProtection.PASSIVE_MODIFIERS = {
	modifier_item_radiance_debuff = true,
	modifier_item_shivas_guard_aura = true,
}
-- Applied to enemies without harming them.
FountainProtection.HARMLESS_MODIFIERS = {
	modifier_truesight = true,
}


function FountainProtection:GetEffect(unit)
	if not unit or not unit.FindModifierByName then return end
	return unit:FindModifierByName(self.EFFECT)
end


function FountainProtection:IsPassive(ability, modifier_name)
	if modifier_name and self.PASSIVE_MODIFIERS[modifier_name] then return true end
	if not ability or not ability.GetBehavior then return false end
	if self.PASSIVE_INFLICTORS[ability:GetAbilityName()] then return true end
	return bit.band(ability:GetBehavior(), DOTA_ABILITY_BEHAVIOR_PASSIVE) ~= 0
end


-- True when damage or a debuff from `source` must be dropped. An active attempt on another team exposes the source.
function FountainProtection:BlocksHarm(source, target, ability, modifier_name)
	local effect = self:GetEffect(source)
	if not effect then return false end

	local other_team = target and target ~= source and target.GetTeamNumber and target:GetTeamNumber() ~= source:GetTeamNumber()
	if other_team and not self:IsPassive(ability, modifier_name) then effect:Expose() end

	return true
end


function FountainProtection:Shields(unit)
	local effect = self:GetEffect(unit)
	return effect ~= nil and not effect:IsExposed()
end
