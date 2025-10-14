package game

Camera :: struct {
	// World position of the camera (center of the view)
	position:        Vec2,
	// Camera size in world units (smaller = zoomed in, larger = zoomed out)
	view_size:       Vec2,
	// Top-left corner of the camera view in world coordinates
	view_top_left:   Vec2,

	// Position of the camera's focus
	target_position: Vec2,
	//
	follow_mode:     enum {
		simple,
		with_lag,
		with_leash,
	},

	//
	lag_follow_rate: f32,
	leash_distance:  Vec2,
}

// Return true if the target is visible
camera_update :: proc(camera: ^Camera) -> bool {
	switch camera.follow_mode {
	case .simple:
		camera.position = camera.target_position

	case .with_lag:
		camera.position = vec2_add(
			camera.position,
			vec2_scale(vec2_sub(camera.target_position, camera.position), camera.lag_follow_rate),
		)

	case .with_leash:
		pos_to_target: Vec2 = vec2_sub(camera.target_position, camera.position)
		if pos_to_target.x >
		   camera.leash_distance.x {camera.position.x += pos_to_target.x - camera.leash_distance.x}
		if pos_to_target.x <
		   -camera.leash_distance.x {camera.position.x += pos_to_target.x + camera.leash_distance.x}
		if pos_to_target.y >
		   camera.leash_distance.y {camera.position.y += pos_to_target.y - camera.leash_distance.y}
		if pos_to_target.y <
		   -camera.leash_distance.y {camera.position.y += pos_to_target.y + camera.leash_distance.y}
	}

	camera.view_top_left = vec2_sub(camera.position, vec2_scale(camera.view_size, 0.5))

	return aabb2_contains(
		AABB2{camera.view_top_left, vec2_add(camera.view_top_left, camera.view_size)},
		camera.target_position,
	)
}

camera_world_to_screen :: proc(camera: ^Camera, world_pos: Vec2, screen_size: Vec2) -> Vec2 {
	// Get position relative to camera's top-left corner
	relative_pos: Vec2 = vec2_sub(world_pos, camera.view_top_left)
	// Scale from world coordinates to screen coordinates
	// (smaller view_size = more zoom = larger scale factor)
	scale: Vec2 = vec2_div(screen_size, camera.view_size)
	screen_pos: Vec2 = vec2_mul(relative_pos, scale)
	return screen_pos
}

camera_screen_to_world :: proc(camera: ^Camera, screen_pos: Vec2, screen_size: Vec2) -> Vec2 {
	// Scale from screen coordinates to world coordinates
	scale: Vec2 = vec2_div(camera.view_size, screen_size)
	relative_pos: Vec2 = vec2_mul(screen_pos, scale)
	world_pos: Vec2 = vec2_add(relative_pos, camera.view_top_left)
	return world_pos
}

camera_world_size_to_screen :: proc(camera: ^Camera, world_size: Vec2, screen_size: Vec2) -> Vec2 {
	// Scale from world size to screen size
	scale: Vec2 = vec2_div(screen_size, camera.view_size)
	screen_sized: Vec2 = vec2_mul(world_size, scale)
	return screen_sized
}

camera_set_target :: proc(camera: ^Camera, target: Vec2) {
	camera.target_position = target
}

// Adjust camera zoom by scaling view_size
// factor > 1.0 zooms out (see more), factor < 1.0 zooms in (see less)
camera_zoom_by_factor :: proc(camera: ^Camera, factor: f32) {
	camera.view_size = vec2_scale(camera.view_size, factor)
	// Recalculate view_top_left to keep camera centered on position
	camera.view_top_left = vec2_sub(camera.position, vec2_scale(camera.view_size, 0.5))

	camera.leash_distance = vec2_scale(camera.leash_distance, factor)
}

