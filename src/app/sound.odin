package app

import "core:log"
import "core:thread"

sound_system_proc :: proc(t: ^thread.Thread) {
	log.debug("Sound system thread starting...")
	defer log.debug("Sound system thread exiting...")

	thread_data := cast(^Thread)t.data
}

