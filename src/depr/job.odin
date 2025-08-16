package game

import "core:log"
import "core:thread"

job_init :: proc() {
	assert(!app.thread_job_sys.initialized, "Job thread already initialized.")

	log.info("Job system initializing...")
}

job_deinit :: proc() {
	assert(app.thread_job_sys.initialized, "Job thread not initialized.")

	log.info("Job system deinitializing...")
}

job_update :: proc() {
}

