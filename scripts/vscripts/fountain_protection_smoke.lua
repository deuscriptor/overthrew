-- Local tools-mode check for fountain protection: on their own fountain units are disarmed, deal no damage (debuffs
-- still land), are untargetable by enemies and take no damage; all of it ends as soon as they leave.
-- Player 0 (Sven) plus one bot on another FFA team, and two neutral dummies.
-- Rerun until "FPROT DONE"; later reruns print the log again.
if not PlayerResource or not HostOptions then print("FPROT waiting for the map") return end
assert(IsInToolsMode(), "requires tools mode")
local state = GameRules:State_Get()
if state < DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP or not PlayerResource:GetPlayer(0) then print("FPROT waiting for the player") return end
if state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
	for id, callback in pairs(EventDriver.serverside_events["Events:npc_spawned"] or {}) do
		if callback[1] == OT3Demo.OnNPCSpawned then EventDriver:CancelListener("Events:npc_spawned", id) end
	end
	PlayerDC.CheckEndGame = function() end
	HostOptions:ClaimHost(0) -- no automatic host: claim it as a player would
	assert(HostOptions:ApplyRules({PlayerID=0, single_draft=0, epic_orbs=0, turbo=0, backpack_items=0, fountain_sloth=1,
		kill_goal=50, infinite_rerolls=0, all_vision=1, invincible_wards=1, longer_wards=1, divine_rapier=1, dagon=1}))
	print("FPROT setup applied")
	return
end
local sven = PlayerResource:GetSelectedHeroEntity(0)
if not IsValidEntity(sven) then
	PlayerResource:GetPlayer(0):SetSelectedHero("npc_dota_hero_sven")
	print("FPROT selecting hero, state " .. state)
	return
end
if not sven.initialized or state < DOTA_GAMERULES_STATE_PRE_GAME then print("FPROT waiting for hero, state " .. state) return end
if not _G.fprot_bot then
	for _, team in ipairs(GameLoop.current_layout.teamlist) do
		if team ~= sven:GetTeam() then
			_G.fprot_bot = GameRules:AddBotPlayerWithEntityScript("npc_dota_hero_pudge", "Protection Bot", team, "", false)
			break
		end
	end
	print("FPROT bot created")
	return
end
local pudge = _G.fprot_bot
if not IsValidEntity(pudge) or not pudge.initialized then print("FPROT waiting for bot") return end
pudge:SetIdleAcquire(false)
sven:SetIdleAcquire(false)

_G.fprot_log = _G.fprot_log or {}
local function out(line) table.insert(_G.fprot_log, line) print(line) end
local function check(condition, message)
	if not condition then _G.fprot_failures = (_G.fprot_failures or 0) + 1 end
	out("FPROT " .. (condition and "ok " or "CHECKFAIL ") .. message)
end
local EFFECT = "modifier_fountain_protection_effect_lua"
local function own_fountain(unit) return GameLoop.towers[unit:GetTeam()]:GetAbsOrigin() end
local function effect() return sven:FindModifierByName(EFFECT) end
-- the look: native fountain invulnerability status effect plus a dark tint on the model
local function dark() return effect() ~= nil and sven:GetRenderColor().x == 40 end
local function normal() return effect() == nil and sven:GetRenderColor().x == 255 end
-- true when the damage changed the victim's health; health is restored afterwards
local function hurts(attacker, victim, damage_type, flags, ability)
	victim:SetHealth(victim:GetMaxHealth())
	local before = victim:GetHealth()
	ApplyDamage({victim = victim, attacker = attacker, damage = 100, damage_type = damage_type, damage_flags = flags or DOTA_DAMAGE_FLAG_NONE, ability = ability})
	local changed = victim:GetHealth() < before
	victim:SetHealth(victim:GetMaxHealth())
	return changed
