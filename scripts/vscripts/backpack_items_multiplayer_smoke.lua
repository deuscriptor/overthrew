-- Local tools-mode multiplayer simulation for Backpack Items: player 0 plus bot players on
-- separate FFA teams. Rerun until "BPTEST DONE" (setup, hero pick, bot creation, then checks).
-- backpack_items_multiplayer_off_smoke runs this with BPMP_OFF set, to check the option-off behavior.
if not PlayerResource or not HostOptions then print("BPTEST waiting for the map") return end
assert(IsInToolsMode() and UsesHostRules(), "requires local FFA tools mode")
local state = GameRules:State_Get()
if state < DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP or not PlayerResource:GetPlayer(0) then print("BPTEST waiting for the player") return end
if state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
	for id, callback in pairs(EventDriver.serverside_events["Events:npc_spawned"] or {}) do
		if callback[1] == OT3Demo.OnNPCSpawned then EventDriver:CancelListener("Events:npc_spawned", id) end
	end
	GameRules:SetPreGameTime(900) -- hero swaps are only open before the horn
	PlayerDC.CheckEndGame = function() end
	HostOptions:ClaimHost(0) -- no automatic host: claim it as a player would
	assert(HostOptions:ApplyRules({PlayerID=0, single_draft=0, epic_orbs=0, turbo=0, backpack_items=BPMP_OFF and 0 or 1,
		kill_goal=50, infinite_rerolls=0, all_vision=0, invincible_wards=1, longer_wards=1, divine_rapier=1, dagon=1}))
	print("BPTEST setup applied, backpack_items=" .. tostring(not BPMP_OFF))
	return
end
local hero = PlayerResource:GetSelectedHeroEntity(0)
if not IsValidEntity(hero) then
	PlayerResource:GetPlayer(0):SetSelectedHero("npc_dota_hero_sven")
	print("BPTEST selecting hero, state " .. state)
	return
end
if not hero.initialized or state < DOTA_GAMERULES_STATE_PRE_GAME then print("BPTEST waiting for hero, state " .. state) return end

-- Bot players: real player IDs, owners and teams, no AI and no network connection.
local BOT_HEROES = {"npc_dota_hero_lina", "npc_dota_hero_axe", "npc_dota_hero_arc_warden"}
if not _G.bpmp_bots then
	_G.bpmp_bots = {}
	local teams = {}
	for _, team in ipairs(GameLoop.current_layout.teamlist) do
		if team ~= hero:GetTeam() then table.insert(teams, team) end
	end
	for index, name in ipairs(BOT_HEROES) do
		_G.bpmp_bots[index] = GameRules:AddBotPlayerWithEntityScript(name, "BP Bot " .. index, teams[index], "", false)
	end
	print("BPTEST bots created")
	return
end
for _, bot in ipairs(_G.bpmp_bots) do
	if not IsValidEntity(bot) or not bot.initialized then print("BPTEST waiting for bots") return end
end
-- The console keeps little backlog, so the finished run prints its whole log again.
if _G.bpmp_status then
	for _, line in ipairs(_G.bpmp_log or {}) do print(line) end
	print("BPTEST " .. _G.bpmp_status)
	return
end
_G.bpmp_status = "running"
_G.bpmp_log = {}
local function out(line) table.insert(_G.bpmp_log, line) print(line) end

local lina, axe, arc = unpack(_G.bpmp_bots)
local sven = hero
local failures = 0
local function check(condition, message)
	if condition then out("BPTEST ok " .. message) else failures = failures + 1 out("BPTEST CHECKFAIL " .. message) end
end
local function info(message) out("BPTEST info " .. message) end
local function count(unit, name) return #unit:FindAllModifiersByName(name) end
local function order(unit, order_type, item, target, position)
	ExecuteOrderFromTable({UnitIndex = unit:entindex(), OrderType = order_type, AbilityIndex = item and item:entindex(),
		TargetIndex = target, Position = position, Queue = false})
end
local HEX_DEBUFF = "modifier_sheepstick_debuff"
local function refresh(unit)
	unit:RemoveModifierByName(HEX_DEBUFF)
	unit:RemoveModifierByName("modifier_black_king_bar_immune")
	unit:RemoveModifierByName("modifier_invisible")
	if not unit:IsAlive() then unit:RespawnHero(false, false) end
	-- Teleported respawns keep fountain protection, which players lose by walking out.
	unit:RemoveModifierByName("modifier_fountain_invulnerability")
	unit:SetHealth(unit:GetMaxHealth())
	unit:SetMana(unit:GetMaxMana())
