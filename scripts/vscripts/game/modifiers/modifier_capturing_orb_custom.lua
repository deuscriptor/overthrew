modifier_capturing_orb_custom = modifier_capturing_orb_custom or class({})


function modifier_capturing_orb_custom:IsHidden() return true end
function modifier_capturing_orb_custom:IsPurgable() return false end
function modifier_capturing_orb_custom:RemoveOnDeath() return true end
