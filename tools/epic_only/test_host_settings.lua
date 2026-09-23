local map = true
UsesHostRules = function() return map end
class = function(t) return t or {} end
EventDriver = {Listen = function() end}
CustomNetTables = {SetTableValue = function() end}
HOST_OPTION = {TOURNAMENT = "tournament_mode"}
HostOptions = {locked = true, options = {}}
function HostOptions:GetOption(name) return self.options[name] or false end
GameRules = {
	SetWhiteListEnabled = function(_, value) assert(not value) end,
}
KeyValues = {ItemKV = {item_branches = {}, item_epic_orb_ffa = {}, removed = "REMOVED"}}
local restricted = {"item_rapier", "item_recipe_rapier", "item_dagon", "item_recipe_dagon"}
for level = 1, 5 do table.insert(restricted, "item_dagon_" .. level) end
for _, name in ipairs(restricted) do KeyValues.ItemKV[name] = {} end
dofile("scripts/vscripts/game/host_items.lua")
dofile("scripts/vscripts/game/upgrades/rerolls.lua")
UpgradeRerolls:Init()
for _, enabled in ipairs({false, true}) do
	HostOptions.options.infinite_rerolls = enabled
	UpgradeRerolls:PreparePlayer(0)
	assert(UpgradeRerolls.current_free_rerolls[0] == (enabled and 999 or 30))
	assert(UpgradeRerolls:_ConsumeRerolls(0, 4))
	assert(UpgradeRerolls.current_free_rerolls[0] == (enabled and 995 or 26), "Allowance must not change rarity costs")
end
for _, rapier in ipairs({false, true}) do for _, dagon in ipairs({false, true}) do
	HostOptions.options.divine_rapier = rapier
	HostOptions.options.dagon = dagon
	HostItems:ApplyRules()
	assert(not HostItems:IsDisabled("item_branches") and not HostItems:IsDisabled("item_epic_orb_ffa"))
	for _, name in ipairs(restricted) do
		assert((not HostItems:IsDisabled(name)) == (HostItems:OptionForItem(name) == "divine_rapier" and rapier or HostItems:OptionForItem(name) == "dagon" and dagon))
	end
end end
local pending = {}
Timers = {CreateTimer = function(_, delay, callback) assert(delay == 0); table.insert(pending, callback) end}
IsValidEntity = function(entity) return entity and not entity.removed end
DisplayError = function() end
local disassembled = 0
local inventory = {
 DisassembleItem = function(_, item) disassembled = disassembled + 1; item.removed = true end,
 GetPlayerOwnerID = function() return 0 end,
}
local function assembled(name)
 return {GetName = function() return name end, GetCaster = function() return inventory end}
end
HostOptions.options.divine_rapier = false
local item = assembled("item_rapier")
HostItems:CheckAssembly(item, inventory)
HostItems:CheckAssembly(item, inventory)
assert(#pending == 1, "Only schedule disassembly once")
pending[1]()
assert(disassembled == 1)
HostOptions.options.divine_rapier = true
HostItems:CheckAssembly(assembled("item_rapier"), inventory)
HostItems:CheckAssembly(assembled("item_branches"), inventory)
HostItems:CheckAssembly(assembled("item_recipe_dagon"), inventory)
assert(#pending == 1, "Allowed items and components must be untouched")
HostOptions.options.divine_rapier = false
local combined = assembled("item_rapier")
inventory.GetItemInSlot = function(_, slot) if slot == 0 then return combined end end
HostItems:QueueInventoryCheck(inventory)
HostItems:QueueInventoryCheck(inventory)
assert(#pending == 2, "Inventory changes must coalesce into one scan")
pending[2]()
assert(not inventory.host_item_check_pending and #pending == 3)
pending[3]()
assert(disassembled == 2, "Result of automatic assembly must be disassembled")
local function ward(name, enabled, duration)
	HostOptions.options.longer_wards = enabled
	local remaining = duration - 0.1
	local modifier = {
		GetDuration = function() return duration end,
		GetRemainingTime = function() return remaining end,
		SetDuration = function(_, value) remaining = value end,
	}
	local sightRemaining = remaining
	local sight = {GetDuration = function() return duration end, GetRemainingTime = function() return sightRemaining end, SetDuration = function(_, value) sightRemaining = value end}
	local unit = {FindModifierByName = function(_, requested)
		if requested == "modifier_item_buff_ward" then return modifier end
		if requested == "modifier_item_ward_true_sight" and name == "npc_dota_sentry_wards" then return sight end
	end}
	HostItems:ExtendWardLifetime(unit, name)
	if name == "npc_dota_sentry_wards" then assert(sightRemaining == remaining, "Detection must last as long as the sentry") end
	HostItems:ExtendWardLifetime(unit, name)
	return remaining
end
for _, name in ipairs({"npc_dota_observer_wards", "npc_dota_sentry_wards"}) do
	assert(ward(name, true, 360) == 1079.9, "Triple once, preserving elapsed time")
	assert(ward(name, false, 360) == 359.9)
end
assert(ward("npc_dota_venomancer_plague_ward_1", true, 40) == 39.9)
map = false
HostItems:ApplyRules()
for _, name in ipairs(restricted) do assert(HostItems:IsDisabled(name), "Other maps must keep bans") end
UpgradeRerolls:PreparePlayer(0)
assert(UpgradeRerolls.current_free_rerolls[0] == 30)
assert(ward("npc_dota_observer_wards", true, 360) == 359.9)
print("PASS host settings: item toggles independent, component restoration scheduled once, other maps restricted, 999 allowance, rarity costs preserved, ward lifetime tripled once")
