-- DISABLED (perf hit) --
-- if you would ever want to filter / modify damage - reconsider, period
-- (rewrite ability, if needed)

function Filters:DamageFilter(event)
	local target = event.entindex_victim_const and EntIndexToHScript(event.entindex_victim_const)
	local attacker = event.entindex_attacker_const and EntIndexToHScript(event.entindex_attacker_const)
	local ability = event.entindex_inflictor_const and EntIndexToHScript(event.entindex_inflictor_const)

	if event.damage and target and not target:IsNull() and target:IsAlive() and attacker and not attacker:IsNull() and attacker:IsAlive() and attacker.GetPlayerOwnerID and attacker:GetPlayerOwnerID() then
		local attacker_id = attacker:GetPlayerOwnerID()

		if attacker_id >= 0 then
			if target.IsRealHero and target:IsRealHero() then
				EndGameStats:Add_HeroDamage(attacker_id, event.damage)
			end
		end
	end

	return true
end


-- Configurable FFA only (Filters:Init): fountain protection, kept to two modifier lookups per damage instance.
-- Protected units deal no damage and take none: the modifier blocks incoming damage itself,
-- and the victim check here also catches HP removal and other flagged damage.
function Filters:FountainDamageFilter(event)
	local attacker = event.entindex_attacker_const and EntIndexToHScript(event.entindex_attacker_const)
	if FountainProtection:Protects(attacker) then return false end

	local victim = event.entindex_victim_const and EntIndexToHScript(event.entindex_victim_const)
	return not FountainProtection:Protects(victim)
end
