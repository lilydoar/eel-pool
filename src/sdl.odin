package game

import "core:log"
import "core:strings"
import "core:time"
import sdl3 "vendor:sdl3"
import sdl3img "vendor:sdl3/image"

RenderTargetSize :: Vec2u{640, 360}

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
		render_target: SDL_Texture,
		terrain:       struct {
			tilemap_atlas_color1: SDL_Texture,
			tilemap_atlas_color2: SDL_Texture,
			tilemap_atlas_color3: SDL_Texture,
		},
	},
	tilemaps:    struct {
		terrain: struct {
			color1: SDL_Tilemap,
			color2: SDL_Tilemap,
			color3: SDL_Tilemap,
		},
	},
}

SDL_Texture :: struct {
	name:    string,
	surface: ^sdl3.Surface,
	texture: ^sdl3.Texture,
}

SDL_Tilemap :: struct {
	name:      string,
	dimension: Vec2i,
	tile_size: Vec2i,
	texture:   ^sdl3.Texture,
	tile:      []^sdl3.Surface,
}

SDL_Animation :: struct {
	name:         string,
	texture:      SDL_Texture,
	frame:        []^sdl3.Surface,
	delay_ms:     u32,

	// world_offset is the vector from the top left of the frame surface to the world_position of the "thing" the animation represents
	world_offset: Vec2,
}

SDL_Level :: struct {
	name:      string,
	size:      Vec2u,
	tile_size: Vec2u,
	tilesets:  []struct {
		tileset:  SDL_Tileset,
		firstgid: u32,
	},
	layers:    []struct {
		name: string,
		size: Vec2u,
		data: []u32,
	},
}

SDL_Tileset :: struct {
	name: string,
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

	must(
		sdl3.SetRenderLogicalPresentation(
			s.renderer.ptr,
			cast(i32)RenderTargetSize.x,
			cast(i32)RenderTargetSize.y,
			.LETTERBOX,
		),
	)

	s.renderer.textures.render_target.name = "render_target"
	s.renderer.textures.render_target.surface = must(
		sdl3.CreateSurface(cast(i32)RenderTargetSize.x, cast(i32)RenderTargetSize.y, .RGBA8888),
	)
	s.renderer.textures.render_target.texture = sdl3.CreateTextureFromSurface(
		s.renderer.ptr,
		s.renderer.textures.render_target.surface,
	)

	terrain_tilemap_color1_name := "terrain_tilemap_color1"
	terrain_tilemap_color1_path := "assets/Tiny_Swords/Terrain/Tilemap_color1.png"

	terrain_tilemap_color2_name := "terrain_tilemap_color2"
	terrain_tilemap_color2_path := "assets/Tiny_Swords/Terrain/Tilemap_color2.png"

	terrain_tilemap_color3_name := "terrain_tilemap_color3"
	terrain_tilemap_color3_path := "assets/Tiny_Swords/Terrain/Tilemap_color3.png"

	// load textures
	s.renderer.textures.terrain.tilemap_atlas_color1 = sdl_texture_load(
		&s.renderer,
		terrain_tilemap_color1_path,
		terrain_tilemap_color1_name,
	)

	s.renderer.textures.terrain.tilemap_atlas_color2 = sdl_texture_load(
		&s.renderer,
		terrain_tilemap_color2_path,
		terrain_tilemap_color2_name,
	)

	s.renderer.textures.terrain.tilemap_atlas_color3 = sdl_texture_load(
		&s.renderer,
		terrain_tilemap_color3_path,
		terrain_tilemap_color3_name,
	)

	load_tilemap :: proc(s: ^SDL, cfg: struct {
			name:      string,
			dimension: Vec2i,
			atlas:     ^SDL_Texture,
		}) -> SDL_Tilemap {
		assert(cfg.dimension.x > 0)
		assert(cfg.dimension.y > 0)
		assert(cfg.atlas != nil)

		tilemap := SDL_Tilemap {
			name      = cfg.name,
			dimension = cfg.dimension,
			tile_size = Vec2i {
				cfg.atlas.surface.w / cfg.dimension.x,
				cfg.atlas.surface.h / cfg.dimension.y,
			},
			texture   = cfg.atlas.texture,
			tile      = make([]^sdl3.Surface, cfg.dimension.x * cfg.dimension.y),
		}

		log.debugf(
			"Loading tilemap '{}' with dimension {} x {} (tile size: {} x {})",
			cfg.name,
			cfg.dimension.x,
			cfg.dimension.y,
			tilemap.tile_size.x,
			tilemap.tile_size.y,
		)

		for y in 0 ..< cfg.dimension.y {
			for x in 0 ..< cfg.dimension.x {
				idx := y * cfg.dimension.x + x
				rect: Maybe(^sdl3.Rect) = &sdl3.Rect {
					tilemap.tile_size.x * cast(i32)x,
					tilemap.tile_size.y * cast(i32)y,
					cast(i32)tilemap.tile_size.x,
					cast(i32)tilemap.tile_size.y,
				}
				tile := sdl3.DuplicateSurface(cfg.atlas.surface)
				sdl3.SetSurfaceClipRect(tile, rect)
				tilemap.tile[idx] = tile
			}
		}

		return tilemap
	}

	s.renderer.tilemaps.terrain.color1 = load_tilemap(
		s,
		{
			terrain_tilemap_color1_name,
			Vec2i{20, 8},
			&s.renderer.textures.terrain.tilemap_atlas_color1,
		},
	)

	s.renderer.tilemaps.terrain.color2 = load_tilemap(
		s,
		{
			terrain_tilemap_color2_name,
			Vec2i{20, 8},
			&s.renderer.textures.terrain.tilemap_atlas_color2,
		},
	)

	s.renderer.tilemaps.terrain.color3 = load_tilemap(
		s,
		{
			terrain_tilemap_color3_name,
			Vec2i{20, 8},
			&s.renderer.textures.terrain.tilemap_atlas_color3,
		},
	)
}

sdl_deinit :: proc(s: ^SDL) {
	log.info("Deinitializing SDL...")

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

	sdl3.SetRenderTarget(s.renderer.ptr, s.renderer.textures.render_target.texture)
	sdl3.SetRenderDrawColor(
		s.renderer.ptr,
		s.renderer.clear_color[0],
		s.renderer.clear_color[1],
		s.renderer.clear_color[2],
		s.renderer.clear_color[3],
	)
	sdl3.RenderClear(s.renderer.ptr)

	quit = sdl_poll_events(s)
	if quit {log.debug("SDL event loop requested quit.")}

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
	sdl3.SetRenderTarget(s.renderer.ptr, nil)
	sdl3.RenderTexture(s.renderer.ptr, s.renderer.textures.render_target.texture, nil, nil)
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

// Get mouse position relative to the current render target
sdl_mouse_get_render_position :: proc(s: ^SDL) -> (pos: Vec2) {
	m_pos := sdl_mouse_get_position(s)
	sdl3.RenderCoordinatesFromWindow(s.renderer.ptr, m_pos.x, m_pos.y, &pos.x, &pos.y)
	return
}

// Renderer utilities

sdl_texture_load :: proc(r: ^SDL_Renderer, file: string, name: string) -> (texture: SDL_Texture) {
	assert(len(file) > 0)
	assert(len(name) > 0)

	log.debugf("Loading texture {} from file: '{}'", name, file)
	defer log.debugf("Loaded texture {}", name)

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

