class = function(t) return t end
LinkLuaModifier = function() end
MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE = 1
DOTA_UNIT_TARGET_FLAG_NONE, DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_BASIC = 0, 1, 1, 18
DOTA_ABILITY_BEHAVIOR_PASSIVE = 2
MODIFIER_STATE_DEBUFF_IMMUNE, MODIFIER_STATE_INVISIBLE, MODIFIER_STATE_TRUESIGHT_IMMUNE, MODIFIER_STATE_NOT_ON_MINIMAP_FOR_ENEMIES = 1, 2, 3, 4
MODIFIER_STATE_DISARMED, MODIFIER_STATE_UNTARGETABLE_ENEMY = 5, 39
MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_MAGICAL, MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PHYSICAL, MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PURE = 20, 21, 22
MODIFIER_PROPERTY_HEALTH_REGEN_PERCENTAGE, MODIFIER_PROPERTY_MANA_REGEN_TOTAL_PERCENTAGE = 10, 11
MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING, MODIFIER_PROPERTY_INVISIBILITY_LEVEL = 12, 13
bit = {band = function(a, b) return math.tointeger(a) & math.tointeger(b) end}
local client = false
IsClient = function() return client end
IsValidEntity = function(v) return v ~= nil end

dofile("scripts/vscripts/game/modifiers/modifier_fountain_rejuvenation_lua.lua")
dofile("scripts/vscripts/game/modifiers/modifier_fountain_protection_lua.lua")
dofile("scripts/vscripts/game/fountain_protection.lua")

local function has(list, value) for _, v in ipairs(list) do if v == value then return true end end return false end
local tower = {Script_GetAttackRange = function() return 1050 end}
local function Aura(class_table)
	return setmetatable({GetParent = function() return tower end}, {__index = class_table})
end

-- The aura covers the same zone and units as fountain rejuvenation, and lingers for 1.5 seconds after leaving.
local aura, rejuvenation = Aura(modifier_fountain_protection_lua), Aura(modifier_fountain_rejuvenation_lua)
assert(aura:IsAura() and aura:IsHidden() and not aura:IsPurgable())
assert(aura:GetModifierAura() == "modifier_fountain_protection_effect_lua")
assert(aura:GetAuraRadius() == 1194 and aura:GetAuraRadius() == rejuvenation:GetAuraRadius())
assert(aura:GetAuraSearchTeam() == rejuvenation:GetAuraSearchTeam() and aura:GetAuraSearchType() == rejuvenation:GetAuraSearchType())
assert(aura:GetAuraSearchFlags() == rejuvenation:GetAuraSearchFlags())
assert(aura:GetAuraDuration() == 1.5, "protection lingers 1.5 seconds after leaving the fountain")

-- Effect: the aura keeps the remaining time full inside the fountain; it runs down while lingering.
local LOOK = "modifier_fountain_protection_look_lua"
local function Parent()
	local parent = {modifiers = {}}
	parent.HasModifier = function(self, name) return self.modifiers[name] ~= nil end
	parent.AddNewModifier = function(self, caster, ability, name) self.modifiers[name] = (self.modifiers[name] or 0) + 1 end
	parent.RemoveModifierByName = function(self, name) self.modifiers[name] = nil end
	return parent
end
local function Effect(parent)
	local effect = setmetatable({stacks = 0, remaining = 1.5}, {__index = modifier_fountain_protection_effect_lua})
	parent = parent or Parent()
	effect.GetParent = function() return parent end
	effect.GetStackCount = function(self) return self.stacks end
	effect.SetStackCount = function(self, value) self.stacks = value end
	effect.GetDuration = function() return 1.5 end
	effect.GetRemainingTime = function(self) return self.remaining end
	effect.StartIntervalThink = function(self, interval) self.think = interval end
	effect:OnCreated()
	return effect
end
local function shielded_state(effect)
	local state = effect:CheckState()
	return state[MODIFIER_STATE_DISARMED] == true, state[MODIFIER_STATE_UNTARGETABLE_ENEMY], effect:GetAbsoluteNoDamageMagical() == 1
		and effect:GetAbsoluteNoDamagePhysical() == 1 and effect:GetAbsoluteNoDamagePure() == 1
end

local effect = Effect()
assert(effect.think == 0.1 and not effect:IsPurgable())
local functions = effect:DeclareFunctions()
for _, property in ipairs({MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_MAGICAL, MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PHYSICAL, MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PURE}) do
	assert(has(functions, property))
