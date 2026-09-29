-- DISABLED (perf hit) --
-- Use "Events:modifier_added" with EventDriver if you need to do something with modifiers
function Filters:ModifierFilter(event)
	if DisableHelp.ModifierGainedFilter(event) == false then
		return false
	end

	local caster = event.entindex_caster_const and EntIndexToHScript(event.entindex_caster_const)
	local parent = event.entindex_caster_const and EntIndexToHScript(event.entindex_parent_const)
	local ability = event.entindex_ability_const and EntIndexToHScript(event.entindex_ability_const)
	local modifier_name = event.name_const

	return true
end


-- Configurable FFA only (Filters:Init): protected units apply no debuffs to enemies (game/fountain_protection.lua).
-- Unprotected casters cost one modifier lookup. Modifiers without an ability come from game mode code and pass.
function Filters:FountainModifierFilter(event)
	local caster = event.entindex_caster_const and EntIndexToHScript(event.entindex_caster_const)
	if not FountainProtection:GetEffect(caster) then return true end

	local parent = event.entindex_parent_const and EntIndexToHScript(event.entindex_parent_const)
	local ability = event.entindex_ability_const and EntIndexToHScript(event.entindex_ability_const)
	local modifier_name = event.name_const
	if not ability or not parent or not parent.GetTeamNumber or parent:GetTeamNumber() == caster:GetTeamNumber() then return true end
	if FountainProtection.HARMLESS_MODIFIERS[modifier_name] then return true end

	return not FountainProtection:BlocksHarm(caster, parent, ability, modifier_name)
end
