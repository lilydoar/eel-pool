package main

import "../../app"
import "../../game"
import "base:runtime"
import "core:log"
import sdl "vendor:sdl3"

main :: proc() {
	context.logger = log.create_console_logger()

	app.cli_parse()

	state: app.AppState

	app.sdl_init()
	defer app.sdl_deinit()

	game_init()
	defer game_deinit()

	if app.cli_options().check {
		log.info("App initialized successfully, exiting.")
		return
	}

	for {
		if quit := app.sdl_poll_events(); quit {break}
		game_update()
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

