DOTA_UNIT_ORDER_CAST_POSITION, DOTA_UNIT_ORDER_CAST_TARGET, DOTA_UNIT_ORDER_CAST_TARGET_TREE = 5, 6, 7
DOTA_UNIT_ORDER_CAST_NO_TARGET, DOTA_UNIT_ORDER_CAST_TOGGLE, DOTA_UNIT_ORDER_MOVE_ITEM = 8, 9, 19
DOTA_ITEM_SLOT_1, DOTA_ITEM_SLOT_7, DOTA_ITEM_SLOT_9, DOTA_STASH_SLOT_6 = 0, 6, 8, 14

local locked, enabled = true, true
HostOptions = {GetOption = function(_, name) return name == "backpack_items" and enabled end}
setmetatable(HostOptions, {__index = function(_, key) if key == "locked" then return locked end end})
local neutral = {item_trinket = "ItemIsNeutralActiveDrop", item_enhancement = "ItemIsNeutralPassiveDrop"}
local notInBackpack = {item_rapier = true, item_gem = true}
GetItemKV = function(name, key) return neutral[name] == key and 1 or nil end
local gameMode = {}
function gameMode:SetCustomBackpackSwapCooldown(value) self.swap = value end
function gameMode:SetCustomBackpackCooldownPercent(value) self.percent = value end
GameRules = {GetGameModeEntity = function() return gameMode end}
local timers = {}
Timers = {CreateTimer = function(_, _, callback) table.insert(timers, callback) end}
local function tick()
	local current = timers
	timers = {}
	for _, callback in ipairs(current) do
		if callback() then table.insert(timers, callback) end
	end
end
local errors = {}
DisplayError = function(player_id, message) table.insert(errors, {player_id, message}) end
IsValidEntity = function(entity) return entity ~= nil and not entity.removed end
local heroes = {}
HeroList = {GetAllHeroes = function() return heroes end}

local function Item(name, fields)
	local item = {name = name, state = 0, toggle = false, usable = false}
	for key, value in pairs(fields or {}) do item[key] = value end
	function item:GetAbilityName() return self.name end
	function item:GetItemSlot() return self.slot end
	function item:GetItemState() return self.state end
	function item:OnEquip() self.state = 1 end
	function item:OnUnequip() self.state = 0 end
	function item:IsItem() return true end
	function item:IsToggle() return self.toggle end
	function item:GetCooldownTimeRemaining() return self.cd or 0 end
	function item:StartCooldown(value) self.cd = value end
	function item:CanBeUsedOutOfInventory() return self.usable end
	function item:SetCanBeUsedOutOfInventory(value) self.usable = value end
	return item
end

local function Unit(fields)
	local unit = {slots = {}, hero = true, illusion = false}
	for key, value in pairs(fields or {}) do unit[key] = value end
	function unit:Give(slot, item) item.slot = slot self.slots[slot] = item return item end
	-- Engine behaviour: a swap across the main/backpack boundary unequips both items
	-- (the engine re-equips the main slot one only later).
	function unit:SwapItems(a, b)
		local first, second = self.slots[a], self.slots[b]
		-- The engine refuses swaps that would put a main-slot-only item into the backpack.
		for _, pair in ipairs({{first, b}, {second, a}}) do
			if pair[1] and pair[2] >= 6 and notInBackpack[pair[1].name] then return end
		end
		self.slots[a], self.slots[b] = second, first
		for _, moved in ipairs({{first, a, b}, {second, b, a}}) do
			local item, from, to = moved[1], moved[2], moved[3]
			if item then
				item.slot = to
				if (from < 6) ~= (to < 6) then item.state = 0 end
			end
		end
		self.swaps = (self.swaps or 0) + 1
	end
	function unit:GetItemInSlot(slot) return self.slots[slot] end
	function unit:HasInventory() return true end
	function unit:IsHero() return self.hero end
	function unit:IsIllusion() return self.illusion end
	return unit
end

dofile("scripts/vscripts/game/backpack_items.lua")

