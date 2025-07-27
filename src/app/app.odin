package app

import "core:log"
import sdl "vendor:sdl3"

AppState :: struct {
	window:      ^sdl.Window,
	window_size: [2]i32,
}

state: AppState

sdl_init :: proc() {
	log.info("Initializing SDL...")
	ok := sdl.Init({.AUDIO, .VIDEO});sdl_assert(ok)

	title: cstring = "Window Title"
	window_width: i32 = 1280
	window_height: i32 = 780

	window := sdl.CreateWindow(title, window_width, window_height, {});sdl_assert(window != nil)
	state.window = window

	ok = sdl.GetWindowSize(state.window, &window_width, &window_height);sdl_assert(ok)
	state.window_size = [2]i32{window_width, window_height}
}

sdl_deinit :: proc() {
	log.info("Deinitializing SDL...")
	if state.window != nil {
		sdl.DestroyWindow(state.window)
		state.window = nil
	}
	state.window_size = [2]i32{-1, -1}

	sdl.Quit()
}

sdl_assert :: proc(ok: bool) {if !ok do log.panicf("SDL error: {}", sdl.GetError())}

sdl_poll_events :: proc() -> (quit: bool) {
	ev: sdl.Event
	for sdl.PollEvent(&ev) {
		#partial switch ev.type {
		case .QUIT:
			quit = true
		}
	}
	return
}

