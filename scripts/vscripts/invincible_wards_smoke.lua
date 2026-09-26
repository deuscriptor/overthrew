-- Disposable tools match only. Run during setup, choose a hero, then run again.
assert(IsInToolsMode() and UsesHostRules())
if GameRules:State_Get() == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
	GameRules:SetPreGameTime(600)
	PlayerDC.CheckEndGame = function() end
	assert(HostOptions:ApplyRules({PlayerID=HostOptions:ResolveHost():GetPlayerID(),
		epic_orbs=0, single_draft=0, turbo=0, kill_goal=50, infinite_rerolls=0,
		all_vision=0, invincible_wards=1, longer_wards=0, divine_rapier=0, dagon=0}))
	print("INVINCIBLE_WARDS_SETUP_PASS")
	return
end
local hero = PlayerResource:GetSelectedHeroEntity(HostOptions:ResolveHost():GetPlayerID())
assert(IsValidEntity(hero), "Choose a hero first")
for _, name in ipairs({"item_ward_observer", "item_ward_sentry"}) do
	local item = hero:AddItemByName(name)
	hero:SetCursorPosition(hero:GetAbsOrigin() + Vector(250, 0, 0))
	item:OnSpellStart()
	hero:TakeItem(item)
	UTIL_Remove(item)
end
Timers:CreateTimer(0.5, function()
	local tested = 0
	for _, classname in ipairs({"npc_dota_ward_base", "npc_dota_ward_base_truesight"}) do
		for _, ward in ipairs(Entities:FindAllByClassname(classname)) do
			assert(ward:HasModifier("modifier_host_invincible_ward") and ward:IsInvulnerable())
			local health = ward:GetHealth()
			ward:SetTeam(DOTA_TEAM_BADGUYS)
			hero:PerformAttack(ward, true, true, true, false, false, false, true)
			ApplyDamage({victim=ward, attacker=hero, damage=10000, damage_type=DAMAGE_TYPE_PURE})
			assert(ward:IsAlive() and ward:GetHealth() == health, "Protected ward took damage")
			local lifetime = ward:FindModifierByName("modifier_item_buff_ward")
			assert(lifetime and lifetime:GetDuration() < 3600, "Protection changed lifetime")
			lifetime:SetDuration(0.5, true)
			Timers:CreateTimer(1, function()
				assert(not IsValidEntity(ward) or not ward:IsAlive(), "Protection prevented expiry")
				print("INVINCIBLE_WARDS_EXPIRY_PASS " .. classname)
			end)
			tested = tested + 1
		end
	end
	assert(tested == 2, "Expected one Observer and one Sentry")
	print("INVINCIBLE_WARDS_DAMAGE_PASS")
end)