-- Rules only apply once the host locks an enabled option.
for _, case in ipairs({{false, true}, {true, false}}) do
	locked, enabled = case[1], case[2]
	BackpackItems:ApplyRules()
	assert(gameMode.swap == nil and #timers == 0, "disabled rules must not configure the backpack")
	assert(BackpackItems:FilterOrder({order_type = DOTA_UNIT_ORDER_CAST_NO_TARGET}, Unit(), Item("item_bkb")) == nil)
end
locked, enabled = true, true
BackpackItems:ApplyRules()
BackpackItems:ApplyRules()
assert(gameMode.swap == 0 and gameMode.percent == 1, "swap delay removed and backpack cooldowns at full rate")
assert(#timers == 1, "one reconcile loop")

-- Reconcile: first copy of each name works; excluded items stay inert; main slots untouched.
local hero = Unit()
heroes = {hero}
local mainItem = hero:Give(0, Item("item_branches"))
local first = hero:Give(6, Item("item_butterfly"))
local second = hero:Give(7, Item("item_butterfly"))
local bkb = hero:Give(8, Item("item_black_king_bar"))
tick()
assert(first.state == 1 and bkb.state == 1, "unique backpack items are equipped")
assert(second.state == 0, "duplicate backpack item stays inactive")
assert(mainItem.state == 0, "main slot items are left to the engine")
hero:Give(6, second) hero:Give(7, first)
tick()
assert(second.state == 1 and first.state == 0, "the lowest slot copy takes over")
for _, name in ipairs({"item_sphere", "item_aeon_disk", "item_trinket", "item_enhancement", "item_recipe_butterfly"}) do
	local excluded = hero:Give(8, Item(name, {state = 1}))
	tick()
	assert(excluded.state == 0, name .. " must be inert in the backpack")
end
assert(#timers == 1, "reconcile keeps running")

-- Active backpack items may be used out of the inventory: the engine casts them natively.
hero = Unit()
heroes = {hero}
local bkb = hero:Give(6, Item("item_black_king_bar"))
local copy = hero:Give(7, Item("item_black_king_bar"))
local sphere = hero:Give(8, Item("item_sphere"))
local nativeMain = hero:Give(0, Item("item_tpscroll", {usable = true})) -- flag not set by this module
tick()
assert(bkb.usable and not copy.usable and not sphere.usable, "only active backpack items can be cast")
assert(nativeMain.usable, "flags this module did not set are left alone")
hero:SwapItems(6, 9) -- into the stash
tick()
assert(not bkb.usable and copy.usable, "leaving the backpack clears the flag; the next copy takes over")
hero:SwapItems(9, 1) -- stash to a main slot
tick()
assert(not bkb.usable, "main slot items are cast by the engine without the flag")
local illusion = Unit({illusion = true})
local illusionItem = illusion:Give(6, Item("item_black_king_bar"))
heroes = {hero, illusion}
tick()
assert(illusionItem.state == 1 and not illusionItem.usable, "illusions keep backpack effects but never cast them")
heroes = {hero}

local function order(order_type, item, unit)
	errors = {}
	return BackpackItems:FilterOrder({order_type = order_type, issuer_player_id_const = 3}, unit or hero, item)
end
assert(order(DOTA_UNIT_ORDER_CAST_NO_TARGET, copy) == nil and #errors == 0, "active backpack casts are left to the engine")
assert(order(DOTA_UNIT_ORDER_CAST_TARGET, bkb) == nil, "main slot casts stay native")
local duplicate = hero:Give(8, Item("item_black_king_bar"))
assert(order(DOTA_UNIT_ORDER_CAST_NO_TARGET, duplicate) == false, "inactive copies are refused")
assert(errors[1][1] == 3 and errors[1][2] == "#backpack_items_error_inactive", "with an error for the issuing player")
local excluded = hero:Give(8, Item("item_sphere"))
assert(order(DOTA_UNIT_ORDER_CAST_TARGET, excluded) == false and errors[1][2] == "#backpack_items_error_inactive")
local armlet = hero:Give(8, Item("item_armlet", {toggle = true}))
tick()
assert(order(DOTA_UNIT_ORDER_CAST_TOGGLE, armlet) == false and errors[1][2] == "#backpack_items_error_unsupported",
	"toggles are refused: toggled effects need a main slot")
assert(order(DOTA_UNIT_ORDER_CAST_NO_TARGET, copy, Unit({hero = false, slots = {[7] = copy}})) == nil, "non-hero units stay native")
enabled = false
assert(order(DOTA_UNIT_ORDER_CAST_NO_TARGET, duplicate) == nil, "disabled option leaves orders native")
enabled = true
timers = {}
print("PASS backpack items: host lock, unique backpack equip, exclusions, native cast flag management and cast order checks")

-- Moves between main slots and the backpack are performed and re-equipped in one step.
local function move(unit, item, slot)
	return BackpackItems:FilterOrder({order_type = DOTA_UNIT_ORDER_MOVE_ITEM, entindex_target = slot}, unit, item)
end
hero = Unit()
local heart = hero:Give(0, Item("item_heart", {state = 1}))
local wand = hero:Give(6, Item("item_magic_wand", {state = 1}))
assert(move(hero, heart, 6) == false, "the order is handled by the script")
assert(heart.slot == 6 and heart.state == 1, "an item moved into the backpack never deactivates")
assert(wand.slot == 0 and wand.state == 1, "the displaced backpack item works in its main slot")
for _ = 1, 5 do -- rapid back-and-forth switching
	move(hero, heart, 0)
	assert(heart.state == 1 and wand.state == 1, "active after every switch")
	move(hero, heart, 6)
	assert(heart.state == 1 and wand.state == 1, "active after every switch")
end
local swaps = hero.swaps
assert(move(hero, wand, 1) == nil and move(hero, heart, 7) == nil, "moves within one area stay native")
assert(move(hero, heart, 9) == nil, "stash moves stay native")
assert(move(Unit({hero = false, slots = {[0] = heart}}), heart, 6) == nil, "non-hero units stay native")
assert(hero.swaps == swaps, "native moves are not performed by the script")
local sphere = hero:Give(1, Item("item_sphere", {state = 1}))
move(hero, sphere, 8)
assert(sphere.slot == 8 and sphere.state == 0, "excluded items still go inert in the backpack")
local copy = hero:Give(2, Item("item_heart", {state = 1}))
move(hero, copy, 8)
assert(copy.slot == 8 and copy.state == 0 and heart.state == 1, "a duplicate moved in stays inactive; the original keeps working")
enabled = false
assert(move(hero, heart, 0) == nil, "disabled option leaves moves native")
enabled = true
print("PASS backpack items: main/backpack moves keep items active with no gap, native moves untouched")

-- Swapping Linken's Sphere or Aeon Disk across main/backpack cools down both swapped items.
hero = Unit()
local sphere2 = hero:Give(0, Item("item_sphere", {state = 1}))
local wand2 = hero:Give(6, Item("item_magic_wand", {state = 1}))
move(hero, sphere2, 6)
assert(sphere2.cd == 6 and wand2.cd == 6, "Linken's Sphere into the backpack: both swapped items cool down")
sphere2.cd, wand2.cd = 0, 0
move(hero, sphere2, 0)
assert(sphere2.cd == 6 and wand2.cd == 6, "and back out of the backpack")
local aeon = hero:Give(7, Item("item_aeon_disk"))
local blade = hero:Give(1, Item("item_black_king_bar", {state = 1, cd = 30}))
move(hero, blade, 7)
assert(aeon.cd == 6 and blade.cd == 30, "Aeon Disk swap: a longer cooldown is never shortened")
local alone = hero:Give(8, Item("item_aeon_disk"))
hero.slots[2] = nil
move(hero, alone, 2)
assert(alone.cd == 6, "moving into an empty slot cools down only the Aeon Disk")
local plainA = hero:Give(3, Item("item_heart", {state = 1}))
local plainB = hero:Give(8, Item("item_butterfly", {state = 1}))
move(hero, plainA, 8)
assert(plainA.cd == nil and plainB.cd == nil, "ordinary swaps start no cooldown")
local inBackpack = hero:Give(6, Item("item_sphere", {cd = 0}))
move(hero, inBackpack, 7)
assert(inBackpack.cd == 0, "moves within the backpack stay native")
enabled = false
local offSphere = hero:Give(4, Item("item_sphere", {state = 1}))
assert(move(hero, offSphere, 8) == nil and offSphere.cd == nil, "disabled option leaves native swaps")
enabled = true
-- Swaps the engine refuses stay with the engine, without a swap cooldown.
local gem = hero:Give(5, Item("item_gem", {state = 1}))
local refusedSphere = hero:Give(8, Item("item_sphere"))
assert(move(hero, refusedSphere, 5) == nil and gem.slot == 5 and refusedSphere.slot == 8, "refused swap is left to the engine")
assert(gem.cd == nil and refusedSphere.cd == nil, "a refused swap starts no cooldown")
print("PASS backpack items: Linken's Sphere / Aeon Disk swaps put both swapped items on a 6 second cooldown; refused swaps stay native")
