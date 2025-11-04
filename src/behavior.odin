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

// Player movement behavior
// Calculates velocity based on input, mode, and action
// Handles different speeds for default/mounted modes and dashing

Behavior_Player_Movement :: struct {
	cfg: struct {
		move_speed:         Vec2,
		move_speed_mounted: Vec2,
		dash_speed:         Vec2,
	},
}

behavior_player_movement_calculate :: proc(
	b: ^Behavior_Player_Movement,
	input: Game_Input_Buffer,
	mount_mode: enum {
		default,
		mounted,
	},
	action: enum {
		idle,
		running,
		dashing,
		guard,
		attack,
	},
	prev_delta: Vec2,
	dash_direction: Vec2,
) -> (
	velocity: Vec2,
	facing: enum {
		right,
		left,
	},
) {
	new_facing := facing

	// Determine velocity based on mode and action
	switch mount_mode {
	case .default:
		#partial switch action {
		case .idle, .running:
			// Normal movement with default speed
			desire_x := resolve_axis_intent(input, .player_move_left, .player_move_right, prev_delta.x)
			desire_y := resolve_axis_intent(input, .player_move_up, .player_move_down, prev_delta.y)

			normalized := vec2_norm_safe(Vec2{desire_x, desire_y})
			velocity = Vec2 {
				normalized.x * b.cfg.move_speed.x,
				normalized.y * b.cfg.move_speed.y,
			}

		case .dashing:
			// Use dash direction and dash speed
			velocity = Vec2 {
				dash_direction.x * b.cfg.dash_speed.x,
				dash_direction.y * b.cfg.dash_speed.y,
			}
		}

	case .mounted:
		#partial switch action {
		case .idle, .running:
			// Normal movement with mounted speed
			desire_x := resolve_axis_intent(input, .player_move_left, .player_move_right, prev_delta.x)
			desire_y := resolve_axis_intent(input, .player_move_up, .player_move_down, prev_delta.y)

			normalized := vec2_norm_safe(Vec2{desire_x, desire_y})
			velocity = Vec2 {
				normalized.x * b.cfg.move_speed_mounted.x,
				normalized.y * b.cfg.move_speed_mounted.y,
			}
		}
	}

	// Update facing based on velocity
	if velocity.x < 0 {
		new_facing = .left
	}
	if velocity.x > 0 {
		new_facing = .right
	}

	return velocity, new_facing
}

// Player dash behavior
// Manages dash state, timing, direction, and cooldown
// Dash can only be activated with movement input and when not on cooldown

Behavior_Player_Dash :: struct {
	cfg:             struct {
		dash_time:     f32,
		cooldown_time: f32,
	},
	state:           enum {
		ready,
		dashing,
		cooldown,
	},
	dash_direction:  Vec2,
	dash_timer:      f32,
	cooldown_timer:  f32,
}

behavior_player_dash_try_start :: proc(
	b: ^Behavior_Player_Dash,
	input: Game_Input_Buffer,
	movement_delta: Vec2,
	mount_mode: enum {
		default,
		mounted,
	},
	dt: f32,
) -> bool {
	// Can only dash if ready (not currently dashing or on cooldown)
	if b.state != .ready {
		return false
	}

	// Check if dash button is pressed
	if !(.player_move_dash in input[0]) {
		return false
	}

	// Require movement input (prevent standing dash)
	has_movement_input :=
		.player_move_left in input[0] ||
		.player_move_right in input[0] ||
		.player_move_up in input[0] ||
		.player_move_down in input[0]

	if !has_movement_input {
		return false
	}

	// Dashing not allowed in mounted mode (based on original logic)
	if mount_mode == .mounted {
		return false
	}

	// Calculate dash direction from current input
	dash_x := resolve_axis_intent(input, .player_move_left, .player_move_right, movement_delta.x)
	dash_y := resolve_axis_intent(input, .player_move_up, .player_move_down, movement_delta.y)

	// If no directional input (shouldn't happen due to check above), use previous movement direction
	if dash_x == 0 && dash_y == 0 {
		b.dash_direction = vec2_norm_safe(movement_delta)
	} else {
		b.dash_direction = vec2_norm_safe(Vec2{dash_x, dash_y})
	}

	// Start dashing
	b.state = .dashing
	b.dash_timer = b.cfg.dash_time

	when DEBUG_GAME {
		log.debugf(
			"Player dash started! Direction: ({}, {})",
			b.dash_direction.x,
			b.dash_direction.y,
		)
	}

	return true
}

behavior_player_dash_update :: proc(b: ^Behavior_Player_Dash, dt: f32) {
	switch b.state {
	case .ready:
		// Nothing to update when ready
	case .dashing:
		b.dash_timer -= dt
		if b.dash_timer <= 0 {
			b.state = .cooldown
			b.cooldown_timer = b.cfg.cooldown_time
		}
	case .cooldown:
		b.cooldown_timer -= dt
		if b.cooldown_timer <= 0 {
			b.cooldown_timer = 0
			b.state = .ready
		}
	}
}

behavior_player_dash_is_active :: proc(b: Behavior_Player_Dash) -> bool {
	return b.state == .dashing
}

// Player mount behavior
// Manages mount/unmount state, cooldown, and vertical offset
// Mounting changes movement speed and visual (player + sheep rendering)

Behavior_Player_Mount :: struct {
	cfg:             struct {
		cooldown_time: f32,
		mount_y_bump:  f32,
	},
	mode:            enum {
		default,
		mounted,
	},
	cooldown_timer:  f32,
}

behavior_player_mount_try_toggle :: proc(
	b: ^Behavior_Player_Mount,
	input: Game_Input_Buffer,
	can_toggle: bool, // Usually: not dashing
	dt: f32,
) -> (
	toggled: bool,
	y_offset: f32,
) {
	// Check cooldown
	if b.cooldown_timer > 0 {
		return false, 0
	}

	// Check if toggle input pressed
	if !(.player_toggle_mount in input[0]) {
		return false, 0
	}

	// Check additional conditions
	if !can_toggle {
		return false, 0
	}

	// Toggle mode
	offset: f32 = 0
	if b.mode == .default {
		b.mode = .mounted
		offset = -b.cfg.mount_y_bump // Move up when mounting
		when DEBUG_GAME {log.debug("Player mounted!")}
	} else {
		b.mode = .default
		offset = b.cfg.mount_y_bump // Move down when unmounting
		when DEBUG_GAME {log.debug("Player unmounted!")}
	}

	// Start cooldown
	b.cooldown_timer = b.cfg.cooldown_time

	return true, offset
}

behavior_player_mount_update :: proc(b: ^Behavior_Player_Mount, dt: f32) {
	if b.cooldown_timer > 0 {
		b.cooldown_timer -= dt
		if b.cooldown_timer < 0 {
			b.cooldown_timer = 0
		}
	}
}