end
local function hurts_any(attacker, victim, ability)
	return hurts(attacker, victim, DAMAGE_TYPE_PHYSICAL, nil, ability) or hurts(attacker, victim, DAMAGE_TYPE_MAGICAL, nil, ability)
		or hurts(attacker, victim, DAMAGE_TYPE_PURE, nil, ability) or hurts(attacker, victim, DAMAGE_TYPE_PURE, DOTA_DAMAGE_FLAG_HPLOSS, ability)
end
local function hurts_all(attacker, victim)
	return hurts(attacker, victim, DAMAGE_TYPE_PHYSICAL) and hurts(attacker, victim, DAMAGE_TYPE_MAGICAL)
		and hurts(attacker, victim, DAMAGE_TYPE_PURE) and hurts(attacker, victim, DAMAGE_TYPE_PURE, DOTA_DAMAGE_FLAG_HPLOSS)
end
local function stun(target, ability, caster)
	target:AddNewModifier(caster or sven, ability, "modifier_stunned", {duration = 1})
	local stunned = target:HasModifier("modifier_stunned")
	target:RemoveModifierByName("modifier_stunned")
	return stunned
end
local function finish()
	_G.fprot_stage = 3
	_G.fprot_status = (_G.fprot_failures or 0) == 0 and "DONE" or ("FAILED " .. _G.fprot_failures)
	print("FPROT " .. _G.fprot_status)
end

local stage = _G.fprot_stage or 0
if stage == 0 then
	-- bot players added mid-game spawn at the map centre, not on their fountain
	FindClearSpaceForUnit(pudge, own_fountain(pudge), true)
	FindClearSpaceForUnit(sven, own_fountain(sven), true)
	local spot = Vector(0, 0, 0) + RandomVector(900)
	_G.fprot_dummy = CreateUnitByName("npc_dota_neutral_centaur_khan", spot, true, nil, nil, DOTA_TEAM_NEUTRALS)
	_G.fprot_other = CreateUnitByName("npc_dota_neutral_centaur_khan", spot + Vector(200, 0, 0), true, nil, nil, DOTA_TEAM_NEUTRALS)
	for _, dummy in ipairs({_G.fprot_dummy, _G.fprot_other}) do dummy:SetIdleAcquire(false) end
	_G.fprot_stage = 1
	out("FPROT units placed, rerun")
	return
