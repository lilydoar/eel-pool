package main

import "../../app"
import "base:runtime"
import "core:dynlib"
import "core:encoding/uuid"
import "core:fmt"
import "core:log"
import "core:strings"
import "core:sync"
import "core:thread"
import "core:time"

ThreadID :: enum {
	GAME,
	RENDER,
	AUDIO,
}

ThreadCount: int : 3

AppThreads :: struct {
	threads:            [ThreadCount]^thread.Thread,
	shutdown_requested: bool,
	shutdown_mutex:     sync.Mutex,
}

app_threads: AppThreads

game_data: GameThreadData
render_data: RenderThreadData
audio_data: AudioThreadData

app_threads_init :: proc() -> bool {
	game_thread_idx := cast(int)ThreadID.GAME
	game_thread := thread.create(game_thread_proc)
	game_thread.user_index = game_thread_idx
	game_thread.data = &game_data
	app_threads.threads[game_thread_idx] = game_thread

	render_thread_idx := cast(int)ThreadID.RENDER
	render_thread := thread.create(render_thread_proc)
	render_thread.user_index = render_thread_idx
	render_thread.data = &render_data
	app_threads.threads[render_thread_idx] = render_thread

	audio_thread_idx := cast(int)ThreadID.AUDIO
	audio_thread := thread.create(audio_thread_proc)
	audio_thread.user_index = audio_thread_idx
	audio_thread.data = &audio_data
	app_threads.threads[audio_thread_idx] = audio_thread

	return true
}

app_threads_start :: proc() {
	log.debug("Starting threads...")

	for i in 0 ..< ThreadCount {
		assert(app_threads.threads[i] != nil, "Thread must be initialized before starting.")
		thread.start(app_threads.threads[i])
	}
}

app_threads_stop :: proc() -> bool {
	log.debug("Stopping threads...")

	sync.mutex_lock(&app_threads.shutdown_mutex)
	app_threads.shutdown_requested = true
	sync.mutex_unlock(&app_threads.shutdown_mutex)

	for i in 0 ..< ThreadCount {
		if app_threads.threads[i] == nil {
			log.debugf("Thread {} is nil, skipping shutdown.", ThreadID(i))
			continue
		}

		log.debugf("Stopping thread {}...", ThreadID(i))

		thread.join(app_threads.threads[i])
	}

	for i in 0 ..< ThreadCount {
		if app_threads.threads[i] == nil {continue}
		thread.destroy(app_threads.threads[i])
	}

	return true
}

GameThreadData :: struct {}

game_thread_proc :: proc(t: ^thread.Thread) {
	context.logger = log.create_console_logger()

	log.debug("Game thread starting...")
	defer log.debug("Game thread exiting...")

	for {
		sync.mutex_lock(&app_threads.shutdown_mutex)
		shutdown_requested := app_threads.shutdown_requested
		sync.mutex_unlock(&app_threads.shutdown_mutex)

		if shutdown_requested {break}

		time.sleep(time.Millisecond * 10)
	}
}

RenderThreadData :: struct {}

render_thread_proc :: proc(t: ^thread.Thread) {
	context.logger = log.create_console_logger()

	log.debug("Render thread starting...")
	defer log.debug("Render thread exiting...")

	for {
		sync.mutex_lock(&app_threads.shutdown_mutex)
		shudown_requested := app_threads.shutdown_requested
		sync.mutex_unlock(&app_threads.shutdown_mutex)

		if shudown_requested {break}

		time.sleep(time.Millisecond * 10)
	}
}

AudioThreadData :: struct {}

audio_thread_proc :: proc(t: ^thread.Thread) {
	context.logger = log.create_console_logger()

	log.debug("Audio thread starting...")
	defer log.debug("Audio thread exiting...")

	for {
		sync.mutex_lock(&app_threads.shutdown_mutex)
		shudown_requested := app_threads.shutdown_requested
		sync.mutex_unlock(&app_threads.shutdown_mutex)

		if shudown_requested {break}

		time.sleep(time.Millisecond * 10)
	}
}

main :: proc() {
	context.logger = log.create_console_logger()

	app.cli_parse()

	state: app.AppState

	app.sdl_init()
	defer app.sdl_deinit()

	app_threads_init()
	defer app_threads_stop()

	app_threads_start()

	game, ok := app.game_api_load()
	if !ok {return}
	defer app.game_api_unload(game)

	game_init(game)
	defer game_deinit(game)

	if app.cli_options().check {
		// TODO
		// Wait for all threads to finish initialization

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

