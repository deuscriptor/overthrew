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
-- Protected units deal no damage. Shielded ones also take none: the modifier blocks it itself,
-- and the victim check here also catches HP removal and other flagged damage.
function Filters:FountainDamageFilter(event)
	local victim = event.entindex_victim_const and EntIndexToHScript(event.entindex_victim_const)
	local attacker = event.entindex_attacker_const and EntIndexToHScript(event.entindex_attacker_const)

	-- the attacker goes first, so an attempt on a shielded victim still exposes it
	if attacker then
		local inflictor = event.entindex_inflictor_const and EntIndexToHScript(event.entindex_inflictor_const)
		if FountainProtection:BlocksHarm(attacker, victim, inflictor) then return false end
	end
	if FountainProtection:Shields(victim) then return false end

	return true
end
