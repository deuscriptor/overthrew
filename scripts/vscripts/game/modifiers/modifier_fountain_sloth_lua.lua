modifier_fountain_sloth_lua = modifier_fountain_sloth_lua or class({})
LinkLuaModifier("modifier_fountain_sloth_effect_lua", "game/modifiers/modifier_fountain_sloth_lua", LUA_MODIFIER_MOTION_NONE)

-- Fountain Sloth host option (added in FountainSloth:ApplyRules). Heroes on their own fountain recover ability
-- cooldowns at half speed, except during the grace period after each spawn. The rules live in game/fountain_sloth.lua.
function modifier_fountain_sloth_lua:IsHidden() return true end
function modifier_fountain_sloth_lua:IsAura() return true end
function modifier_fountain_sloth_lua:IsPurgable() return false end
function modifier_fountain_sloth_lua:GetAttributes() return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE end


-- Same zone as modifier_fountain_protection_lua. A respawned hero stays invulnerable and out of game until it acts
-- (modifier_fountain_invulnerability), and idling there is slowed too.
function modifier_fountain_sloth_lua:GetAuraRadius() return self:GetParent():Script_GetAttackRange() + 144 end
function modifier_fountain_sloth_lua:GetAuraDuration() return 0 end
function modifier_fountain_sloth_lua:GetAuraSearchFlags()
	return DOTA_UNIT_TARGET_FLAG_INVULNERABLE + DOTA_UNIT_TARGET_FLAG_OUT_OF_WORLD
end
function modifier_fountain_sloth_lua:GetAuraSearchTeam() return DOTA_UNIT_TARGET_TEAM_FRIENDLY end
function modifier_fountain_sloth_lua:GetAuraSearchType() return DOTA_UNIT_TARGET_HERO end
function modifier_fountain_sloth_lua:GetModifierAura() return "modifier_fountain_sloth_effect_lua" end

function modifier_fountain_sloth_lua:GetAuraEntityReject(entity)
	return entity:IsIllusion() or FountainSloth:InGrace(entity)
end


-- The engine ignores MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE_ONGOING on Lua modifiers, and StartCooldown resets the HUD
-- cooldown sweep. So recovering abilities are frozen for every other interval: half speed, sweep intact. Freezes
-- are counted, so each one is undone exactly once and those of other sources stay. Items are left alone.
modifier_fountain_sloth_effect_lua = modifier_fountain_sloth_effect_lua or class({})

modifier_fountain_sloth_effect_lua.interval = 0.1

function modifier_fountain_sloth_effect_lua:IsDebuff() return true end
function modifier_fountain_sloth_effect_lua:IsPurgable() return false end
-- reaches heroes still invulnerable from their respawn
function modifier_fountain_sloth_effect_lua:GetAttributes() return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE end
function modifier_fountain_sloth_effect_lua:GetTexture() return "faceless_void_time_dilation" end

function modifier_fountain_sloth_effect_lua:OnCreated()
	if IsClient() then return end
	self.frozen = {}
	self:OnIntervalThink()
	self:StartIntervalThink(self.interval)
end

-- Thinks alternate between freezing and thawing, so abilities are scanned only on every other think.
function modifier_fountain_sloth_effect_lua:OnIntervalThink()
	if self.thaw_next then
		self:Thaw()
	else
		self:Freeze()
	end
	self.thaw_next = not self.thaw_next
end

-- an ability on cooldown, or one restoring a charge
local function IsRecovering(ability)
	if not ability:IsCooldownReady() then return true end
	local charges = ability:GetMaxAbilityCharges(ability:GetLevel())
	return charges > 0 and ability:GetCurrentAbilityCharges() < charges
end

function modifier_fountain_sloth_effect_lua:Freeze()
	local parent = self:GetParent()
	for index = 0, parent:GetAbilityCount() - 1 do
		local ability = parent:GetAbilityByIndex(index)
		if ability and ability:GetLevel() > 0 and IsRecovering(ability) then
			ability:SetFrozenCooldown(true)
			table.insert(self.frozen, ability)
		end
	end
end

function modifier_fountain_sloth_effect_lua:Thaw()
	local frozen = self.frozen
	for index = 1, #frozen do
		if not frozen[index]:IsNull() then frozen[index]:SetFrozenCooldown(false) end
		frozen[index] = nil
	end
end

function modifier_fountain_sloth_effect_lua:OnDestroy()
	if IsClient() then return end
	self:Thaw()
end
