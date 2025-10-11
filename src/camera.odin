package game


Camera :: struct {
	// World position of the camera (center of the view)
	position:        Vec2,
	// Camera size in world units
	view_size:       Vec2,
	// Top-left corner of the camera view in world coordinates
	view_top_left:   Vec2,

	// Position of the camera's focus
	target_position: Vec2,
	//
	follow_mode:     enum {
		simple,
		with_lag,
	},
}

// Return true if the target is visible
camera_update :: proc(camera: ^Camera) -> bool {
	switch camera.follow_mode {
	case .simple:
		camera.position = camera.target_position

	case .with_lag:
		lazy_follow_rate: f32 = 0.1
		camera.position = vec2_add(
			camera.position,
			vec2_scale(vec2_sub(camera.target_position, camera.position), lazy_follow_rate),
		)
	}

	camera.view_top_left = vec2_sub(camera.position, vec2_scale(camera.view_size, 0.5))

	return aabb2_contains(
		AABB2{camera.view_top_left, vec2_add(camera.view_top_left, camera.view_size)},
		camera.target_position,
	)
}

camera_world_to_screen :: proc(camera: ^Camera, world_pos: Vec2, screen_size: Vec2) -> Vec2 {
	relative_pos: Vec2 = vec2_sub(world_pos, camera.view_top_left)
	screen_pos: Vec2 = vec2_div(relative_pos, vec2_div(screen_size, camera.view_size))
	return screen_pos
}

camera_set_target :: proc(camera: ^Camera, target: Vec2) {
	camera.target_position = target
}

