-- Fired when hero loses item from inventory
function Events:OnInventoryItemChange(event)
	local item = EntIndexToHScript(event.item_entindex) ---@type CDOTA_Item
	local hero = EntIndexToHScript(event.hero_entindex) ---@type CDOTA_BaseNPC_Hero
	-- Assembly can report only consumed components, whose handles are already gone.
	-- Check the resulting inventory after the engine has finished combining.
	HostItems:QueueInventoryCheck(hero)

	if not IsValidEntity(item) or not IsValidEntity(hero) or hero:IsIllusion() then return end
	HostItems:CheckAssembly(item, hero)
	if not event.removed and not event.dropped then print("discarded item change - not applicable to neutrals") return end

	local container = item:GetContainer()
end