end
local disarmed, untargetable, no_damage = shielded_state(effect)
assert(disarmed and untargetable == true and no_damage, "inside: disarmed, untargetable by enemies, no damage taken")
assert(effect:GetTexture() == "omniknight_guardian_angel")
local parent = effect:GetParent()
assert(parent.modifiers[LOOK] == 1, "dark look while shielded")
local look = setmetatable({}, {__index = modifier_fountain_protection_look_lua})
assert(look:IsHidden() and not look:IsPurgable() and look:StatusEffectPriority() == 20000)
assert(look:GetStatusEffectName() == "particles/status_fx/status_effect_dark_willow_shadow_realm.vpcf", "native fountain invulnerability look")
-- the look darkens the model and its cosmetics, and restores them when it ends
local function Model(class_name) return {class_name = class_name, color = 255, GetClassname = function(self) return self.class_name end,
	SetRenderColor = function(self, r, g, b) assert(r == g and g == b) self.color = r end} end
local hero, wearable, extra, thinker = Model("npc_dota_hero_sven"), Model("dota_item_wearable"), Model("additional_wearable"), Model("npc_dota_thinker")
local peers = {wearable, thinker, extra}
for i, model in ipairs(peers) do model.NextMovePeer = function() return peers[i + 1] end end
hero.FirstMoveChild = function() return peers[1] end
look.GetParent = function() return hero end
look.StartIntervalThink = function(self, interval) self.think = interval end
look:OnCreated()
assert(hero.color == 40 and wearable.color == 40 and extra.color == 40 and thinker.color == 255 and look.think == 0.5, "dark tint")
wearable.color = 255
look:OnIntervalThink()
assert(wearable.color == 40, "cosmetics equipped later are darkened too")
look:OnDestroy()
assert(hero.color == 255 and wearable.color == 255 and extra.color == 255, "tint restored")
effect:Expose()
assert(not effect:IsLingering() and not effect:IsExposed(), "no exposure inside the fountain")

effect.remaining = 1.45
assert(effect:IsLingering() == false, "the first 0.1 s after leaving still reads as inside")
effect.remaining = 0.75
assert(effect:IsLingering())
disarmed, untargetable, no_damage = shielded_state(effect)
assert(disarmed and untargetable and no_damage, "lingering: still shielded until an attempt")
effect:Expose()
assert(effect:IsExposed() and effect:GetTexture() == "pugna_decrepify")
assert(parent.modifiers[LOOK] == nil, "exposed: normal look")
effect:Expose()
assert(parent.modifiers[LOOK] == nil)
disarmed, untargetable, no_damage = shielded_state(effect)
assert(disarmed and untargetable == nil and effect:GetAbsoluteNoDamagePure() == 0, "exposed: disarmed, targetable, takes damage")
effect:OnIntervalThink()
assert(effect:IsExposed(), "exposure lasts while lingering")
effect.remaining = 1.5
effect:OnIntervalThink()
assert(not effect:IsExposed() and parent.modifiers[LOOK] == 1, "returning to the fountain forgives the exposure and restores the look")
effect:OnIntervalThink()
assert(parent.modifiers[LOOK] == 1, "the look is added once")
effect:OnDestroy()
assert(parent.modifiers[LOOK] == nil, "the look ends with the effect")

client = true
local on_client = Effect()
assert(on_client.think == nil and on_client:GetParent().modifiers[LOOK] == nil, "clients only read the stack count")
on_client:OnDestroy()
client = false

-- Filters: damage and debuffs from protected units are dropped; active attempts on enemies while lingering expose.
Filters = {}
local entities, next_index = {[0] = {}}, 1 -- 0: world entity, no methods
EntIndexToHScript = function(index) return entities[index] end
local function Register(entity) entities[next_index] = entity next_index = next_index + 1 return next_index - 1 end
local function Unit(team, state) -- state: nil (unprotected), "inside" or "lingering"
	local unit = {team = team, GetTeamNumber = function(self) return self.team end}
	if state then
		unit.effect = Effect()
		unit.effect.remaining = state == "lingering" and 0.75 or 1.5
	end
	unit.FindModifierByName = function(self, name) return name == "modifier_fountain_protection_effect_lua" and self.effect or nil end
	return unit, Register(unit)
end
local function Ability(name, behavior)
	return Register({GetAbilityName = function() return name end, GetBehavior = function() return behavior end})
end
local active, passive = Ability("sven_storm_bolt", 1 + 4 + 8), Ability("sven_great_cleave", DOTA_ABILITY_BEHAVIOR_PASSIVE)
local radiance, shivas = Ability("item_radiance", 105553120461320), Ability("item_shivas_guard", 4196356)
dofile("scripts/vscripts/filters/damage.lua")
dofile("scripts/vscripts/filters/modifier.lua")
local function damage(victim, attacker, inflictor)
	return Filters:FountainDamageFilter({entindex_victim_const = victim, entindex_attacker_const = attacker, entindex_inflictor_const = inflictor, damage = 100})
