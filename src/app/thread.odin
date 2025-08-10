package app

import "core:log"
import "core:sync"
import "core:thread"
import "core:time"

APP_DESIRED_FRAME_TIME := time.Millisecond * 16
GAME_DESIRED_FRAME_TIME := time.Millisecond * 16
RENDER_DESIRED_FRAME_TIME := time.Millisecond * 16
AUDIO_DESIRED_FRAME_TIME := time.Millisecond * 16

Thread :: struct {
	initialized:        bool,
	shutdown_requested: bool,
	shutdown_mtx:       sync.Mutex,
	thread:             ^thread.Thread,
	clock:              ThreadClock,
	label:              string,
}

thread_init :: proc(
	p: proc(t: ^thread.Thread),
	data: rawptr,
	want_frame_time: time.Duration = time.Millisecond * 16,
	label: string = "",
) -> Thread {
	clock := thread_clock_init(want_frame_time)
	thread_ptr := thread.create(p)

	t: Thread
	defer t.initialized = true
	t.clock = clock
	t.thread = thread_ptr
	t.label = label

	return t
}

thread_start :: proc(t: ^Thread, timeout: time.Duration = time.Second * 5) -> bool {
	assert(t != nil)
	assert(t.thread != nil)

	label := t.label
	if label == "" {label = "<unnamed>"}

	log.infof("Starting thread {}...", label)
	thread.start(t.thread)

	wait_start := time.now()

	for {
		if t.initialized {return true}

		wait_dur := time.diff(wait_start, time.now())
		if wait_dur >= timeout {
			log.warnf("Timeout waiting for thread {} to initialize.", label)
			break
		}
	}

	log.infof("Terminating thread {}...", label)
	thread.terminate(t.thread, 1)
	return false
}

thread_stop :: proc(t: ^Thread, timeout: time.Duration = time.Second * 5, exit_code: int = 0) {
	assert(t != nil)
	assert(t.thread != nil)

	label := t.label
	if label == "" {label = "<unnamed>"}

	sync.mutex_lock(&t.shutdown_mtx)
	t.shutdown_requested = true
	sync.mutex_unlock(&t.shutdown_mtx)

	wait_start := time.now()

	for {
		if thread.is_done(t.thread) {return}

		if !t.initialized {break}

		wait_dur := time.diff(wait_start, time.now())
		if wait_dur >= timeout {
			log.warnf("Timeout waiting for thread {} to shutdown.", label)
			break
		}

		time.sleep(time.Millisecond * 10)
	}

	log.infof("Terminating thread {}...", label)
	thread.terminate(t.thread, 1)
}

thread_deinit :: proc(t: ^Thread) {
	assert(t != nil)
	assert(t.thread != nil)
	thread.destroy(t.thread)
	t^ = Thread{}
}

// AppThreads :: struct {
// 	threads:            [ChildThreadCount]^thread.Thread,
// 	shutdown_requested: bool,
// 	shutdown_mutex:     sync.Mutex,
// 	app_data:           AppThreadData,
// 	game_data:          GameThreadData,
// 	render_data:        RenderThreadData,
// 	audio_data:         AudioThreadData,
// }

// AppThreadData :: struct {
// 	initialized: bool,
// 	clock:       ThreadClock,
// }
//
// GameThreadData :: struct {
// 	initialized: bool,
// 	clock:       ThreadClock,
// 	game_api:    GameAPI,
// }
//
// RenderThreadData :: struct {
// 	initialized: bool,
// 	clock:       ThreadClock,
// }
//
// AudioThreadData :: struct {
// 	initialized: bool,
// 	clock:       ThreadClock,
// }
//
// app_threads_init :: proc() -> bool {
// 	app.threads.app_data.clock = thread_clock_init(APP_DESIRED_FRAME_TIME)
//
// 	game_thread_idx := cast(int)ThreadID.GAME
// 	game_thread: ^thread.Thread
// 	when ODIN_DEBUG {
// 		game_thread = thread.create(game_entry_proc_develop)
// 	} else {
// 		game_thread = thread.create(game_entry_proc_release)
// 	}
// 	game_thread.user_index = game_thread_idx
// 	game_thread.data = &app.threads.game_data
// 	app.threads.threads[game_thread_idx] = game_thread
//
// 	render_thread_idx := cast(int)ThreadID.RENDER
// 	render_thread := thread.create(render_thread_proc)
// 	render_thread.user_index = render_thread_idx
// 	render_thread.data = &app.threads.render_data
// 	app.threads.threads[render_thread_idx] = render_thread
//
// 	audio_thread_idx := cast(int)ThreadID.AUDIO
// 	audio_thread := thread.create(audio_thread_proc)
// 	audio_thread.user_index = audio_thread_idx
// 	audio_thread.data = &app.threads.audio_data
// 	app.threads.threads[audio_thread_idx] = audio_thread
//
// 	return true
// }

// app_threads_start :: proc() {
// 	log.debug("Starting threads...")
//
// 	for i in cast(int)ThreadID.GAME ..< ChildThreadCount {
// 		assert(app.threads.threads[i] != nil, "Thread must be initialized before starting.")
// 		thread.start(app.threads.threads[i])
// 	}
// }

