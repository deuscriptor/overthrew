-- Illusion performance benchmark (issue #24): player 0 Pangolier against a bot Phantom Lancer, both with a
-- late-game set of generic upgrades and items, and Backpack Items on. Rerun until "ILLPERF DONE"; the finished
-- run prints its whole log again. Times are server wall-clock milliseconds (Plat_FloatTime), so only compare runs
-- made on the same machine. Use a fresh session for each run.
if not PlayerResource or not HostOptions then print("ILLPERF waiting for the map") return end
assert(IsInToolsMode(), "requires tools mode")
local state = GameRules:State_Get()
if state < DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP or not PlayerResource:GetPlayer(0) then print("ILLPERF waiting for the player") return end
if state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
	-- the Tools-only demo listener hands spawned units to the demo player; matches never run it
	for id, callback in pairs(EventDriver.serverside_events["Events:npc_spawned"] or {}) do
		if callback[1] == OT3Demo.OnNPCSpawned then EventDriver:CancelListener("Events:npc_spawned", id) end
	end
	GameRules:SetPreGameTime(900)
	PlayerDC.CheckEndGame = function() end
	HostOptions:ClaimHost(0)
	assert(HostOptions:ApplyRules({PlayerID=0, single_draft=0, epic_orbs=0, turbo=1, backpack_items=1, fountain_sloth=1,
		kill_goal=50, infinite_rerolls=1, all_vision=1, invincible_wards=1, longer_wards=1, divine_rapier=1, dagon=1}))
	print("ILLPERF setup applied")
	return
end
local hero = PlayerResource:GetSelectedHeroEntity(0)
if not IsValidEntity(hero) then
	PlayerResource:GetPlayer(0):SetSelectedHero("npc_dota_hero_pangolier")
	print("ILLPERF selecting hero, state " .. state)
	return
end
if not hero.initialized or state < DOTA_GAMERULES_STATE_PRE_GAME then print("ILLPERF waiting for hero, state " .. state) return end
if not _G.illperf_bot then
	local team
	for _, candidate in ipairs(GameLoop.current_layout.teamlist) do
		if candidate ~= hero:GetTeam() then team = candidate break end
	end
	_G.illperf_bot = GameRules:AddBotPlayerWithEntityScript("npc_dota_hero_phantom_lancer", "Perf Bot", team, "", false)
	print("ILLPERF bot created")
	return
end
if not IsValidEntity(_G.illperf_bot) or not _G.illperf_bot.initialized then print("ILLPERF waiting for bot") return end
if _G.illperf_status then
	for _, line in ipairs(_G.illperf_log or {}) do print(line) end
	print("ILLPERF " .. _G.illperf_status)
	return
end
_G.illperf_status = "running"
_G.illperf_log = {}
local function out(line) table.insert(_G.illperf_log, line) print(line) end

local pango, lancer = hero, _G.illperf_bot
local now = Plat_FloatTime
local function fmt(value) return string.format("%.2f", value) end

-- Lua-side attribution: wall time and calls of the script paths that run per illusion.
local probes = {}
local function probe(owner, key, label)
	local original = owner and owner[key]
	if type(original) ~= "function" then out("ILLPERF info no probe for " .. label) return end
	local stats = {ms = 0, calls = 0}
	probes[label] = stats
	owner[key] = function(...)
		local started = now()
		local a, b, c = original(...)
		stats.ms = stats.ms + (now() - started) * 1000
		stats.calls = stats.calls + 1
		return a, b, c
	end
end
probe(Events, "_OnNpcInitFinished", "spawn_init")
probe(Upgrades, "ProcessClone", "process_clone")
probe(BackpackItems, "Reconcile", "backpack_reconcile")
probe(EventDriver, "Dispatch", "event_driver")
-- modifier classes live in their own script scopes; a live instance leads to the class
local bat_handler = pango:FindModifierByName("modifier_bat_handler")
local bat_handler_class = bat_handler and getmetatable(bat_handler) and getmetatable(bat_handler).__index
probe(bat_handler_class, "OnModifierAdded", "bat_handler")
probe(bat_handler_class, "RecalculateBAT", "bat_recalculate")
local function reset_probes() for _, stats in pairs(probes) do stats.ms, stats.calls = 0, 0 end end
local function probe_report()
	local labels = {}
	for label in pairs(probes) do table.insert(labels, label) end
	table.sort(labels)
	local parts = {}
	for _, label in ipairs(labels) do
		local stats = probes[label]
		if stats.calls > 0 then table.insert(parts, label .. " " .. fmt(stats.ms) .. "ms/" .. stats.calls) end
	end
	return table.concat(parts, ", ")
end

local GENERICS = {
	generic_damage = 4, generic_attack_speed = 4, generic_all_attributes = 2, generic_armor = 2,
	generic_magic_resistance = 2, generic_universal_lifesteal = 2, generic_status_res_on_disable = 2,
	generic_magic_resistance_reduction = 1, generic_manaburn = 2, generic_armor_shred = 2,
	generic_critical_strike = 2, generic_movement_speed = 2, generic_health_percentage = 2, generic_universal_shield = 1,
}
local ITEMS = {
	[lancer] = {"item_heart", "item_butterfly", "item_diffusal_blade", "item_skadi", "item_manta", "item_basher",
		"item_vitality_booster", "item_ultimate_orb", "item_point_booster"},
	[pango] = {"item_desolator", "item_skadi", "item_butterfly", "item_heart", "item_greater_crit", "item_black_king_bar"},
}
local CENTER = Vector(0, 0, 0)
local function prepare(unit)
	unit:SetIdleAcquire(false)
	for _ = unit:GetLevel(), 29 do unit:HeroLevelUp(false) end
	for slot = 0, 16 do local item = unit:GetItemInSlot(slot) if item then unit:RemoveItem(item) end end
	for _, name in ipairs(ITEMS[unit]) do unit:AddItemByName(name) end
	for name, count in pairs(GENERICS) do Upgrades:AddGenericUpgrade(unit, name, count) end
	unit:RemoveModifierByName("modifier_fountain_invulnerability")
end

local illusions = {}
local function clear_illusions()
	for _, unit in ipairs(HeroList:GetAllHeroes()) do
		if unit:IsIllusion() then unit:ForceKill(false) end
	end
	illusions = {}
end
local function spawn(count, at, facing)
	local started = now()
	illusions = CreateIllusions(lancer, lancer, {outgoing_damage = -60, incoming_damage = 200, duration = 60},
		count, 72, false, true) or {}
	local sync_ms = (now() - started) * 1000
	for index, unit in ipairs(illusions) do
		unit:SetIdleAcquire(false)
		if at then FindClearSpaceForUnit(unit, at + facing * (100 + 40 * index), true) end
		unit:Stop()
	end
	return sync_ms
end

local steps = {}
local function step(delay, callback) table.insert(steps, {delay, callback}) end
local function finish(status)
	for label in pairs(probes) do probes[label] = nil end
	_G.illperf_status = status
	out("ILLPERF " .. status)
end
local function run()
	local index = 0
	local function next_step()
		index = index + 1
		local current = steps[index]
		if not current then return finish(_G.illperf_failures == 0 and "DONE" or ("FAILED " .. _G.illperf_failures .. " checks")) end
		Timers:CreateTimer(current[1], function()
			local ok, err = xpcall(current[2], debug.traceback)
			if not ok then return finish("FAILED " .. tostring(err)) end
			next_step()
		end)
	end
	next_step()
end

local results = {}
step(0, function()
	prepare(lancer)
	prepare(pango)
	FindClearSpaceForUnit(pango, CENTER, true)
	FindClearSpaceForUnit(lancer, CENTER + Vector(0, -600, 0), true)
	pango:Stop() lancer:Stop()
	out("ILLPERF info lancer modifiers " .. #lancer:FindAllModifiers() .. ", generics " .. table.count(lancer.upgrades.generic or {}))
end)

for _, count in ipairs({0, 10, 30}) do
	local result = {count = count}
	table.insert(results, result)
	step(0.5, function()
		clear_illusions()
	end)
	step(0.5, function()
		reset_probes()
		result.spawn_sync = spawn(count, CENTER + Vector(0, 400, 0), Vector(1, 0, 0))
	end)
	-- the npc_spawned processing is deferred by a frame
	step(0.3, function()
		result.spawn_deferred = probes.spawn_init and probes.spawn_init.ms or 0
		result.spawn_probes = probe_report()
		local sample = illusions[1]
		if sample then result.illusion_modifiers = #sample:FindAllModifiers() end
		reset_probes()
	end)
	-- a second of real server ticks (Backpack Items reconcile loop)
	step(1.0, function()
		result.tick = probes.backpack_reconcile and probes.backpack_reconcile.ms or 0
		result.tick_probes = probe_report()
	end)
	step(0.1, function()
		reset_probes()
		local started = now()
		for _ = 1, 200 do
			pango:AddNewModifier(pango, nil, "modifier_rooted", {duration = 0.01})
			pango:RemoveModifierByName("modifier_rooted")
		end
		result.modifier_add = (now() - started) * 1000 / 200 * 1000
		result.modifier_probes = probe_report()
	end)
	step(0.1, function()
		reset_probes()
		lancer:SetHealth(lancer:GetMaxHealth())
		local started = now()
		for _ = 1, 200 do
			ApplyDamage({victim = lancer, attacker = pango, damage = 1, damage_type = DAMAGE_TYPE_PURE})
		end
		result.damage = (now() - started) * 1000 / 200 * 1000
		result.damage_probes = probe_report()
		lancer:SetHealth(lancer:GetMaxHealth())
	end)
	-- Swashbuckle: 4 strikes, each attacking every unit in the line (illusions die along the way)
	step(0.1, function()
		reset_probes()
		local started = now()
		local attacks = 0
		for _ = 1, 4 do
			for _, unit in ipairs(illusions) do
				if IsValidEntity(unit) and unit:IsAlive() then
					pango:PerformAttack(unit, true, true, true, false, false, false, true)
					attacks = attacks + 1
				end
			end
		end
		result.swash_sim = (now() - started) * 1000
		result.swash_attacks = attacks
		result.swash_probes = probe_report()
		for _, unit in ipairs(illusions) do
			if IsValidEntity(unit) and unit:IsAlive() then unit:Kill(nil, pango) end
		end
	end)
	-- killed illusions stay in the world for seconds
	step(0.5, function()
		lancer:SetHealth(lancer:GetMaxHealth())
		local started = now()
		for _ = 1, 200 do
			ApplyDamage({victim = lancer, attacker = pango, damage = 1, damage_type = DAMAGE_TYPE_PURE})
		end
		result.dead_damage = (now() - started) * 1000 / 200 * 1000
		local body = illusions[1]
		result.dead_modifiers = body and not body:IsNull() and #body:FindAllModifiers() or "-"
		lancer:SetHealth(lancer:GetMaxHealth())
	end)
	-- the real ability, with server frame times sampled every frame while it plays out
	step(0.5, function()
		clear_illusions()
	end)
	step(0.3, function()
		local facing = Vector(1, 0, 0)
		FindClearSpaceForUnit(pango, CENTER, true)
		pango:SetForwardVector(facing)
		pango:Stop()
		spawn(count, pango:GetAbsOrigin(), facing)
	end)
	step(0.5, function()
		reset_probes()
		local ability = pango:FindAbilityByName("pangolier_swashbuckle")
		ability:SetLevel(4)
		ability:EndCooldown()
		pango:SetMana(pango:GetMaxMana())
		local target = pango:GetAbsOrigin() + Vector(1, 0, 0) * 300
		ExecuteOrderFromTable({UnitIndex = pango:entindex(), OrderType = DOTA_UNIT_ORDER_VECTOR_TARGET_POSITION,
			AbilityIndex = ability:entindex(), Position = target + Vector(1, 0, 0) * 600, Queue = false})
		ExecuteOrderFromTable({UnitIndex = pango:entindex(), OrderType = DOTA_UNIT_ORDER_CAST_POSITION,
			AbilityIndex = ability:entindex(), Position = target, Queue = false})
		local frames, last, worst, total = 0, now(), 0, 0
		result.frames = {count = 0}
		Timers:CreateTimer(0, function()
			local current = now()
			local delta = (current - last) * 1000
			last = current
			frames = frames + 1
			total = total + delta
			if delta > worst then worst = delta end
			if frames < 60 then return 0 end
			result.frames = {count = frames, worst = worst, average = total / frames, cast = not ability:IsCooldownReady()}
		end)
	end)
	step(2.5, function()
		result.real_probes = probe_report()
		local frames = result.frames
		out(string.format("ILLPERF N=%d spawn sync %sms deferred %sms (illusion modifiers %s) | reconcile %sms/s | modifier add %sus | damage %sus | swash sim %sms/%d attacks | dead bodies damage %sus (modifiers %s) | real swash cast %s worst frame %sms avg %sms",
			count, fmt(result.spawn_sync), fmt(result.spawn_deferred), tostring(result.illusion_modifiers or "-"),
			fmt(result.tick), fmt(result.modifier_add), fmt(result.damage), fmt(result.swash_sim), result.swash_attacks,
			fmt(result.dead_damage), tostring(result.dead_modifiers),
			tostring(frames.cast), fmt(frames.worst or 0), fmt(frames.average or 0)))
		out("ILLPERF   spawn: " .. result.spawn_probes)
		out("ILLPERF   tick: " .. result.tick_probes)
		out("ILLPERF   modifier add x200: " .. result.modifier_probes)
		out("ILLPERF   damage x200: " .. result.damage_probes)
		out("ILLPERF   swash sim: " .. result.swash_probes)
		out("ILLPERF   real swash: " .. result.real_probes)
	end)
end

-- Behavior checks for the routed events and the death cleanup.
_G.illperf_failures = 0
local function check(condition, message)
	if condition then
		out("ILLPERF ok " .. message)
	else
		_G.illperf_failures = _G.illperf_failures + 1
		out("ILLPERF CHECKFAIL " .. message)
	end
end
local checked, reference
step(0.5, function()
	clear_illusions()
end)
step(0.5, function()
	-- every upgrade an illusion can host, for the stats comparison below
	for name, count in pairs({generic_spell_amp = 2, generic_status_resistance = 2, generic_slow_resistance = 1, generic_reach = 2,
		generic_heal_amp = 2, generic_item_cdr = 1, generic_primary_attribute = 2, generic_secondary_attributes = 2,
		generic_all_attributes_per_level = 1, generic_primary_attribute_per_level = 1, generic_secondary_attributes_per_level = 1}) do
		Upgrades:AddGenericUpgrade(lancer, name, count)
	end
	spawn(2)
	checked, reference = illusions[1], illusions[2]
	checked:SetHealth(checked:GetMaxHealth() * 0.5)
	reference:SetHealth(reference:GetMaxHealth() * 0.5)
	pango:SetHealth(pango:GetMaxHealth() * 0.5)
	lancer:SetHealth(lancer:GetMaxHealth() * 0.5)
end)
step(0.3, function()
	local slot = checked:GetItemInSlot(6)
	check(slot and slot:GetItemState() == 1 and checked.backpack_reconciled, "an illusion's backpack item is equipped, once")
	-- the hero has a modifier per generic upgrade, its illusion one modifier hosting them
	check(checked:HasModifier("modifier_illusion_generic_upgrades") and not checked:HasModifier("modifier_generic_armor_upgrade")
		and lancer:HasModifier("modifier_generic_armor_upgrade"), "the illusion's generic upgrades are hosted in one modifier")
	-- the reference illusion carries its generic upgrades as modifiers of their own, as before they were hosted
	reference:RemoveModifierByName("modifier_illusion_generic_upgrades")
	Upgrades:AddGenericUpgradeModifiers(reference, lancer)
end)
step(0.3, function()
	local STATS = {"GetIdealSpeed", "GetStrength", "GetAgility", "GetIntellect", "GetMaxHealth", "GetMaxMana",
		"GetStatusResistance", "GetCastRangeBonus", "Script_GetAttackRange", "GetAverageTrueAttackDamage", "GetHealthRegen",
		"GetManaRegen"}
	-- methods that take arguments
	local ARGS = {GetPhysicalArmorValue = {false}, GetSpellAmplification = {false}, GetAttackSpeed = {false}, GetIntellect = {false},
		GetAverageTrueAttackDamage = {pango}, Script_GetMagicalArmorValue = {pango:GetAbilityByIndex(0)}}
	for stat in pairs(ARGS) do table.insert(STATS, stat) end
	local function read(unit, stat)
		if ARGS[stat] then return unit[stat](unit, unpack(ARGS[stat])) end
		return unit[stat](unit)
	end
	local mismatches, hero_differences = {}, {}
	for _, stat in ipairs(STATS) do
		local hosted, separate, hero_value = read(checked, stat), read(reference, stat), read(lancer, stat)
		if math.abs(hosted - separate) > 0.01 + math.abs(separate) * 0.001 then
			table.insert(mismatches, stat .. " " .. fmt(hosted) .. "/" .. fmt(separate))
		end
		if math.abs(hero_value - separate) > 0.01 + math.abs(separate) * 0.001 then
			table.insert(hero_differences, stat .. " " .. fmt(hero_value) .. "/" .. fmt(separate))
		end
	end
	check(#mismatches == 0, "hosted upgrades give an illusion the same " .. #STATS .. " stats as upgrade modifiers ("
		.. table.concat(mismatches, ", ") .. ")")
	-- the engine applies no armor or magic resistance from Lua modifiers to illusions, hosted or not
	out("ILLPERF info hero/illusion differences: " .. table.concat(hero_differences, ", "))
	local creep = CreateUnitByName("npc_dota_neutral_kobold", checked:GetAbsOrigin() + Vector(80, 0, 0), true, nil, nil, DOTA_TEAM_NEUTRALS)
	local attacker_health = checked:GetHealth()
	checked:PerformAttack(creep, true, true, true, false, false, false, true)
	check(checked:GetHealth() > attacker_health, "a hosted upgrade works on attacks (universal lifesteal heals the illusion)")
	creep:RemoveSelf()
	-- enough damage to get through the universal shield upgrade
	local pango_health = pango:GetHealth()
	lancer:SetHealth(lancer:GetMaxHealth())
	ApplyDamage({victim = lancer, attacker = pango, damage = 1500, damage_type = DAMAGE_TYPE_PURE})
	check(pango:GetHealth() > pango_health, "universal lifesteal heals the hero on its spell damage")
	lancer:SetHealth(lancer:GetMaxHealth() * 0.5)
	local illusion_health, lancer_health = checked:GetHealth(), lancer:GetHealth()
	pango:SetHealth(pango:GetMaxHealth())
	-- (illusions deal no damage through ApplyDamage)
	ApplyDamage({victim = pango, attacker = lancer, damage = 1500, damage_type = DAMAGE_TYPE_PURE})
	check(lancer:GetHealth() > lancer_health and checked:GetHealth() == illusion_health, "a hero's lifesteal does not heal its illusion")
	checked:AddNewModifier(pango, nil, "modifier_stunned", {duration = 0.1})
	check(checked:HasModifier("modifier_generic_status_res_on_disable_bonus"), "a stunned illusion gains disable status resistance")
	local bat = pango:GetModifierStackCount("modifier_bat_handler", pango)
	Upgrades:AddGenericUpgradeModifier(pango, "generic_base_attack_time", 4)
	pango:AddNewModifier(pango, nil, "modifier_rooted", {duration = 0.01})
	local lowered = pango:GetModifierStackCount("modifier_bat_handler", pango)
	pango:RemoveModifierByName("modifier_generic_base_attack_time_upgrade")
	pango:AddNewModifier(pango, nil, "modifier_rooted", {duration = 0.01})
	check(lowered < bat and pango:GetModifierStackCount("modifier_bat_handler", pango) == bat,
		"the BAT handler follows modifiers added to its hero (" .. bat .. " -> " .. lowered .. ")")
	local lance = lancer:FindAbilityByName("phantom_lancer_spirit_lance")
	lance:SetLevel(4)
	lance:EndCooldown()
	lancer:SetMana(lancer:GetMaxMana())
	pango:RemoveModifierByName("modifier_generic_magic_resistance_reduction_target")
	lancer:CastAbilityOnTarget(pango, lance, lancer:GetPlayerOwnerID())
end)
step(1.0, function()
	check(pango:FindModifierByNameAndCaster("modifier_generic_magic_resistance_reduction_target", lancer) ~= nil,
		"a targeted spell applies magic resistance reduction")
	checked:Kill(nil, pango)
end)
step(0.3, function()
	local names = {}
	for _, modifier in pairs(checked:FindAllModifiers()) do
		local name = modifier:GetName()
		if name:find("^modifier_generic_") or name == "modifier_ability_upgrades_controller" or name == "modifier_illusion_generic_upgrades"
			or name == "modifier_primary_attribute_reader" or name == "modifier_bat_handler" then table.insert(names, name) end
	end
	check(#names == 0, "a killed illusion keeps no upgrade modifiers (" .. table.concat(names, ", ") .. ")")
	pango:SetHealth(pango:GetMaxHealth())
	lancer:SetHealth(lancer:GetMaxHealth())
	clear_illusions()
end)
run()
