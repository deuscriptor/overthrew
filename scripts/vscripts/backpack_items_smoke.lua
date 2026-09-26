-- Local tools-mode check for Backpack Items. Run in setup, again to pick a hero, then once more.
if not PlayerResource or not HostOptions then print("BPTEST waiting for the map") return end
assert(IsInToolsMode() and UsesHostRules(), "Backpack Items smoke requires local FFA tools mode")
local state = GameRules:State_Get()
if state < DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP or not PlayerResource:GetPlayer(0) then print("BPTEST waiting for the player") return end
if state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
	GameRules:SetPreGameTime(900)
	PlayerDC.CheckEndGame = function() end -- keep the single-player test alive
	assert(HostOptions:ApplyRules({PlayerID=0, single_draft=0, epic_orbs=0, turbo=0, backpack_items=1, kill_goal=50,
		infinite_rerolls=0, all_vision=0, invincible_wards=1, longer_wards=1, divine_rapier=1, dagon=1}))
	print("BPTEST setup applied")
	return
end
local hero = PlayerResource:GetSelectedHeroEntity(0)
if not IsValidEntity(hero) then
	PlayerResource:GetPlayer(0):SetSelectedHero("npc_dota_hero_sven")
	print("BPTEST selecting hero, state " .. state)
	return
end

local failures = 0
local function check(condition, message)
	if condition then print("BPTEST ok " .. message) else failures = failures + 1 print("BPTEST CHECKFAIL " .. message) end
end
local game_mode = GameRules:GetGameModeEntity()
check(BackpackItems:IsEnabled(), "option locked on")
check(game_mode:GetCustomBackpackSwapCooldown() == 0, "no backpack swap delay")
check(game_mode:GetCustomBackpackCooldownPercent() == 1, "backpack cooldowns at full rate")

local function clear()
	for slot = 0, 16 do local item = hero:GetItemInSlot(slot) if item then hero:RemoveItem(item) end end
	hero:RemoveModifierByName("modifier_black_king_bar_immune")
	for _ = 1, 6 do hero:AddItemByName("item_branches") end
	hero:SetMana(hero:GetMaxMana())
end
local function order(order_type, item, target)
	ExecuteOrderFromTable({UnitIndex = hero:entindex(), OrderType = order_type, AbilityIndex = item:entindex(),
		TargetIndex = target, Queue = false})
end
local function count(name) return #hero:FindAllModifiersByName(name) end
local steps, index = {}, 0
local function step(delay, callback) table.insert(steps, {delay, callback}) end
local function run()
	index = index + 1
	local current = steps[index]
	if not current then print("BPTEST DONE failures=" .. failures) return end
	Timers:CreateTimer(current[1], function() current[2]() run() end)
end

local first, second, bkb, hex, axe, start
step(0, function()
	clear()
	first = hero:AddItemByName("item_butterfly")
	second = hero:AddItemByName("item_butterfly")
	bkb = hero:AddItemByName("item_black_king_bar")
end)
step(0.35, function()
	check(first:GetItemSlot() == 6 and first:GetItemState() == 1, "first backpack Butterfly works")
	check(second:GetItemState() == 0, "duplicate backpack Butterfly stays inactive")
	check(count("modifier_item_butterfly") == 1, "only one Butterfly effect from the backpack")
	check(bkb:GetItemState() == 1 and count("modifier_item_black_king_bar") == 1, "BKB passive stats from the backpack")
	bkb:EndCooldown() -- item cooldowns are shared per item type on a hero
	order(DOTA_UNIT_ORDER_CAST_NO_TARGET, bkb)
end)
step(0.3, function()
	check(hero:HasModifier("modifier_black_king_bar_immune"), "BKB active cast from the backpack")
	check(bkb:GetCooldownTimeRemaining() > 0, "backpack cast starts the cooldown")
	-- Moving a Butterfly into a main slot leaves one functioning copy in the backpack.
	order(DOTA_UNIT_ORDER_MOVE_ITEM, first, 0)
end)
step(0.35, function()
	check(first:GetItemSlot() == 0 and second:GetItemState() == 1, "remaining backpack copy takes over")
	check(count("modifier_item_butterfly") == 2, "main slot and backpack copies both work")
	order(DOTA_UNIT_ORDER_MOVE_ITEM, first, 6) -- swaps with the branch, not the other Butterfly
end)
step(0.35, function()
	check(first:GetItemState() + second:GetItemState() == 1, "back in the backpack, duplicates are unique again")
	check(count("modifier_item_butterfly") == 1, "one Butterfly effect after moving back")
	clear()
	hero:AddItemByName("item_sphere")
	hero:AddItemByName("item_aeon_disk")
	hex = hero:AddItemByName("item_sheepstick")
end)
step(0.35, function()
	check(count("modifier_item_sphere") == 0, "Linken's Sphere is inert in the backpack")
	check(count("modifier_item_aeon_disk") == 0, "Aeon Disk is inert in the backpack")
	check(hex:GetItemState() == 1, "Scythe of Vyse works from the backpack")
	local enemy_team = hero:GetTeamNumber() == DOTA_TEAM_BADGUYS and DOTA_TEAM_GOODGUYS or DOTA_TEAM_BADGUYS
	-- Away from the fountain, which would kill the target.
	FindClearSpaceForUnit(hero, Vector(0, 0, 0), true)
	hex:EndCooldown()
	start = hero:GetAbsOrigin()
	axe = CreateUnitByName("npc_dota_hero_axe", start + Vector(1400, 0, 0), true, nil, nil, enemy_team)
end)
step(0.2, function()
	print("BPTEST info target visible without vision source: " .. tostring(hero:CanEntityBeSeenByMyTeam(axe)))
	-- A player can only target what they see; grant vision like a ward would.
	AddFOWViewer(hero:GetTeamNumber(), axe:GetAbsOrigin(), 800, 6, false)
end)
step(0.2, function() order(DOTA_UNIT_ORDER_CAST_TARGET, hex, axe:entindex()) end)
step(3.5, function()
	check(axe:HasModifier("modifier_sheepstick_debuff"), "out-of-range target: hero walks in and hexes")
	check((hero:GetAbsOrigin() - start):Length2D() > 300, "hero approached the target")
	check(hex:GetCooldownTimeRemaining() > 0, "hex cooldown started")
	UTIL_Remove(axe)
	clear()
end)

