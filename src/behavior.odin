package game

import "core:log"

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
