-- Run from the addon root: lua tools/test_fountain_sloth.lua
-- Fountain Sloth: the aura's zone, targets and grace period, and the freeze/thaw cycle that halves cooldown speed.
class = function(t) return t end
LinkLuaModifier = function() end
MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE = 1
DOTA_UNIT_TARGET_FLAG_NONE, DOTA_UNIT_TARGET_FLAG_INVULNERABLE, DOTA_UNIT_TARGET_FLAG_OUT_OF_WORLD = 0, 64, 262144
DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_BASIC = 1, 1, 18
MODIFIER_STATE_DISARMED, MODIFIER_STATE_UNTARGETABLE_ENEMY = 5, 39
MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_MAGICAL, MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PHYSICAL, MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PURE = 20, 21, 22
local client = false
IsClient = function() return client end
IsValidEntity = function(v) return v ~= nil and not v.removed end
local now = 100
GameRules = {GetGameTime = function() return now end}
local listeners = {}
-- the engine calls callback(context, event)
ListenToGameEvent = function(name, callback, context) table.insert(listeners, {name = name, callback = callback, context = context}) end
Dynamic_Wrap = function(scope, name) return function(...) return scope[name](...) end end
local entities = {}
EntIndexToHScript = function(index) return entities[index] end
HostOptions = {locked = false, options = {fountain_sloth = true}}
function HostOptions:GetOption(name) return self.options[name] or false end

dofile("scripts/vscripts/game/modifiers/modifier_fountain_protection_lua.lua")
dofile("scripts/vscripts/game/modifiers/modifier_fountain_sloth_lua.lua")
dofile("scripts/vscripts/game/fountain_sloth.lua")

local tower = {Script_GetAttackRange = function() return 1050 end}
local function Aura(class_table)
	return setmetatable({GetParent = function() return tower end}, {__index = class_table})
end

-- The zone is the fountain protection zone; heroes only, including ones invulnerable and out of game after a respawn.
local aura, protection = Aura(modifier_fountain_sloth_lua), Aura(modifier_fountain_protection_lua)
assert(aura:IsAura() and aura:IsHidden() and not aura:IsPurgable())
assert(aura:GetAttributes() == MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE)
assert(aura:GetModifierAura() == "modifier_fountain_sloth_effect_lua")
assert(aura:GetAuraRadius() == protection:GetAuraRadius() and aura:GetAuraSearchTeam() == protection:GetAuraSearchTeam())
assert(aura:GetAuraSearchType() == DOTA_UNIT_TARGET_HERO, "heroes only")
assert(aura:GetAuraSearchFlags() == DOTA_UNIT_TARGET_FLAG_INVULNERABLE + DOTA_UNIT_TARGET_FLAG_OUT_OF_WORLD, "respawned heroes idling on the fountain")
assert(aura:GetAuraDuration() == 0, "the sloth doesn't linger after leaving the fountain")

-- Each spawn (respawn and buyback included) of a hero starts the grace period; illusions are never slowed.
local function Unit(index, hero, illusion)
	local unit = {IsHero = function() return hero end, IsIllusion = function() return illusion == true end}
	entities[index] = unit
	return unit
end
local sven, illusion, creep = Unit(1, true), Unit(2, true, true), Unit(3, false)
assert(not aura:GetAuraEntityReject(sven), "a hero never spawned in this match is slowed")
assert(aura:GetAuraEntityReject(illusion), "illusions are rejected")
for index = 1, 3 do FountainSloth:OnNPCSpawned({entindex = index}) end
FountainSloth:OnNPCSpawned({entindex = 99})
assert(sven.fountain_sloth_grace_end == 105 and illusion.fountain_sloth_grace_end == nil and creep.fountain_sloth_grace_end == nil)
assert(aura:GetAuraEntityReject(sven), "grace period after spawning")
now = 104.9
assert(aura:GetAuraEntityReject(sven))
now = 105
assert(not aura:GetAuraEntityReject(sven), "slowed once the grace period ends")
now = 200
FountainSloth:OnNPCSpawned({entindex = 1})
assert(aura:GetAuraEntityReject(sven) and sven.fountain_sloth_grace_end == 205, "every respawn restarts it")

-- Applied once the rules lock, only with the option on: the aura goes on every fountain tower.
local function Tower()
	local t = {modifiers = {}}
	t.AddNewModifier = function(self, caster, ability, name, keys)
		assert(caster == self and ability == nil and keys.duration == -1)
		table.insert(self.modifiers, name)
	end
	return t
