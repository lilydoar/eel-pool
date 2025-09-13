package game

import "core:log"
import "core:strings"
import "core:time"
import sdl3 "vendor:sdl3"
import sdl3img "vendor:sdl3/image"

SDL :: struct {
	window:   SDL_Window,
	keyboard: SDL_Keyboard,
	mouse:    SDL_Mouse,
	gamepad:  SDL_Gamepad,
	renderer: SDL_Renderer,
}

SDL_Options :: struct {
	window_title: string,
	window_size:  Vec2i,
	window_flags: sdl3.WindowFlags,
}

SDL_Window :: struct {
	ptr:          ^sdl3.Window,
	title:        cstring,
	size_prev:    Vec2i,
	size_curr:    Vec2i,
	is_minimized: bool,
}


SDL_Keyboard :: struct {
	// Physical keys on the keyboard.
	scancodes_prev: [len(sdl3.Scancode)]bool,
	scancodes_curr: [len(sdl3.Scancode)]bool,

	// Symbolic keys. Unaware of the keyboard layout.
	keycodes_prev:  map[sdl3.Keycode]bool,
	keycodes_curr:  map[sdl3.Keycode]bool,
}

SDL_Mouse :: struct {
	// Mouse position in pixels relative to the window's top-left corner.
	pos_prev:     Vec2,
	pos_curr:     Vec2,

	// Mouse buttons pressed.
	buttons_prev: sdl3.MouseButtonFlags,
	buttons_curr: sdl3.MouseButtonFlags,
}

SDL_Gamepad :: ^sdl3.Gamepad

SDL_Renderer :: struct {
	ptr:         ^sdl3.Renderer,
	clear_color: sdl3.Color,
	textures:    struct {
		terrain: struct {
			tilemap_color1: SDL_Texture,
			tilemap_color2: SDL_Texture,
			tilemap_color3: SDL_Texture,
		},
		player:  struct {
			idle_atlas:    SDL_Texture,
			run_atlas:     SDL_Texture,
			guard_atlas:   SDL_Texture,
			attack1_atlas: SDL_Texture,
			attack2_atlas: SDL_Texture,
		},
	},
	animations:  struct {
		player: struct {
			idle:    SDL_Animation,
			run:     SDL_Animation,
			guard:   SDL_Animation,
			attack1: SDL_Animation,
			attack2: SDL_Animation,
		},
	},
}

SDL_Texture :: struct {
	name:    string,
	surface: ^sdl3.Surface,
	texture: ^sdl3.Texture,
}

SDL_Animation :: struct {
	name:     string,
	texture:  ^sdl3.Texture,
	frame:    []^sdl3.Surface,
	delay_ms: u32,
}

