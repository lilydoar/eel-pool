package lib

import game "../.."
import "base:runtime"
import "core:log"
import data "../../data"

@(export)
game_state :: proc() -> rawptr {return nil}

@(export)
game_init :: proc(game_ptr: rawptr, ctx: rawptr, logger: rawptr, sdl: rawptr, asset: rawptr) {
	game_typed := cast(^game.Game)game_ptr
	ctx_typed := cast(^runtime.Context)ctx
	logger_typed := cast(^log.Logger)logger
	sdl_typed := cast(^game.SDL)sdl
	asset_typed := cast(^data.Asset_Manager)asset
	game.game_init(game_typed, ctx_typed^, logger_typed^, sdl_typed, asset_typed)
}

@(export)
game_deinit :: proc(game_ptr: rawptr) {
	game_typed := cast(^game.Game)game_ptr
	game.game_deinit(game_typed)
}

@(export)
game_update :: proc(sdl: rawptr, game_ptr: rawptr, asset: rawptr) {
	sdl_typed := cast(^game.SDL)sdl
	game_typed := cast(^game.Game)game_ptr
	asset_typed := cast(^data.Asset_Manager)asset
	game.game_update(sdl_typed, game_typed, asset_typed)
}

