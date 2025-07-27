package main

import "../../app"
import "base:runtime"
import "core:dynlib"
import "core:encoding/uuid"
import "core:fmt"
import "core:log"
import "core:os"
import "core:os/os2"
import "core:strings"

main :: proc() {
	context.logger = log.create_console_logger()

	state: app.AppState

	app.sdl_init()
	defer app.sdl_deinit()

	game, ok := app.game_api_load()
	if !ok {return}
	defer app.game_api_unload(game)

	game_init(game)
	defer game_deinit(game)

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

