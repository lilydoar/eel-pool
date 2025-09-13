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

			//
			state:    enum {
				idle,
				running,
				guard,
				attack,
			},
			facing:   enum {
				right,
				left,
			},
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
	when FRAME_DEBUG {log.debugf("Current game input: {}", game.input)}

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

	if player_final_move_x == 0 && player_final_move_y == 0 {
		game.entity.player.state = .idle
	} else {
		game.entity.player.state = .running
	}

	if player_final_move_x < 0 {
		game.entity.player.facing = .left
	} else if player_final_move_x > 0 {
		game.entity.player.facing = .right
	}

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

	// Draw tilemap
	{
		dim_x := r.tilemaps.terrain.color1.dimension.x
		dim_y := r.tilemaps.terrain.color1.dimension.y

		padding: f32 = 20

		for x in 0 ..< dim_x {
			for y in 0 ..< dim_y {
				tile_idx := cast(u32)(y * dim_x + x)
				game_draw_tilemap_tile(
					game,
					r,
					{
						r.tilemaps.terrain.color1,
						tile_idx,
						sdl3.FRect {
							cast(f32)(x * r.tilemaps.terrain.color1.tile_size.x) +
							(padding * cast(f32)x),
							cast(f32)(y * r.tilemaps.terrain.color1.tile_size.y) +
							(padding * cast(f32)y),
							cast(f32)r.tilemaps.terrain.color1.tile_size.x,
							cast(f32)r.tilemaps.terrain.color1.tile_size.y,
						},
					},
				)
			}
		}
	}

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

	game_draw_animation(game, r, {r.animations.player.idle, sdl3.FRect{0, 192, 192, 192}, false})
	game_draw_animation(game, r, {r.animations.player.run, sdl3.FRect{192, 192, 192, 192}, false})
	game_draw_animation(
		game,
		r,
		{r.animations.player.guard, sdl3.FRect{192 * 2, 192, 192, 192}, false},
	)
	game_draw_animation(
		game,
		r,
		{r.animations.player.attack1, sdl3.FRect{192 * 3, 192, 192, 192}, false},
	)
	game_draw_animation(
		game,
		r,
		{r.animations.player.attack2, sdl3.FRect{192 * 4, 192, 192, 192}, false},
	)

	{
		// Draw player()
		dst := sdl3.FRect {
			cast(f32)game.entity.player.screen_x,
			cast(f32)game.entity.player.screen_y,
			cast(f32)game.entity.player.screen_w,
			cast(f32)game.entity.player.screen_h,
		}

		mirror_x := false if game.entity.player.facing == .right else true

		switch game.entity.player.state {
		case .idle:
			game_draw_animation(game, r, {r.animations.player.idle, dst, mirror_x})
		case .running:
			game_draw_animation(game, r, {r.animations.player.run, dst, mirror_x})
		case .guard:
		case .attack:
		}
	}
}

game_bind_control_to_key :: proc(game: ^Game, ctrl: game_control, key: sdl3.Keycode) {
	game.cfg.control[ctrl] = key
}

game_draw_tilemap_tile :: proc(game: ^Game, r: ^SDL_Renderer, cmd: struct {
		tilemap:  SDL_Tilemap,
		tile_idx: u32,
		dest:     sdl3.FRect,
	}) {

	clip: sdl3.Rect
	sdl3.GetSurfaceClipRect(cmd.tilemap.tile[cmd.tile_idx], &clip)

	src: Maybe(^sdl3.FRect) = &sdl3.FRect {
		cast(f32)clip.x,
		cast(f32)clip.y,
		cast(f32)clip.w,
		cast(f32)clip.h,
	}

	dst_local := cmd.dest
	dst: Maybe(^sdl3.FRect) = &dst_local

	when FRAME_DEBUG {log.debugf(
			"Render tilemap tile {}: src: {}, dest: {}",
			cmd.tile_idx,
			src,
			dst,
		)}

	sdl3.RenderTexture(r.ptr, cmd.tilemap.texture, src, dst)
}

game_draw_animation :: proc(game: ^Game, r: ^SDL_Renderer, cmd: struct {
		anim:     SDL_Animation,
		dest:     sdl3.FRect,
		mirror_x: bool,
	}) {
	elapsed_ms: u64 = game.frame_count
	frame := (elapsed_ms / cast(u64)cmd.anim.delay_ms) % cast(u64)len(cmd.anim.frame)
	// when FRAME_DEBUG {
	// 	log.debugf("animation {} frame: {}", r.animations.player.idle.name, frame)
	// }

	clip: sdl3.Rect
	sdl3.GetSurfaceClipRect(cmd.anim.frame[frame], &clip)

	src: Maybe(^sdl3.FRect) = &sdl3.FRect {
		cast(f32)clip.x,
		cast(f32)clip.y,
		cast(f32)clip.w,
		cast(f32)clip.h,
	}

	dst_local := cmd.dest
	dst: Maybe(^sdl3.FRect) = &dst_local

	// when FRAME_DEBUG {log.debugf(
	// 		"Render {} frame {}: src: {}, dest: {}",
	// 		r.animations.player.idle.name,
	// 		frame,
	// 		src,
	// 		dst,
	// 	)}
	sdl3.RenderTextureRotated(
		r.ptr,
		cmd.anim.texture,
		src,
		dst,
		0,
		{0, 0},
		.NONE if !cmd.mirror_x else .HORIZONTAL,
	)
}

