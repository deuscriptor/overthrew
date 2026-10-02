class = function(t) return t end
local original_require = require
LinkLuaModifier = function() end
MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE = 1
DOTA_UNIT_TARGET_FLAG_NONE, DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_BASIC = 0, 1, 1, 18
MODIFIER_STATE_DEBUFF_IMMUNE, MODIFIER_STATE_INVISIBLE, MODIFIER_STATE_TRUESIGHT_IMMUNE, MODIFIER_STATE_NOT_ON_MINIMAP_FOR_ENEMIES = 1, 2, 3, 4
MODIFIER_STATE_DISARMED, MODIFIER_STATE_UNTARGETABLE_ENEMY = 5, 39
MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_MAGICAL, MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PHYSICAL, MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PURE = 20, 21, 22
MODIFIER_PROPERTY_HEALTH_REGEN_PERCENTAGE, MODIFIER_PROPERTY_MANA_REGEN_TOTAL_PERCENTAGE = 10, 11
MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING, MODIFIER_PROPERTY_INVISIBILITY_LEVEL = 12, 13
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

-- The aura covers the same zone and units as fountain rejuvenation, and ends as soon as a unit leaves it.
local aura, rejuvenation = Aura(modifier_fountain_protection_lua), Aura(modifier_fountain_rejuvenation_lua)
assert(aura:IsAura() and aura:IsHidden() and not aura:IsPurgable())
assert(aura:GetModifierAura() == "modifier_fountain_protection_effect_lua")
assert(aura:GetAuraRadius() == 1194 and aura:GetAuraRadius() == rejuvenation:GetAuraRadius())
assert(aura:GetAuraSearchTeam() == rejuvenation:GetAuraSearchTeam() and aura:GetAuraSearchType() == rejuvenation:GetAuraSearchType())
assert(aura:GetAuraSearchFlags() == rejuvenation:GetAuraSearchFlags())
assert(aura:GetAuraDuration() == 0, "protection doesn't linger after leaving the fountain")

-- Effect: disarmed, untargetable by enemies, no damage taken, with the dark look.
local effect = setmetatable({}, {__index = modifier_fountain_protection_effect_lua})
assert(not effect:IsPurgable() and effect:GetTexture() == "omniknight_guardian_angel")
local functions = effect:DeclareFunctions()
for _, property in ipairs({MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_MAGICAL, MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PHYSICAL, MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PURE}) do
	assert(has(functions, property))
end
local state = effect:CheckState()
assert(state[MODIFIER_STATE_DISARMED] == true and state[MODIFIER_STATE_UNTARGETABLE_ENEMY] == true, "disarmed, untargetable by enemies")
assert(effect:GetAbsoluteNoDamageMagical() == 1 and effect:GetAbsoluteNoDamagePhysical() == 1 and effect:GetAbsoluteNoDamagePure() == 1, "no damage taken")
assert(effect:StatusEffectPriority() == 20000)
assert(effect:GetStatusEffectName() == "particles/status_fx/status_effect_dark_willow_shadow_realm.vpcf", "native fountain invulnerability look")
-- the look darkens the model and its cosmetics, and restores them when it ends
local function Model(class_name) return {class_name = class_name, color = 255, GetClassname = function(self) return self.class_name end,
	SetRenderColor = function(self, r, g, b) assert(r == g and g == b) self.color = r end} end
local hero, wearable, extra, thinker = Model("npc_dota_hero_sven"), Model("dota_item_wearable"), Model("additional_wearable"), Model("npc_dota_thinker")
local peers = {wearable, thinker, extra}
for i, model in ipairs(peers) do model.NextMovePeer = function() return peers[i + 1] end end
hero.FirstMoveChild = function() return peers[1] end
effect.GetParent = function() return hero end
effect.StartIntervalThink = function(self, interval) self.think = interval end
effect:OnCreated()
assert(hero.color == 40 and wearable.color == 40 and extra.color == 40 and thinker.color == 255 and effect.think == 0.5, "dark tint")
wearable.color = 255
effect:OnIntervalThink()
assert(wearable.color == 40, "cosmetics equipped later are darkened too")
effect:OnDestroy()
assert(hero.color == 255 and wearable.color == 255 and extra.color == 255, "tint restored")

client = true
local on_client = setmetatable({GetParent = function() return hero end}, {__index = modifier_fountain_protection_effect_lua})
hero.color = 77
on_client:OnCreated()
on_client:OnDestroy()
assert(on_client.think == nil and hero.color == 77, "clients leave the tint to the server")
client = false

-- Damage filter: damage to and from protected units is dropped. Debuffs aren't filtered.
Filters = {}
local entities, next_index = {[0] = {}}, 1 -- 0: world entity, no methods
EntIndexToHScript = function(index) return entities[index] end
local function Register(entity) entities[next_index] = entity next_index = next_index + 1 return next_index - 1 end
local function Unit(team, protected)
	local unit = {team = team, GetTeamNumber = function(self) return self.team end}
	unit.HasModifier = function(_, name) return protected == true and name == "modifier_fountain_protection_effect_lua" end
	return unit, Register(unit)
end
local active = Register({GetAbilityName = function() return "sven_storm_bolt" end})
dofile("scripts/vscripts/filters/damage.lua")
dofile("scripts/vscripts/filters/modifier.lua")
local function damage(victim, attacker, inflictor)
	return Filters:FountainDamageFilter({entindex_victim_const = victim, entindex_attacker_const = attacker, entindex_inflictor_const = inflictor, damage = 100})
end

local _, enemy = Unit(3)
local _, enemy_too = Unit(4)
local _, home = Unit(2, true)
local _, other_home = Unit(3, true)
local _, own_unit = Unit(2)
assert(damage(enemy, enemy_too) == true and damage(enemy, enemy_too, active) == true, "unprotected units fight normally")
assert(damage(home, enemy) == false and damage(home, enemy, active) == false, "protected units take no damage")
assert(damage(enemy, home) == false and damage(enemy, home, active) == false, "no damage dealt from the fountain")
assert(damage(other_home, home) == false and damage(home, home, active) == false and damage(own_unit, home) == false,
	"nor to a protected enemy, to itself or to its own team")
assert(damage(enemy, nil) == true and damage(enemy, 0) == true, "missing or non-unit attacker")
assert(damage(home, nil) == false and damage(home, 0) == false, "protected victims take no damage from the world either")
assert(Filters.FountainModifierFilter == nil, "no modifier filter: protected units apply debuffs")

-- Protected heroes can't capture or contest orbs.
require = function() end
dofile("scripts/vscripts/game/capture_points/capture_point_area.lua")
require = original_require
local function Hero(modifiers)
	return {
		IsInvulnerable = function() return false end,
		HasModifier = function(_, name) return modifiers[name] == true end,
		IsSpiritBear = function() return false end, GetUnitLabel = function() return "" end,
		IsRealHero = function() return true end, IsTempestDouble = function() return false end, IsMonkeyClone = function() return false end,
	}
end
assert(capture_point_area:ValidCapturingUnit(Hero({})) == true, "an unprotected hero captures")
assert(capture_point_area:ValidCapturingUnit(Hero({modifier_fountain_protection_effect_lua = true})) == false, "a protected hero doesn't")

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
require = function() end
dofile("scripts/vscripts/filters/init.lua")
require = original_require
registered = {}
Filters:Init()
assert(registered.damage == Filters.FountainDamageFilter)
assert(registered.modifier == nil, "the modifier gained filter stays off")
print("PASS fountain protection: own fountain zone only, no linger, dark look, disarmed, untargetable, no damage taken or dealt, debuffs pass, no orb captures, damage filter registered")