sdl_init :: proc(s: ^SDL, opts: SDL_Options) {
	log.info("Initializing SDL...")
	defer log.info("SDL initialized")

	must(sdl3.Init({.AUDIO, .VIDEO, .GAMEPAD}), "init SDL")

	assert(len(opts.window_title) > 0)
	title := strings.clone_to_cstring(opts.window_title)

	log.debugf(
		"Creating window: '{}' Size: {} x {} Flags: {}",
		opts.window_title,
		opts.window_size.x,
		opts.window_size.y,
		opts.window_flags,
	)

	s.window.title = must(title)
	s.window.ptr = must(
		sdl3.CreateWindow(
			s.window.title,
			opts.window_size.x,
			opts.window_size.y,
			opts.window_flags,
		),
		"create window",
	)

	s.keyboard.keycodes_prev = make(map[sdl3.Keycode]bool)
	s.keyboard.keycodes_curr = make(map[sdl3.Keycode]bool)

	s.renderer.ptr = must(sdl3.CreateRenderer(s.window.ptr, nil), "create renderer")
	s.renderer.clear_color = sdl3.Color{0, 0, 0, 255}

	terrain_tilemap_color1_name := "terrain_tilemap_color1"
	terrain_tilemap_color1_path := "assets/Tiny_Swords/Terrain/Tilemap_color1.png"

	terrain_tilemap_color2_name := "terrain_tilemap_color2"
	terrain_tilemap_color2_path := "assets/Tiny_Swords/Terrain/Tilemap_color2.png"

	terrain_tilemap_color3_name := "terrain_tilemap_color3"
	terrain_tilemap_color3_path := "assets/Tiny_Swords/Terrain/Tilemap_color3.png"

	player_idle_name := "player_idle"
	player_idle_path := "assets/Tiny_Swords/Units/Blue_Units/Warrior/Warrior_Idle.png"

	player_run_name := "player_run"
	player_run_path := "assets/Tiny_Swords/Units/Blue_Units/Warrior/Warrior_Run.png"

	player_guard_name := "player_guard"
	player_guard_path := "assets/Tiny_Swords/Units/Blue_Units/Warrior/Warrior_guard.png"

	player_attack1_name := "player_attack1"
	player_attack1_path := "assets/Tiny_Swords/Units/Blue_Units/Warrior/Warrior_attack1.png"

	player_attack2_name := "player_attack2"
	player_attack2_path := "assets/Tiny_Swords/Units/Blue_Units/Warrior/Warrior_attack2.png"

	// load textures
	s.renderer.textures.terrain.tilemap_color1 = sdl_texture_load(
		&s.renderer,
		terrain_tilemap_color1_path,
		terrain_tilemap_color1_name,
	)

	s.renderer.textures.terrain.tilemap_color2 = sdl_texture_load(
		&s.renderer,
		terrain_tilemap_color2_path,
		terrain_tilemap_color2_name,
	)

	s.renderer.textures.terrain.tilemap_color3 = sdl_texture_load(
		&s.renderer,
		terrain_tilemap_color3_path,
		terrain_tilemap_color3_name,
	)

	s.renderer.textures.player.idle_atlas = sdl_texture_load(
		&s.renderer,
		player_idle_path,
		player_idle_name,
	)
	s.renderer.textures.player.run_atlas = sdl_texture_load(
		&s.renderer,
		player_run_path,
		player_run_name,
	)
	s.renderer.textures.player.guard_atlas = sdl_texture_load(
		&s.renderer,
		player_guard_path,
		player_guard_name,
	)
	s.renderer.textures.player.attack1_atlas = sdl_texture_load(
		&s.renderer,
		player_attack1_path,
		player_attack1_name,
	)
	s.renderer.textures.player.attack2_atlas = sdl_texture_load(
		&s.renderer,
		player_attack2_path,
		player_attack2_name,
	)

	load_animation :: proc(s: ^SDL, cfg: struct {
			name:     string,
			len:      u32,
			size:     Vec2i,
			delay_ms: u32,
			atlas:    ^SDL_Texture,
		}) -> SDL_Animation {

		anim := SDL_Animation {
			name     = cfg.name,
			texture  = cfg.atlas.texture,
			frame    = make([]^sdl3.Surface, cfg.len),
			delay_ms = cfg.delay_ms,
		}

		for idx in 0 ..< cfg.len {
			rect: Maybe(^sdl3.Rect) = &sdl3.Rect {
				cfg.size.x * cast(i32)idx,
				0,
				cast(i32)cfg.size.x,
				cast(i32)cfg.size.y,
			}
			frame := sdl3.DuplicateSurface(cfg.atlas.surface)
			sdl3.SetSurfaceClipRect(frame, rect)
			anim.frame[idx] = frame
		}

		return anim
	}

	s.renderer.animations.player.idle = load_animation(
		s,
		{
			player_idle_name,
			cast(u32)8,
			Vec2i{192, 192},
			10,
			&s.renderer.textures.player.idle_atlas,
		},
	)

	s.renderer.animations.player.run = load_animation(
		s,
		{player_run_name, cast(u32)6, Vec2i{192, 192}, 10, &s.renderer.textures.player.run_atlas},
	)

	s.renderer.animations.player.guard = load_animation(
		s,
		{
			player_guard_name,
			cast(u32)6,
			Vec2i{192, 192},
			10,
			&s.renderer.textures.player.guard_atlas,
		},
	)

	s.renderer.animations.player.attack1 = load_animation(
		s,
		{
			player_attack1_name,
			cast(u32)4,
			Vec2i{192, 192},
			10,
			&s.renderer.textures.player.attack1_atlas,
		},
	)

	s.renderer.animations.player.attack2 = load_animation(
		s,
		{
			player_attack2_name,
			cast(u32)4,
			Vec2i{192, 192},
			10,
			&s.renderer.textures.player.attack2_atlas,
		},
	)
}

sdl_deinit :: proc(s: ^SDL) {
	log.info("Deinitializing SDL...")

	// TODO
	// anim deinit

	sdl_texture_deinit(&s.renderer.textures.player.idle_atlas)
	sdl_texture_deinit(&s.renderer.textures.player.run_atlas)
	sdl_texture_deinit(&s.renderer.textures.player.guard_atlas)
	sdl_texture_deinit(&s.renderer.textures.player.attack1_atlas)
	sdl_texture_deinit(&s.renderer.textures.player.attack2_atlas)

	sdl3.DestroyRenderer(s.renderer.ptr)

	delete(s.keyboard.keycodes_prev)
	delete(s.keyboard.keycodes_curr)

	sdl3.CloseGamepad(s.gamepad)

	sdl3.DestroyWindow(s.window.ptr)
	delete(s.window.title)

	sdl3.Quit()
}

