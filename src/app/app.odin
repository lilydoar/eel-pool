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
	sdl:          SDL,
	wgpu:         WGPU,
	// TODO: Init the threads
	thread_job:   Thread,
	thread_game:  Thread,
	thread_sound: Thread,

	// Application
	ctx:          runtime.Context,
	threads:      AppThreads,
}

app: App

app_init :: proc() {
	cli_parse()

	log.info("Starting app initialization...")

	app.ctx = context

	sdl_init()
	wgpu_init()

	threads_init()

	app_threads_init()
	app_threads_start()

	app.threads.app_data.clock = thread_clock_init(APP_DESIRED_FRAME_TIME)

	app_init_wait()
}

app_init_wait :: proc() {
	// TODO: If a thread fails during it initialization it will return and never be initialized.
	// It should also mark itself as failed so we can check for that within this loop.

	initialization_wait: time.Stopwatch
	time.stopwatch_start(&initialization_wait)
	for !(cast(^GameThreadData)app.threads.threads[ThreadID.GAME].data).initialized ||
	    !(cast(^GameThreadData)app.threads.threads[ThreadID.RENDER].data).initialized ||
	    !(cast(^GameThreadData)app.threads.threads[ThreadID.AUDIO].data).initialized {
		if (time.stopwatch_duration(initialization_wait) > time.Second * 5) {
			log.warn("Timeout waiting for initialization.")
			os.exit(1)
		}
		time.sleep(time.Millisecond * 10)
	}
	time.stopwatch_stop(&initialization_wait)

	wait_ms := cast(u64)(time.stopwatch_duration(initialization_wait) / time.Millisecond)
	log.debugf("initialization wait time: {} ms", wait_ms)

	app.threads.app_data.initialized = true
}

app_deinit :: proc() {
	log.info("Deinitializing app...")
	app_threads_stop()
	sprite_batcher_deinit()
	wgpu_deinit()
	sdl_deinit()
}

