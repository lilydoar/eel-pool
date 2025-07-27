package game

GameState :: struct {}

state: ^GameState

@(export)
game_state :: proc() -> rawptr {return state}

@(export)
game_state_fingerprint :: proc() -> string {
	return ""
}

@(export)
game_init :: proc() {}

@(export)
game_deinit :: proc() {}

@(export)
game_update :: proc() {}

