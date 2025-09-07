package main

import game "../../"

main :: proc() {
	app: game.App

	game.app_init(&app, context)
	defer game.app_deinit(&app)

	game.app_run(&app)
}