sdl_frame_begin :: proc(s: ^SDL) -> (quit: bool) {
	// Track state across time steps.
	s.window.size_prev = s.window.size_curr
	s.keyboard.scancodes_prev = s.keyboard.scancodes_curr

	clear(&s.keyboard.keycodes_prev)
	for keycode, pressed in s.keyboard.keycodes_curr {
		s.keyboard.keycodes_prev[keycode] = pressed
	}

	s.mouse.pos_prev = s.mouse.pos_curr
	s.mouse.buttons_prev = s.mouse.buttons_curr

	quit = sdl_poll_events(s)
	if quit {log.debug("SDL event loop requested quit.")}

	sdl3.SetRenderDrawColor(
		s.renderer.ptr,
		s.renderer.clear_color[0],
		s.renderer.clear_color[1],
		s.renderer.clear_color[2],
		s.renderer.clear_color[3],
	)
	sdl3.RenderClear(s.renderer.ptr)

	return
}

sdl_poll_events :: proc(s: ^SDL) -> (quit: bool) {
	e: sdl3.Event
	for sdl3.PollEvent(&e) {
		quit = sdl_handle_event(s, e)
		if quit {return}
	}
	return
}

sdl_handle_event :: proc(s: ^SDL, e: sdl3.Event) -> (quit: bool) {
	#partial switch e.type {
	case .QUIT, .WINDOW_CLOSE_REQUESTED:
		quit = true
	case .WINDOW_RESIZED, .WINDOW_PIXEL_SIZE_CHANGED, .WINDOW_METAL_VIEW_RESIZED:
		s.window.size_curr = sdl_get_window_size(s)
	case .WINDOW_MINIMIZED, .WINDOW_MAXIMIZED, .WINDOW_RESTORED:
		s.window.size_curr = sdl_get_window_size(s)
		s.window.is_minimized = e.type == .WINDOW_MINIMIZED
	case .KEY_DOWN, .KEY_UP:
		pressed := e.type == .KEY_DOWN
		s.keyboard.scancodes_curr[e.key.scancode] = pressed
		s.keyboard.keycodes_curr[e.key.key] = pressed
	case .MOUSE_MOTION:
		s.mouse.pos_curr = {e.motion.x, e.motion.y}
	// s.mouse.buttons_curr = e.motion.state
	case .MOUSE_BUTTON_DOWN, .MOUSE_BUTTON_UP:
		if flag, ok := sdl_mouse_button_to_flag(e.button.button); ok {
			if e.type == .MOUSE_BUTTON_DOWN {
				s.mouse.buttons_curr += {flag}
			} else {
				s.mouse.buttons_curr -= {flag}
			}
		}
	case .GAMEPAD_ADDED:
		if s.gamepad != nil {return}
		s.gamepad = sdl3.OpenGamepad(e.gdevice.which)
		if s.gamepad == nil {
			log.warn("Open gamepad device: {}", e.gdevice.which)
			return
		}
	case .GAMEPAD_REMOVED:
		if s.gamepad == nil {return}
		if sdl3.GetGamepadID(s.gamepad) != e.gdevice.which {return}
		sdl3.CloseGamepad(s.gamepad)
		s.gamepad = nil
	}

	return
}

sdl_frame_end :: proc(s: ^SDL) {
	sdl3.RenderPresent(s.renderer.ptr)
}

// Helpers
sdl_get_window_size :: proc(s: ^SDL) -> (size: Vec2i) {
	sdl3.GetWindowSize(s.window.ptr, &size.x, &size.y)
	return
}

// Helper to convert button number to flag
sdl_mouse_button_to_flag :: proc(button: u8) -> (sdl3.MouseButtonFlag, bool) {
	switch button {
	case sdl3.BUTTON_LEFT:
		return .LEFT, true
	case sdl3.BUTTON_MIDDLE:
		return .MIDDLE, true
	case sdl3.BUTTON_RIGHT:
		return .RIGHT, true
	case sdl3.BUTTON_X1:
		return .X1, true
	case sdl3.BUTTON_X2:
		return .X2, true
	case:
		return .LEFT, false
	}
}

