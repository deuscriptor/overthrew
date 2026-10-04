-- An illusion's generic upgrades in one modifier (game/upgrades/illusion_generic_upgrades.lua).
-- The server gets the counts as creation keys, {generic_armor = 2, ...}, and clients as transmitted data. Both build
-- the upgrades in OnCreated and never change them, so Upgrades:AddIllusionGenericUpgrades creates a new modifier
-- instead of updating one.
-- It also carries the cosmetics of the hero's look that would need a modifier of their own (issue #31): the status
-- effect of an equipped hero effect (`status_fx`, a creation key and transmitted), and the cleanup of the illusion's
-- cosmetic particles when it dies.
require("game/upgrades/illusion_generic_upgrades")

modifier_illusion_generic_upgrades = modifier_illusion_generic_upgrades or class({})


function modifier_illusion_generic_upgrades:IsHidden() return true end
function modifier_illusion_generic_upgrades:IsPurgable() return false end
function modifier_illusion_generic_upgrades:RemoveOnDeath() return IsServer() and self:GetParent():IsIllusionGoneOnDeath() end


function modifier_illusion_generic_upgrades:OnCreated(kv)
	if IsServer() then
		self.counts = {}
		for upgrade_name in pairs(IllusionGenericUpgrades.HOSTED) do
			if kv[upgrade_name] then self.counts[upgrade_name] = kv[upgrade_name] end
		end
		self.status_fx = kv.status_fx
		self:SetHasCustomTransmitterData(true)
	end
	self:BuildUpgrades()
end


function modifier_illusion_generic_upgrades:OnDestroy()
	self:DestroyUpgrades()
	if not IsServer() then return end
	-- removed at death (RemoveOnDeath); a live illusion only gets a new host (Monkey King soldiers, hero swaps)
	local parent = self:GetParent()
	if Equipment and not parent:IsAlive() then Equipment:OnIllusionKilled(parent) end
end


function modifier_illusion_generic_upgrades:GetStatusEffectName()
	return self.status_fx
end


function modifier_illusion_generic_upgrades:BuildUpgrades()
	self:DestroyUpgrades()
	self.upgrades, self.handlers = IllusionGenericUpgrades:Build(self, self.counts)
end


function modifier_illusion_generic_upgrades:DestroyUpgrades()
	for _, upgrade in ipairs(self.upgrades or {}) do
		if upgrade.OnDestroy then upgrade:OnDestroy() end
	end
	self.upgrades, self.handlers = {}, {}
end


function modifier_illusion_generic_upgrades:AddCustomTransmitterData()
	return {counts = self.counts, status_fx = self.status_fx}
end


-- Clients get the data before OnCreated, when the modifier cannot tell its parent yet.
function modifier_illusion_generic_upgrades:HandleCustomTransmitterData(data)
	self.counts = data.counts or {}
	self.status_fx = data.status_fx
end


function modifier_illusion_generic_upgrades:DeclareFunctions()
	local functions = {}
	for _, property in ipairs(IllusionGenericUpgrades.PROPERTIES) do table.insert(functions, property[1]) end
	return functions
end


-- Each getter asks the hosted upgrades implementing it; shared (additive) properties are summed.
for _, property in ipairs(IllusionGenericUpgrades.PROPERTIES) do
	local getter = property[2]
	modifier_illusion_generic_upgrades[getter] = function(self, params)
		local handlers = self.handlers and self.handlers[getter]
		if not handlers then return end
		if not handlers[2] then return handlers[1][getter](handlers[1], params) end

		local total
		for _, upgrade in ipairs(handlers) do
			local value = upgrade[getter](upgrade, params)
			if type(value) == "number" then total = (total or 0) + value end
		end
		return total
	end
end
