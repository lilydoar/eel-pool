package app

import "base:runtime"
import "core:fmt"
import "core:log"
import os "core:os/os2"
import "core:time"

log_opts: log.Options : {
	.Level,
	.Time,
	// .Short_File_Path,
	// .Long_File_Path,
	.Procedure,
	.Line,
	.Terminal_Color,
	// .Thread_Id,
}

App :: struct {
	ctx:          runtime.Context,
	sdl:          SDL,
	wgpu:         WGPU,
	thread_job:   Thread,
	thread_game:  Thread,
	thread_sound: Thread,

	// Application
	// threads:           AppThreads,
}

app: App

app_panic :: proc(ok: bool, msg: string = "") {
	if !ok do log.panic("app panic: {}", msg)
}

app_init :: proc() {
	cli_parse()

	log.info("Starting app initialization...")

	app.ctx = context

	sdl_init()
	wgpu_init()

	app.thread_job = thread_init(job_init, job_deinit, job_update, label = "Job System")

	app.thread_sound = thread_init(sound_init, sound_deinit, sound_update, label = "Sound System")

	when ODIN_DEBUG {
		game_update := game_dev_update
		game_label := "Game System <dev>"
	} else {
		game_update := game_rel_update
		game_label := "Game System <rel>"
	}
	app.thread_game = thread_init(game_init, game_deinit, game_update, label = game_label)

	thread_init_wait: time.Stopwatch
	time.stopwatch_start(&thread_init_wait)
	// scope the thread starting time
	{
		defer time.stopwatch_stop(&thread_init_wait)

		app_panic(thread_start(&app.thread_job), "Failed to start job system thread.")
		app_panic(thread_start(&app.thread_sound), "Failed to start sound system thread.")
		app_panic(thread_start(&app.thread_game), "Failed to start game thread.")
	}

	wait_ms := cast(u64)(time.stopwatch_duration(thread_init_wait) / time.Millisecond)
	log.debugf("initialization wait time: {} ms", wait_ms)
}

app_deinit :: proc() {
	log.info("Deinitializing app...")

	thread_deinit_wait: time.Stopwatch
	time.stopwatch_start(&thread_deinit_wait)
	// scope the thread stopping time
	{
		defer time.stopwatch_stop(&thread_deinit_wait)

		thread_stop(&app.thread_game)
		thread_stop(&app.thread_sound)
		thread_stop(&app.thread_job)
	}

	thread_deinit(&app.thread_sound)
	thread_deinit(&app.thread_game)
	thread_deinit(&app.thread_job)

	wait_ms := cast(u64)(time.stopwatch_duration(thread_deinit_wait) / time.Millisecond)
	log.debugf("deinitialization wait time: {} ms", wait_ms)

	wgpu_deinit()
	sdl_deinit()
}

