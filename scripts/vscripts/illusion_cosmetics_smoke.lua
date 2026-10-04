-- Illusion cosmetics (issue #31): player 0 Phantom Lancer with an aura and a hero effect equipped. Illusions carry
-- the hero effect's status effect in modifier_illusion_generic_upgrades instead of modifier_hero_status_fx, copy the
-- cosmetic particles, and drop them when they die (entity_killed doesn't fire for illusions). Rerun until
-- "ILLCOSM DONE"; the finished run prints its whole log again. Use a fresh session.
if not PlayerResource or not HostOptions then print("ILLCOSM waiting for the map") return end
assert(IsInToolsMode(), "requires tools mode")
local state = GameRules:State_Get()
if state < DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP or not PlayerResource:GetPlayer(0) then print("ILLCOSM waiting for the player") return end
if state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
	-- the Tools-only demo listener hands spawned units to the demo player; matches never run it
	for id, callback in pairs(EventDriver.serverside_events["Events:npc_spawned"] or {}) do
		if callback[1] == OT3Demo.OnNPCSpawned then EventDriver:CancelListener("Events:npc_spawned", id) end
	end
	GameRules:SetPreGameTime(900)
	PlayerDC.CheckEndGame = function() end
	HostOptions:ClaimHost(0)
	assert(HostOptions:ApplyRules({PlayerID=0, single_draft=0, epic_orbs=0, turbo=1, backpack_items=0, fountain_sloth=1,
		kill_goal=50, infinite_rerolls=1, all_vision=1, invincible_wards=1, longer_wards=1, divine_rapier=1, dagon=1}))
	print("ILLCOSM setup applied")
	return
end
local hero = PlayerResource:GetSelectedHeroEntity(0)
if not IsValidEntity(hero) then
	PlayerResource:GetPlayer(0):SetSelectedHero("npc_dota_hero_phantom_lancer")
	print("ILLCOSM selecting hero, state " .. state)
	return
end
if not hero.initialized or state < DOTA_GAMERULES_STATE_PRE_GAME then print("ILLCOSM waiting for hero, state " .. state) return end
if _G.illcosm_status then
	for _, line in ipairs(_G.illcosm_log or {}) do print(line) end
	print("ILLCOSM " .. _G.illcosm_status)
	return
end
_G.illcosm_status = "running"
_G.illcosm_log = {}
_G.illcosm_failures = 0
local function out(line) table.insert(_G.illcosm_log, line) print(line) end
local function check(condition, label)
	if not condition then _G.illcosm_failures = _G.illcosm_failures + 1 end
	out("ILLCOSM " .. (condition and "PASS " or "FAIL ") .. label)
end

local AURA, SKIN = "aura_green_1", "skin_constellation"
local SKIN_STATUS_FX = ITEM_DEFINITIONS[SKIN].particles[1].path

local function particles_of(unit)
	local count = 0
	for _, assets in pairs(unit._equipment_bound_assets or {}) do count = count + #(assets.particles or {}) end
	return count
end
local function host_of(unit) return unit:FindModifierByName("modifier_illusion_generic_upgrades") end

local steps = {}
local function step(delay, callback) table.insert(steps, {delay, callback}) end
local function finish(status)
	_G.illcosm_status = status
	out("ILLCOSM " .. status)
end
local function run()
	local index = 0
	local function next_step()
		index = index + 1
		local current = steps[index]
		if not current then return finish(_G.illcosm_failures == 0 and "DONE" or ("FAILED " .. _G.illcosm_failures .. " checks")) end
		Timers:CreateTimer(current[1], function()
			local ok, err = xpcall(current[2], debug.traceback)
			if not ok then return finish("FAILED " .. tostring(err)) end
			next_step()
		end)
	end
	next_step()
end

local illusions, bare, dead, alive = {}, nil, nil, nil
step(0, function()
	hero:SetIdleAcquire(false)
	hero:RemoveModifierByName("modifier_fountain_invulnerability")
	FindClearSpaceForUnit(hero, Vector(0, 0, 0), true)
	hero:Stop()
	assert(Equipment:Equip(0, AURA) and Equipment:Equip(0, SKIN))
end)
-- equipping waits for the particles to precache
step(2.0, function()
	check(hero:HasModifier("modifier_hero_status_fx"), "the hero shows the hero effect through modifier_hero_status_fx")
	local status_fx, has_particles = Equipment:GetCopiedLook(0)
	check(status_fx == SKIN_STATUS_FX and has_particles, "the copied look names the status effect and lasting particles")
	illusions = CreateIllusions(hero, hero, {outgoing_damage = -60, incoming_damage = 200, duration = 60}, 3, 72, false, true) or {}
	for _, unit in ipairs(illusions) do unit:SetIdleAcquire(false) unit:Stop() end
	check(#illusions == 3, "three illusions created")
end)
step(0.5, function()
	for index, unit in ipairs(illusions) do
		local host = host_of(unit)
		check(host ~= nil and host:GetStatusEffectName() == SKIN_STATUS_FX, "illusion " .. index .. " carries the status effect in its host")
		check(not unit:HasModifier("modifier_hero_status_fx"), "illusion " .. index .. " has no modifier_hero_status_fx")
		check(particles_of(unit) == 2, "illusion " .. index .. " copies the aura and hero effect particles (" .. particles_of(unit) .. ")")
	end
	dead, alive = illusions[1], illusions[2]
	dead:ForceKill(false)
end)
-- killed illusions stay in the world for seconds
step(0.3, function()
	check(IsValidEntity(dead) and not dead:IsAlive(), "the killed illusion is still in the world")
	check(host_of(dead) == nil, "the killed illusion dropped its host, with the status effect")
	check(particles_of(dead) == 0, "the killed illusion dropped its cosmetic particles (" .. particles_of(dead) .. " left)")
	check(particles_of(alive) == 2 and host_of(alive) ~= nil, "the other illusions keep their look")
	-- a live illusion processed again (Monkey King soldiers, hero swaps) gets a new host and keeps its particles
	Upgrades:ProcessClone(alive, hero)
	check(particles_of(alive) == 2 and host_of(alive) and host_of(alive):GetStatusEffectName() == SKIN_STATUS_FX,
		"an illusion processed again keeps its particles and status effect")
	-- without a hero effect or upgrades, an aura alone still gets a host to drop it at death
	assert(Equipment:Unequip(0, SKIN))
	bare = (CreateIllusions(hero, hero, {outgoing_damage = -60, incoming_damage = 200, duration = 60}, 1, 72, false, true) or {})[1]
	if bare then bare:SetIdleAcquire(false) bare:Stop() end
end)
step(0.5, function()
	check(bare ~= nil and host_of(bare) ~= nil and host_of(bare):GetStatusEffectName() == nil and particles_of(bare) == 1,
		"an illusion without a hero effect gets a host without a status effect, and the aura")
	bare:ForceKill(false)
end)
step(0.3, function()
	check(particles_of(bare) == 0, "its aura is dropped at death")
	for _, unit in ipairs(HeroList:GetAllHeroes()) do
		if unit:IsIllusion() and unit:IsAlive() then unit:ForceKill(false) end
	end
	Equipment:Unequip(0, AURA)
	out("ILLCOSM info check the client: illusions show the hero effect colours, killed ones none (jpeg_screenshot)")
end)
run()
