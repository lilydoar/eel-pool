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

	if app.cli_options().check {
		log.info("App initialized successfully, exiting.")
		return
	}

	for {
		app.thread_clock_frame_start(&app.state.threads.app_data.clock)

		if quit := app.sdl_poll_events(); quit {break}

		if app.wgpu_is_ready() {app.wgpu_frame()}

		app.thread_clock_frame_end(&app.state.threads.app_data.clock)
		app.thread_clock_sleep(&app.state.threads.app_data.clock)
	}
}

