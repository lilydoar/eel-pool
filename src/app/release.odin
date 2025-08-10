package app

import "core:log"
import "core:sync"
import "core:thread"
import "core:time"

import "../game"

game_proc_release :: proc(t: ^thread.Thread) {
}

// game_entry_proc_release :: proc(t: ^thread.Thread) {
// 	context.logger = log.create_console_logger(opt = log_opts)
//
// 	log.debug("Game thread starting...")
// 	defer log.debug("Game thread exiting...")
//
// 	thread_data := cast(^GameThreadData)t.data
//
// 	game.game_init()
// 	defer game.game_deinit()
//
// 	thread_data.initialized = true
//
// 	// I think I need to wait for other threads to finish initialization before I start the game update.
// 	// Don't want to load in a scene/interact with the game before render thread finishes (I think? headless?)
//
// 	for {
// 		sync.mutex_lock(&app.threads.shutdown_mutex)
// 		shutdown_requested := app.threads.shutdown_requested
// 		sync.mutex_unlock(&app.threads.shutdown_mutex)
//
// 		if shutdown_requested {break}
//
// 		game.game_update()
//
// 		time.sleep(time.Millisecond * 10)
// 	}
// }

