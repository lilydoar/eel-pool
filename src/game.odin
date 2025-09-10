package game

import "base:runtime"
import "core:log"

import sdl3 "vendor:sdl3"

Game :: struct {
	ctx:           runtime.Context,
	cfg:           Game_Config,
	frame_count:   u64,
	frame_step_ms: f64, // ms per game frame (fixed step)

	//
	input:         bit_set[game_control],

	// 
	entity:        struct {
		player: struct {
			// The player's position in pixels relative to the top-left corner of the screen
			screen_x: f32,
			screen_y: f32,
			// The player's size on the screen in pixels
			screen_w: f32,
			screen_h: f32,
		},
	},
}

Game_Config :: struct {
	control: map[game_control]sdl3.Keycode,
	entity:  struct {
		player: struct {
			player_move_speed_x_axis: f32,
			player_move_speed_y_axis: f32,
		},
	},
}

game_control :: enum {
	player_move_up,
	player_move_down,
	player_move_left,
	player_move_right,
}

game_init :: proc(game: ^Game, ctx: runtime.Context, logger: log.Logger) {
	context = ctx

	// Initialization code for the game module
	log.debug("Begin initializing game module")
	defer log.debug("End initializing game module")

	game.ctx = ctx
	game.ctx.logger = logger

	game.frame_step_ms = 1000 / 60 // 16.666 ms per frame at 60 FPS

	game.entity.player.screen_w = 128
	game.entity.player.screen_h = 128

	game.cfg.control = make(map[game_control]sdl3.Keycode)
	game_bind_control_to_key(game, .player_move_up, sdl3.K_W)
	game_bind_control_to_key(game, .player_move_down, sdl3.K_S)
	game_bind_control_to_key(game, .player_move_left, sdl3.K_A)
	game_bind_control_to_key(game, .player_move_right, sdl3.K_D)

	game.cfg.entity.player.player_move_speed_x_axis = 4
	game.cfg.entity.player.player_move_speed_y_axis = 4
}

game_deinit :: proc(game: ^Game) {
	context = game.ctx

	// Cleanup code for the game module
	log.debug("Begin deinitializing game module")
	defer log.debug("End deinitializing game module")

	delete(game.cfg.control)
}

game_update :: proc(sdl: ^SDL, game: ^Game) {
	context = game.ctx

	// Update logic for the game module
	when FRAME_DEBUG {log.debugf("Begin game update: frame_count: {}", game.frame_count)}
	when FRAME_DEBUG {defer log.debug("End game update")}

	game.input = {}
	for k, v in game.cfg.control {
		if sdl.keyboard.keycodes_curr[v] {game.input = game.input + {k}}
	}
	log.debugf("Current game input: {}", game.input)

	player_desire_move_x: f32
	player_desire_move_y: f32

	if .player_move_up in game.input {player_desire_move_y -= 1.0}
	if .player_move_down in game.input {player_desire_move_y += 1.0}
	if .player_move_left in game.input {player_desire_move_x -= 1.0}
	if .player_move_right in game.input {player_desire_move_x += 1.0}

	player_final_move_x := cast(f32)(cast(f64)player_desire_move_x *
		cast(f64)game.cfg.entity.player.player_move_speed_x_axis)
	player_final_move_y := cast(f32)(cast(f64)player_desire_move_y *
		cast(f64)game.cfg.entity.player.player_move_speed_y_axis)

	game.entity.player.screen_x += player_final_move_x
	game.entity.player.screen_y += player_final_move_y

	bounds_x: f32 = cast(f32)sdl.window.size_curr.x - game.entity.player.screen_w
	bounds_y: f32 = cast(f32)sdl.window.size_curr.y - game.entity.player.screen_h
	if game.entity.player.screen_x < 0.0 {game.entity.player.screen_x = 0.0}
	if game.entity.player.screen_y < 0.0 {game.entity.player.screen_y = 0.0}
	if game.entity.player.screen_x > bounds_x {game.entity.player.screen_x = bounds_x}
	if game.entity.player.screen_y > bounds_y {game.entity.player.screen_y = bounds_y}

	when FRAME_DEBUG {
		log.debugf("player desire move: {}, {}", player_desire_move_x, player_desire_move_y)
		log.debugf("player final move: {}, {}", player_final_move_x, player_final_move_y)
		log.debugf(
			"player position: {}, {}",
			game.entity.player.screen_x,
			game.entity.player.screen_y,
		)
	}

	game.frame_count += 1
}

