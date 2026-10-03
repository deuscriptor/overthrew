-- Local tools-mode check for Fountain Sloth: on their own fountain heroes recover ability cooldowns at half speed, off
-- it at the normal rate; each respawn or buyback starts a 5 s grace period; illusions are left alone.
-- Player 0 (Sven). FSLOTH_OFF (fountain_sloth_off_smoke) runs it with the option off: the fountain changes nothing.
-- Rerun until "FSLOTH DONE"; later reruns print the log again.
if not PlayerResource or not HostOptions then print("FSLOTH waiting for the map") return end
assert(IsInToolsMode(), "requires tools mode")
local off = FSLOTH_OFF == true
local state = GameRules:State_Get()
if state < DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP or not PlayerResource:GetPlayer(0) then print("FSLOTH waiting for the player") return end
if state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
	for id, callback in pairs(EventDriver.serverside_events["Events:npc_spawned"] or {}) do
		if callback[1] == OT3Demo.OnNPCSpawned then EventDriver:CancelListener("Events:npc_spawned", id) end
	end
	PlayerDC.CheckEndGame = function() end
	HostOptions:ClaimHost(0) -- no automatic host: claim it as a player would
	assert(HostOptions:ApplyRules({PlayerID=0, single_draft=0, epic_orbs=0, turbo=0, backpack_items=0, fountain_sloth=off and 0 or 1,
		kill_goal=50, infinite_rerolls=0, all_vision=1, invincible_wards=1, longer_wards=1, divine_rapier=1, dagon=1}))
	print("FSLOTH setup applied")
	return
end
local sven = PlayerResource:GetSelectedHeroEntity(0)
if not IsValidEntity(sven) then
	PlayerResource:GetPlayer(0):SetSelectedHero("npc_dota_hero_sven")
	print("FSLOTH selecting hero, state " .. state)
	return
end
if not sven.initialized or state < DOTA_GAMERULES_STATE_PRE_GAME then print("FSLOTH waiting for hero, state " .. state) return end
if state < DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
	GameRules:ForceGameStart()
	print("FSLOTH starting the game, rerun")
	return
end
sven:SetIdleAcquire(false)

_G.fsloth_log = _G.fsloth_log or {}
local function out(line) table.insert(_G.fsloth_log, line) print(line) end
local function check(condition, message)
	if not condition then _G.fsloth_failures = (_G.fsloth_failures or 0) + 1 end
	out("FSLOTH " .. (condition and "ok " or "CHECKFAIL ") .. message)
end
local EFFECT = "modifier_fountain_sloth_effect_lua"
local slowed_rate = off and 1 or 0.5
-- the sloth freezes cooldowns for every other 0.1 s, so a measurement may be off by up to 0.1 s: measure 3 s or more
local function near(value, expected) return math.abs(value - expected) <= 0.05 end
local function fountain() return GameLoop.towers[sven:GetTeam()]:GetAbsOrigin() end
local function on_fountain()
	local tower = GameLoop.towers[sven:GetTeam()]
	return (sven:GetAbsOrigin() - tower:GetAbsOrigin()):Length2D() < tower:Script_GetAttackRange() + 144
end
local away = Vector(0, 0, 0) + RandomVector(700)
local bolt = sven:FindAbilityByName("sven_storm_bolt")
bolt:SetLevel(1)
local staff = sven:FindItemInInventory("item_force_staff") or sven:AddItemByName("item_force_staff")

-- Cooldown seconds recovered per game second over `span`, for a 30 s cooldown started now.
local function measure(ability, span, callback)
	ability:EndCooldown()
	ability:StartCooldown(30)
	local start, remaining = GameRules:GetGameTime(), ability:GetCooldownTimeRemaining()
	Timers:CreateTimer(span, function()
		callback((remaining - ability:GetCooldownTimeRemaining()) / (GameRules:GetGameTime() - start))
	end)
end
local function finish()
	_G.fsloth_stage = 3
	_G.fsloth_status = (_G.fsloth_failures or 0) == 0 and "DONE" or ("FAILED " .. _G.fsloth_failures)
	print("FSLOTH " .. _G.fsloth_status)
end

local stage = _G.fsloth_stage or 0
if stage == 0 then
	FindClearSpaceForUnit(sven, fountain(), true)
	_G.fsloth_stage = 1
	out("FSLOTH Sven placed on his fountain, rerun")
	return
