-- Run from the addon root: lua tools/test_illusion_performance.lua
-- Issue #24: per-unit modifiers hear only their own unit's events, killed illusions drop their upgrade modifiers,
-- and a clone's stats are recalculated once. Production Lua runs against engine mocks.
-- illusion_perf_smoke.lua measures the costs in Workshop Tools.
local function has(list, value) for _, v in ipairs(list or {}) do if v == value then return true end end return false end
local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end

-- Valve's class() copies the base class into the new one.
class = function(base) local c = {} for k, v in pairs(base or {}) do c[k] = v end return c end
IsServer = function() return true end
IsClient = function() return false end
IsValidEntity = function(entity) return entity ~= nil and not entity.null end
LinkLuaModifier = function() end
bit = {band = function(a, b) return math.tointeger(a) & math.tointeger(b) end}
MODIFIER_EVENT_ON_HERO_KILLED, MODIFIER_EVENT_ON_MODIFIER_ADDED, MODIFIER_EVENT_ON_TAKEDAMAGE_KILLCREDIT = 101, 102, 103
MODIFIER_EVENT_ON_TAKEDAMAGE, MODIFIER_EVENT_ON_SPELL_TARGET_READY = 104, 105
MODIFIER_PROPERTY_BASE_ATTACK_TIME_CONSTANT, MODIFIER_PROPERTY_PROCATTACK_FEEDBACK = 201, 202
MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING = 203
MODIFIER_STATE_HEXED, MODIFIER_STATE_ROOTED, MODIFIER_STATE_FEARED = 1, 2, 3
DOTA_DAMAGE_FLAG_REFLECTION, DOTA_DAMAGE_CATEGORY_ATTACK, DOTA_DAMAGE_CATEGORY_SPELL = 16, 1, 0
LUA_MODIFIER_MOTION_NONE, PATTACH_OVERHEAD_FOLLOW, PATTACH_ABSORIGIN_FOLLOW, OVERHEAD_ALERT_HEAL = 0, 1, 2, 3