end
-- Six branches fill the main slots, so further items land in the backpack.
local function clear(unit)
	for slot = 0, 16 do local item = unit:GetItemInSlot(slot) if item then unit:RemoveItem(item) end end
	refresh(unit)
	for _ = 1, 6 do unit:AddItemByName("item_branches") end
end
local function give(unit, name)
	local item = unit:AddItemByName(name)
	item:EndCooldown() -- item cooldowns are shared per item type on a hero
	-- The per-tick loop would make it castable on the next tick.
	if BackpackItems:IsEnabled() then BackpackItems:Reconcile(unit) end
	return item
end
-- The hero whose inventory holds the item, if any.
local function holder(item)
	if not item or item:IsNull() then return end
	for _, unit in ipairs(HeroList:GetAllHeroes()) do
		for slot = 0, 16 do if unit:GetItemInSlot(slot) == item then return unit end end
	end
end
local CENTER = Vector(0, 0, 0)
local function place(unit, offset) FindClearSpaceForUnit(unit, CENTER + offset, true) unit:Stop() end
local function arrange()
	place(sven, Vector(0, 0, 0))
	place(lina, Vector(300, 0, 0))
	place(axe, Vector(-300, 0, 0))
	place(arc, Vector(0, 300, 0))
end

-- Record who issued each order the backpack filter sees.
local original_filter = BackpackItems.FilterOrder
local seen_orders = {}
BackpackItems.FilterOrder = function(self, event, unit, ...)
	table.insert(seen_orders, {unit = unit, issuer = event.issuer_player_id_const, order_type = event.order_type})
	return original_filter(self, event, unit, ...)
end
-- Record custom errors shown to each player.
local original_error = DisplayError
local errors = {}
DisplayError = function(player_id, message)
	table.insert(errors, {player_id = player_id, message = message})
	return original_error(player_id, message)