-- Rapid switching: sample every server tick while items bounce between a main slot and the backpack.
local heart, wings, lapses, samples
step(0, function()
	clear()
	-- Distinct main-slot items, so the ones displaced into the backpack are not duplicates.
	hero:RemoveItem(hero:GetItemInSlot(0)) hero:RemoveItem(hero:GetItemInSlot(1))
	hero:AddItemByName("item_ogre_axe") -- slot 0
	hero:AddItemByName("item_blade_of_alacrity") -- slot 1
	heart = hero:AddItemByName("item_heart") -- slot 6 (backpack)
	wings = hero:AddItemByName("item_butterfly") -- slot 7 (backpack)
end)
step(0.35, function()
	lapses, samples = 0, 0
	local maxHealth, strength, agility = hero:GetMaxHealth(), hero:GetStrength(), hero:GetAgility()
	local moves = 0
	Timers:CreateTimer(0, function()
		samples = samples + 1
		if count("modifier_item_heart") ~= 1 or count("modifier_item_butterfly") ~= 1 or hero:GetMaxHealth() < maxHealth
			or hero:GetStrength() < strength or hero:GetAgility() < agility then
			lapses = lapses + 1
		end
		if moves >= 10 then return end
		moves = moves + 1
		-- Alternate: into main slot 0, then back into the backpack (each swap displaces a branch).
		order(DOTA_UNIT_ORDER_MOVE_ITEM, heart, moves % 2 == 1 and 0 or 6)
		order(DOTA_UNIT_ORDER_MOVE_ITEM, wings, moves % 2 == 1 and 1 or 7)
		return 1 / 30
	end)
end)
step(0.6, function()
	check(samples >= 10, "sampled every server tick during 10 rapid switches (" .. samples .. " samples)")
	check(lapses == 0, "moved items (Heart, Butterfly and the displaced Ogre Axe/Blade) never lapse (" .. lapses .. " lapses)")
	check(heart:GetItemSlot() == 6 and wings:GetItemSlot() == 7, "items end back in the backpack")
	clear()
end)

-- Linken's Sphere / Aeon Disk swaps put both swapped items on a 6 second cooldown.
local sphere, aeon, enemy, enemyHex
step(0, function()
	clear()
	sphere = hero:AddItemByName("item_sphere") -- slot 6 (backpack)
	aeon = hero:AddItemByName("item_aeon_disk") -- slot 7 (backpack)
	sphere:EndCooldown() aeon:EndCooldown()
	for slot = 0, 1 do hero:GetItemInSlot(slot):EndCooldown() end
end)
step(0.3, function()
	order(DOTA_UNIT_ORDER_MOVE_ITEM, sphere, 0)
	order(DOTA_UNIT_ORDER_MOVE_ITEM, aeon, 1)
end)
step(0.2, function()
	local function cooling(item) local left = item:GetCooldownTimeRemaining() return left > 5 and left <= 6 end
	check(sphere:GetItemSlot() == 0 and cooling(sphere), "Linken's Sphere swapped in: 6 second cooldown")
	check(cooling(hero:GetItemInSlot(6)), "the item swapped with Linken's Sphere: 6 second cooldown")
	check(aeon:GetItemSlot() == 1 and cooling(aeon), "Aeon Disk swapped in: 6 second cooldown")
	check(cooling(hero:GetItemInSlot(7)), "the item swapped with Aeon Disk: 6 second cooldown")
	-- A freshly swapped Linken's Sphere cannot block; a ready one can.
	local enemy_team = hero:GetTeamNumber() == DOTA_TEAM_BADGUYS and DOTA_TEAM_GOODGUYS or DOTA_TEAM_BADGUYS
	enemy = CreateUnitByName("npc_dota_hero_axe", hero:GetAbsOrigin() + Vector(250, 0, 0), true, nil, nil, enemy_team)
	enemyHex = enemy:AddItemByName("item_sheepstick")
	enemy:SetCursorCastTarget(hero)
	enemyHex:OnSpellStart()
	check(hero:HasModifier("modifier_sheepstick_debuff"), "enemy hex is not blocked during the swap cooldown")
	hero:RemoveModifierByName("modifier_sheepstick_debuff")
	sphere:EndCooldown()
	enemy:SetCursorCastTarget(hero)
	enemyHex:OnSpellStart()
	check(not hero:HasModifier("modifier_sheepstick_debuff"), "a ready Linken's Sphere still blocks (control)")
	hero:RemoveModifierByName("modifier_sheepstick_debuff")
	UTIL_Remove(enemy)
	clear()
end)
run()
