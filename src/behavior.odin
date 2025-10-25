package game

import "core:log"

// Fire in a direction at a constant speed

Behavior_Missile :: struct {
	cfg:          struct {
		speed:        f32,
		lifetime_sec: f32,
	},
	state:        enum {
		inactive,
		active,
	},
	trigger_time: f64,
	direction:    Vec2,
}

behavior_missile_next_pos :: proc(
	b: ^Behavior_Missile,
	current_time: f64,
	current_pos: Vec2,
) -> (
	next_pos: Vec2,
) {
	switch b.state {
	case .inactive:
		// Do nothing
		return current_pos
	case .active:
		vel := vec2_scale(b.direction, b.cfg.speed)
		next_position := vec2_add(current_pos, vel)
		return next_position
	}
	return current_pos
}

behavior_missile_lifetime_is_expired :: proc(b: Behavior_Missile, current_time: f64) -> bool {
	return current_time - b.trigger_time > cast(f64)b.cfg.lifetime_sec
}

// Every N seconds fire a missile
// Fire towards current target position

Behavior_Range_Activated_Missle_Spawner :: struct {
	cfg:          struct {
		trigger_rad:  f32,
		cooldown_sec: f64,
		proto:        Entity_ID,
	},
	state:        enum {
		idle,
		cooldown,
	},
	trigger_time: f64,
}

range_activated_missile_spawner_update :: proc(
	b: ^Behavior_Range_Activated_Missle_Spawner,
	e_pool: ^Entity_Pool,
	p_pool: ^Entity_Pool,
	current_time: f64,
	current_position: Vec2,
	target_position: Vec2,
) {
	switch b.state {
	case .idle:
		// Check for target in range
		// If target in range, spawn missile and switch to cooldown state
		missile_to_target: Vec2
		missile_to_target = vec2_sub(target_position, current_position)
		if vec2_len(missile_to_target) < b.cfg.trigger_rad {
			b.trigger_time = current_time
			b.state = .cooldown

			missile_dir := vec2_norm_safe(missile_to_target)

			// Get prototype and create a copy with proper initialization
			proto := entity_pool_get_entity(p_pool, b.cfg.proto)
			missile := proto

			// Set position to archer's position
			missile.position = Part_World_Position{current_position.x, current_position.y, 0}

			// Initialize missile variant with direction and active state
			if missile_var, ok := &missile.variant.(Entity_Missile); ok {
				missile_var.direction = missile_dir
				missile_var.behavior.direction = missile_dir
				missile_var.behavior.state = .active
				missile_var.behavior.trigger_time = current_time
			}

			entity_pool_create_entity(e_pool, missile)
		}
	case .cooldown:
		// Wait for cooldown to expire
		if current_time - b.trigger_time > b.cfg.cooldown_sec {
			b.state = .idle
		}
	}
}

// Arrow sprite is a range activated missile
// Starts in idle state
// When player enters range it activates
// "Fires" in a straight line at an accelerating speed at the player's current position
// Activated state has a lifetime, after which the entities' memory scope ( lifetime ) ends

Behavior_Range_Activated_Missile :: struct {
	cfg:          struct {
		trigger_radius:             f32,
		acceleration_px_per_frame2: f32,
		// How long to apply acceleration for
		acceleration_time_sec:      f32,
		lifetime_sec:               f32,
	},
	state:        enum {
		idle,
		active,
	},
	trigger_time: f64,
	flying_dir:   Vec2,
}

range_activated_missile_check_trigger :: proc(
	m: ^Behavior_Range_Activated_Missile,
	current_position: Vec2,
	target_position: Vec2,
	current_time: f64,
) -> bool {
	if m.state != .idle {
		// Already triggered
		return false
	}
	missile_to_target: Vec2
	missile_to_target = vec2_sub(target_position, current_position)
	if vec2_len(missile_to_target) < m.cfg.trigger_radius {
		m.trigger_time = current_time
		m.state = .active
		m.flying_dir = vec2_norm_safe(missile_to_target)
		// Missile triggered
		return true
	}
	// Missile did not trigger
	return false
}

range_activated_missile_next_position :: proc(
	m: Behavior_Range_Activated_Missile,
	current_position: Vec2,
	current_velocity: Vec2,
	current_time: f64,
) -> (
	next_position: Vec2,
) {
	assert(m.cfg.acceleration_time_sec > 0)

	acc: Vec2
	if current_time - m.trigger_time > cast(f64)m.cfg.acceleration_time_sec {
		acc = Vec2{0.0, 0.0}
	} else {
		acc = vec2_scale(m.flying_dir, m.cfg.acceleration_px_per_frame2)
	}

	vel := vec2_add(current_velocity, acc)
	pos := vec2_add(current_position, vel)

	when DEBUG_FRAME {
		log.debugf(
			"Missile acc: (%.2f, %.2f), vel: (%.2f, %.2f), pos: (%.2f, %.2f)",
			acc.x,
			acc.y,
			vel.x,
			vel.y,
			pos.x,
			pos.y,
		)
	}

	return pos
}

range_activated_missile_is_lifetime_expired :: proc(
	m: Behavior_Range_Activated_Missile,
	current_time: f64,
) -> bool {
	return current_time - m.trigger_time > cast(f64)m.cfg.lifetime_sec
}