end
GameLoop = {towers = {[2] = Tower(), [3] = Tower()}}
FountainSloth:ApplyRules()
assert(#listeners == 0 and #GameLoop.towers[2].modifiers == 0, "nothing before the rules lock")
HostOptions.locked = true
HostOptions.options.fountain_sloth = false
FountainSloth:ApplyRules()
assert(#listeners == 0 and #GameLoop.towers[2].modifiers == 0, "nothing with the option off")
HostOptions.options.fountain_sloth = true
FountainSloth:ApplyRules()
FountainSloth:ApplyRules()
assert(#listeners == 1 and listeners[1].name == "npc_spawned" and listeners[1].context == FountainSloth, "spawns tracked once")
for _, t in pairs(GameLoop.towers) do
	assert(#t.modifiers == 1 and t.modifiers[1] == "modifier_fountain_sloth_lua", "one aura per fountain")
end
now = 300
listeners[1].callback(listeners[1].context, {entindex = 1})
assert(sven.fountain_sloth_grace_end == 305, "the registered listener starts the grace period")

-- Effect: a debuff that reaches invulnerable heroes and thinks every 0.1 s.
local effect_class = modifier_fountain_sloth_effect_lua
assert(effect_class:IsDebuff() and not effect_class:IsPurgable())
assert(effect_class:GetAttributes() == MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE)
assert(effect_class:GetTexture() == "faceless_void_time_dilation")
assert(effect_class.DeclareFunctions == nil, "no modifier properties: the engine ignores ongoing cooldown speed on Lua modifiers")

-- Abilities with a stack-counted frozen state, like the engine's.
local function Ability(level, remaining, max_charges, charges)
	local ability = {level = level, remaining = remaining, max_charges = max_charges or 0, charges = charges or 0, freezes = 0}
	function ability:GetLevel() return self.level end
	function ability:IsCooldownReady() return self.remaining <= 0 end
	function ability:GetMaxAbilityCharges(l) assert(l == self.level) return self.max_charges end
	function ability:GetCurrentAbilityCharges() return self.charges end
	function ability:SetFrozenCooldown(frozen) self.freezes = self.freezes + (frozen and 1 or -1) end
	function ability:IsNull() return self.removed == true end
	return ability
end
local on_cooldown, ready, unlearned = Ability(1, 10), Ability(2, 0), Ability(0, 5)
local restoring, full_charges = Ability(1, 0, 3, 2), Ability(1, 0, 3, 3)
local slots = {[0] = on_cooldown, [1] = ready, [2] = unlearned, [4] = restoring, [5] = full_charges}
local hero = {
	GetAbilityCount = function() return 6 end,
	GetAbilityByIndex = function(_, index) return slots[index] end,
}
local effect = setmetatable({GetParent = function() return hero end}, {__index = effect_class})
effect.StartIntervalThink = function(self, interval) self.think = interval end
local function freezes() return on_cooldown.freezes, ready.freezes, unlearned.freezes, restoring.freezes, full_charges.freezes end
local function frozen(a, b, c, d, e)
	local fa, fb, fc, fd, fe = freezes()
	return fa == a and fb == b and fc == c and fd == d and fe == e
end

effect:OnCreated()
assert(effect.think == 0.1)
assert(frozen(1, 0, 0, 1, 0), "arriving freezes cooldowns and charge restores at once; ready and unlearned abilities stay as they are")
effect:OnIntervalThink()
assert(frozen(0, 0, 0, 0, 0), "the next think thaws exactly what was frozen")
-- A cooldown sampled over one second: frozen for every other 0.1 s, so it recovers half a second.
local recovered = 0
for _ = 1, 10 do
	effect:OnIntervalThink()
	if on_cooldown.freezes == 0 then recovered = recovered + 0.1 end
end
assert(math.abs(recovered - 0.5) < 1e-9, "half speed")
-- A cooldown started while frozen runs until the next freeze; a cooldown that ended is no longer frozen.
assert(on_cooldown.freezes == 0)
effect:OnIntervalThink()
ready.remaining = 3
on_cooldown.remaining = 0
effect:OnIntervalThink()
effect:OnIntervalThink()
assert(frozen(0, 1, 0, 1, 0))
-- Leaving, dying or the aura ending thaw everything; a removed ability is skipped.
restoring.removed = true
effect:OnDestroy()
assert(frozen(0, 0, 0, 1, 0) and #effect.frozen == 0, "thawed on destroy")
effect:OnDestroy()
assert(frozen(0, 0, 0, 1, 0), "thawing twice changes nothing")
local function Effect()
	local instance = setmetatable({GetParent = function() return hero end}, {__index = effect_class})
	instance.StartIntervalThink = function() end
	return instance
end
-- Another source's freeze is kept.
ready.freezes = 1
local other = Effect()
other:OnCreated()
assert(ready.freezes == 2)
other:OnDestroy()
assert(ready.freezes == 1, "only its own freezes are undone")
-- With nothing recovering, the abilities are still scanned only on every other think.
ready.remaining, restoring.charges = 0, 3
local scans = 0
hero.GetAbilityCount = function() scans = scans + 1 return 6 end
local idle = Effect()
idle:OnCreated()
for _ = 1, 10 do idle:OnIntervalThink() end
assert(scans == 6 and #idle.frozen == 0, "one scan per 0.2 s: " .. scans)

client = true
local on_client = setmetatable({GetParent = function() error("clients leave cooldowns to the server") end}, {__index = effect_class})
on_client:OnCreated()
on_client:OnDestroy()
assert(on_client.think == nil and on_client.frozen == nil)
client = false
print("PASS fountain sloth: fountain zone, heroes only (invulnerable included), no illusions, 5 s grace per spawn, applied once when on, half-speed freeze cycle for cooldowns and charges, thawed on leave")
