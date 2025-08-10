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

	if app.cli_options().frame != 0 {
		log.infof("Running for %d frames then exiting.", app.cli_options().frame)
	}

	should_loop := proc() -> bool {
		// if app.cli_options().frame != 0 {
		// 	game_frame := app.app.threads.game_data.clock.frame_count
		// 	frame_limit := cast(u64)(app.cli_options().frame)
		// 	return game_frame < frame_limit
		// }
		return true
	}

	for should_loop() {
		// app.thread_clock_frame_start(&app.app.threads.app_data.clock)

		if quit := app.sdl_poll_events(); quit {break}

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

		// app.thread_clock_frame_end(&app.app.threads.app_data.clock)
		// app.thread_clock_sleep(&app.app.threads.app_data.clock)
	}
}