elseif stage == 1 then
	local leg_b, leg_c, leg_d, leg_e
	local aura_count = 0
	for _, tower in pairs(GameLoop.towers) do
		if tower:HasModifier("modifier_fountain_sloth_lua") then aura_count = aura_count + 1 end
	end
	check(aura_count == (off and 0 or table.count(GameLoop.towers)), "fountain auras: " .. aura_count)
	check(sven:HasModifier("modifier_fountain_protection_effect_lua"), "Sven is on his fountain")
	check(sven:HasModifier(EFFECT) ~= off, "on fountain: " .. (off and "no sloth" or "sloth applied"))
	if not off then
		local effect = sven:FindModifierByName(EFFECT)
		check(effect:IsDebuff() and effect:GetTexture() == "faceless_void_time_dilation", "on fountain: shown as a debuff")
	end

	-- A: on the fountain, ability cooldowns recover at half speed
	measure(bolt, 3, function(rate)
		check(near(rate, slowed_rate), string.format("A: ability on fountain recovers at %.3f per second", rate))
		-- items are not abilities: their cooldowns are untouched
		measure(staff, 3, function(item_rate)
			out(string.format("FSLOTH A: item on fountain recovers at %.3f per second", item_rate))
			check(near(item_rate, 1), "A: item cooldowns unaffected")
			leg_b()
		end)
	end)

	-- B: off the fountain the sloth ends at once and cooldowns recover normally
	leg_b = function()
		bolt:EndCooldown()
		bolt:StartCooldown(30)
		FindClearSpaceForUnit(sven, away, true)
		local left = GameRules:GetGameTime()
		Timers:CreateTimer(0, function()
			if sven:HasModifier(EFFECT) and GameRules:GetGameTime() - left < 2 then return 0.03 end
			local ended = GameRules:GetGameTime() - left
			check(not sven:HasModifier(EFFECT) and ended <= 0.35, string.format("B: sloth gone %.2f s after leaving", ended))
			measure(bolt, 3, function(rate)
				check(near(rate, 1), string.format("B: off the fountain recovers at %.3f per second", rate))
				leg_c()
			end)
		end)
	end

	-- C: respawn invulnerability doesn't hide a hero from the sloth; illusions are never slowed
	leg_c = function()
		FindClearSpaceForUnit(sven, fountain(), true)
		local illusion = CreateIllusions(sven, sven, {outgoing_damage = -100, incoming_damage = 0, duration = 20}, 1, 72, false, true)[1]
		FindClearSpaceForUnit(illusion, fountain(), true)
		Timers:CreateTimer(0.6, function()
			sven:AddNewModifier(sven, nil, "modifier_fountain_invulnerability", {})
			Timers:CreateTimer(0.6, function()
				check(sven:IsInvulnerable() and sven:HasModifier(EFFECT) ~= off, "C: invulnerable on the fountain, sloth unchanged")
				check(illusion:HasModifier("modifier_fountain_protection_effect_lua") and not illusion:HasModifier(EFFECT),
					"C: illusion on the fountain, no sloth")
				measure(bolt, 4, function(rate)
					check(near(rate, slowed_rate), string.format("C: invulnerable recovers at %.3f per second", rate))
					sven:RemoveModifierByName("modifier_fountain_invulnerability")
					illusion:ForceKill(false)
					leg_d()
				end)
			end)
		end)
	end

	-- D, E: a respawn and a buyback on the fountain each start the grace period. Sven dies on the fountain with a
	-- cooldown frozen half the time; his death must thaw it.
	local function grace_leg(label, revive, after)
		FindClearSpaceForUnit(sven, fountain(), true)
		bolt:EndCooldown()
		bolt:StartCooldown(30)
		Timers:CreateTimer(0.55, function()
			check(sven:HasModifier(EFFECT) ~= off, label .. ": dies on the fountain " .. (off and "without" or "with") .. " the sloth")
			sven:ForceKill(false) -- fountain protection blocks Kill on the own fountain
			Timers:CreateTimer(0.5, function()
				check(not sven:IsAlive() and not sven:HasModifier(EFFECT), label .. ": dead, sloth gone")
				local revived_by = revive() -- optional check that the revive, not the respawn timer, brought him back
				local requested = GameRules:GetGameTime()
				Timers:CreateTimer(0, function()
					if not sven:IsAlive() then
						if GameRules:GetGameTime() - requested < 2 then return 0.03 end
						check(false, label .. ": hero revived")
						finish()
						return
					end
					local alive = GameRules:GetGameTime()
					if revived_by then check(revived_by(), label .. ": revived by it") end
					-- respawns are invulnerable until the hero acts, which keeps fountain protection off but not the sloth
					check(on_fountain() and not sven:HasModifier(EFFECT), string.format("%s: back on the fountain (%.0f away, invulnerable: %s), no sloth yet",
						label, (sven:GetAbsOrigin() - fountain()):Length2D(), tostring(sven:IsInvulnerable())))
					-- during the grace period cooldowns recover normally
					measure(bolt, 4, function(rate)
						check(not sven:HasModifier(EFFECT) and near(rate, 1),
							string.format("%s: grace period recovers at %.3f per second", label, rate))
						Timers:CreateTimer(0, function()
							local since = GameRules:GetGameTime() - alive
							if sven:HasModifier(EFFECT) == off and since < 7 then return 0.03 end
							if off then
								check(not sven:HasModifier(EFFECT), label .. ": no sloth after the grace period")
							else
								check(sven:HasModifier(EFFECT) and since >= 4.95 and since <= 5.6,
									string.format("%s: sloth applied %.2f s after reviving", label, since))
							end
							measure(bolt, 4, function(slow_rate)
								check(near(slow_rate, slowed_rate), string.format("%s: then recovers at %.3f per second", label, slow_rate))
								after()
							end)
						end)
					end)
				end)
			end)
		end)
	end
	leg_d = function()
		grace_leg("D respawn", function() sven:RespawnHero(false, false) end, leg_e)
	end
	leg_e = function()
		grace_leg("E buyback", function()
			sven:SetBuybackCooldownTime(0)
			PlayerResource:ModifyGold(0, 20000, true, DOTA_ModifyGold_CheatCommand)
			local gold = PlayerResource:GetGold(0)
			ExecuteOrderFromTable({UnitIndex = sven:entindex(), OrderType = DOTA_UNIT_ORDER_BUYBACK})
			-- the respawn timer is short in tools mode; only a paid buyback proves the order worked
			return function() return PlayerResource:GetGold(0) < gold end
		end, finish)
	end
	_G.fsloth_stage = 2
	out("FSLOTH stage 1 done, timers running; rerun in 50 s")
	return
elseif stage == 2 then
	print("FSLOTH timers still running, rerun")
	return
end
for _, line in ipairs(_G.fsloth_log) do print(line) end
print("FSLOTH " .. _G.fsloth_status)
