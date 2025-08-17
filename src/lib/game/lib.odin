package lib

import game "../.."

@(export)
game_state :: proc() -> rawptr {return nil}

@(export)
game_init :: proc() {game.game_init()}

@(export)
game_deinit :: proc() {game.game_deinit()}

@(export)
game_update :: proc() {game.game_update()}

