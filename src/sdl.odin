package game

import "core:log"
import "core:strings"
import sdl3 "vendor:sdl3"

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

