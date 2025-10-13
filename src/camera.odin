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

	case .with_leash:
		leash_dst := Vec2{300.0, 200.0}

		pos_to_target: Vec2 = vec2_sub(camera.target_position, camera.position)
		if pos_to_target.x > leash_dst.x {camera.position.x += pos_to_target.x - leash_dst.x}
		if pos_to_target.x < -leash_dst.x {camera.position.x += pos_to_target.x + leash_dst.x}
		if pos_to_target.y > leash_dst.y {camera.position.y += pos_to_target.y - leash_dst.y}
		if pos_to_target.y < -leash_dst.y {camera.position.y += pos_to_target.y + leash_dst.y}
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
	// scale = screen_size / view_size
	// (smaller view_size = more zoom = larger scale factor)
	scale: Vec2 = vec2_div(screen_size, camera.view_size)
	screen_pos: Vec2 = vec2_mul(relative_pos, scale)
	return screen_pos
}

camera_screen_to_world :: proc(camera: ^Camera, screen_pos: Vec2, screen_size: Vec2) -> Vec2 {
	// Scale from screen coordinates to world coordinates
	// scale = view_size / screen_size
	scale: Vec2 = vec2_div(camera.view_size, screen_size)
	relative_pos: Vec2 = vec2_mul(screen_pos, scale)
	world_pos: Vec2 = vec2_add(relative_pos, camera.view_top_left)
	return world_pos
}

// Convert world size to screen size
camera_world_size_to_screen :: proc(camera: ^Camera, world_size: Vec2, screen_size: Vec2) -> Vec2 {
	// Scale from world size to screen size
	// scale = screen_size / view_size
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
}

// Set camera zoom to specific view size
camera_set_view_size :: proc(camera: ^Camera, view_size: Vec2) {
	camera.view_size = view_size
	// Recalculate view_top_left to keep camera centered on position
	camera.view_top_left = vec2_sub(camera.position, vec2_scale(camera.view_size, 0.5))
}

// Get zoom level relative to reference size (1.0 = normal, >1.0 = zoomed in, <1.0 = zoomed out)
camera_get_zoom_level :: proc(camera: ^Camera, reference_size: Vec2) -> f32 {
	// Average zoom across both axes
	return (reference_size.x / camera.view_size.x + reference_size.y / camera.view_size.y) * 0.5
}

