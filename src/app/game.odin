package app

import "core:log"
import "core:sync"
import "core:thread"
import "core:time"

game_init :: proc() {
	assert(!app.thread_game.initialized, "Game thread already initialized.")
	defer app.thread_game.initialized = true

	log.info("Game system initializing...")
	// game.game_init()
}

game_deinit :: proc() {
	log.info("Game system deinitializing...")
	// game.game_deinit()
}

game_dev_update :: proc() {
	log.debug("Game dev update...")

	// game.game_update()

	// <dev> only behaviors:
	// handle reload requests

	// reload game code

	// reload game data

	// reload game state
	// {
	// Scene looping system
	// If currently playing a loop,
	// and frame that just completed is last frame in loop,
	// then reload game state to the beginning of the loop.
	// }

	// reload asset <asset-id>

	// load scene: scenes can be loaded in the background without stopping the current scene
	// play scene: reload game state and game code to initial state of new scene

	// ...
}

game_rel_update :: proc() {
	// game_api.game_update()
}

