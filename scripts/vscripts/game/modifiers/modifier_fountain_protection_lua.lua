modifier_fountain_protection_lua = modifier_fountain_protection_lua or class({})
LinkLuaModifier("modifier_fountain_protection_effect_lua", "game/modifiers/modifier_fountain_protection_lua", LUA_MODIFIER_MOTION_NONE)

-- Configurable FFA only (added in GameLoop:InitTowers). Units on their own fountain are protected, and the protection
-- ends as soon as they leave it: the aura doesn't linger. Damage and debuff rules live in game/fountain_protection.lua.
function modifier_fountain_protection_lua:IsHidden() return true end
function modifier_fountain_protection_lua:IsAura() return true end
function modifier_fountain_protection_lua:IsPurgable() return false end
function modifier_fountain_protection_lua:GetAttributes() return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE end


-- same zone as modifier_fountain_rejuvenation_lua
function modifier_fountain_protection_lua:GetAuraRadius() return self:GetParent():Script_GetAttackRange() + 144 end
function modifier_fountain_protection_lua:GetAuraDuration() return 0 end
function modifier_fountain_protection_lua:GetAuraSearchFlags() return DOTA_UNIT_TARGET_FLAG_NONE end
function modifier_fountain_protection_lua:GetAuraSearchTeam() return DOTA_UNIT_TARGET_TEAM_FRIENDLY end
function modifier_fountain_protection_lua:GetAuraSearchType() return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC end
function modifier_fountain_protection_lua:GetModifierAura() return "modifier_fountain_protection_effect_lua" end


-- Disarmed, untargetable by enemies and immune to damage.
modifier_fountain_protection_effect_lua = modifier_fountain_protection_effect_lua or class({})

function modifier_fountain_protection_effect_lua:IsPurgable() return false end
function modifier_fountain_protection_effect_lua:GetTexture() return "omniknight_guardian_angel" end

function modifier_fountain_protection_effect_lua:CheckState()
	return {
		[MODIFIER_STATE_DISARMED] = true,
		[MODIFIER_STATE_UNTARGETABLE_ENEMY] = true,
	}
end

function modifier_fountain_protection_effect_lua:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_MAGICAL, -- GetAbsoluteNoDamageMagical
		MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PHYSICAL, -- GetAbsoluteNoDamagePhysical
		MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PURE, -- GetAbsoluteNoDamagePure
	}
end

function modifier_fountain_protection_effect_lua:GetAbsoluteNoDamageMagical() return 1 end
function modifier_fountain_protection_effect_lua:GetAbsoluteNoDamagePhysical() return 1 end
function modifier_fountain_protection_effect_lua:GetAbsoluteNoDamagePure() return 1 end


-- The look of the native AFK fountain invulnerability: CDOTA_Modifier_FountainInvulnerabilityBuff in client.dll
-- returns this status effect (Dark Willow's Shadow Realm) with priority 20000.
function modifier_fountain_protection_effect_lua:GetStatusEffectName()
	return "particles/status_fx/status_effect_dark_willow_shadow_realm.vpcf"
end
function modifier_fountain_protection_effect_lua:StatusEffectPriority() return 20000 end

-- The status effect keeps the model's own brightness: dark heroes turn black, light ones icy chrome. Darkening the
-- model and its cosmetics (separate entities) makes every hero look like the native effect on a dark hero.
modifier_fountain_protection_effect_lua.tint = 40

function modifier_fountain_protection_effect_lua:OnCreated()
	if IsClient() then return end
	self:Tint(self.tint)
	self:StartIntervalThink(0.5)
end

-- cosmetics equipped while on the fountain
function modifier_fountain_protection_effect_lua:OnIntervalThink()
	self:Tint(self.tint)
end

function modifier_fountain_protection_effect_lua:OnDestroy()
	if IsClient() then return end
	self:Tint(255)
end

function modifier_fountain_protection_effect_lua:Tint(value)
	local parent = self:GetParent()
	if not IsValidEntity(parent) then return end
	parent:SetRenderColor(value, value, value)

	local model = parent:FirstMoveChild()
	while model ~= nil do
		local class_name = model:GetClassname()
		if class_name == "dota_item_wearable" or class_name == "prop_dynamic" or class_name == "additional_wearable" then
			model:SetRenderColor(value, value, value)
		end
		model = model:NextMovePeer()
	end
end
