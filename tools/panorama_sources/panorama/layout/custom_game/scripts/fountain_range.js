const particle_name = "particles/ui/fountain_range/fountain_range.vpcf";
const aura_bonus_range = 450;
// range checks while the unit is away from every enemy fountain
const update_interval = 0.1;

const fountain_particles = {};

function UpdateFountainParticles() {
	const portrait_unit = Players.GetLocalPlayerPortraitUnit();
	if (!portrait_unit || portrait_unit == -1) return void $.Schedule(update_interval, UpdateFountainParticles);

	const current_pos = Entities.GetAbsOrigin(portrait_unit);
	const alt_down = GameUI.IsAltDown();
	let tracking = false;

	for (const config of Object.values(fountain_particles)) {
		const current_attack_radius = Entities.GetAttackRange(config.unit);

		const distance = Vector.len(Vector.sub(current_pos, config.position));
		const is_in_range = alt_down || distance <= current_attack_radius + aura_bonus_range;
		const is_targeted = alt_down || distance <= current_attack_radius;
		// the target marker only follows a control point set by script, not one attached to the unit
		const follows_unit = is_in_range && !alt_down;
		const target_position = follows_unit ? current_pos : config.position;
		tracking = tracking || follows_unit;

		if (is_in_range != config.is_in_range) {
			config.is_in_range = is_in_range;
			Particles.SetParticleControl(config.p_id, 6, [is_in_range ? 1 : 0, 0, 0]);
		}
		if (target_position.some((value, i) => value != config.target_position[i])) {
			config.target_position = target_position;
			Particles.SetParticleControl(config.p_id, 7, target_position);
		}
		if (is_targeted != config.is_targeted) {
			config.is_targeted = is_targeted;
			Particles.SetParticleControl(config.p_id, 13, [is_targeted ? 1 : 0, is_targeted ? 1 : 0, 2]);
		}
	}

	// every frame only while the marker follows the unit inside a ring
	$.Schedule(tracking ? 0 : update_interval, UpdateFountainParticles);
}

function CreateFountainParticleAt(unit, team) {
	const p_id = Particles.CreateParticle(particle_name, ParticleAttachment_t.PATTACH_WORLDORIGIN, -1);
	const team_color = GameUI.CustomUIConfig().team_colors_rgb[team] || [1, 1, 1];
	const position = Entities.GetAbsOrigin(unit);

	const radius_value = Entities.GetAttackRange(unit) + aura_bonus_range;

	// ffa has double highground, place particle below (otherwise it breaks, and there's no way to fix that in the particle)
	position[2] = 117;

	// 0, 2 - position
	Particles.SetParticleControl(p_id, 0, position);
	Particles.SetParticleControl(p_id, 2, position);
	// 3 - radius
	Particles.SetParticleControl(p_id, 3, [radius_value, 0, 0]);
	// 4 - color
	Particles.SetParticleControl(p_id, 4, [team_color[0] / 255.0, team_color[1] / 255.0, team_color[2] / 255.0]);
	// src model
	Particles.SetParticleControlEnt(
		p_id,
		5,
		unit,
		ParticleAttachment_t.PATTACH_ABSORIGIN_FOLLOW,
		"attach_attack1",
		position,
		true,
	);
	// 6 - is in range
	Particles.SetParticleControl(p_id, 6, [0, 0, 0]);
	// 7 - target hero pos (the fountain while out of range)
	Particles.SetParticleControl(p_id, 7, position);
	// 9 - danger level (always on here as fountain is deadly)
	Particles.SetParticleControl(p_id, 9, [2, 0, 0]);
	// 13 - config [is_in_range, is_targeted, danger_level]
	Particles.SetParticleControl(p_id, 13, [0, 0, 2]);

	fountain_particles[team] = {
		unit: unit,
		position: position,
		p_id: p_id,
		is_in_range: false,
		is_targeted: false,
		target_position: position,
	};
}

function Init() {
	if (Game.GameStateIsBefore(DOTA_GameState.DOTA_GAMERULES_STATE_PRE_GAME)) return $.Schedule(0.5, Init);

	const info = Game.GetLocalPlayerInfo();
	if (info.player_id < 0) return $.Schedule(0.5, Init);

	const range_sources = Entities.GetAllEntitiesByClassname("npc_dota_tower");
	if (range_sources.length <= 0) {
		return $.Schedule(0.1, Init);
	}

	for (const unit of range_sources) {
		const team = Entities.GetTeamNumber(unit);

		if (team != info.player_team_id) {
			CreateFountainParticleAt(unit, team);
		}
	}

	UpdateFountainParticles();
}

(() => {
	Init();
})();
