package game

import "core:log"
import shared "../"
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

	// Initialize render buffer communication
	shared.render_buffer_init()

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

	log.debug("Game update: sending GOL board render packet")

	// Create render packet with GOL board data
	current_grid := &state.gol_board.grid_double_buff[state.gol_board.grid_double_buff_idx]
	
	packet := shared.RenderPacket{
		type = .GOL_BOARD,
		data = shared.GOLBoardRenderPacket{
			board_size = i32(state.gol_board.size),
			board_data = make([dynamic]i32, len(current_grid)),
		},
	}
	
	// Copy board data  
	gol_data := &packet.data.(shared.GOLBoardRenderPacket)
	alive_cells := 0
	for i in 0..<len(current_grid) {
		cell_value := i32(current_grid[i])
		gol_data.board_data[i] = cell_value
		if cell_value == 1 do alive_cells += 1
	}
	
	// Send to render thread
	shared.render_buffer_write(&packet)
	log.debugf("Game update: sent packet with {} alive cells", alive_cells)
	
	// Clean up local packet (render buffer has its own copy)
	shared.render_packet_deinit(&packet)
}

