package app

import "core:crypto"
import "core:dynlib"
import "core:encoding/uuid"
import "core:fmt"
import "core:log"
import "core:os/os2"

when ODIN_OS == .Windows {
	GAME_LIB_EXT :: ".dll"
} else when ODIN_OS == .Darwin {
	GAME_LIB_EXT :: ".dylib"
} else {
	GAME_LIB_EXT :: ".so"
}

GAME_LIB_DIR :: "bin/gamelib/"
GAME_LIB_NAME :: "game"

GameAPI :: struct {
	lib:         dynlib.Library,
	id:          uuid.Identifier,

	// API functions
	state:       proc() -> rawptr,
	fingerprint: proc() -> string,
	init:        proc(),
	deinit:      proc(),
	update:      proc(),
}

game_api_path :: proc(id: uuid.Identifier) -> string {
	return fmt.tprintf(GAME_LIB_DIR + GAME_LIB_NAME + "_{}" + GAME_LIB_EXT, uuid.to_string(id))
}

game_api_load :: proc() -> (GameAPI, bool) {
	log.info("Loading game library...")

	id: uuid.Identifier
	{
		context.random_generator = crypto.random_generator()
		id = uuid.generate_v7()
	}

	src_path := GAME_LIB_DIR + GAME_LIB_NAME + GAME_LIB_EXT

	if err := os2.copy_file(game_api_path(id), src_path); err != nil {
		log.errorf("Copying game library source file {0}: {1}", src_path, err)
		return GameAPI{}, false
	}

	api := GameAPI {
		id = id,
	}

	if _, ok := dynlib.initialize_symbols(&api, game_api_path(id), "game_", "lib"); !ok {
		log.warn("Loading game library: {0}", dynlib.last_error())
		return GameAPI{}, false
	}

	log.debugf("Loaded game library: {0}", game_api_path(id))

	return api, true
}

game_api_unload :: proc(api: GameAPI) {
	log.infof("Unloading game library {0}...", game_api_path(api.id))

	path := game_api_path(api.id)

	if api.lib != nil {
		if !dynlib.unload_library(api.lib) {
			log.warnf("Unloading game library {0}: {1}", path, dynlib.last_error())
		}
	}

	if err := os2.remove(path); err != nil {
		log.warnf("Removing game library file {0}: {1}", path, err)
	}
}

