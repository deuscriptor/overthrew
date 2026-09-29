class = function(t) return t end
LinkLuaModifier = function() end
MODIFIER_STATE_DEBUFF_IMMUNE, MODIFIER_STATE_INVISIBLE, MODIFIER_STATE_TRUESIGHT_IMMUNE, MODIFIER_STATE_NOT_ON_MINIMAP_FOR_ENEMIES = 1, 2, 3, 4
MODIFIER_PROPERTY_HEALTH_REGEN_PERCENTAGE, MODIFIER_PROPERTY_MANA_REGEN_TOTAL_PERCENTAGE = 10, 11
MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING, MODIFIER_PROPERTY_INVISIBILITY_LEVEL = 12, 13
PATTACH_ABSORIGIN_FOLLOW = 1
local client = false
IsClient = function() return client end
IsValidEntity = function(v) return v ~= nil end
local host_map, locked, all_vision = true, true, true
UsesHostRules = function() return host_map end
HostOptions = {GetOption = function(_, name) return name == "all_vision" and all_vision end}
setmetatable(HostOptions, {__index = function(_, key) if key == "locked" then return locked end end})
local particles = 0
ParticleManager = setmetatable({}, {__index = function() return function() particles = particles + 1 end end})

dofile("scripts/vscripts/game/modifiers/modifier_fountain_rejuvenation_lua.lua")

local function Unit(team)
	return {
		team = team,
		GetTeamNumber = function(self) return self.team end,
		GetUnitName = function() return "npc_dota_hero_sven" end,
		FindItemInInventory = function() end,
		FindModifierByName = function() end,
		Purge = function() end,
	}
end
local function Effect(unit)
	local effect = setmetatable({stacks = 0}, {__index = modifier_fountain_rejuvenation_effect_lua})
	effect.GetParent = function() return unit end
	effect.SetStackCount = function(self, value) self.stacks = value end
	effect.GetStackCount = function(self) return self.stacks end
	effect.StartIntervalThink = function() end
	effect:OnCreated()
	return effect
end
local function has(list, value) for _, v in ipairs(list) do if v == value then return true end end return false end

-- All Vision on the configurable map: smoked, hidden from true sight and the minimap, with no smoke visuals.
local sven = Unit(2)
local effect = Effect(sven)
local state = effect:CheckState()
assert(effect:GetStackCount() == 1 and effect:GetModifierInvisibilityLevel() == 0, "invisible without the translucent model")
assert(state[MODIFIER_STATE_INVISIBLE] and state[MODIFIER_STATE_TRUESIGHT_IMMUNE] and state[MODIFIER_STATE_NOT_ON_MINIMAP_FOR_ENEMIES])
assert(state[MODIFIER_STATE_DEBUFF_IMMUNE], "fountain debuff immunity kept")
assert(has(effect:DeclareFunctions(), MODIFIER_PROPERTY_INVISIBILITY_LEVEL))
assert(particles == 0 and effect.OnDestroy == nil, "no smoke particle")

-- Clients only read the stack count the server set.
client = true
local on_client = Effect(Unit(3))
assert(on_client:GetStackCount() == 0)
on_client:SetStackCount(1)
assert(on_client:CheckState()[MODIFIER_STATE_INVISIBLE])
client = false

-- All Vision off, rules not locked yet, or another map: no smoke.
for _, case in ipairs({{true, true, false}, {true, false, true}, {false, true, true}}) do
	host_map, locked, all_vision = case[1], case[2], case[3]
	local plain = Effect(Unit(2))
	local plain_state = plain:CheckState()
	assert(plain:GetStackCount() == 0 and plain:GetModifierInvisibilityLevel() == 0)
	assert(not plain_state[MODIFIER_STATE_INVISIBLE] and not plain_state[MODIFIER_STATE_NOT_ON_MINIMAP_FOR_ENEMIES])
	assert(plain_state[MODIFIER_STATE_DEBUFF_IMMUNE])
end
assert(particles == 0)
print("PASS fountain smoke: All Vision only, invisible to enemies incl. true sight and minimap, no smoke visuals")
