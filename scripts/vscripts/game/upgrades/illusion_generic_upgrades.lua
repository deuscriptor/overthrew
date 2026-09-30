-- Generic upgrades of an illusion, hosted by one modifier (server and client).
-- The engine visits every Lua modifier of every hero unit on each attack and damage instance, and an illusion used to
-- carry one modifier per generic upgrade of its hero. modifier_illusion_generic_upgrades carries them instead: each
-- hosted upgrade runs its own modifier class as a plain object, and the host forwards the engine's calls to it.
IllusionGenericUpgrades = IllusionGenericUpgrades or {}

-- Upgrades that work hosted: hidden, with no thinker, particle effect, state, transmitted data or event of their own
-- (UnitEvents handlers work), declaring only properties listed below. The rest stay modifiers of their own, such as
-- Universal Shield and Flying Movement, which show a buff.
IllusionGenericUpgrades.HOSTED = {
	generic_all_attributes = true,
	generic_all_attributes_per_level = true,
	generic_armor = true,
	generic_armor_shred = true,
	generic_attack_speed = true,
	generic_critical_strike = true,
	generic_damage = true,
	generic_heal_amp = true,
	generic_health_percentage = true,
	generic_item_cdr = true,
	generic_magic_resistance = true,
	generic_magic_resistance_reduction = true,
	generic_manaburn = true,
	generic_movement_speed = true,
	generic_primary_attribute = true,
	generic_primary_attribute_per_level = true,
	generic_reach = true,
	generic_secondary_attributes = true,
	generic_secondary_attributes_per_level = true,
	generic_slow_resistance = true,
	generic_spell_amp = true,
	generic_status_res_on_disable = true,
	generic_status_resistance = true,
	generic_universal_lifesteal = true,
}

-- Properties of hosted upgrades and their getters. The host declares all of them: the engine asks for declared
-- functions before the modifier is created, and before the client knows which upgrades it hosts. Upgrades may share
-- only additive properties, which the host sums (test_illusion_performance.lua checks it).
IllusionGenericUpgrades.PROPERTIES = {
	{MODIFIER_PROPERTY_STATS_STRENGTH_BONUS, "GetModifierBonusStats_Strength", additive = true},
	{MODIFIER_PROPERTY_STATS_AGILITY_BONUS, "GetModifierBonusStats_Agility", additive = true},
	{MODIFIER_PROPERTY_STATS_INTELLECT_BONUS, "GetModifierBonusStats_Intellect", additive = true},
	{MODIFIER_PROPERTY_PROCATTACK_FEEDBACK, "GetModifierProcAttack_Feedback", additive = true},
	{MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS, "GetModifierPhysicalArmorBonus"},
	{MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS, "GetModifierMagicalResistanceBonus"},
	{MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT, "GetModifierAttackSpeedBonus_Constant"},
	{MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE, "GetModifierSpellAmplify_Percentage"},
	{MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT, "GetModifierMoveSpeedBonus_Constant"},
	{MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING, "GetModifierStatusResistanceStacking"},
	{MODIFIER_PROPERTY_SLOW_RESISTANCE_STACKING, "GetModifierSlowResistance_Stacking"},
	{MODIFIER_PROPERTY_EXTRA_HEALTH_PERCENTAGE, "GetModifierExtraHealthPercentage"},
	{MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE, "GetModifierPreAttack_BonusDamage"},
	{MODIFIER_PROPERTY_HEAL_AMPLIFY_PERCENTAGE_SOURCE, "GetModifierHealAmplify_PercentageSource"},
	{MODIFIER_PROPERTY_HEAL_AMPLIFY_PERCENTAGE_TARGET, "GetModifierHealAmplify_PercentageTarget"},
	{MODIFIER_PROPERTY_HP_REGEN_AMPLIFY_PERCENTAGE, "GetModifierHPRegenAmplify_Percentage"},
	{MODIFIER_PROPERTY_LIFESTEAL_AMPLIFY_PERCENTAGE, "GetModifierLifestealRegenAmplify_Percentage"},
	{MODIFIER_PROPERTY_SPELL_LIFESTEAL_AMPLIFY_PERCENTAGE, "GetModifierSpellLifestealRegenAmplify_Percentage"},
	{MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE, "GetModifierPreAttack_CriticalStrike"},
	{MODIFIER_PROPERTY_PROCATTACK_BONUS_DAMAGE_PHYSICAL, "GetModifierProcAttack_BonusDamage_Physical"},
	{MODIFIER_PROPERTY_CAST_RANGE_BONUS_STACKING, "GetModifierCastRangeBonusStacking"},
	{MODIFIER_PROPERTY_ATTACK_RANGE_BONUS, "GetModifierAttackRangeBonus"},
	{MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE, "GetModifierPercentageCooldown"},
}

IllusionGenericUpgrades.GETTERS = {}
for _, property in ipairs(IllusionGenericUpgrades.PROPERTIES) do
	IllusionGenericUpgrades.GETTERS[property[1]] = property[2]
end


-- The modifier API hosted upgrades use; the host answers for the unit.
local Hosted = {}
function Hosted:GetParent() return self.host:GetParent() end
function Hosted:GetCaster() return self.host:GetCaster() end
function Hosted:GetAbility() end
function Hosted:GetName() return self.name end
function Hosted:IsNull() return self.host:IsNull() end
function Hosted:GetStackCount() return self.stack_count end
function Hosted:SetStackCount(count) self.stack_count = count end
function Hosted:GetRemainingTime() return -1 end
function Hosted:GetDuration() return -1 end
function Hosted:GetUpgradeValueFor(value_name) return CDOTA_Modifier_Lua.GetUpgradeValueFor(self, value_name) end
function Hosted:GetPrimaryAttributeOfParent() return CDOTA_Modifier_Lua.GetPrimaryAttributeOfParent(self) end


local metatables = {}

--- The upgrade's modifier class. The linked copy lives in its own script scope, so the file is loaded again here.
function IllusionGenericUpgrades:GetClass(upgrade_name)
	local modifier_name = "modifier_" .. upgrade_name .. "_upgrade"
	if not _G[modifier_name] then
		local definition = GenericUpgrades.generic_upgrades_data[upgrade_name]
		require((definition and definition.path or DEFAULT_PATH) .. modifier_name)
	end
	return _G[modifier_name]
end


--- Creates the hosted upgrades for {upgrade_name = count}. Returns them, and per getter the upgrades implementing it.
function IllusionGenericUpgrades:Build(host, counts)
	local names = {}
	for upgrade_name in pairs(counts or {}) do table.insert(names, upgrade_name) end
	table.sort(names)

	local upgrades, handlers = {}, {}
	for _, upgrade_name in ipairs(names) do
		local class_table = self.HOSTED[upgrade_name] and self:GetClass(upgrade_name)
		if class_table then
			metatables[class_table] = metatables[class_table] or {__index = function(_, key)
				local value = class_table[key]
				if value == nil then return Hosted[key] end
				return value
			end}
			local upgrade = setmetatable({
				host = host,
				name = "modifier_" .. upgrade_name .. "_upgrade",
				upgrade_name = upgrade_name,
				stack_count = counts[upgrade_name],
			}, metatables[class_table])
			if upgrade.OnCreated then upgrade:OnCreated({}) end
			for _, property in ipairs(upgrade.DeclareFunctions and upgrade:DeclareFunctions() or {}) do
				local getter = self.GETTERS[property]
				if getter and upgrade[getter] then
					handlers[getter] = handlers[getter] or {}
					table.insert(handlers[getter], upgrade)
				end
			end
			table.insert(upgrades, upgrade)
		end
	end
	return upgrades, handlers
end
