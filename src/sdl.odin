package game

import "core:fmt"
import "core:log"
import "core:strings"
import "core:time"
import sdl3 "vendor:sdl3"
import sdl3img "vendor:sdl3/image"

// TODO
// Move to options file
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
	clear_color:  sdl3.Color,
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

	// Key modifiers (shift, ctrl, alt, etc.)
	mods_prev:      sdl3.Keymod,
	mods_curr:      sdl3.Keymod,
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
	},
}

SDL_Texture :: struct {
	name:    string,
	surface: ^sdl3.Surface,
	texture: ^sdl3.Texture,
}

SDL_Animation :: struct {
	name:         string,
	texture:      SDL_Texture,
	frame:        []^sdl3.Surface,
	delay_ms:     u32,

	// TODO: This is sus
	// world_offset is the vector from the top left of the frame surface to the world_position of the "thing" the animation represents
	world_offset: Vec2,
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

sdl_frame_begin :: proc(s: ^SDL, delta_ms: f32 = 0) -> (quit: bool) {
	// Track state across time steps.
	s.window.size_prev = s.window.size_curr
	s.keyboard.scancodes_prev = s.keyboard.scancodes_curr

	clear(&s.keyboard.keycodes_prev)
	for keycode, pressed in s.keyboard.keycodes_curr {
		s.keyboard.keycodes_prev[keycode] = pressed
	}

	s.keyboard.mods_prev = s.keyboard.mods_curr

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
		if pressed {
			s.keyboard.keycodes_curr[e.key.key] = true
		} else {
			delete_key(&s.keyboard.keycodes_curr, e.key.key)
		}
		s.keyboard.mods_curr = e.key.mod

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

// TODO
// Review before continued usage
// 
// Capture screenshot from render target and save to file
sdl_capture_screenshot :: proc(s: ^SDL) {
	// Generate filename with timestamp and frame count
	now := time.now()
	date_str := fmt.tprintf("%04d%02d%02d", time.year(now), time.month(now), time.day(now))
	hour, min, sec := time.clock(now)
	time_str := fmt.tprintf("%02d%02d%02d", hour, min, sec)

	// Use tick for random ID
	random_id := fmt.tprintf("%08X", u32(time.tick_now()._nsec) & 0xFFFFFFFF)

	filename := fmt.tprintf("dev/screen_capture/%s-%s-%s.bmp", date_str, time_str, random_id)
	filename_cstr := strings.clone_to_cstring(filename, context.temp_allocator)

	// Ensure render target is still active
	sdl3.SetRenderTarget(s.renderer.ptr, s.renderer.textures.render_target.texture)

	// Read pixels from the current render target - returns a new surface
	surface := sdl3.RenderReadPixels(s.renderer.ptr, nil)
	if surface == nil {
		log.errorf("Failed to read pixels from render target: {}", sdl3.GetError())
		return
	}
	defer sdl3.DestroySurface(surface)

	// Save the surface as BMP
	save_result := sdl3.SaveBMP(surface, filename_cstr)

	if save_result {
		log.infof("Screenshot saved: {}", filename)
	} else {
		log.errorf("Failed to save screenshot: {} - {}", filename, sdl3.GetError())
	}
}

// Helpers
sdl_get_window_size :: proc(s: ^SDL) -> (size: Vec2i) {
	sdl3.GetWindowSize(s.window.ptr, &size.x, &size.y);return
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

// Check if key is currently down (held)
sdl_key_is_down :: proc(s: ^SDL, key: sdl3.Keycode) -> bool {
	return key in s.keyboard.keycodes_curr
}

// Check if key is currently up (not pressed)
sdl_key_is_up :: proc(s: ^SDL, key: sdl3.Keycode) -> bool {
	return key not_in s.keyboard.keycodes_curr
}

// Check if key was just pressed this frame (transition from up to down)
sdl_key_was_pressed :: proc(s: ^SDL, key: sdl3.Keycode) -> bool {
	return key in s.keyboard.keycodes_curr && key not_in s.keyboard.keycodes_prev
}

// Check if key was just released this frame (transition from down to up)
sdl_key_was_released :: proc(s: ^SDL, key: sdl3.Keycode) -> bool {
	return key not_in s.keyboard.keycodes_curr && key in s.keyboard.keycodes_prev
}

// Check if specific modifier is active
sdl_mod_is_active :: proc(s: ^SDL, mod: sdl3.KeymodFlag) -> bool {
	return mod in s.keyboard.mods_curr
}

// Check if any of the specified modifiers are active
sdl_mods_any_active :: proc(s: ^SDL, mods: sdl3.Keymod) -> bool {
	return (s.keyboard.mods_curr & mods) != {}
}

// Check if all of the specified modifiers are active
sdl_mods_all_active :: proc(s: ^SDL, mods: sdl3.Keymod) -> bool {
	return (s.keyboard.mods_curr & mods) == mods
}

// Check if no modifiers are active
sdl_mods_none_active :: proc(s: ^SDL) -> bool {
	return s.keyboard.mods_curr == {}
}

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

