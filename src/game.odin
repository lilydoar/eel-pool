package game

import "base:runtime"
import "core:log"

Game :: struct {
	// Runtime
	frame_count:  u64,
	ctx:          runtime.Context,

	// Game state
	chunk_system: Chunk_S,
}

game_init :: proc(game: ^Game, ctx: runtime.Context, logger: log.Logger) {
	context = ctx

	// Initialization code for the game module
	log.debug("Begin initializing game module")
	defer log.debug("End initializing game module")

	game.ctx = ctx
	game.ctx.logger = logger
}

game_deinit :: proc(game: ^Game) {
	context = game.ctx

	// Cleanup code for the game module
	log.debug("Begin deinitializing game module")
	defer log.debug("End deinitializing game module")
}

game_update :: proc(game: ^Game) {
	context = game.ctx

	// Update logic for the game module
	when FRAME_DEBUG {log.debug("Begin updating game state")}
	when FRAME_DEBUG {defer log.debug("End updating game state")}
}

game_draw :: proc(game: ^Game, frame: ^WGPU_RenderPass_Active) {
	context = game.ctx

	// Drawing logic for the game module
	when FRAME_DEBUG {log.debug("Begin drawing game frame")}
	when FRAME_DEBUG {defer log.debug("End drawing game frame")}
}

