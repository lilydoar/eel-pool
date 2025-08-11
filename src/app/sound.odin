package app

import "core:log"
import "core:thread"

sound_init :: proc() {
	log.info("Sound system initializing...")
}

sound_deinit :: proc() {
	log.info("Sound system deinitializing...")
}

sound_update :: proc() {
}

