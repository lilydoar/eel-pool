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

		if app.wgpu_is_ready() {
			app.sprite_batcher_add_sprite(
				{
					position = {0, 0, 0, 0},
					tex_coords = {0, 0, 1, 1},
					color = {0.8, 0.9, 0.2, 1},
					scale = {1, 1},
					tex_idx = 0,
				},
			)
			app.sprite_batcher_add_sprite(
				{
					position = {-0.5, -0.5, 0.0, 0},
					tex_coords = {0, 0, 1, 1},
					color = {0.2, 0.8, 0.9, 0.6},
					scale = {0.75, 0.75},
					tex_idx = 0,
				},
			)
			app.wgpu_frame()
			app.sprite_batcher_clear()
		}

		app.thread_clock_frame_end(&app.state.threads.app_data.clock)
		app.thread_clock_sleep(&app.state.threads.app_data.clock)
	}
}

