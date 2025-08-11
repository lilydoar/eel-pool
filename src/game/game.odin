package game

import shared "../."
import "core:fmt"
import "core:log"
import "core:strings"

// game state fingerprint.
// 
// The fingerprint is a string that uniquely identifies
// the current generation of the game state.
// This is used for reloading the game data in dev mode.
//
// fingerprint format example: 0.1.0-123456
// version_major :: 0
// version_minor :: 1
// version_patch :: 0
// game state struct size in bytes :: 123456
fingerprint_format :: "{0}.{0}.{0}-{1})"

State :: struct {
	gol_board: GOLBoard,
}

state: State

@(export)
game_state :: proc() -> rawptr {return &state}

@(export)
game_state_size :: proc() -> u64 {
	return u64(size_of(State))
}

@(export)
game_state_fingerprint :: proc() -> string {
	b: strings.Builder
	strings.builder_init(&b)
	fmt.sbprintf(
		&b,
		fingerprint_format,
		version_major,
		version_minor,
		version_patch,
		size_of(State),
	)
	result := strings.to_string(b)
	return result
}

@(export)
game_init :: proc() {
	board_size := 20
	log.debugf("Initializing Game Of Life board: [{0} x {0}]", board_size)
	gol_board := gol_board_init(board_size)
	gol_board_set_glider(&gol_board, 1, 1)
	state.gol_board = gol_board

	// gol_board_print(&state.gol_board, viewport_min, viewport_max)

	// Setup up handle maps, pools, etc.
}

@(export)
game_deinit :: proc() {
	// Tear down handle maps, pools, etc.
}

@(export)
game_update :: proc() {
	gol_board_update(&state.gol_board)
	// gol_board_print(&state.gol_board, viewport_min, viewport_max)

	// TODO: Packet the board data and send it to the render thread
}

viewport_min: shared.Vec2i = shared.Vec2i{0, 0}
viewport_max: shared.Vec2i = shared.Vec2i{40, 10}

