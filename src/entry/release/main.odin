package main

import "../../app"
import "../../game"
import "base:runtime"
import "core:log"
import "core:time"
import sdl "vendor:sdl3"

main :: proc() {
	context.logger = log.create_console_logger()

	app.app_init()
	defer app.app_deinit()

	if app.cli_options().check {
		log.info("App initialized successfully, exiting.")
		return
	}

	for {
		app.thread_clock_frame_start(&app.state.threads.app_data.clock)

		if quit := app.sdl_poll_events(); quit {break}

		app.thread_clock_frame_end(&app.state.threads.app_data.clock)
		app.thread_clock_sleep(&app.state.threads.app_data.clock)
	}
}

