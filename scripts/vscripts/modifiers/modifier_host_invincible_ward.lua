modifier_host_invincible_ward = class({})

function modifier_host_invincible_ward:IsHidden() return true end
function modifier_host_invincible_ward:IsPurgable() return false end

function modifier_host_invincible_ward:CheckState()
	return {
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_ATTACK_IMMUNE] = true,
	}
end
