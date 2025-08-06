package app

import "core:log"
import "core:sync"
import "core:thread"
import "core:time"

APP_DESIRED_FRAME_TIME := time.Millisecond * 16
GAME_DESIRED_FRAME_TIME := time.Millisecond * 16
RENDER_DESIRED_FRAME_TIME := time.Millisecond * 16
AUDIO_DESIRED_FRAME_TIME := time.Millisecond * 16

ThreadID :: enum {
	ENTRY,
	GAME,
	RENDER,
	AUDIO,
}

ChildThreadCount: int : 4

AppThreads :: struct {
	threads:            [ChildThreadCount]^thread.Thread,
	shutdown_requested: bool,
	shutdown_mutex:     sync.Mutex,
	app_data:           AppThreadData,
	game_data:          GameThreadData,
	render_data:        RenderThreadData,
	audio_data:         AudioThreadData,
}

AppThreadData :: struct {
	initialized: bool,
	clock:       ThreadClock,
}

app_initialized :: proc() -> bool {
	return state.threads.app_data.initialized
}

GameThreadData :: struct {
	initialized: bool,
	clock:       ThreadClock,
	game_api:    GameAPI,
}

RenderThreadData :: struct {
	initialized: bool,
	clock:       ThreadClock,
}

AudioThreadData :: struct {
	initialized: bool,
	clock:       ThreadClock,
}

app_threads_init :: proc() -> bool {
	state.threads.app_data.clock = thread_clock_init(APP_DESIRED_FRAME_TIME)

	game_thread_idx := cast(int)ThreadID.GAME
	game_thread: ^thread.Thread
	when ODIN_DEBUG {
		game_thread = thread.create(game_entry_proc_develop)
	} else {
		game_thread = thread.create(game_entry_proc_release)
	}
	game_thread.user_index = game_thread_idx
	game_thread.data = &state.threads.game_data
	state.threads.threads[game_thread_idx] = game_thread

	render_thread_idx := cast(int)ThreadID.RENDER
	render_thread := thread.create(render_thread_proc)
	render_thread.user_index = render_thread_idx
	render_thread.data = &state.threads.render_data
	state.threads.threads[render_thread_idx] = render_thread

	audio_thread_idx := cast(int)ThreadID.AUDIO
	audio_thread := thread.create(audio_thread_proc)
	audio_thread.user_index = audio_thread_idx
	audio_thread.data = &state.threads.audio_data
	state.threads.threads[audio_thread_idx] = audio_thread

	return true
}

app_threads_start :: proc() {
	log.debug("Starting threads...")

	for i in cast(int)ThreadID.GAME ..< ChildThreadCount {
		assert(state.threads.threads[i] != nil, "Thread must be initialized before starting.")
		thread.start(state.threads.threads[i])
	}
}

app_threads_stop :: proc() -> bool {
	log.debug("Stopping threads...")

	sync.mutex_lock(&state.threads.shutdown_mutex)
	state.threads.shutdown_requested = true
	sync.mutex_unlock(&state.threads.shutdown_mutex)

	for i in cast(int)ThreadID.GAME ..< ChildThreadCount {
		if state.threads.threads[i] == nil {
			log.debugf("Thread {} is nil, skipping shutdown.", ThreadID(i))
			continue
		}

		log.debugf("Stopping thread {}...", ThreadID(i))

		thread.join(state.threads.threads[i])
	}

	for i in cast(int)ThreadID.GAME ..< ChildThreadCount {
		if state.threads.threads[i] == nil {continue}
		thread.destroy(state.threads.threads[i])
	}

	return true
}

render_thread_proc :: proc(t: ^thread.Thread) {
	context.logger = log.create_console_logger(opt = log_opts)

	log.debug("Render thread starting...")
	defer log.debug("Render thread exiting...")

	thread_data := cast(^RenderThreadData)t.data
	thread_data.clock = thread_clock_init(RENDER_DESIRED_FRAME_TIME)
	thread_data.initialized = true

	for {
		thread_clock_frame_start(&thread_data.clock)

		sync.mutex_lock(&state.threads.shutdown_mutex)
		shutdown_requested := state.threads.shutdown_requested
		sync.mutex_unlock(&state.threads.shutdown_mutex)

		if shutdown_requested {break}

		thread_clock_frame_end(&thread_data.clock)
		thread_clock_sleep(&thread_data.clock)
	}
}

audio_thread_proc :: proc(t: ^thread.Thread) {
	context.logger = log.create_console_logger(opt = log_opts)

	log.debug("Audio thread starting...")
	defer log.debug("Audio thread exiting...")

	thread_data := cast(^AudioThreadData)t.data
	thread_data.clock = thread_clock_init(AUDIO_DESIRED_FRAME_TIME)
	thread_data.initialized = true

	for {
		thread_clock_frame_start(&thread_data.clock)

		sync.mutex_lock(&state.threads.shutdown_mutex)
		shutdown_requested := state.threads.shutdown_requested
		sync.mutex_unlock(&state.threads.shutdown_mutex)

		if shutdown_requested {break}

		thread_clock_frame_end(&thread_data.clock)
		thread_clock_sleep(&thread_data.clock)
	}
}

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

thread_clock_frame_curr_duration :: proc(clock: ^ThreadClock) -> time.Duration {
	sync.mutex_lock(&clock.timing_mutex)
	dur := time.diff(clock.curr_frame.start, clock.curr_frame.end)
	sync.mutex_unlock(&clock.timing_mutex)
	return dur
}

thread_clock_frame_prev_duration :: proc(clock: ^ThreadClock) -> time.Duration {
	sync.mutex_lock(&clock.timing_mutex)
	dur := time.diff(clock.prev_frame.start, clock.prev_frame.end)
	sync.mutex_unlock(&clock.timing_mutex)
	return dur
}

thread_clock_sleep :: proc(clock: ^ThreadClock) {
	curr_frame_dur := thread_clock_frame_curr_duration(clock)
	if curr_frame_dur >= clock.frame_duration_target {return}
	desired_sleep_dur := clock.frame_duration_target - curr_frame_dur
	time.sleep(desired_sleep_dur)
}