// app_threads_stop :: proc() -> bool {
// 	log.debug("Stopping threads...")
//
// 	sync.mutex_lock(&app.threads.shutdown_mutex)
// 	app.threads.shutdown_requested = true
// 	sync.mutex_unlock(&app.threads.shutdown_mutex)
//
// 	for i in cast(int)ThreadID.GAME ..< ChildThreadCount {
// 		if app.threads.threads[i] == nil {
// 			log.debugf("Thread {} is nil, skipping shutdown.", ThreadID(i))
// 			continue
// 		}
//
// 		log.debugf("Stopping thread {}...", ThreadID(i))
//
// 		thread.join(app.threads.threads[i])
// 	}
//
// 	for i in cast(int)ThreadID.GAME ..< ChildThreadCount {
// 		if app.threads.threads[i] == nil {continue}
// 		thread.destroy(app.threads.threads[i])
// 	}
//
// 	return true
// }

// render_thread_proc :: proc(t: ^thread.Thread) {
// 	context.logger = log.create_console_logger(opt = log_opts)
//
// 	log.debug("Render thread starting...")
// 	defer log.debug("Render thread exiting...")
//
// 	thread_data := cast(^RenderThreadData)t.data
// 	thread_data.clock = thread_clock_init(RENDER_DESIRED_FRAME_TIME)
// 	thread_data.initialized = true
//
// 	for {
// 		thread_clock_frame_start(&thread_data.clock)
//
// 		sync.mutex_lock(&app.threads.shutdown_mutex)
// 		shutdown_requested := app.threads.shutdown_requested
// 		sync.mutex_unlock(&app.threads.shutdown_mutex)
//
// 		if shutdown_requested {break}
//
// 		thread_clock_frame_end(&thread_data.clock)
// 		thread_clock_sleep(&thread_data.clock)
// 	}
// }

// audio_thread_proc :: proc(t: ^thread.Thread) {
// 	context.logger = log.create_console_logger(opt = log_opts)
//
// 	log.debug("Audio thread starting...")
// 	defer log.debug("Audio thread exiting...")
//
// 	thread_data := cast(^AudioThreadData)t.data
// 	thread_data.clock = thread_clock_init(AUDIO_DESIRED_FRAME_TIME)
// 	thread_data.initialized = true
//
// 	for {
// 		thread_clock_frame_start(&thread_data.clock)
//
// 		sync.mutex_lock(&app.threads.shutdown_mutex)
// 		shutdown_requested := app.threads.shutdown_requested
// 		sync.mutex_unlock(&app.threads.shutdown_mutex)
//
// 		if shutdown_requested {break}
//
// 		thread_clock_frame_end(&thread_data.clock)
// 		thread_clock_sleep(&thread_data.clock)
// 	}
// }

ThreadClock :: struct {
	timing_mutex:          sync.Mutex,
	frame_duration_target: time.Duration,
	frame_count:           u64,
	curr_frame:            FrameTimeData,
	prev_frame:            FrameTimeData,
}

FrameTimeData :: struct {
	start: time.Time,
	end:   time.Time,
}

thread_clock_init :: proc(target_frame_duration: time.Duration) -> ThreadClock {
	clock: ThreadClock
	clock.frame_duration_target = target_frame_duration
	clock.curr_frame.start = time.now()
	clock.curr_frame.end = clock.curr_frame.start
	clock.prev_frame.start = clock.curr_frame.start
	clock.prev_frame.end = clock.curr_frame.end
	return clock
}

thread_clock_frame_start :: proc(clock: ^ThreadClock) {
	sync.mutex_lock(&clock.timing_mutex)
	clock.prev_frame.start = clock.curr_frame.start
	clock.prev_frame.end = clock.curr_frame.end
	clock.curr_frame.start = time.now()
	sync.mutex_unlock(&clock.timing_mutex)
}

thread_clock_frame_end :: proc(clock: ^ThreadClock) {
	sync.mutex_lock(&clock.timing_mutex)
	clock.curr_frame.end = time.now()
	sync.mutex_unlock(&clock.timing_mutex)
}

thread_clock_frame_curr_dur :: proc(clock: ^ThreadClock) -> time.Duration {
	sync.mutex_lock(&clock.timing_mutex)
	dur := time.diff(clock.curr_frame.start, clock.curr_frame.end)
	sync.mutex_unlock(&clock.timing_mutex)
	return dur
}

thread_clock_frame_prev_dur :: proc(clock: ^ThreadClock) -> time.Duration {
	sync.mutex_lock(&clock.timing_mutex)
	dur := time.diff(clock.prev_frame.start, clock.prev_frame.end)
	sync.mutex_unlock(&clock.timing_mutex)
	return dur
}

thread_clock_sleep :: proc(clock: ^ThreadClock) {
	curr_frame_dur := thread_clock_frame_curr_dur(clock)
	if curr_frame_dur >= clock.frame_duration_target {return}
	desired_sleep_dur := clock.frame_duration_target - curr_frame_dur
	time.sleep(desired_sleep_dur)
}

