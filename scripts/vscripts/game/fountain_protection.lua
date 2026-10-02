-- Fountain protection on the configurable FFA map; the zone is modifier_fountain_protection_lua. Protected units deal
-- no damage and take none (Filters:FountainDamageFilter).
FountainProtection = FountainProtection or {}

FountainProtection.EFFECT = "modifier_fountain_protection_effect_lua"


function FountainProtection:Protects(unit)
	return unit ~= nil and unit.HasModifier ~= nil and unit:HasModifier(self.EFFECT)
end
