package game

import "core:log"

import sdl3 "vendor:sdl3"

SDL :: struct {
	initialized:    bool,
	window:         ^sdl3.Window,
	keyboard_state: ^bool,
	mouse_x:        f32,
	mouse_y:        f32,
	mouse_buttons:  sdl3.MouseButtonFlags,
	gamepad:        ^sdl3.Gamepad,
}

sdl_panic :: proc(ok: bool) {
	if !ok do log.panicf("SDL panic: {}", sdl3.GetError())
}

sdl_panic_msg :: proc(ok: bool, msg: string = "") {
	if !ok do log.panicf("SDL panic: {}: {}", msg, sdl3.GetError())
}

sdl_warn :: proc(ok: bool) {
	if !ok do log.warnf("SDL warn: {}", sdl3.GetError())
}

sdl_warn_msg :: proc(ok: bool, msg: string = "") {
	if !ok do log.warnf("SDL warn: {}: {}", msg, sdl3.GetError())
}

sdl_init :: proc() {
	log.info("Initializing SDL...")

	assert(!app.sdl.initialized)
	defer app.sdl.initialized = true

	ok := sdl3.Init({.AUDIO, .VIDEO})
	sdl_panic(ok)

	title: cstring = "Window Title"
	window_width: i32 = 1280
	window_height: i32 = 780

	// read the profile config and load application flags based on dev/release
	// release: full_screen, no window decorations, etc.
	// development: windowed, with decorations, resizable, etc.
	// viewport: run as the viewport in an editor
	// Define environments that truly need different behavior

	flags: sdl3.WindowFlags = {.RESIZABLE}

	app.sdl.window = sdl3.CreateWindow(title, window_width, window_height, flags)
	sdl_panic(app.sdl.window != nil)

	app.sdl.keyboard_state = sdl3.GetKeyboardState(nil)
	app.sdl.mouse_buttons = sdl3.GetMouseState(&app.sdl.mouse_x, &app.sdl.mouse_y)
}

sdl_deinit :: proc() {
	log.info("Deinitializing SDL...")

	assert(app.sdl.initialized)
	defer app.sdl.initialized = false

	sdl3.CloseGamepad(app.sdl.gamepad)
	sdl3.DestroyWindow(app.sdl.window)
	sdl3.Quit()
}

sdl_poll_events :: proc() -> bool {
	assert(app.sdl.initialized)

	e: sdl3.Event
	for sdl3.PollEvent(&e) {
		quit := sdl_handle_event(e)
		if quit {return true}
	}
	return false
}

sdl_handle_event :: proc(e: sdl3.Event) -> (quit: bool) {
	assert(app.sdl.initialized)

	#partial switch e.type {
	case .QUIT:
		return true
	case .WINDOW_RESIZED, .WINDOW_PIXEL_SIZE_CHANGED:
		w := cast(u32)(e.window.data1)
		h := cast(u32)(e.window.data2)
		wgpu_resize(w, h)
	case .MOUSE_MOTION:
		app.sdl.mouse_x = e.motion.x
		app.sdl.mouse_y = e.motion.y
	case .MOUSE_BUTTON_DOWN, .MOUSE_BUTTON_UP:
		app.sdl.mouse_buttons = sdl3.GetMouseState(&app.sdl.mouse_x, &app.sdl.mouse_y)
	case .GAMEPAD_ADDED:
		if app.sdl.gamepad != nil {return true}
		app.sdl.gamepad = sdl3.OpenGamepad(e.gdevice.which)
		if app.sdl.gamepad == nil {
			log.warnf("Failed to open gamepad: %s", sdl3.GetError())
		} else {
			log.infof("Gamepad connected: %s", sdl3.GetGamepadName(app.sdl.gamepad))
		}
	case .GAMEPAD_REMOVED:
		if app.sdl.gamepad == nil {return true}
		if sdl3.GetGamepadID(app.sdl.gamepad) == e.gdevice.which {
			log.infof("Gamepad disconnected: %s", sdl3.GetGamepadName(app.sdl.gamepad))
			sdl3.CloseGamepad(app.sdl.gamepad)
			app.sdl.gamepad = nil
		}
	}
	return false
}

sdl_get_window_size :: proc() -> (i32, i32) {
	assert(app.sdl.initialized)

	w: i32 = 0
	h: i32 = 0
	ok := sdl3.GetWindowSize(app.sdl.window, &w, &h)
	sdl_warn(ok)
	return w, h
}

