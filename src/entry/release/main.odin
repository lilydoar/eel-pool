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

game_init :: proc "c" () {
	context = runtime.default_context()
	game.game_init()
}

game_deinit :: proc "c" () {
	context = runtime.default_context()
	game.game_deinit()
}

game_update :: proc "c" () {
	context = runtime.default_context()
	game.game_update()
}