local errors = {}
ErrorTracking = {Try = function(callback, ...)
	local ok, err = pcall(callback, ...)
	if not ok then table.insert(errors, err) end
	return ok
end}
local dispatched = {}
local listeners = {}
EventDriver = {
	Dispatch = function(_, name, data) table.insert(dispatched, {name, data}) end,
	Listen = function(_, name, callback, context) table.insert(listeners, {name, callback, context}) return #listeners end,
	CancelListener = function() end,
}
local timers = {}
Timers = {CreateTimer = function(_, _, callback) table.insert(timers, callback) return "timer" .. #timers end}
local function tick()
	local current = timers
	timers = {}
	for _, callback in ipairs(current) do
		if callback() then table.insert(timers, callback) end
	end
end
ParticleManager = {CreateParticle = function() return 1 end, SetParticleControl = function() end}
SendOverheadEventMessage = function() end

dofile("scripts/vscripts/libraries/unit_events.lua")

-- Modifier instances: class methods plus the engine methods the code under test uses.
local function Modifier(class_table, parent, fields)
	local modifier = setmetatable({parent = parent, stacks = 0}, {__index = class_table})
	for key, value in pairs(fields or {}) do modifier[key] = value end
	modifier.GetParent = function(self) return self.parent end
	modifier.GetName = modifier.GetName or function(self) return self.name end
	modifier.IsNull = function(self) return self.null == true end
	modifier.GetStackCount = function(self) return self.stacks end
	modifier.SetStackCount = function(self, value) self.stacks = value end
	modifier.GetRemainingTime = modifier.GetRemainingTime or function(self) return self.remaining or -1 end
	modifier.Destroy = function(self)
		self.null = true
		for index, other in ipairs(self.parent.modifiers) do
			if other == self then table.remove(self.parent.modifiers, index) break end
		end
		if self.OnDestroy then self:OnDestroy() end
	end
	return modifier
end
local function Unit(fields)
	local unit = {modifiers = {}, bat = 1.7, illusion = false, soldier = false, tempest = false, healed = 0, stat_bonus = 0}
	for key, value in pairs(fields or {}) do unit[key] = value end
	function unit:GetBaseAttackTime() return self.bat end
	function unit:FindAllModifiers() local copy = {} for i, m in ipairs(self.modifiers) do copy[i] = m end return copy end
	function unit:IsIllusion() return self.illusion end
	function unit:IsMonkeyKingSoldier() return self.soldier end
	function unit:IsTempestDouble() return self.tempest end
	function unit:IsClone() return self.clone == true end
	function unit:IsAlive() return not self.dead end
	function unit:GetPlayerOwnerID() return self.player_id or 0 end
	function unit:IsSpiritBear() return false end
	function unit:IsHero() return true end
	function unit:GetTeam() return self.team or 2 end
	function unit:HealWithParams(amount) self.healed = self.healed + amount end
	function unit:GetAbsOrigin() return {} end
	function unit:CalculateStatBonus() self.stat_bonus = self.stat_bonus + 1 end
	return unit
end
local function Plain(name, fields)
	local modifier = {name = name}
	for key, value in pairs(fields or {}) do modifier[key] = value end
	modifier.GetName = function(self) return self.name end
	modifier.IsNull = function(self) return self.null == true end
	modifier.GetRemainingTime = function(self) return self.remaining or -1 end
	modifier.Destroy = function(self)
		self.null = true
		for index, other in ipairs(self.parent.modifiers) do
			if other == self then table.remove(self.parent.modifiers, index) break end
		end
	end
	return modifier
end
local function attach(unit, modifier) modifier.parent = unit table.insert(unit.modifiers, modifier) return modifier end

-- UnitEvents: handlers run only for their own parent; nulled or unregistered modifiers stop; errors stay contained.
local calls = {}
local Recorder = {OnModifierAdded = function(self, event) table.insert(calls, {self, event}) end}
local a, b = Unit(), Unit()
local first, second, other = Modifier(Recorder, a), Modifier(Recorder, a), Modifier(Recorder, b)
for _, modifier in ipairs({first, second, other}) do UnitEvents:Register(modifier, "OnModifierAdded") end
local payload = {unit = a}
UnitEvents:Notify(a, "OnModifierAdded", payload)
assert(#calls == 2 and calls[1][2] == payload, "both handlers of the unit run, with the event")
assert(calls[1][1] ~= other and calls[2][1] ~= other, "another unit's handler does not run")
UnitEvents:Notify(nil, "OnModifierAdded", payload)
UnitEvents:Notify(Unit(), "OnModifierAdded", payload)
calls = {}
second.null = true
UnitEvents:Unregister(first)
UnitEvents:Notify(a, "OnModifierAdded", payload)
assert(#calls == 0 and count(a.unit_event_handlers.OnModifierAdded) == 0, "unregistered and removed modifiers are dropped")
local failing = Modifier({OnModifierAdded = function() error("boom") end}, b)
UnitEvents:Register(failing, "OnModifierAdded")
UnitEvents:Notify(b, "OnModifierAdded", payload)
assert(#errors == 1 and #calls == 1 and calls[1][1] == other, "a failing handler does not stop the others")
errors = {}
-- a handler adding a modifier that registers on the same unit
local late = Modifier(Recorder, a)
local adder = Modifier({OnModifierAdded = function() UnitEvents:Register(late, "OnModifierAdded") end}, a)
UnitEvents:Register(adder, "OnModifierAdded")
calls = {}
UnitEvents:Notify(a, "OnModifierAdded", payload)
UnitEvents:Notify(a, "OnModifierAdded", payload)
assert(#errors == 0 and #calls == 1 and calls[1][1] == late, "handlers registered meanwhile run from the next event")

-- The proxy is the only global listener: it routes by unit, attacker and caster.
dofile("scripts/vscripts/modifiers/modifier_event_proxy.lua")
local proxy_functions = modifier_event_proxy:DeclareFunctions()
for _, event in ipairs({MODIFIER_EVENT_ON_MODIFIER_ADDED, MODIFIER_EVENT_ON_TAKEDAMAGE, MODIFIER_EVENT_ON_SPELL_TARGET_READY}) do
	assert(has(proxy_functions, event), "proxy listens to event " .. event)
end
local seen = {}
local Listener = {}
for _, name in ipairs({"OnModifierAdded", "OnTakeDamage", "OnSpellTargetReady"}) do
	Listener[name] = function(self, event) table.insert(seen, {self.parent, name, event}) end
end
local attacker, victim = Unit(), Unit()
for _, unit in ipairs({attacker, victim}) do
	local listener = Modifier(Listener, unit)
	for _, name in ipairs({"OnModifierAdded", "OnTakeDamage", "OnSpellTargetReady"}) do UnitEvents:Register(listener, name) end
end
local buff = Plain("modifier_stunned")
modifier_event_proxy:OnModifierAdded({unit = victim, added_buff = buff})
assert(#seen == 1 and seen[1][1] == victim and seen[1][3].unit == victim and seen[1][3].modifier == buff, "added modifier: its unit")
assert(dispatched[#dispatched][1] == "Events:modifier_added" and dispatched[#dispatched][2] == seen[1][3], "and the global listeners")
seen = {}
modifier_event_proxy:OnTakeDamage({attacker = attacker, unit = victim, damage = 10})
assert(#seen == 1 and seen[1][1] == attacker and seen[1][2] == "OnTakeDamage", "damage: the attacker only")
seen = {}
modifier_event_proxy:OnSpellTargetReady({unit = attacker, target = victim})
assert(#seen == 1 and seen[1][1] == attacker and seen[1][2] == "OnSpellTargetReady", "spell target: the caster only")
seen = {}
buff.null = true
modifier_event_proxy:OnModifierAdded({unit = victim, added_buff = buff})
modifier_event_proxy:OnTakeDamage({unit = victim, damage = 10})
assert(#seen == 0, "removed buffs and sourceless damage reach nobody")

-- BAT handler: no global event; the lowest BAT of its parent's modifiers wins, recalculated when one is added there.
dofile("scripts/vscripts/game/modifiers/modifier_bat_handler.lua")
assert(not has(modifier_bat_handler:DeclareFunctions(), MODIFIER_EVENT_ON_MODIFIER_ADDED), "no global modifier event")
local hero = Unit({bat = 1.7})
local handler = attach(hero, Modifier(modifier_bat_handler, hero, {name = "modifier_bat_handler"}))
handler:OnCreated()
assert(handler:GetModifierBaseAttackTimeConstant() == 1.7, "base BAT")
local function add(unit, modifier)
	attach(unit, modifier)
	modifier_event_proxy:OnModifierAdded({unit = unit, added_buff = modifier})
end
local ability = {IsNull = function() return false end, GetSpecialValueFor = function(_, name) return name == "base_attack_time" and 1.4 end}
local rage = Plain("modifier_troll_warlord_berserkers_rage", {GetAbility = function() return ability end})
add(hero, rage)
assert(math.abs(handler:GetModifierBaseAttackTimeConstant() - 1.4) < 1e-9, "a native BAT modifier applies")
local other_hero = Unit({bat = 1.7})
local other_handler = attach(other_hero, Modifier(modifier_bat_handler, other_hero, {name = "modifier_bat_handler"}))
other_handler:OnCreated()
handler.stacks = 999
add(other_hero, Plain("modifier_troll_warlord_berserkers_rage", {GetAbility = function() return ability end}))
assert(handler.stacks == 999 and math.abs(other_handler:GetModifierBaseAttackTimeConstant() - 1.4) < 1e-9,
	"only the handler of the unit that got the modifier recalculates")
local lua_bat = Plain("modifier_lua_bat", {GetModifierBaseAttackTimeConstant = function() return 1.2 end, remaining = 5})
add(hero, lua_bat)
assert(math.abs(handler:GetModifierBaseAttackTimeConstant() - 1.2) < 1e-9, "the lowest BAT wins")
add(hero, Plain("modifier_direct", {GetBaseAttackTimeDirectBonus = function() return -0.1 end}))
assert(math.abs(handler:GetModifierBaseAttackTimeConstant() - 1.1) < 1e-9, "direct bonuses add up")
add(hero, Plain("modifier_stunned"))
assert(#timers == 1, "one expiry watch for the timed modifier setting the BAT, however many modifiers are added")
tick()
assert(#timers == 1, "the watch polls while the modifier lasts")
lua_bat:Destroy()
tick()
assert(#timers == 0 and math.abs(handler:GetModifierBaseAttackTimeConstant() - 1.3) < 1e-9, "its end restores the BAT")
handler:Destroy()
add(hero, Plain("modifier_stunned"))
assert(count(hero.unit_event_handlers.OnModifierAdded) == 0, "a removed handler stops listening")

-- Upgrade modifiers that need events register on their parent instead of declaring global events.
require = function() end
dofile("scripts/vscripts/game/upgrades/generic_upgrades/modifier_base_generic_upgrade.lua")
for _, file in ipairs({"universal_lifesteal", "magic_resistance_reduction", "status_res_on_disable"}) do
	dofile("scripts/vscripts/game/upgrades/generic_upgrades/modifier_generic_" .. file .. "_upgrade.lua")
end
local function Upgrade(class_table, unit, name)
	local upgrade = attach(unit, Modifier(class_table, unit, {name = name, RecalculateBonusPerUpgrade = function(self) self.bonus = 50 end}))
	upgrade:OnCreated()
	return upgrade
end
assert(not has(modifier_generic_universal_lifesteal_upgrade:DeclareFunctions(), MODIFIER_EVENT_ON_TAKEDAMAGE), "lifesteal: no global event")
assert(modifier_generic_magic_resistance_reduction_upgrade.DeclareFunctions == nil, "magic resistance reduction: no global event")
local lancer, illusion, enemy = Unit(), Unit({illusion = true}), Unit({team = 3})
local lifesteal = Upgrade(modifier_generic_universal_lifesteal_upgrade, lancer, "modifier_generic_universal_lifesteal_upgrade")
local illusion_lifesteal = Upgrade(modifier_generic_universal_lifesteal_upgrade, illusion, "modifier_generic_universal_lifesteal_upgrade")
local spell_damage = {attacker = lancer, unit = enemy, damage = 100, damage_flags = 0, damage_category = DOTA_DAMAGE_CATEGORY_SPELL}
modifier_event_proxy:OnTakeDamage(spell_damage)
assert(lancer.healed == 50 and illusion.healed == 0, "spell lifesteal heals the attacker only")
modifier_event_proxy:OnTakeDamage({attacker = enemy, unit = lancer, damage = 100, damage_flags = 0, damage_category = DOTA_DAMAGE_CATEGORY_SPELL})
assert(lancer.healed == 50, "damage taken does not heal")
illusion_lifesteal:Destroy()
assert(count(illusion.unit_event_handlers.OnTakeDamage) == 0, "a removed upgrade stops listening")
local reduction = Upgrade(modifier_generic_magic_resistance_reduction_upgrade, lancer, "modifier_generic_magic_resistance_reduction_upgrade")
local cast_targets = {}
reduction.OnSpellTargetReady = function(self, event) table.insert(cast_targets, event.target) end
modifier_event_proxy:OnSpellTargetReady({unit = lancer, target = enemy})
modifier_event_proxy:OnSpellTargetReady({unit = enemy, target = lancer})
assert(#cast_targets == 1 and cast_targets[1] == enemy, "magic resistance reduction hears its parent's casts only")
local listeners_before = #listeners
local status = Upgrade(modifier_generic_status_res_on_disable_upgrade, illusion, "modifier_generic_status_res_on_disable_upgrade")
assert(#listeners == listeners_before, "status resistance on disable: no per-instance global listener")
local disabled = {}
status.OnModifierAdded = function(self, event) table.insert(disabled, event.modifier) end
local stun = Plain("modifier_stunned")
add(illusion, stun)
add(enemy, Plain("modifier_stunned"))
assert(#disabled == 1 and disabled[1] == stun, "status resistance on disable hears its parent's modifiers only")

-- Killed illusions drop the modifiers heroes keep through death (the engine asks RemoveOnDeath when the unit dies).
CDOTA_BaseNPC = {}
dofile("scripts/vscripts/extensions/cdota_basenpc.lua")
dofile("scripts/vscripts/game/modifiers/modifier_primary_attribute_reader.lua")
dofile("scripts/vscripts/game/upgrades/modifier_ability_upgrades_controller.lua")
local function Body(fields)
	local unit = setmetatable(Unit(fields), {__index = CDOTA_BaseNPC})
	if fields.no_tempest_check then unit.IsTempestDouble = nil end
	return unit
end
local kept_classes = {modifier_base_generic_upgrade, modifier_generic_universal_lifesteal_upgrade,
	modifier_ability_upgrades_controller, modifier_primary_attribute_reader}
for _, case in ipairs({
	{{illusion = true}, true, "an illusion"},
	{{illusion = true, no_tempest_check = true}, true, "an illusion of a unit without IsTempestDouble"},
	{{illusion = false}, false, "a hero"},
	{{illusion = true, soldier = true}, false, "a Monkey King soldier (reused)"},
	{{illusion = true, tempest = true}, false, "Tempest Double (comes back)"},
}) do
	for _, class_table in ipairs(kept_classes) do
		local modifier = Modifier(class_table, Body(case[1]))
		assert(modifier:RemoveOnDeath() == case[2], case[3] .. (case[2] and " drops" or " keeps") .. " upgrade modifiers at death")
	end
end
IsServer = function() return false end
assert(Modifier(modifier_base_generic_upgrade, Body({illusion = true})):RemoveOnDeath() == false, "clients leave it to the server")
IsServer = function() return true end

-- Hosted generic upgrades: an illusion carries them in one modifier.
local PROPERTY_NAMES = {"STATS_STRENGTH_BONUS", "STATS_AGILITY_BONUS", "STATS_INTELLECT_BONUS", "PROCATTACK_FEEDBACK",
	"PHYSICAL_ARMOR_BONUS", "MAGICAL_RESISTANCE_BONUS", "ATTACKSPEED_BONUS_CONSTANT", "SPELL_AMPLIFY_PERCENTAGE",
	"MOVESPEED_BONUS_CONSTANT", "SLOW_RESISTANCE_STACKING", "EXTRA_HEALTH_PERCENTAGE", "PREATTACK_BONUS_DAMAGE",
	"HEAL_AMPLIFY_PERCENTAGE_SOURCE", "HEAL_AMPLIFY_PERCENTAGE_TARGET", "HP_REGEN_AMPLIFY_PERCENTAGE",
	"LIFESTEAL_AMPLIFY_PERCENTAGE", "SPELL_LIFESTEAL_AMPLIFY_PERCENTAGE", "PREATTACK_CRITICALSTRIKE",
	"PROCATTACK_BONUS_DAMAGE_PHYSICAL", "CAST_RANGE_BONUS_STACKING", "ATTACK_RANGE_BONUS", "COOLDOWN_PERCENTAGE"}
for index, name in ipairs(PROPERTY_NAMES) do _G["MODIFIER_PROPERTY_" .. name] = 300 + index end
DOTA_ATTRIBUTE_STRENGTH, DOTA_ATTRIBUTE_AGILITY, DOTA_ATTRIBUTE_INTELLECT = 0, 1, 2
DEFAULT_PATH = "game/upgrades/generic_upgrades/"
-- per upgrade value and the primary attribute, instead of the KV files and the attribute reader
local VALUES = {generic_armor = 3, generic_all_attributes = 5, generic_primary_attribute = 7, generic_secondary_attributes = 11}
CDOTA_Modifier_Lua = {
	-- like the extension, which looks for stat boost handlers on the parent
	GetUpgradeValueFor = function(self) self:GetParent() return VALUES[self.upgrade_name] or 1 end,
	GetPrimaryAttributeOfParent = function(self) return self:GetParent().primary end,
}
UpgradesUtilities = {CalculateUpgradeValue = function(_, _, value, count) return value * count end}
local loaded = {}
require = function(path)
	if loaded[path] then return end
	loaded[path] = true
	dofile("scripts/vscripts/" .. path .. ".lua")
end
GenericUpgrades = {generic_upgrades_data = {}}
dofile("scripts/vscripts/game/upgrades/illusion_generic_upgrades.lua")
for upgrade_name in pairs(IllusionGenericUpgrades.HOSTED) do GenericUpgrades.generic_upgrades_data[upgrade_name] = {} end
GENERIC_UPGRADES_DATA = GenericUpgrades.generic_upgrades_data -- the client's copy

-- The rules that let an upgrade be hosted hold for every hosted upgrade, and only additive properties are shared.
local ADDITIVE, providers = {}, {}
for _, property in ipairs(IllusionGenericUpgrades.PROPERTIES) do
	assert(property[1] ~= nil, property[2] .. ": constant defined")
	if property.additive then ADDITIVE[property[1]] = true end
end
for upgrade_name in pairs(IllusionGenericUpgrades.HOSTED) do
	local class_table = IllusionGenericUpgrades:GetClass(upgrade_name)
	assert(class_table, upgrade_name .. ": class loads")
	assert(class_table:IsHidden() == true, upgrade_name .. ": hidden")
	for _, method in ipairs({"CheckState", "GetEffectName", "GetStatusEffectName", "OnIntervalThink", "AddCustomTransmitterData",
		"HandleCustomTransmitterData", "OnStackCountChanged", "GetModifierAura", "GetBaseAttackTimeDirectBonus"}) do
		assert(class_table[method] == nil, upgrade_name .. ": no " .. method)
	end
	for _, property in ipairs(class_table.DeclareFunctions and class_table:DeclareFunctions() or {}) do
		local getter = IllusionGenericUpgrades.GETTERS[property]
		assert(getter and class_table[getter], upgrade_name .. ": declares only hosted properties (" .. tostring(property) .. ")")
		providers[property] = (providers[property] or 0) + 1
		assert(ADDITIVE[property] or providers[property] == 1, upgrade_name .. ": shares " .. getter .. ", which is not additive")
	end
end

local function HostParent(fields)
	local unit = setmetatable(Unit(fields), {__index = CDOTA_BaseNPC})
	function unit:GetLevel() return 30 end
	function unit:IsRangedAttacker() return false end
	function unit:IsRealHero() return not self.illusion end
	function unit:GetUnitLabel() return "" end
	return unit
end
dofile("scripts/vscripts/game/upgrades/modifier_illusion_generic_upgrades.lua")
local function Host(parent)
	local host = attach(parent, Modifier(modifier_illusion_generic_upgrades, parent, {name = "modifier_illusion_generic_upgrades"}))
	host.SetHasCustomTransmitterData = function(self, value) self.transmits = value end
	host.GetCaster = function(self) return self.parent end
	return host
end
assert(#modifier_illusion_generic_upgrades:DeclareFunctions() == #IllusionGenericUpgrades.PROPERTIES,
	"the host declares every hosted property: the engine asks before creation")

-- Server: the creation keys hold the counts; getters ask the upgrades implementing them.
local body = HostParent({illusion = true, primary = DOTA_ATTRIBUTE_STRENGTH})
local host = Host(body)
host:OnCreated({duration = -1, generic_armor = 2, generic_all_attributes = 1, generic_primary_attribute = 1,
	generic_secondary_attributes = 1, generic_status_res_on_disable = 1, generic_universal_lifesteal = 1,
	generic_armor_shred = 1, generic_universal_shield = 1, unrelated = 4})
assert(host.transmits and #host.upgrades == 7, "hosts the hosted upgrades it was created with, and nothing else")
assert(host:AddCustomTransmitterData().counts.generic_armor == 2 and host:AddCustomTransmitterData().counts.unrelated == nil)
assert(host:GetModifierPhysicalArmorBonus() == 6, "a single upgrade answers alone")
assert(host:GetModifierBonusStats_Strength() == 5 + 7 and host:GetModifierBonusStats_Agility() == 5 + 11,
	"shared stats are summed (primary and secondary attributes follow the parent's primary attribute)")
assert(host:GetModifierMoveSpeedBonus_Constant() == nil, "nothing for properties no hosted upgrade has")
local feedback = 0
for _, upgrade in ipairs(host.handlers.GetModifierProcAttack_Feedback) do
	upgrade.GetModifierProcAttack_Feedback = function() feedback = feedback + 1 return 2 end
end
assert(host:GetModifierProcAttack_Feedback({}) == 4 and feedback == 2, "attack procs of every hosted upgrade run")
-- hosted upgrades use UnitEvents like their own modifiers would, and stop with the host
local hosted_status
for _, upgrade in ipairs(host.upgrades) do
	if upgrade.upgrade_name == "generic_status_res_on_disable" then hosted_status = upgrade end
end
local disables = 0
hosted_status.OnModifierAdded = function() disables = disables + 1 end
add(body, Plain("modifier_stunned"))
assert(disables == 1 and hosted_status:GetParent() == body and hosted_status:GetStackCount() == 1, "a hosted upgrade hears its unit's events")
assert(host:RemoveOnDeath() == true, "a killed illusion drops the host")
host:Destroy()
add(body, Plain("modifier_stunned"))
assert(disables == 1 and #host.upgrades == 0, "the host's upgrades stop with it")

-- Issue #31: the host carries the hero effect's status effect, and drops the illusion's cosmetics when it dies.
assert(host:GetStatusEffectName() == nil and host:AddCustomTransmitterData().status_fx == nil, "no status effect without a hero effect")
local cleared = {}
Equipment = {OnIllusionKilled = function(_, unit) table.insert(cleared, unit) end}
local styled_body = HostParent({illusion = true, primary = DOTA_ATTRIBUTE_STRENGTH})
local styled_host = Host(styled_body)
styled_host:OnCreated({duration = -1, status_fx = "particles/skin.vpcf"})
assert(#styled_host.upgrades == 0 and styled_host:GetStatusEffectName() == "particles/skin.vpcf"
	and styled_host:AddCustomTransmitterData().status_fx == "particles/skin.vpcf", "a host carries the status effect it was created with")
styled_host:Destroy()
assert(#cleared == 0, "a live illusion whose host is replaced keeps its cosmetics")
local dying_host = Host(styled_body)
dying_host:OnCreated({duration = -1})
styled_body.dead = true
dying_host:Destroy()
assert(#cleared == 1 and cleared[1] == styled_body, "a host removed at death drops the illusion's cosmetics")
Equipment = nil

-- Client: the counts arrive before OnCreated, when the modifier cannot tell its parent yet.
IsServer = function() return false end
local client_body = HostParent({illusion = true, primary = DOTA_ATTRIBUTE_AGILITY})
local client_host = Host(client_body)
local parent_ready = false
client_host.GetParent = function(self)
	assert(parent_ready, "the parent is asked for before OnCreated")
	return self.parent
end
client_host:HandleCustomTransmitterData({counts = {generic_armor = 2, generic_primary_attribute = 1}, status_fx = "particles/skin.vpcf"})
parent_ready = true
client_host:OnCreated()
assert(client_host:GetModifierPhysicalArmorBonus() == 6 and client_host:GetModifierBonusStats_Agility() == 7,
	"clients host the same upgrades, for the stats they show")
assert(client_host:GetStatusEffectName() == "particles/skin.vpcf", "clients show the transmitted status effect")
client_host:Destroy()
IsServer = function() return true end

-- Upgrades: an illusion gets a new host with its counts; other clones get upgrade modifiers; stats are recalculated once.
GenericUpgrades.generic_upgrades_data = {
	generic_armor = {class = "modifier"},
	generic_damage = {class = "modifier"},
	generic_cleave = {class = "modifier", ignore_illusions = 1},
	generic_universal_shield = {class = "modifier"},
}
CustomNetTables = {SetTableValue = function() end}
EventStream = {Listen = function() end}
require = function() end
dofile("scripts/vscripts/game/upgrades/upgrades.lua")

local source = Unit()
source.upgrades = {generic = {generic_armor = {count = 2}, generic_damage = {count = 3}, generic_cleave = {count = 1},
	generic_universal_shield = {count = 1}}}
local function Clone(fields)
	local clone = Unit(fields)
	clone.created = {}
	function clone:HasModifier(name) return self:FindModifierByName(name) ~= nil end
	function clone:FindModifierByName(name) for _, m in ipairs(self.modifiers) do if m.name == name then return m end end end
	function clone:RemoveModifierByName(name) local m = self:FindModifierByName(name) if m then m:Destroy() end end
	function clone:FindAbilityByName() end
	function clone:IsAlive() return true end
	function clone:AddNewModifier(_, _, name, kv)
		local modifier = attach(self, Plain(name))
		modifier.SetStackCount = function(m, value) m.stacks = value end
		modifier.ForceRefresh = function() end
		self.created[name] = kv or {}
		return modifier
	end
	return clone
end
local illusion_clone = Clone({illusion = true})
Upgrades:ProcessClone(illusion_clone, source)
local kv = illusion_clone.created.modifier_illusion_generic_upgrades
assert(kv and kv.generic_armor == 2 and kv.generic_damage == 3 and kv.duration == -1, "the host is created with the hosted counts")
assert(kv.generic_cleave == nil and not illusion_clone:HasModifier("modifier_generic_cleave_upgrade"), "upgrades ignored by illusions are skipped")
assert(kv.generic_universal_shield == nil and illusion_clone:FindModifierByName("modifier_generic_universal_shield_upgrade").stacks == 1,
	"upgrades it cannot host stay modifiers of their own")
assert(not illusion_clone:HasModifier("modifier_generic_armor_upgrade"), "hosted upgrades get no modifier of their own")
assert(illusion_clone.stat_bonus == 1, "an illusion's stats are recalculated once (" .. illusion_clone.stat_bonus .. ")")
for _, name in ipairs({"modifier_bat_handler", "modifier_primary_attribute_reader", "modifier_ability_upgrades_controller"}) do
	assert(illusion_clone:HasModifier(name), name .. " added")
end
local first_host = illusion_clone:FindModifierByName("modifier_illusion_generic_upgrades")
source.upgrades.generic.generic_armor.count = 4
Upgrades:ProcessClone(illusion_clone, source) -- Monkey King soldiers are processed again
local hosts = 0
for _, m in ipairs(illusion_clone.modifiers) do if m.name == "modifier_illusion_generic_upgrades" then hosts = hosts + 1 end end
assert(first_host.null and hosts == 1 and illusion_clone.created.modifier_illusion_generic_upgrades.generic_armor == 4,
	"processing an illusion again replaces its host")
local meepo_clone = Clone({illusion = false})
Upgrades:ProcessClone(meepo_clone, source)
assert(meepo_clone:FindModifierByName("modifier_generic_armor_upgrade").stacks == 4 and not meepo_clone:HasModifier("modifier_illusion_generic_upgrades"),
	"other clones keep a modifier per upgrade")
assert(meepo_clone.stat_bonus == 1, "their stats are recalculated once too")
local single = Clone()
assert(Upgrades:AddGenericUpgradeModifier(single, "generic_armor", 1) == true and single.stat_bonus == 1, "a single upgrade still recalculates")

-- Issue #31: the host carries the owner's status effect, and an illusion with cosmetics gets one even without upgrades.
local looks = {}
Equipment = {GetCopiedLook = function(_, player_id) local look = looks[player_id] or {} return look[1], look[2] or false end}
looks[0] = {"particles/skin.vpcf", true}
local styled = Clone({illusion = true})
Upgrades:ProcessClone(styled, source)
kv = styled.created.modifier_illusion_generic_upgrades
assert(kv and kv.status_fx == "particles/skin.vpcf" and kv.generic_armor == 4, "the host is created with the owner's status effect")
local bare_source = Unit()
bare_source.upgrades = {generic = {}}
looks[0] = {nil, true}
local aura_only = Clone({illusion = true})
Upgrades:ProcessClone(aura_only, bare_source)
assert(aura_only:HasModifier("modifier_illusion_generic_upgrades") and aura_only.stat_bonus == 0,
	"an illusion with only cosmetic particles gets a host, to drop them at death, and no stat recalculation")
looks[0] = nil
local plain = Clone({illusion = true})
Upgrades:ProcessClone(plain, bare_source)
assert(not plain:HasModifier("modifier_illusion_generic_upgrades"), "an illusion without upgrades or cosmetics gets no host")
Equipment = nil

-- Equipment (issue #31): illusions copy the hero's cosmetic particles but not the status effect modifier, which their
-- host carries; Meepo clones keep the modifier; a killed illusion's particles are destroyed.
INVENTORY_SLOTS = {SPRAY = "1", AURA = "2", HERO_EFFECT = "3", KILL_EFFECT = "4", PET = "5", COSMETIC_SKILL = "6", HIGH_FIVE = "7"}
PATTACH_SPECIAL_STATUS_FX, PATTACH_POINT_FOLLOW = "STATUS_FX", 4
ITEM_DEFINITIONS = {
	test_aura = {slot = INVENTORY_SLOTS.AURA, particles = {{path = "aura.vpcf", attach_type = PATTACH_ABSORIGIN_FOLLOW}}},
	test_skin = {slot = INVENTORY_SLOTS.HERO_EFFECT, particles = {
		{path = "skin.vpcf", attach_type = PATTACH_SPECIAL_STATUS_FX},
		{path = "skin_attach.vpcf", attach_type = PATTACH_POINT_FOLLOW},
	}},
	test_kill = {slot = INVENTORY_SLOTS.KILL_EFFECT,
		particle_variants = {hero = {path = "kill.vpcf", attach_type = PATTACH_ABSORIGIN_FOLLOW, persists = false}}},
	test_pet = {slot = INVENTORY_SLOTS.PET, particles = {{path = "pet.vpcf", attach_type = PATTACH_ABSORIGIN_FOLLOW}}},
}
PlayerResource = {IsValidPlayerID = function(_, player_id) return player_id == 0 or player_id == 1 end}
local live_particles, particle_count = {}, 0
ParticleManager = {
	CreateParticle = function(_, path) particle_count = particle_count + 1 live_particles[particle_count] = path return particle_count end,
	DestroyParticle = function(_, id) live_particles[id] = nil end,
	ReleaseParticleIndex = function() end,
	SetParticleControlEnt = function() end,
	SetParticleControl = function() end,
}
dofile("scripts/vscripts/libraries/webapi/inventory/equipment.lua")
Equipment.equipped_items[0] = {
	[INVENTORY_SLOTS.AURA] = {name = "test_aura"},
	[INVENTORY_SLOTS.HERO_EFFECT] = {name = "test_skin"},
	[INVENTORY_SLOTS.KILL_EFFECT] = {name = "test_kill"},
	[INVENTORY_SLOTS.PET] = {name = "test_pet"},
}
Equipment.equipped_items[1] = {[INVENTORY_SLOTS.KILL_EFFECT] = {name = "test_kill"}}
local status_fx, has_particles = Equipment:GetCopiedLook(0)
assert(status_fx == "skin.vpcf" and has_particles == true, "the look names the hero effect's status effect and lasting particles")
status_fx, has_particles = Equipment:GetCopiedLook(1)
assert(status_fx == nil and has_particles == false, "kill effects (one-off) and slots with their own handling are not copied")
assert(Equipment:GetCopiedLook(2) == nil, "a player with nothing equipped")

local function particles_of(unit)
	local paths = {}
	for _, assets in pairs(unit._equipment_bound_assets or {}) do
		for _, id in ipairs(assets.particles or {}) do
			if live_particles[id] then table.insert(paths, live_particles[id]) end
		end
	end
	table.sort(paths)
	return table.concat(paths, ",")
end
local copied_illusion = Clone({illusion = true})
Equipment:OnNpcSpawned({unit = copied_illusion})
assert(particles_of(copied_illusion) == "aura.vpcf,skin_attach.vpcf", "an illusion copies the lasting particles (" .. particles_of(copied_illusion) .. ")")
assert(not copied_illusion:HasModifier("modifier_hero_status_fx"), "an illusion gets no status effect modifier of its own")
local meepo = Clone({clone = true})
Equipment:OnNpcSpawned({unit = meepo})
assert(meepo:HasModifier("modifier_hero_status_fx") and meepo.created.modifier_hero_status_fx.status_fx_name == "skin.vpcf"
	and particles_of(meepo) == "aura.vpcf,skin_attach.vpcf", "a Meepo clone keeps the status effect modifier and the particles")
Equipment:OnIllusionKilled(copied_illusion)
assert(particles_of(copied_illusion) == "" and particles_of(meepo) == "aura.vpcf,skin_attach.vpcf",
	"a killed illusion's particles are destroyed, and only its own")

assert(#errors == 0, "no handler errors: " .. tostring(errors[1]))
print("PASS illusion performance: unit-scoped events, BAT handler, killed illusions drop upgrade modifiers, hosted generic upgrades, clone stats, hosted hero effect and cosmetics dropped at death")