end
local function debuff(parent, caster, ability, name)
	return Filters:FountainModifierFilter({entindex_parent_const = parent, entindex_caster_const = caster, entindex_ability_const = ability, name_const = name or "modifier_stunned", duration = 1})
end

local _, enemy = Unit(3)
local _, enemy_too = Unit(4)
local home, home_index = Unit(2, "inside")
assert(damage(enemy, enemy_too) == true and debuff(enemy, enemy_too, active) == true, "unprotected units fight normally")
assert(damage(home_index, enemy) == false and damage(home_index, enemy, active) == false, "shielded inside")
assert(damage(enemy, home_index) == false and damage(enemy, home_index, active) == false, "no damage dealt from the fountain")
assert(debuff(enemy, home_index, active) == false, "no debuffs applied from the fountain")
assert(not home.effect:IsExposed(), "attempts from inside never expose")
assert(damage(enemy, nil) == true and damage(enemy, 0) == true, "missing or non-unit attacker")
assert(debuff(enemy, nil, active) == true and debuff(enemy, 0, active) == true)

-- passive sources are blocked but never expose
local out, out_index = Unit(2, "lingering")
assert(damage(enemy, out_index, passive) == false and damage(enemy, out_index, radiance) == false)
assert(debuff(enemy, out_index, passive, "modifier_generic_passive_debuff") == false)
assert(debuff(enemy, out_index, shivas, "modifier_item_shivas_guard_aura") == false)
assert(debuff(enemy, out_index, radiance, "modifier_item_radiance_debuff") == false)
assert(damage(out_index, out_index, active) == false, "self damage is blocked")
local _, own_unit = Unit(2)
assert(damage(own_unit, out_index) == false and debuff(own_unit, out_index, active) == true, "own team: damage blocked, buffs pass")
assert(debuff(enemy, out_index, nil, "modifier_game_mode_marker") == true, "game mode modifiers without an ability pass")
assert(debuff(enemy, out_index, active, "modifier_truesight") == true, "true sight is not a debuff")
assert(not out.effect:IsExposed(), "passive, self, own team and harmless modifiers never expose")
assert(damage(out_index, enemy) == false, "still shielded")

-- an active attempt exposes: targetable and hittable, but still unable to harm
assert(damage(enemy, out_index) == false and out.effect:IsExposed(), "attempted attack or damage exposes")
assert(damage(out_index, enemy) == true and damage(out_index, enemy, active) == true, "exposed unit takes damage")
assert(damage(enemy, out_index, active) == false and debuff(enemy, out_index, active) == false, "exposed unit still can't harm")

local caster, caster_index = Unit(2, "lingering")
assert(debuff(enemy, caster_index, active) == false and caster.effect:IsExposed(), "attempted debuff exposes")
local shivas_caster, shivas_index = Unit(2, "lingering")
assert(debuff(enemy, shivas_index, shivas, "modifier_item_shivas_guard_blast") == false and shivas_caster.effect:IsExposed(), "an item's active still counts")
local shielded_victim, victim_index = Unit(3, "lingering")
local striker, striker_index = Unit(2, "lingering")
assert(damage(victim_index, striker_index) == false and striker.effect:IsExposed() and not shielded_victim.effect:IsExposed(), "attempt on a shielded unit exposes the attacker")

-- Registered only on the configurable FFA map.
local registered = {}
local game_mode = {
	SetDamageFilter = function(_, callback) registered.damage = callback end,
	SetModifierGainedFilter = function(_, callback) registered.modifier = callback end,
	SetModifyExperienceFilter = function() end, SetModifyGoldFilter = function() end,
	SetExecuteOrderFilter = function() end, SetItemAddedToInventoryFilter = function() end, SetHealingFilter = function() end,
}
GameRules = {GetGameModeEntity = function() return game_mode end}
Dynamic_Wrap = function(scope, name) return scope[name] end
local original_require = require
require = function() end
dofile("scripts/vscripts/filters/init.lua")
require = original_require
for _, host_map in ipairs({true, false}) do
	registered = {}
	UsesHostRules = function() return host_map end
	Filters:Init()
	assert((registered.damage == Filters.FountainDamageFilter) == host_map)
	assert((registered.modifier == Filters.FountainModifierFilter) == host_map)
end
print("PASS fountain protection: own fountain zone plus 1.5 second linger, dark look until exposed, disarmed, untargetable and shielded until an active attempt while lingering, no damage or debuffs dealt, filters on FFA only")
