package app

import "core:log"
import "core:sync"
import "core:thread"
import "core:time"

game_thread_proc_develop :: proc(t: ^thread.Thread) {
	context.logger = log.create_console_logger(opt = log_opts)

	log.debug("Development game thread starting...")
	defer log.debug("Development game thread exiting...")

	thread_data := cast(^GameThreadData)t.data

	// TODO: How to do this statically for release builds?
	game, ok := game_api_load()
	if !ok {return}
	defer game_api_unload(game)
	thread_data.game_api = game

	thread_data.game_api.init()
	defer thread_data.game_api.deinit()

	thread_data.initialized = true

	// I think I need to wait for other threads to finish initialization before I start the game update.
	// Don't want to load in a scene/interact with the game before render thread finishes (I think? headless?)

	for {
		sync.mutex_lock(&app_threads.shutdown_mutex)
		shutdown_requested := app_threads.shutdown_requested
		sync.mutex_unlock(&app_threads.shutdown_mutex)

		if shutdown_requested {break}

		thread_data.game_api.update()

		time.sleep(time.Millisecond * 10)
	}
}