elseif stage == 1 then
	local dummy, other = _G.fprot_dummy, _G.fprot_other
	local bolt = sven:FindAbilityByName("sven_storm_bolt")
	bolt:SetLevel(1)
	check(effect() ~= nil and pudge:HasModifier(EFFECT), "Sven and Pudge protected on their own fountains")
	check(not dummy:HasModifier(EFFECT) and not other:HasModifier(EFFECT), "dummies away from fountains unprotected")
	check(hurts_all(other, dummy) and stun(dummy, other:GetAbilityByIndex(0), other) == true, "control: unprotected units damage and stun each other")
	check(sven:IsDisarmed() and sven:IsUntargetableFrom(dummy) and sven:IsUntargetableFrom(pudge), "on fountain: disarmed, untargetable by enemies")
	check(not hurts_any(dummy, sven), "on fountain: takes no damage (all types, HP removal)")
	check(not hurts_any(sven, dummy) and not hurts_any(sven, pudge) and not hurts_any(sven, sven), "on fountain: deals no damage, self damage included")
	check(stun(dummy, bolt), "on fountain: applies debuffs to enemies")
	check(dark(), "on fountain: dark look")

	-- the aura has no linger: inside the zone the effect must stay the same instance, not be recreated every aura tick
	local first = effect()
	local created = first:GetCreationTime()
	Timers:CreateTimer(1, function()
		check(effect() == first and effect():GetCreationTime() == created, "on fountain: the effect stays put (no flicker)")
	end)

	local function leave(offset)
		FindClearSpaceForUnit(sven, dummy:GetAbsOrigin() + offset, true)
		return GameRules:GetGameTime()
	end
	local function on_end(left, callback)
		Timers:CreateTimer(0, function()
			if effect() then
				if GameRules:GetGameTime() - left < 2 then return 0.03 end
				check(false, "protection still on 2 s after leaving")
				finish()
			else
				callback(GameRules:GetGameTime() - left)
			end
		end)
	end
	local function go_home(callback)
		FindClearSpaceForUnit(sven, own_fountain(sven), true)
		Timers:CreateTimer(0.5, callback)
	end

	local leg_b, leg_c
	-- A: leaving ends the protection at once
	Timers:CreateTimer(1.2, function()
		local left = leave(Vector(0, 250, 0))
		on_end(left, function(ended)
			check(ended <= 0.35, string.format("A: protection ended %.2f s after leaving", ended))
			check(not sven:IsDisarmed() and not sven:IsUntargetableFrom(dummy) and normal(), "A: off the fountain: armed, targetable, normal look")
			check(hurts(sven, dummy, DAMAGE_TYPE_PHYSICAL), "A: off the fountain: deals damage")
			-- fountain rejuvenation lingers 0.5 s after leaving, and its debuff immunity also blocks pure damage
			Timers:CreateTimer(0.6, function()
				check(not sven:HasModifier("modifier_fountain_rejuvenation_effect_lua"), "A: rejuvenation linger over")
				check(hurts_all(dummy, sven) and hurts_all(sven, dummy), "A: damage of all types both ways")
				go_home(leg_b)
			end)
		end)
	end)

	-- B: back on the fountain: protected again; a real Storm Bolt cast right after leaving lands
	leg_b = function()
		check(effect() ~= nil and dark() and not hurts_any(dummy, sven) and not hurts_any(sven, dummy), "B: back on the fountain: protected, dark look")
		dummy:SetHealth(dummy:GetMaxHealth())
		leave(Vector(0, 200, 0))
		sven:SetForwardVector((dummy:GetAbsOrigin() - sven:GetAbsOrigin()):Normalized())
		sven:GiveMana(sven:GetMaxMana())
		bolt:EndCooldown()
		sven:CastAbilityOnTarget(dummy, bolt, 0)
		Timers:CreateTimer(0.9, function()
			check(not bolt:IsCooldownReady(), "B: Storm Bolt cast")
			check(dummy:IsStunned() and dummy:GetHealth() < dummy:GetMaxHealth(), "B: Storm Bolt stuns and damages")
			dummy:SetHealth(dummy:GetMaxHealth())
			go_home(leg_c)
		end)
	end

	-- C: a real orb on the edge of Sven's fountain zone. Protected Sven doesn't capture it; one step out, he does.
	leg_c = function()
		local tower = own_fountain(sven)
		local direction = (Vector(0, 0, 0) - tower):Normalized()
		direction.z = 0
		local spot = GetGroundPosition(tower + direction * 1150, nil)
		local orb = GameMode:SpawnOrbDrop(spot, UPGRADE_RARITY_COMMON, false)
		local area = orb:FindModifierByName("capture_point_area")
		if not area then check(false, "C: orb spawned") finish() return end
		FindClearSpaceForUnit(sven, tower + direction * 1080, true)
		Timers:CreateTimer(0.5, function()
			check(effect() ~= nil and not area.is_capturing and area.progress == 0, "C: protected Sven inside the zone doesn't capture")
			FindClearSpaceForUnit(sven, tower + direction * 1300, true)
			Timers:CreateTimer(0.5, function()
				check(effect() == nil and area.is_capturing and area.current_team == sven:GetTeam(), "C: one step out, Sven captures")
				area:StopPoint()
				go_home(finish)
			end)
		end)
	end
	_G.fprot_stage = 2
	out("FPROT stage 1 done, timers running; rerun in 10 s")
	return
elseif stage == 2 then
	print("FPROT timers still running, rerun")
	return
end
for _, line in ipairs(_G.fprot_log) do print(line) end
print("FPROT " .. _G.fprot_status)
