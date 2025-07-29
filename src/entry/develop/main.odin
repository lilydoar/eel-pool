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

	game, ok := app.game_api_load()
	if !ok {return}
	defer app.game_api_unload(game)

	game_init(game)
	defer game_deinit(game)

	app.app_thread_data.initialized = true
	app.app_init_wait()

	if app.cli_options().check {
		log.info("App initialized successfully, exiting.")
		return
	}

	for {
		if quit := app.sdl_poll_events(); quit {break}
		game_update(game)
	}
}

game_init :: proc "c" (game: app.GameAPI) {
	context = runtime.default_context()
	game.init()
}

game_deinit :: proc "c" (game: app.GameAPI) {
	context = runtime.default_context()
	game.deinit()
}

game_update :: proc "c" (game: app.GameAPI) {
	context = runtime.default_context()
	game.update()
}

