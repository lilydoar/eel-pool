package app

import "core:log"
import "core:sync"
import "core:thread"
import "core:time"

game_proc_develop :: proc(t: ^thread.Thread) {
}

// game_entry_proc_develop :: proc(t: ^thread.Thread) {
// 	context.logger = log.create_console_logger(opt = log_opts)
//
// 	log.debug("Development game thread starting...")
// 	defer log.debug("Development game thread exiting...")
//
// 	thread_data := cast(^GameThreadData)t.data
// 	thread_data.clock = thread_clock_init(GAME_DESIRED_FRAME_TIME)
//
// 	game, ok := game_api_load()
// 	if !ok {return}
// 	defer game_api_unload(game)
// 	thread_data.game_api = game
//
// 	thread_data.game_api.init()
// 	defer thread_data.game_api.deinit()
//
// 	thread_data.initialized = true
//
// 	// I think I need to wait for other threads to finish initialization before I start the game update.
// 	// Don't want to load in a scene/interact with the game before render thread finishes (I think? headless?)
//
// 	for {
// 		thread_clock_frame_start(&thread_data.clock)
//
// 		sync.mutex_lock(&app.threads.shutdown_mutex)
// 		shutdown_requested := app.threads.shutdown_requested
// 		sync.mutex_unlock(&app.threads.shutdown_mutex)
// 		if shutdown_requested {break}
//
// 		// If signal to reload game code
// 		// Load new game api
// 		// Copy over game state to new api
// 		// Switch to the new game api
//
// 		// If signal to reload game data
// 		// Load new game data
// 		// Swap the game data values that the game state is currently using
//
// 		if app_initialized() {
// 			thread_data.game_api.update()
// 			thread_data.clock.frame_count += 1
//
// 			// TODO: Produce a render packet and make it available to the renderer
// 		}
//
// 		thread_clock_frame_end(&thread_data.clock)
// 		thread_clock_sleep(&thread_data.clock)
// 	}
// }

