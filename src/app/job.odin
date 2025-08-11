package app

import "core:log"
import "core:thread"

job_init :: proc() {
	log.info("Job system initializing...")
}

job_deinit :: proc() {
	log.info("Job system deinitializing...")
}

job_update :: proc() {
}

