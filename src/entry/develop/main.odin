package main

import "../../app"
import "base:runtime"
import "core:dynlib"
import "core:encoding/uuid"
import "core:fmt"
import "core:log"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"

main :: proc() {
	context.logger = log.create_console_logger(opt = app.log_opts)

	app.app_init()
	defer app.app_deinit()
	
	log.debug("App init completed, checking CLI options")
	
	if app.cli_options().check {
		log.info("App initialized successfully, exiting.")
		return
	}
	
	log.debug("Starting main thread loop")

	for {
		app.thread_clock_frame_start(&app.state.threads.app_data.clock)
		log.debug("Main thread loop iteration")

		if quit := app.sdl_poll_events(); quit {break}

		// WebGPU rendering must happen on main thread due to threading constraints.
		// WebGPU surfaces and resources cannot be safely accessed from other threads.
		// The render thread is now deprecated for WebGPU operations.
		if app.wgpu_is_ready() {
			app.wgpu_frame()
		} else {
			log.debug("WebGPU not ready, skipping frame")
		}

		app.thread_clock_frame_end(&app.state.threads.app_data.clock)
		app.thread_clock_sleep(&app.state.threads.app_data.clock)
	}
}

