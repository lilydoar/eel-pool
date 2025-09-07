package game

import "base:runtime"
import "core:log"

import sdl3 "vendor:sdl3"

Game :: struct {
	ctx:         runtime.Context,
	frame_count: u64,
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

game_draw :: proc(game: ^Game, r: ^SDL_Renderer) {
	context = game.ctx

	// Drawing logic for the game module
	when FRAME_DEBUG {log.debug("Begin drawing game frame")}
	when FRAME_DEBUG {defer log.debug("End drawing game frame")}

	src: Maybe(^sdl3.FRect) = &sdl3.FRect{0, 0, 192, 192}
	dst: Maybe(^sdl3.FRect) = &sdl3.FRect{x = 0, y = 0, w = 192, h = 192}

	sdl3.RenderTexture(r.ptr, r.textures.player.texture, src, dst)
}

