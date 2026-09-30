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
	function unit:IsClone() return false end
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

-- Upgrades: clone stats are recalculated once.
local generic_kv = {
	generic_armor = {class = "modifier"},
	generic_damage = {class = "modifier"},
	generic_cleave = {class = "modifier", ignore_illusions = 1},
}
GenericUpgrades = {generic_upgrades_data = generic_kv}
CustomNetTables = {SetTableValue = function() end}
EventStream = {Listen = function() end}
dofile("scripts/vscripts/game/upgrades/upgrades.lua")

local source = Unit()
source.upgrades = {generic = {generic_armor = {count = 2}, generic_damage = {count = 3}, generic_cleave = {count = 1}}}
local clone = Unit({illusion = true})
local added = {}
function clone:HasModifier(name) for _, m in ipairs(self.modifiers) do if m.name == name then return true end end return false end
function clone:FindModifierByName(name) for _, m in ipairs(self.modifiers) do if m.name == name then return m end end end
function clone:FindAbilityByName() end
function clone:IsAlive() return true end
function clone:AddNewModifier(_, _, name)
	local modifier = attach(self, Plain(name))
	modifier.SetStackCount = function(m, value) m.stacks = value end
	modifier.ForceRefresh = function() end
	table.insert(added, name)
	return modifier
end
Upgrades:ProcessClone(clone, source)
assert(clone.stat_bonus == 1, "a clone's stats are recalculated once, not per upgrade (" .. clone.stat_bonus .. ")")
assert(clone:FindModifierByName("modifier_generic_armor_upgrade").stacks == 2, "generic upgrades keep their counts")
assert(clone:FindModifierByName("modifier_generic_damage_upgrade").stacks == 3)
assert(not clone:HasModifier("modifier_generic_cleave_upgrade"), "upgrades ignored by illusions are skipped")
for _, name in ipairs({"modifier_bat_handler", "modifier_primary_attribute_reader", "modifier_ability_upgrades_controller"}) do
	assert(clone:HasModifier(name), name .. " added")
end
local single = Unit()
single.FindModifierByName, single.AddNewModifier = clone.FindModifierByName, clone.AddNewModifier
assert(Upgrades:AddGenericUpgradeModifier(single, "generic_armor", 1) == true and single.stat_bonus == 1, "a single upgrade still recalculates")

assert(#errors == 0, "no handler errors: " .. tostring(errors[1]))
print("PASS illusion performance: unit-scoped events, BAT handler, killed illusions drop upgrade modifiers, clone stats")
