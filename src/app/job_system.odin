package app

import "core:log"
import "core:thread"

job_system_proc :: proc(t: ^thread.Thread) {
	log.debug("Job system thread starting...")
	defer log.debug("Job system thread exiting...")

	thread_data := cast(^Thread)t.data
}

