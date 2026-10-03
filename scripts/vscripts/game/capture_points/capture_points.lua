local ORB_PARTICLE_NAME = {
	[UPGRADE_RARITY_COMMON] = "particles/orb_common.vpcf",
	[UPGRADE_RARITY_RARE] = "particles/orb_rare.vpcf",
	[UPGRADE_RARITY_EPIC] = "particles/orb_epic.vpcf",
}

function GameMode:SpawnOrbDrop(spawn_point, orb_type, should_launch, on_destroyed_callback)
	local source_orb_type = orb_type
	orb_type = ResolveOrbRarity(orb_type)
	EmitGlobalSound("Item.PickUpGemWorld")

	local capture_point = CreateUnitByName("npc_dummy_capture", spawn_point, false, nil, nil, DOTA_TEAM_NEUTRALS)
	capture_point:SetOrigin(spawn_point)
	capture_point:AddNewModifier(capture_point, nil, "capture_point_area", {
		orb_type = orb_type, source_orb_type = source_orb_type, should_launch = should_launch
	})
	capture_point.on_destroyed_callback = on_destroyed_callback

	capture_point.orb_fx = ParticleManager:CreateParticle(ORB_PARTICLE_NAME[orb_type], PATTACH_ABSORIGIN_FOLLOW, capture_point)
	local origin = GetGroundPosition(capture_point:GetOrigin(), capture_point)
	ParticleManager:SetParticleControl(capture_point.orb_fx, 0, origin)
	ParticleManager:SetParticleControl(capture_point.orb_fx, 3, origin)

	return capture_point
end

-- models/props_winter/present.vmdl
