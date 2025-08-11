package app

import "core:log"
import "core:sync"
import "core:thread"
import "core:time"

MAIN_DESIRED_FRAME_TIME := time.Millisecond * 16

// TODO: Rename Thread to System. Or build a System specific construct. Start to capture lifecycle of separate app systems. 

Thread :: struct {
	initialized:        bool,
	shutdown_requested: bool,
	shutdown_mtx:       sync.Mutex,
	thread:             ^thread.Thread,
	clock:              ThreadClock,
	data:               ThreadData,
	label:              string,
}

ThreadData :: struct {
	parent: ^Thread,
	init:   proc(),
	deinit: proc(),
	update: proc(),
}

// The lifetime of the worker threads is managed by the Thread type.
// But, the main thread is managed by the OS and runtime.
// This means the fields: thread and data procs, are null on the main thread.
thread_init_main :: proc() -> Thread {
	t: Thread
	t.clock = thread_clock_init(MAIN_DESIRED_FRAME_TIME)
	t.label = "Main Thread"
	return t
}

// thread_init creates a new thread system resource.
// Initializes a clock for the thread to update the thread inner loop at a "uniform" rate.
// Sets up the proc ptrs that tell the thread how to do init, deinit, and inner loop update
thread_init :: proc(
	proc_init: proc(),
	proc_deinit: proc(),
	proc_update: proc(),
	want_frame_time: time.Duration = time.Millisecond * 16,
	label: string = "",
) -> Thread {
	t: Thread
	t.thread = thread.create(thread_proc)
	t.clock = thread_clock_init(want_frame_time)
	t.data = ThreadData {
		init   = proc_init,
		deinit = proc_deinit,
		update = proc_update,
	}
	t.label = label

	return t
}

thread_deinit :: proc(t: ^Thread) {
	assert(t != nil)
	assert(t.thread != nil)
	thread.destroy(t.thread)
	t^ = Thread{}
}

// thread_start starts the thread and waits for it to initialize.
// If the thread does not initialize within the timeout duration, it is terminated and false is returned.
// 
// WARN: The thread pointer must be constant between the thread's corresponding calls of thread start/stop.
thread_start :: proc(t: ^Thread, timeout: time.Duration = time.Second * 5) -> bool {
	assert(t != nil)
	assert(t.thread != nil)
	assert(!t.initialized)

	label := t.label
	if label == "" {label = "<unnamed>"}

	// We must set the thread local data here because we do not know
	// the thread's address in the thread_init function since t gets 
	// passed out by value
	t.thread.data = &t.data
	t.data.parent = t

	log.infof("Starting thread {}...", label)
	thread.start(t.thread)

	log.debugf("Waiting for thread {} to initialize...", label)
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

// thread_stop requests the thread to shutdown and waits for it to finish.
// If the thread does not shutdown within the timeout duration, it is forcibly terminated.
thread_stop :: proc(t: ^Thread, timeout: time.Duration = time.Second * 5, exit_code: int = 0) {
	assert(t != nil)
	assert(t.thread != nil)

	label := t.label
	if label == "" {label = "<unnamed>"}

	if !t.initialized {
		log.warnf("Thread {} is not initialized, terminating", label)
		thread.terminate(t.thread, 1)
		return
	}

	thread_shutdown_requested_set(t, true)

	wait_start := time.now()

	for {
		if thread.is_done(t.thread) {return}

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

// thread_proc is the entry point for the worker threads.
// This orchestrates worker initialization, the thread loop, 
// and deinitialization.
thread_proc :: proc(t: ^thread.Thread) {
	assert(t != nil)

	context.logger = log.create_console_logger()

	data := cast(^ThreadData)t.data
	parent := data.parent
	label := parent.label
	if label == "" {label = "<unnamed>"}

	log.infof("Thread {} initializing...", label)

	data.init()
	defer data.deinit()

	parent.initialized = true

	log.infof("Thread {} starting loop...", label)
	for {
		if thread_shutdown_requested_get(parent) {break}
		defer thread_clock_sleep(&parent.clock)

		thread_clock_frame_start(&parent.clock)
		defer thread_clock_frame_end(&parent.clock)

		data.update()
	}
}

thread_shutdown_requested_get :: proc(t: ^Thread) -> bool {
	assert(t != nil)
	sync.mutex_lock(&t.shutdown_mtx)
	req := t.shutdown_requested
	sync.mutex_unlock(&t.shutdown_mtx)
	return req
}

thread_shutdown_requested_set :: proc(t: ^Thread, val: bool) {
	assert(t != nil)
	sync.mutex_lock(&t.shutdown_mtx)
	t.shutdown_requested = val
	sync.mutex_unlock(&t.shutdown_mtx)
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
	clock_mutex:           sync.Mutex,
	frame_duration_target: time.Duration,
	frame_count:           u64,
	curr_frame:            TimeSpan,
	prev_frame:            TimeSpan,
}

TimeSpan :: struct {
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
	sync.mutex_lock(&clock.clock_mutex)
	clock.frame_count += 1
	clock.prev_frame.start = clock.curr_frame.start
	clock.prev_frame.end = clock.curr_frame.end
	clock.curr_frame.start = time.now()
	sync.mutex_unlock(&clock.clock_mutex)
}

thread_clock_frame_end :: proc(clock: ^ThreadClock) {
	sync.mutex_lock(&clock.clock_mutex)
	clock.curr_frame.end = time.now()
	sync.mutex_unlock(&clock.clock_mutex)
}

thread_clock_frame_curr_dur :: proc(clock: ^ThreadClock) -> time.Duration {
	sync.mutex_lock(&clock.clock_mutex)
	dur := time.diff(clock.curr_frame.start, clock.curr_frame.end)
	sync.mutex_unlock(&clock.clock_mutex)
	return dur
}

thread_clock_frame_prev_dur :: proc(clock: ^ThreadClock) -> time.Duration {
	sync.mutex_lock(&clock.clock_mutex)
	dur := time.diff(clock.prev_frame.start, clock.prev_frame.end)
	sync.mutex_unlock(&clock.clock_mutex)
	return dur
}

thread_clock_sleep :: proc(clock: ^ThreadClock) {
	curr_frame_dur := thread_clock_frame_curr_dur(clock)
	if curr_frame_dur >= clock.frame_duration_target {return}
	desired_sleep_dur := clock.frame_duration_target - curr_frame_dur
	time.sleep(desired_sleep_dur)
}

