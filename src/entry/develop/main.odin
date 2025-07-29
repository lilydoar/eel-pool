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

	app.app_thread_data.initialized = true
	app.app_init_wait()

	if app.cli_options().check {
		log.info("App initialized successfully, exiting.")
		return
	}

	for {
		if quit := app.sdl_poll_events(); quit {break}
		time.sleep(10 * time.Millisecond)
	}
}

