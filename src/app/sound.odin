package app

import "core:log"
import "core:thread"

sound_init :: proc() {
	assert(!app.thread_sound.initialized, "Sound thread already initialized.")

	log.info("Sound system initializing...")
}

sound_deinit :: proc() {
	assert(app.thread_sound.initialized, "Sound thread not initialized.")

	log.info("Sound system deinitializing...")
}

sound_update :: proc() {
}