end
local function diag(item)
	return string.format(" [cd %.2f, mana %d, last error %s]", item:GetCooldownTimeRemaining(), sven:GetMana(), tostring(errors[#errors] and errors[#errors].message))
end
local function last_error(player_id)
	for index = #errors, 1, -1 do if errors[index].player_id == player_id then return errors[index].message end end
end

-- Native casts turn the hero toward the target first, so checks wait 0.5s after target casts.
local steps, index = {}, 0
local function step(delay, callback) table.insert(steps, {delay, callback}) end
local function finish()
	BackpackItems.FilterOrder = original_filter
	DisplayError = original_error
	_G.bpmp_status = "DONE failures=" .. failures
	for _, line in ipairs(_G.bpmp_log) do print(line) end
	print("BPTEST DONE failures=" .. failures)
end
local function run()
	index = index + 1
	local current = steps[index]
	if not current then return finish() end
	Timers:CreateTimer(current[1], function()
		local ok, err = pcall(current[2])
		if not ok then failures = failures + 1 out("BPTEST CHECKFAIL step " .. index .. " error: " .. tostring(err)) end
		run()
	end)
end

local heroes = {sven, lina, axe, arc}
local ids = {}
for _, unit in ipairs(heroes) do
	ids[unit] = unit:GetPlayerOwnerID()
	-- Idle heroes standing next to each other would auto-attack; damage disables Blink Dagger.
	unit:SetIdleAcquire(false)
	unit:SetAcquisitionRange(0)
	refresh(unit)
end

if BPMP_OFF then
	-- Option off: every player keeps native backpack behavior.
	local hexes = {}
	step(0, function()
		check(not BackpackItems:IsEnabled(), "option locked off")
		arrange()
		for _, unit in ipairs(heroes) do
			clear(unit)
			give(unit, "item_butterfly")
			hexes[unit] = give(unit, "item_sheepstick")
		end
	end)
	step(0.4, function()
		for _, unit in ipairs(heroes) do
			check(count(unit, "modifier_item_butterfly") == 0, unit:GetUnitName() .. ": backpack Butterfly inactive")
			check(not hexes[unit]:CanBeUsedOutOfInventory(), unit:GetUnitName() .. ": backpack Scythe not castable")
		end
		order(lina, DOTA_UNIT_ORDER_CAST_TARGET, hexes[lina], sven:entindex())
		order(sven, DOTA_UNIT_ORDER_CAST_TARGET, hexes[sven], axe:entindex())
	end)
	step(0.5, function()
		check(not sven:HasModifier(HEX_DEBUFF) and not axe:HasModifier(HEX_DEBUFF), "backpack casts are refused for every player")
		check(hexes[lina]:IsCooldownReady() and hexes[sven]:IsCooldownReady(), "no backpack cooldown spent")
		for _, entry in ipairs(seen_orders) do
			if entry.order_type == DOTA_UNIT_ORDER_CAST_TARGET then
				info("filter saw a cast order from issuer " .. tostring(entry.issuer))
			end
		end
		local sphere = give(lina, "item_sphere")
		order(lina, DOTA_UNIT_ORDER_MOVE_ITEM, sphere, 0)
	end)
	step(0.5, function()
		local swapped = lina:GetItemInSlot(6)
		info("native move: Linken's cooldown " .. string.format("%.2f", lina:GetItemInSlot(0):GetCooldownTimeRemaining())
			.. ", displaced branch cooldown " .. string.format("%.2f", swapped and swapped:GetCooldownTimeRemaining() or -1))
		check(GameRules:GetGameModeEntity():GetCustomBackpackSwapCooldown() ~= 0, "native backpack swap delay kept")
		for _, unit in ipairs(heroes) do clear(unit) end
	end)
	run()
	return
end

-- 1. Every hero runs its own backpack; uniqueness is per hero, not shared between players.
step(0, function()
	check(BackpackItems:IsEnabled(), "option locked on")
	arrange()
	for _, unit in ipairs(heroes) do
		clear(unit)
		give(unit, "item_butterfly")
		give(unit, "item_butterfly")
	end
end)
step(0.3, function()
	for _, unit in ipairs(heroes) do
		check(count(unit, "modifier_item_butterfly") == 1, unit:GetUnitName() .. " (player " .. ids[unit] .. "): exactly one backpack Butterfly works")
	end
	check(ids[lina] ~= 0 and ids[lina] ~= ids[axe] and lina:GetTeam() ~= sven:GetTeam() and lina:GetTeam() ~= axe:GetTeam(),
		"bots are separate players on separate teams")
	-- Cost of the per-tick reconcile with every hero carrying a full backpack.
	if os and os.clock then
		local started = os.clock()
		for _ = 1, 1000 do for _, unit in ipairs(HeroList:GetAllHeroes()) do BackpackItems:Reconcile(unit) end end
		local per_tick = (os.clock() - started)
		info(string.format("reconcile of %d heroes: %.3f ms per tick", #HeroList:GetAllHeroes(), per_tick))
		check(per_tick < 1, "reconcile of all heroes costs under 1 ms per tick")
	else
		info("os.clock unavailable; reconcile cost not measured")
	end
end)

-- 2. Casts between players.
local hexes = {}
step(0, function()
	for _, unit in ipairs(heroes) do
		clear(unit)
		hexes[unit] = give(unit, "item_sheepstick")
	end
	seen_orders = {}
end)
step(0.3, function()
	order(lina, DOTA_UNIT_ORDER_CAST_TARGET, hexes[lina], sven:entindex())
end)
step(0.5, function()
	check(sven:HasModifier(HEX_DEBUFF), "a bot's backpack hex lands on player 0's hero")
	check(not hexes[lina]:IsCooldownReady() and hexes[sven]:IsCooldownReady(), "only the caster's hex goes on cooldown")
	local issuer
	for _, entry in ipairs(seen_orders) do if entry.unit == lina then issuer = entry.issuer end end
	info("script-issued order for the bot reached the filter with issuer " .. tostring(issuer))
	-- A hexed hero is muted: the engine refuses its backpack cast, as it would a main slot one.
	local bkb = give(sven, "item_black_king_bar")
	order(sven, DOTA_UNIT_ORDER_CAST_NO_TARGET, bkb)
	check(not sven:HasModifier("modifier_black_king_bar_immune") and bkb:IsCooldownReady(), "hexed player cannot cast from the backpack")
	sven:RemoveItem(bkb)
	refresh(sven)
	-- An inactive copy is refused with an error for the issuer (script orders carry issuer -1;
	-- real player orders are covered by the client check). Harmless for a bot.
	local copy = give(lina, "item_sheepstick")
	errors = {}
	order(lina, DOTA_UNIT_ORDER_CAST_TARGET, copy, sven:entindex())
	check(last_error(-1) == "#backpack_items_error_inactive" and not sven:HasModifier(HEX_DEBUFF), "a bot's inactive copy is refused with an error, without a script error")
	lina:RemoveItem(copy)
end)
step(0.1, function()
	-- Same tick: player 0 and a bot hex each other. As with native casts, the first cast
	-- mutes the other caster, whose cast is then refused without spending its cooldown.
	hexes[axe]:EndCooldown() hexes[sven]:EndCooldown()
	order(sven, DOTA_UNIT_ORDER_CAST_TARGET, hexes[sven], axe:entindex())
	order(axe, DOTA_UNIT_ORDER_CAST_TARGET, hexes[axe], sven:entindex())
end)
step(0.5, function()
	local sven_hexed, axe_hexed = sven:HasModifier(HEX_DEBUFF), axe:HasModifier(HEX_DEBUFF)
	info("same-tick mutual hex: player 0 hexed=" .. tostring(sven_hexed) .. ", bot hexed=" .. tostring(axe_hexed))
	check(sven_hexed ~= axe_hexed, "exactly one of two simultaneous backpack hexes lands")
	local loser_hex = sven_hexed and hexes[sven] or hexes[axe]
	check(loser_hex:IsCooldownReady(), "the refused cast keeps its cooldown")
	refresh(sven) refresh(axe)
end)

-- 3. Linken's Sphere and Aeon Disk across players.
local spheres = {}
step(0, function()
	for _, unit in ipairs(heroes) do hexes[unit]:EndCooldown() end
	spheres[lina] = give(lina, "item_sphere") -- backpack: inert
	-- Axe: Linken's Sphere in a main slot (replaces a branch).
	axe:RemoveItem(axe:GetItemInSlot(0))
	spheres[axe] = give(axe, "item_sphere")
end)
step(0.3, function()
	check(spheres[axe]:GetItemSlot() < 6 and spheres[lina]:GetItemSlot() >= 6, "sphere layout: Axe main, Lina backpack")
	order(sven, DOTA_UNIT_ORDER_CAST_TARGET, hexes[sven], lina:entindex())
end)
step(0.5, function()
	check(lina:HasModifier(HEX_DEBUFF), "a bot's backpack Linken's Sphere does not block player 0's backpack hex")
	refresh(lina)
	hexes[sven]:EndCooldown()
	order(sven, DOTA_UNIT_ORDER_CAST_TARGET, hexes[sven], axe:entindex())
end)
step(0.5, function()
	check(not axe:HasModifier(HEX_DEBUFF), "a bot's ready main-slot Linken's Sphere blocks player 0's backpack hex")
	check(not spheres[axe]:IsCooldownReady(), "the block puts the bot's Linken's Sphere on cooldown")
	-- Player 0 gets a ready main-slot sphere; the bot swaps its own sphere in from the backpack.
	sven:RemoveItem(sven:GetItemInSlot(0))
	spheres[sven] = give(sven, "item_sphere")
	spheres[lina]:EndCooldown()
	order(lina, DOTA_UNIT_ORDER_MOVE_ITEM, spheres[lina], 0)
end)
step(0.5, function()
	check(spheres[lina]:GetItemSlot() == 0 and spheres[lina]:GetCooldownTimeRemaining() > 5, "bot's swap puts its Linken's Sphere on the 6 second cooldown")
	check(spheres[sven]:IsCooldownReady(), "another player's Linken's Sphere is unaffected by the bot's swap")
	hexes[sven]:EndCooldown()
	order(sven, DOTA_UNIT_ORDER_CAST_TARGET, hexes[sven], lina:entindex())
end)
step(0.5, function()
	check(lina:HasModifier(HEX_DEBUFF), "the bot's freshly swapped Linken's Sphere does not block" .. diag(hexes[sven]))
	refresh(lina)
	hexes[lina]:EndCooldown()
	order(lina, DOTA_UNIT_ORDER_CAST_TARGET, hexes[lina], sven:entindex())
end)
step(0.5, function()
	check(not sven:HasModifier(HEX_DEBUFF), "player 0's ready Linken's Sphere blocks the bot's backpack hex")
	refresh(sven)
	for _, unit in ipairs(heroes) do clear(unit) end
end)
local aeons = {}
step(0, function()
	aeons[lina] = give(lina, "item_aeon_disk") -- backpack
	axe:RemoveItem(axe:GetItemInSlot(0))
	aeons[axe] = give(axe, "item_aeon_disk") -- main slot
end)
step(0.3, function()
	for _, unit in ipairs({lina, axe}) do
		ApplyDamage({victim = unit, attacker = sven, damage = unit:GetHealth() * 0.6, damage_type = DAMAGE_TYPE_PURE})
	end
	check(not lina:HasModifier("modifier_item_aeon_disk_buff"), "a bot's backpack Aeon Disk does not trigger on player 0's damage")
	check(axe:HasModifier("modifier_item_aeon_disk_buff"), "a bot's main-slot Aeon Disk triggers (control)")
	for _, unit in ipairs(heroes) do clear(unit) end
end)

-- 4. A queued out-of-range cast is dropped when the target acts: invisibility, or a kill by a third player.
local pending_hex
step(0, function()
	arrange()
	pending_hex = give(sven, "item_sheepstick")
	place(lina, Vector(1500, 0, 0))
	AddFOWViewer(sven:GetTeamNumber(), lina:GetAbsOrigin(), 600, 3, false)
end)
step(0.5, function()
	check(sven:CanEntityBeSeenByMyTeam(lina), "target visible before the order")
	order(sven, DOTA_UNIT_ORDER_CAST_TARGET, pending_hex, lina:entindex())
end)
step(0.15, function()
	check(sven:IsMoving(), "the engine walks the hero into range for the backpack cast")
	lina:AddNewModifier(lina, nil, "modifier_invisible", {duration = 5})
end)
step(0.5, function()
	check(not lina:HasModifier(HEX_DEBUFF) and pending_hex:IsCooldownReady(), "target turning invisible: no hex and no cooldown spent")
	refresh(lina)
	arrange()
	place(axe, Vector(-1500, 0, 0))
	AddFOWViewer(sven:GetTeamNumber(), axe:GetAbsOrigin(), 600, 3, false)
end)
step(0.5, function()
	order(sven, DOTA_UNIT_ORDER_CAST_TARGET, pending_hex, axe:entindex())
end)
step(0.15, function()
	check(sven:IsMoving(), "second cast: walking into range")
	axe:Kill(nil, arc) -- a third player takes the kill
end)
step(0.3, function()
	check(not axe:IsAlive() and pending_hex:IsCooldownReady(), "target killed by a third player: no cast, no cooldown spent")
	refresh(axe)
	arrange()
	for _, unit in ipairs(heroes) do clear(unit) end
end)

-- 5. Items the engine keeps out of the backpack stay out, and refused swaps start no cooldown.
local rapier, gem, sphere_in
step(0, function()
	sven:RemoveItem(sven:GetItemInSlot(0))
	sven:RemoveItem(sven:GetItemInSlot(1))
	rapier = give(sven, "item_rapier") -- slot 0
	gem = give(sven, "item_gem") -- slot 1
	sphere_in = give(sven, "item_sphere") -- backpack
	local butterfly = give(sven, "item_butterfly") -- backpack
	check(rapier:GetItemSlot() == 0 and gem:GetItemSlot() == 1 and sphere_in:GetItemSlot() >= 6, "layout: Rapier and Gem main, Linken's backpack")
	order(sven, DOTA_UNIT_ORDER_MOVE_ITEM, rapier, 8)
	order(sven, DOTA_UNIT_ORDER_MOVE_ITEM, butterfly, 0)
	order(sven, DOTA_UNIT_ORDER_MOVE_ITEM, sphere_in, 1)
end)
step(0.5, function()
	check(rapier:GetItemSlot() == 0 and count(sven, "modifier_item_divine_rapier") == 1, "Divine Rapier cannot be moved into the backpack, either way")
	check(gem:GetItemSlot() == 1 and sphere_in:GetItemSlot() >= 6, "Gem cannot be swapped out by Linken's Sphere")
	check(sphere_in:IsCooldownReady() and gem:IsCooldownReady(), "the refused Linken's swap starts no cooldown")
	clear(sven)
end)

-- 6. Hero swap between player 0 and a bot while both carry equipped backpack items.
local swap_items = {}
step(0, function()
	swap_items.heart = give(sven, "item_heart")
	swap_items.wings = give(sven, "item_butterfly")
	swap_items.wings2 = give(sven, "item_butterfly")
	swap_items.satanic = give(lina, "item_satanic")
	swap_items.hex = give(lina, "item_sheepstick")
	place(axe, Vector(-1500, 0, 0))
	AddFOWViewer(lina:GetTeamNumber(), axe:GetAbsOrigin(), 600, 3, false)
end)
local swap_ok, swap_error
step(0.3, function()
	check(count(sven, "modifier_item_heart") == 1 and count(lina, "modifier_item_satanic") == 1, "both heroes' backpack items work before the swap")
	-- The bot queues a far backpack cast right before the swap.
	order(lina, DOTA_UNIT_ORDER_CAST_TARGET, swap_items.hex, axe:entindex())
end)
step(0.3, function()
	check(lina:IsMoving(), "bot walking into range for its backpack cast before the swap")
	local id = ids[lina]
	local get_connection = PlayerResource.GetConnectionState
	PlayerResource.GetConnectionState = function(self, player_id)
		if player_id == id then return DOTA_CONNECTION_STATE_CONNECTED end
		return get_connection(self, player_id)
	end
	swap_ok, swap_error = pcall(function()
		assert(HeroSwaps:IsOpen(), "hero swaps closed")
		assert(HeroSwaps:Handle("request", 0, {target = id}))
		assert(HeroSwaps:Handle("accept", id, {request_id = HeroSwaps.next_id}))
		HeroSwaps:Tick()
	end)
	PlayerResource.GetConnectionState = get_connection
	check(swap_ok, "hero swap executed" .. (swap_ok and "" or (": " .. tostring(swap_error))))
	check(PlayerResource:GetSelectedHeroEntity(0) == lina and PlayerResource:GetSelectedHeroEntity(id) == sven, "heroes changed owners")
	-- Same server step as the swap.
	info("right after the swap: new Heart state " .. swap_items.heart:GetItemState() .. ", Satanic state " .. swap_items.satanic:GetItemState())
	-- The item left with the inventory; like a main slot item, the old order cannot cast it.
	Timers:CreateTimer(0.2, function() info("after the swap the hero is still walking: " .. tostring(lina:IsMoving()) .. " (native order behavior)") end)
	check(count(sven, "modifier_item_satanic") == 0 or holder(swap_items.satanic) == sven, "no Satanic effect left behind")
end)
step(0.1, function()
	check(holder(swap_items.heart) == lina and swap_items.heart:GetItemSlot() >= 6, "Heart moved into the other hero's backpack")
	check(count(lina, "modifier_item_heart") == 1 and count(sven, "modifier_item_heart") == 0, "Heart works on the new hero only")
	check(count(lina, "modifier_item_butterfly") == 1 and count(sven, "modifier_item_butterfly") == 0, "Butterfly uniqueness recomputed on the new hero")
	check(count(sven, "modifier_item_satanic") == 1 and count(lina, "modifier_item_satanic") == 0, "Satanic works on the new hero only")
end)
step(2.5, function()
	check(not axe:HasModifier(HEX_DEBUFF), "the cast queued before the swap does not fire after it")
	info("hex handle now belongs to " .. holder(swap_items.hex):GetUnitName() .. ", cooldown ready " .. tostring(swap_items.hex:IsCooldownReady()))
	-- Swap back so later sections keep their heroes.
	local id = ids[lina]
	local get_connection = PlayerResource.GetConnectionState
	PlayerResource.GetConnectionState = function(self, player_id)
		if player_id == id then return DOTA_CONNECTION_STATE_CONNECTED end
		return get_connection(self, player_id)
	end
	pcall(function()
		assert(HeroSwaps:Handle("request", 0, {target = id}))
		assert(HeroSwaps:Handle("accept", id, {request_id = HeroSwaps.next_id}))
		HeroSwaps:Tick()
	end)
	PlayerResource.GetConnectionState = get_connection
	check(PlayerResource:GetSelectedHeroEntity(0) == sven, "swapped back")
	refresh(axe)
	arrange()
	for _, unit in ipairs(heroes) do clear(unit) end
end)

-- 7. Native cast behavior against other players: fountain protection, invisibility, Lotus Orb.
local p_hex, p_bkb, blade, lotus
step(0, function()
	arrange()
	p_hex = give(sven, "item_sheepstick")
	p_bkb = give(sven, "item_black_king_bar")
	sven:AddNewModifier(sven, nil, "modifier_fountain_invulnerability", {})
	order(sven, DOTA_UNIT_ORDER_CAST_NO_TARGET, p_bkb)
end)
step(0.5, function()
	check(sven:HasModifier("modifier_black_king_bar_immune"), "backpack cast works under fountain protection, like a native cast")
	check(not sven:HasModifier("modifier_fountain_invulnerability"), "the cast ends fountain protection, like a native cast")
	refresh(sven)
	-- The bot goes invisible with a main-slot Shadow Blade, then hexes player 0 from its backpack.
	lina:RemoveItem(lina:GetItemInSlot(0))
	blade = give(lina, "item_invis_sword")
	hexes[lina] = give(lina, "item_sheepstick")
	order(lina, DOTA_UNIT_ORDER_CAST_NO_TARGET, blade)
end)
step(0.5, function()
	check(lina:HasModifier("modifier_item_invisibility_edge_windwalk"), "bot invisible")
	order(lina, DOTA_UNIT_ORDER_CAST_TARGET, hexes[lina], sven:entindex())
end)
step(0.5, function()
	check(sven:HasModifier(HEX_DEBUFF), "invisible bot's backpack hex lands")
	check(not lina:HasModifier("modifier_item_invisibility_edge_windwalk"), "the backpack cast breaks the bot's invisibility")
	refresh(sven)
	lotus = give(axe, "item_lotus_orb")
	axe:AddNewModifier(axe, lotus, "modifier_item_lotus_orb_active", {duration = 6})
	p_hex:EndCooldown()
	order(sven, DOTA_UNIT_ORDER_CAST_TARGET, p_hex, axe:entindex())
end)
step(0.5, function()
	check(axe:HasModifier(HEX_DEBUFF) and sven:HasModifier(HEX_DEBUFF), "a bot's Lotus Orb reflects player 0's backpack hex" .. diag(p_hex))
	refresh(sven) refresh(axe) axe:RemoveModifierByName("modifier_item_lotus_orb_active")
	for _, unit in ipairs(heroes) do clear(unit) end
end)

-- 8. Point, target and consumable casts with every main slot full: main-slot items
-- never move and nothing lapses on any server tick.
local blink, clarity, dagon, heart, watch
step(0, function()
	arrange()
	sven:RemoveItem(sven:GetItemInSlot(0))
	heart = give(sven, "item_heart") -- slot 0
	blink = give(sven, "item_blink")
	clarity = give(sven, "item_clarity")
	dagon = give(sven, "item_dagon_5")
	watch = {lapses = 0, samples = 0, done = false}
	local max_health = sven:GetMaxHealth()
	Timers:CreateTimer(0, function()
		if watch.done then return end
		watch.samples = watch.samples + 1
		if count(sven, "modifier_item_heart") ~= 1 or sven:GetMaxHealth() < max_health or sven:GetItemInSlot(0) ~= heart then
			watch.lapses = watch.lapses + 1
		end
		return 1 / 30
	end)
end)
step(0.3, function()
	watch.start = sven:GetAbsOrigin()
	order(sven, DOTA_UNIT_ORDER_CAST_POSITION, blink, nil, watch.start + Vector(600, 0, 0))
end)
step(0.3, function()
	-- The pit around the map center shortens blinks toward it; any real jump counts.
	local moved = (sven:GetAbsOrigin() - watch.start):Length2D()
	check(moved > 150 and not blink:IsCooldownReady(), string.format("Blink Dagger blinks from the backpack (%d units)", moved) .. diag(blink))
	order(sven, DOTA_UNIT_ORDER_CAST_TARGET, clarity, sven:entindex())
end)
step(0.3, function()
	check(clarity:IsNull() or holder(clarity) == nil, "Clarity is consumed from the backpack")
	check(sven:HasModifier("modifier_clarity_potion"), "Clarity effect applied")
	local health = lina:GetHealth()
	place(lina, sven:GetAbsOrigin() + Vector(300, 0, 0))
	watch.lina_health = health
	order(sven, DOTA_UNIT_ORDER_CAST_TARGET, dagon, lina:entindex())
end)
step(0.3, function()
	check(lina:GetHealth() < watch.lina_health - 300, "Dagon damages a bot from the backpack")
	watch.done = true
	check(watch.samples >= 20 and watch.lapses == 0, "main-slot Heart never lapsed during three backpack casts (" .. watch.lapses .. " lapses in " .. watch.samples .. " ticks)")
	check(heart:GetItemSlot() == 0 and blink:GetItemSlot() >= 6 and dagon:GetItemSlot() >= 6, "main-slot items stay in place during backpack casts")
	refresh(lina)
	for _, unit in ipairs(heroes) do clear(unit) end
	arrange()
end)

-- 9. Channelled items, toggles, and the flag when an item leaves the backpack.
local meteor, armlet, moved
step(0, function()
	meteor = give(sven, "item_meteor_hammer")
	armlet = give(sven, "item_armlet")
	moved = give(sven, "item_blade_mail")
	check(moved:CanBeUsedOutOfInventory(), "active backpack items are castable")
	order(sven, DOTA_UNIT_ORDER_CAST_POSITION, meteor, nil, sven:GetAbsOrigin() + Vector(300, 0, 0))
	errors = {}
	order(sven, DOTA_UNIT_ORDER_CAST_TOGGLE, armlet)
end)
step(0.5, function()
	check(sven:IsChanneling() and not meteor:IsCooldownReady(), "Meteor Hammer channels from the backpack")
	check(not armlet:GetToggleState() and last_error(-1) == "#backpack_items_error_unsupported", "Armlet toggle refused with an error")
	sven:Stop()
	sven:SwapItems(moved:GetItemSlot(), DOTA_STASH_SLOT_1)
	BackpackItems:Reconcile(sven)
	check(moved:GetItemSlot() == DOTA_STASH_SLOT_1 and not moved:CanBeUsedOutOfInventory(), "an item moved to the stash is no longer castable")
	for _, unit in ipairs(heroes) do clear(unit) end
	arrange()
end)

-- 10. Illusions and Tempest Double.
local manta, double
step(0, function()
	give(sven, "item_butterfly") -- slot 6
	manta = give(sven, "item_manta") -- slot 7
	give(sven, "item_black_king_bar") -- slot 8
	give(arc, "item_butterfly")
	give(arc, "item_black_king_bar")
	local tempest = arc:FindAbilityByName("arc_warden_tempest_double")
	tempest:SetLevel(1)
	tempest:EndCooldown()
	arc:CastAbilityNoTarget(tempest, ids[arc])
end)
step(0.3, function()
	order(sven, DOTA_UNIT_ORDER_CAST_NO_TARGET, manta)
end)
step(0.8, function()
	check(not manta:IsCooldownReady(), "Manta Style cast from the backpack")
	local illusions = 0
	for _, unit in ipairs(HeroList:GetAllHeroes()) do
		if unit:IsIllusion() and unit:GetPlayerOwnerID() == 0 then
			illusions = illusions + 1
			local copy = unit:GetItemInSlot(6)
			info("illusion backpack slot 6: " .. (copy and (copy:GetAbilityName() .. " state " .. copy:GetItemState()) or "empty")
				.. ", Butterfly effects " .. count(unit, "modifier_item_butterfly"))
		elseif unit:IsTempestDouble() and unit:GetPlayerOwnerID() == ids[arc] then
			double = unit
		end
	end
	check(illusions == 2, "two Manta illusions (" .. illusions .. ")")
	for _, unit in ipairs(HeroList:GetAllHeroes()) do
		if unit:IsIllusion() and unit:GetPlayerOwnerID() == 0 then
			local copy = unit:GetItemInSlot(8)
			if copy then
				copy:EndCooldown()
				order(unit, DOTA_UNIT_ORDER_CAST_NO_TARGET, copy)
				_G.bpmp_illusion = unit
			end
			break
		end
	end
	check(double ~= nil, "Tempest Double spawned")
	if double then
		check(count(double, "modifier_item_butterfly") == 1, "Tempest Double's backpack Butterfly works")
		local copy
		for slot = 6, 8 do local item = double:GetItemInSlot(slot) if item and item:GetAbilityName() == "item_black_king_bar" then copy = item end end
		if copy then
			copy:EndCooldown()
			order(double, DOTA_UNIT_ORDER_CAST_NO_TARGET, copy)
		else
			info("Tempest Double has no backpack BKB")
		end
	end
end)
step(0.3, function()
	if double then check(double:HasModifier("modifier_black_king_bar_immune"), "Tempest Double casts from its backpack") end
	local illusion = _G.bpmp_illusion
	if illusion then
		local copy = illusion:GetItemInSlot(8)
		check(copy and copy:IsCooldownReady() and not illusion:HasModifier("modifier_black_king_bar_immune")
			and not copy:CanBeUsedOutOfInventory(), "a Manta illusion cannot cast its backpack BKB")
	end
	for _, unit in ipairs(HeroList:GetAllHeroes()) do
		if unit:IsIllusion() or unit:IsTempestDouble() then unit:ForceKill(false) end
	end
	for _, unit in ipairs(heroes) do clear(unit) end
	arrange()
end)
run()
