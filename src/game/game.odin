package game

GameState :: struct {
	scene: Scene,
}

state: GameState

@(export)
game_state :: proc() -> rawptr {return &state}

@(export)
game_state_fingerprint :: proc() -> string {
	return ""
}

@(export)
game_init :: proc() {
	// Setup up handle maps, pools, etc.
}

@(export)
game_deinit :: proc() {
	// Tear down handle maps, pools, etc.
}

@(export)
game_update :: proc() {}