game_draw :: proc(game: ^Game, r: ^SDL_Renderer) {
	context = game.ctx

	// Drawing logic for the game module
	when FRAME_DEBUG {log.debug("Begin drawing game frame")}
	when FRAME_DEBUG {defer log.debug("End drawing game frame")}

	// Draw idle atlas
	for frame in 0 ..< len(r.animations.player.idle.frame) {
		clip: sdl3.Rect
		sdl3.GetSurfaceClipRect(r.animations.player.idle.frame[frame], &clip)

		src: Maybe(^sdl3.FRect) = &sdl3.FRect {
			cast(f32)clip.x,
			cast(f32)clip.y,
			cast(f32)clip.w,
			cast(f32)clip.h,
		}
		dst: Maybe(^sdl3.FRect) = &sdl3.FRect {
			cast(f32)clip.x,
			cast(f32)clip.y,
			cast(f32)clip.w,
			cast(f32)clip.h,
		}

		sdl3.RenderTexture(r.ptr, r.animations.player.idle.texture, src, dst)
	}

	{
		// Draw idle animation
		elapsed_ms: u64 = game.frame_count
		frame :=
			(elapsed_ms / cast(u64)r.animations.player.idle.delay_ms) %
			cast(u64)len(r.animations.player.idle.frame)
		// when FRAME_DEBUG {
		// 	log.debugf("animation {} frame: {}", r.animations.player.idle.name, frame)
		// }

		clip: sdl3.Rect
		sdl3.GetSurfaceClipRect(r.animations.player.idle.frame[frame], &clip)

		src: Maybe(^sdl3.FRect) = &sdl3.FRect {
			cast(f32)clip.x,
			cast(f32)clip.y,
			cast(f32)clip.w,
			cast(f32)clip.h,
		}
		dst: Maybe(^sdl3.FRect) = &sdl3.FRect{0, cast(f32)clip.h, cast(f32)clip.w, cast(f32)clip.h}

		// when FRAME_DEBUG {log.debugf(
		// 		"Render {} frame {}: src: {}, dest: {}",
		// 		r.animations.player.idle.name,
		// 		frame,
		// 		src,
		// 		dst,
		// 	)}
		sdl3.RenderTexture(r.ptr, r.animations.player.idle.texture, src, dst)
	}

	{
		// Draw run animation
		elapsed_ms: u64 = game.frame_count
		frame :=
			(elapsed_ms / cast(u64)r.animations.player.run.delay_ms) %
			cast(u64)len(r.animations.player.run.frame)
		// when FRAME_DEBUG {
		// 	log.debugf("animation {} frame: {}", r.animations.player.run.name, frame)
		// }

		clip: sdl3.Rect
		sdl3.GetSurfaceClipRect(r.animations.player.run.frame[frame], &clip)

		src: Maybe(^sdl3.FRect) = &sdl3.FRect {
			cast(f32)clip.x,
			cast(f32)clip.y,
			cast(f32)clip.w,
			cast(f32)clip.h,
		}
		dst: Maybe(^sdl3.FRect) = &sdl3.FRect {
			cast(f32)clip.w,
			cast(f32)clip.h,
			cast(f32)clip.w,
			cast(f32)clip.h,
		}

		// when FRAME_DEBUG {log.debugf(
		// 		"Render {} frame {}: src: {}, dest: {}",
		// 		r.animations.player.run.name,
		// 		frame,
		// 		src,
		// 		dst,
		// 	)}
		sdl3.RenderTexture(r.ptr, r.animations.player.run.texture, src, dst)
	}

	{
		// Draw player()
		elapsed_ms: u64 = game.frame_count
		frame :=
			(elapsed_ms / cast(u64)r.animations.player.run.delay_ms) %
			cast(u64)len(r.animations.player.run.frame)
		// when FRAME_DEBUG {
		// 	log.debugf("animation {} frame: {}", r.animations.player.run.name, frame)
		// }

		clip: sdl3.Rect
		sdl3.GetSurfaceClipRect(r.animations.player.run.frame[frame], &clip)
		src: Maybe(^sdl3.FRect) = &sdl3.FRect {
			cast(f32)clip.x,
			cast(f32)clip.y,
			cast(f32)clip.w,
			cast(f32)clip.h,
		}

		dst: Maybe(^sdl3.FRect) = &sdl3.FRect {
			cast(f32)game.entity.player.screen_x,
			cast(f32)game.entity.player.screen_y,
			cast(f32)game.entity.player.screen_w,
			cast(f32)game.entity.player.screen_h,
		}
		when FRAME_DEBUG {log.debugf(
				"Render {} frame {}: src: {}, dest: {}",
				r.animations.player.run.name,
				frame,
				src,
				dst,
			)}
		sdl3.RenderTexture(r.ptr, r.animations.player.run.texture, src, dst)
	}
}

game_bind_control_to_key :: proc(game: ^Game, ctrl: game_control, key: sdl3.Keycode) {
	game.cfg.control[ctrl] = key
}

