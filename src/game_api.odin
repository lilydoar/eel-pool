package game

import "core:dynlib"
import "core:fmt"
import "core:log"
import os "core:os/os2"
import "core:path/filepath"
import "core:strconv"
import "core:strings"

GameAPI :: struct {
	lib:    dynlib.Library,

	// API
	state:  proc() -> rawptr,
	init:   proc(),
	deinit: proc(),
	update: proc(),
}

GameAPI_Dyn :: struct {
	// TODO: Store a single path, and just use filepath functions to parse it
	path:          string,
	name:          string,
	symbol_prefix: string,
	api:           GameAPI,
	gen:           u32,
}

game_api_init :: proc(
	path: string,
	name: string = "game",
	prefix: string = "game_",
) -> (
	api: GameAPI_Dyn,
) {
	// TODO
	// if release mode, create a fixed game api 

	// TODO
	// If dev mode, load the game lib

	api.path = path
	api.name = name
	api.symbol_prefix = prefix

	game_api_dyn_load(&api)

	return
}

game_api_dyn_load :: proc(a: ^GameAPI_Dyn) -> bool {
	log.debugf("Loading game library {}...", a.gen)
	defer log.debugf("Loaded game library")

	defer a.gen += 1

	ext: string
	when ODIN_OS == .Windows {
		ext = "dll"
	} else when ODIN_OS == .Darwin {
		ext = "dylib"
	} else {
		ext = "so"
	}

	src_name := fmt.tprintf("{}.{}", a.name, ext)
	src := filepath.join({a.path, src_name})

	dest_name := fmt.tprintf("{}_{}.{}", a.name, a.gen, ext)
	dest := filepath.join({a.path, dest_name})

	// If we load the original file, it can't be changed until the game unloads it.
	// So we copy the file first to prevent holding a lock on the original file.
	if err := os.copy_file(dest, src); err != nil {
		log.warnf("Copying game library source file {}: {}", src, err)
		return false
	}

	api_next: GameAPI
	if _, ok := dynlib.initialize_symbols(&api_next, dest, a.symbol_prefix, "lib"); !ok {
		log.warn("Loading game library: {0}", dynlib.last_error())
		return false
	}

	a.api = api_next
	return true
}

game_api_dyn_unload :: proc(a: ^GameAPI_Dyn) {
	if a.api.lib == nil {return}

	log.debugf("Unloading game library {}...", a.gen)
	defer log.debugf("Unloaded game library")

	ok := dynlib.unload_library(a.api.lib)
	if !ok {log.warn("Unloading game library: {0}", dynlib.last_error())}
	a.api = GameAPI{}
}

