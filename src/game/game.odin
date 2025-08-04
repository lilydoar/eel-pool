package game

import "core:log"
GameState :: struct {
	gol_board: GOLBoard,
}

state: GameState

@(export)
game_state :: proc() -> rawptr {return &state}

@(export)
game_state_fingerprint :: proc() -> string {
	return "0.1.0"
}

@(export)
game_init :: proc() {
	board_size := 20
	log.debugf("Initializing Game Of Life board: [{0} x {0}]", board_size)
	gol_board := gol_board_init(board_size)
	gol_board_set_glider(&gol_board, 1, 1)
	state.gol_board = gol_board

	// Setup up handle maps, pools, etc.
}

@(export)
game_deinit :: proc() {
	// Tear down handle maps, pools, etc.
}

@(export)
game_update :: proc() {
	gol_board_update(&state.gol_board)
	// gol_board_print(&state.gol_board)

	// TODO: Packet the board data and send it to the render thread
}