// Mouse button utility functions 
sdl_mouse_button_is_down :: proc {
	sdl_mouse_button_is_down_flag,
	sdl_mouse_button_is_down_num,
}
sdl_mouse_button_is_up :: proc {
	sdl_mouse_button_is_up_flag,
	sdl_mouse_button_is_up_num,
}
sdl_mouse_button_was_pressed :: proc {
	sdl_mouse_button_was_pressed_flag,
	sdl_mouse_button_was_pressed_num,
}
sdl_mouse_button_was_released :: proc {
	sdl_mouse_button_was_released_flag,
	sdl_mouse_button_was_released_num,
}

sdl_mouse_button_is_down_flag :: proc(s: ^SDL, button: sdl3.MouseButtonFlag) -> bool {
	return button in s.mouse.buttons_curr
}

sdl_mouse_button_is_down_num :: proc(s: ^SDL, button: u8) -> bool {
	if flag, ok := sdl_mouse_button_to_flag(button); ok {
		return flag in s.mouse.buttons_curr
	}
	return false
}

sdl_mouse_button_is_up_flag :: proc(s: ^SDL, button: sdl3.MouseButtonFlag) -> bool {
	return button not_in s.mouse.buttons_curr
}

sdl_mouse_button_is_up_num :: proc(s: ^SDL, button: u8) -> bool {
	if flag, ok := sdl_mouse_button_to_flag(button); ok {
		return flag not_in s.mouse.buttons_curr
	}
	return true
}

sdl_mouse_button_was_pressed_flag :: proc(s: ^SDL, button: sdl3.MouseButtonFlag) -> bool {
	return button in s.mouse.buttons_curr && button not_in s.mouse.buttons_prev
}

sdl_mouse_button_was_pressed_num :: proc(s: ^SDL, button: u8) -> bool {
	if flag, ok := sdl_mouse_button_to_flag(button); ok {
		return flag in s.mouse.buttons_curr && flag not_in s.mouse.buttons_prev
	}
	return false
}

sdl_mouse_button_was_released_flag :: proc(s: ^SDL, button: sdl3.MouseButtonFlag) -> bool {
	return button not_in s.mouse.buttons_curr && button in s.mouse.buttons_prev
}

sdl_mouse_button_was_released_num :: proc(s: ^SDL, button: u8) -> bool {
	if flag, ok := sdl_mouse_button_to_flag(button); ok {
		return flag not_in s.mouse.buttons_curr && flag in s.mouse.buttons_prev
	}
	return false
}

// Mouse position utilities
sdl_mouse_get_position :: proc(s: ^SDL) -> Vec2 {
	return s.mouse.pos_curr
}

sdl_mouse_get_delta :: proc(s: ^SDL) -> Vec2 {
	return Vec2{s.mouse.pos_curr.x - s.mouse.pos_prev.x, s.mouse.pos_curr.y - s.mouse.pos_prev.y}
}

sdl_mouse_did_move :: proc(s: ^SDL) -> bool {
	return s.mouse.pos_curr != s.mouse.pos_prev
}

// Renderer utilities

sdl_texture_load :: proc(r: ^SDL_Renderer, file: string, name: string) -> (texture: SDL_Texture) {
	log.debugf("Loading texture {} from file: '{}'", name, file)
	defer log.debugf("Loaded texture {} from file: '{}'", name, file)

	f := strings.clone_to_cstring(file)
	defer delete(f)

	texture.name = name
	texture.surface = must(sdl3img.Load(f), "load image")
	texture.texture = must(
		sdl3.CreateTextureFromSurface(r.ptr, texture.surface),
		"texture from surface",
	)

	assert(texture.surface != nil)
	assert(texture.texture != nil)
	assert(texture.surface.w == texture.texture.w)
	assert(texture.surface.h == texture.texture.h)
	return
}

sdl_texture_deinit :: proc(t: ^SDL_Texture) {
	log.debugf("Deinitializing texture: '{}'", t.name)
	defer log.debugf("Deinitialized texture: '{}'", t.name)

	if t.texture != nil {sdl3.DestroyTexture(t.texture)}
	if t.surface != nil {sdl3.DestroySurface(t.surface)}
}

// TODO
// sdl_animation_load :: proc() -> SDL_Animation {}
// sdl_animation_deinit :: proc(a: ^SDL_Animation) {}

sdl_draw_debug :: proc(sdl: ^SDL) {
	// Draw debug information (e.g., FPS, frame time, etc.)

	// TODO: Draw FPS
}

