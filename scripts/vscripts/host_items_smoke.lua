-- Run only in a disposable local game with a selected hero. Clears test inventory.
assert(IsInToolsMode())
local hero = PlayerResource:GetSelectedHeroEntity(0)
assert(IsValidEntity(hero))
local courier = PlayerResource:GetPreferredCourierForPlayer(0)
assert(IsValidEntity(courier))
local function clear(unit)
	for slot = 0, 20 do local item = unit:GetItemInSlot(slot); if item and slot ~= 15 then UTIL_Remove(item) end end
end
local function names(unit)
	local result = {}
	for slot = 0,20 do local item = unit:GetItemInSlot(slot); if item then result[item:GetName()] = item end end
	return result
end
local function build(unit, recipe)
	local definition = GetAbilityKeyValuesByName(recipe)
	for component in definition.ItemRequirements["01"]:gmatch("[^;]+") do unit:AddItemByName(component) end
	if tonumber(definition.ItemCost) > 0 then unit:AddItemByName(recipe) end
end
local scenarios = {
	{hero, "item_recipe_rapier", "item_rapier", "divine_rapier", false},
	{hero, "item_recipe_dagon", "item_dagon", "dagon", false},
	{hero, "item_recipe_aeon_disk", "item_aeon_disk", "aeon_disk", false},
	{courier, "item_recipe_rapier", "item_rapier", "divine_rapier", false},
	{courier, "item_recipe_dagon", "item_dagon", "dagon", false},
	{courier, "item_recipe_aeon_disk", "item_aeon_disk", "aeon_disk", false},
	{hero, "item_recipe_rapier", "item_rapier", "divine_rapier", true},
	{hero, "item_recipe_dagon", "item_dagon", "dagon", true},
	{hero, "item_recipe_aeon_disk", "item_aeon_disk", "aeon_disk", true},
	{hero, "item_recipe_radiance", "item_radiance", "divine_rapier", false},
}
local index = 0
local function nextTest()
	index = index + 1
	local test = scenarios[index]
	if not test then
		HostOptions.options.divine_rapier = true
		HostOptions.options.dagon = true
		HostOptions.options.aeon_disk = true
		clear(hero)
		clear(courier)
		print("HOST_ITEMS_ENGINE_PASS hero/courier assembly, components preserved, enabled items, shared components")
		return
	end
	local unit, recipe, result, option, enabled = unpack(test)
	clear(unit)
	HostOptions.options[option] = enabled
	local gold = hero:GetGold()
	build(unit, recipe)
	Timers:CreateTimer(0.4, function()
		local inventory = names(unit)
		local blocked = HostItems:IsDisabled(result)
		assert((inventory[result] ~= nil) == not blocked, result .. " assembly policy failed on " .. unit:GetUnitName())
		if blocked then
			local definition = GetAbilityKeyValuesByName(recipe)
			for component in definition.ItemRequirements["01"]:gmatch("[^;]+") do
				assert(inventory[component] and inventory[component]:IsCombineLocked(), component .. " not preserved")
			end
			if tonumber(definition.ItemCost) > 0 then assert(inventory[recipe], "Recipe not preserved") end
		end
		assert(hero:GetGold() == gold, "Component restoration changed gold")
		print("HOST_ITEMS_CASE_PASS", index, result, unit:GetUnitName(), enabled)
		nextTest()
	end)
end
nextTest()
