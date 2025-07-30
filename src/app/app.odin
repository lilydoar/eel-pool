package app

import "core:log"
import os "core:os/os2"
import "core:time"
import sdl "vendor:sdl3"

log_opts: log.Options : {
	.Level,
	.Time,
	// .Short_File_Path,
	// .Long_File_Path,
	.Procedure,
	.Line,
	.Terminal_Color,
	// .Thread_Id,
}

AppState :: struct {
	window:      ^sdl.Window,
	window_size: [2]i32,
	threads:     AppThreads,
}

state: AppState

app_init :: proc() {
	cli_parse()

	log.info("Starting app initialization...")

	sdl_init()

	app_threads_init()
	app_threads_start()

	state.threads.app_data.clock = thread_clock_init(APP_DESIRED_FRAME_TIME)
	state.threads.app_data.initialized = true

	app_init_wait()
}

app_init_wait :: proc() {
	// TODO: If a thread fails during it initialization it will return and never be initialized.
	// It should also mark itself as failed so we can check for that within this loop.

	initialization_wait: time.Stopwatch
	time.stopwatch_start(&initialization_wait)
	for !state.threads.app_data.initialized ||
	    !(cast(^GameThreadData)state.threads.threads[ThreadID.GAME].data).initialized ||
	    !(cast(^GameThreadData)state.threads.threads[ThreadID.RENDER].data).initialized ||
	    !(cast(^GameThreadData)state.threads.threads[ThreadID.AUDIO].data).initialized {
		if (time.stopwatch_duration(initialization_wait) > time.Second * 5) {
			log.warn("Timeout waiting for initialization.")
			os.exit(1)
		}
		time.sleep(time.Millisecond * 10)
	}
	time.stopwatch_stop(&initialization_wait)

	wait_ms := cast(u64)(time.stopwatch_duration(initialization_wait) / time.Millisecond)
	log.debugf("initialization wait time: {} ms", wait_ms)
}

app_deinit :: proc() {
	log.info("Deinitializing app...")
	app_threads_stop()
	sdl_deinit()
}

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

