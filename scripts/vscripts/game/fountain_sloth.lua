-- Fountain Sloth host option: on their own fountain, heroes recover ability cooldowns at half speed. Each spawn
-- (respawn and buyback included) starts a grace period before it applies. The zone is modifier_fountain_sloth_lua.
FountainSloth = FountainSloth or {}

FountainSloth.AURA = "modifier_fountain_sloth_lua"
FountainSloth.GRACE_PERIOD = 5


function FountainSloth:IsEnabled()
	return HostOptions.locked and HostOptions:GetOption("fountain_sloth")
end


function FountainSloth:ApplyRules()
	if not self:IsEnabled() or self.applied then return end
	self.applied = true
	-- The raw event fires as the hero spawns, before the aura can catch it on the fountain.
	ListenToGameEvent("npc_spawned", Dynamic_Wrap(FountainSloth, "OnNPCSpawned"), FountainSloth)
	for _, tower in pairs(GameLoop.towers) do
		tower:AddNewModifier(tower, nil, self.AURA, {duration = -1})
	end
end


function FountainSloth:OnNPCSpawned(event)
	local unit = EntIndexToHScript(event.entindex)
	if not IsValidEntity(unit) or not unit:IsHero() or unit:IsIllusion() then return end
	unit.fountain_sloth_grace_end = GameRules:GetGameTime() + self.GRACE_PERIOD
end


function FountainSloth:InGrace(unit)
	return (unit.fountain_sloth_grace_end or 0) > GameRules:GetGameTime()
end
