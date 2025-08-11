package main

import "../../app"
import "core:log"

should_loop: proc() -> bool = proc() -> bool {return true}

main :: proc() {
	context.logger = log.create_console_logger(opt = app.log_opts)

	app.app_init()
	defer app.app_deinit()

	if app.cli_options().check {
		log.info("App initialized successfully, exiting.")
		return
	}

	if app.cli_options().game_frame != 0 {
		log.infof("Running for %d frames then exiting.", app.cli_options().game_frame)
		should_loop = proc() -> bool {
			game_frame := app.app.thread_game.clock.frame_count
			frame_limit := cast(u64)(app.cli_options().game_frame)
			// log.debugf("Game frame: {}, limit: {}", game_frame, frame_limit)
			return game_frame < frame_limit
		}
	}

	clock := app.app.thread_main.clock

	for should_loop() {
		defer app.thread_clock_sleep(&clock)

		app.thread_clock_frame_start(&clock)
		defer app.thread_clock_frame_end(&clock)

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
	}
}

