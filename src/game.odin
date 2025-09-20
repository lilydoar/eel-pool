package game

import "base:runtime"
import "core:encoding/json"
import "core:log"
import os "core:os/os2"

import sdl3 "vendor:sdl3"

Game :: struct {
	ctx:           runtime.Context,
	cfg:           Game_Config,
	frame_count:   u64,
	frame_step_ms: f64, // ms per game frame (fixed step)

	//
	input:         bit_set[game_control],

	// 
	level:         game_level,
	entity:        struct {
		player: struct {
			// The player's position in pixels relative to the top-left corner of the screen
			screen_x: f32,
			screen_y: f32,
			// The player's size on the screen in pixels
			screen_w: f32,
			screen_h: f32,

			//
			action:   enum {
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
		enemy:  struct {
			screen_x:     f32,
			screen_y:     f32,
			screen_w:     f32,
			screen_h:     f32,
			rotation_rad: f32,
			// Is the enemy entity active?
			active:       bool,
			velocity:     Vec2,
			behavior:     Behavior_Range_Activated_Missile,
		},
	},
}

Game_Config :: struct {
	control_key:    map[game_control]sdl3.Keycode,
	control_button: map[game_control]sdl3.MouseButtonFlag,
	entity:         struct {
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

	//
	editor_place_player,
	editor_place_enemy,
}

game_level :: struct {
	layers: []struct {
		name:      string,
		size:      Vec2i,
		tile:      []u32,
		collision: []game_tile_collision_kind,
	},
}

game_tile_collision_kind :: enum {
	empty,
	solid,
	slope_up,
	slope_down,
	slope_left,
	slope_right,
}

game_sprite :: struct {
	texture:      SDL_Texture,
	world_offset: Vec2,
}

game_init :: proc(game: ^Game, ctx: runtime.Context, logger: log.Logger) {
	context = ctx

	// Initialization code for the game module
	log.debug("Begin initializing game module")
	defer log.debug("End initializing game module")

	game.ctx = ctx
	game.ctx.logger = logger

	game.frame_step_ms = 1000 / 60 // 16.666 ms per frame at 60 FPS

	game.entity.player.screen_w = 192
	game.entity.player.screen_h = 192

	game.entity.enemy.screen_w = 64
	game.entity.enemy.screen_h = 64

	game.entity.enemy.behavior.cfg = {
		// TODO: Draw debug circle of this radius for tuning purposes
		trigger_radius       = 240,
		acceleration         = 11,
		acceleration_time_ms = 1000,
		// NOTE: The intention of the above acc and acc_t is to design missiles with different motion dynamics
		// What might be more effective as a design tool is "drawing" velocity curves
		// Example: Start slow, speed up for most of the length of the shot, slow down at the end
		// Design experience of drawing line along which the missile will travel, be able to tweak how the missile proceeds along the line 
		// Once again, interpolation
		lifetime_ms          = 1800,
	}

	game.cfg.control_key = make(map[game_control]sdl3.Keycode)
	game.cfg.control_button = make(map[game_control]sdl3.MouseButtonFlag)

	game_bind_control_to_key(game, .player_move_up, sdl3.K_W)
	game_bind_control_to_key(game, .player_move_down, sdl3.K_S)
	game_bind_control_to_key(game, .player_move_left, sdl3.K_A)
	game_bind_control_to_key(game, .player_move_right, sdl3.K_D)

	game_bind_control_to_mouse_button(game, .editor_place_player, .LEFT)
	game_bind_control_to_mouse_button(game, .editor_place_enemy, .RIGHT)

	game.cfg.entity.player.player_move_speed_x_axis = 4
	game.cfg.entity.player.player_move_speed_y_axis = 4

	load_level :: proc(path: string) -> game_level {
		log.debugf("Loading level from file: {}", path)
		defer log.debugf("Finished loading level from file: {}", path)

		data, err := os.read_entire_file_from_path(path, context.allocator)
		if err != nil {
			log.panicf("Failed to load level file {}: {}", path, err)
		}

		level: game_level
		if err := json.unmarshal(data, &level); err != nil {
			log.panicf("Failed to parse level file {}: {}", path, err)
		}

		assert(
			level.layers[0].size.x * level.layers[0].size.y == cast(i32)len(level.layers[0].tile),
		)
		assert(
			level.layers[0].size.x * level.layers[0].size.y ==
			cast(i32)len(level.layers[0].collision),
		)

		log.debugf(
			"Loaded level: size: {}, tiles: {}, collision: {}",
			level.layers[0].size,
			level.layers[0].tile,
			level.layers[0].collision,
		)

		return level
	}

	game.level = load_level("data/levels/default.json")
}

game_deinit :: proc(game: ^Game) {
	context = game.ctx

	// Cleanup code for the game module
	log.debug("Begin deinitializing game module")
	defer log.debug("End deinitializing game module")

	delete(game.cfg.control_key)
	delete(game.cfg.control_button)
}

game_update :: proc(sdl: ^SDL, game: ^Game) {
	context = game.ctx

	// Update logic for the game module
	when FRAME_DEBUG {log.debugf(
			"Begin game update: frame_count: {}, game time: {}ms",
			game.frame_count,
			cast(f64)game.frame_count * game.frame_step_ms,
		)}
	when FRAME_DEBUG {defer log.debug("End game update")}

	game.input = {}
	for k, keycode in game.cfg.control_key {
		if sdl.keyboard.keycodes_curr[keycode] {game.input = game.input + {k}}
	}
	for k, v in game.cfg.control_button {
		if sdl_mouse_button_is_down(sdl, v) {game.input = game.input + {k}}
	}
	when FRAME_DEBUG {log.debugf("Current game input: {}", game.input)}

	mouse_pos := sdl_mouse_get_position(sdl)

	// Editor actions
	if .editor_place_player in game.input {
		game.entity.player.screen_x = mouse_pos.x
		game.entity.player.screen_y = mouse_pos.y
	} else if .editor_place_enemy in game.input {
		if !game.entity.enemy.active {game.entity.enemy.active = true}
		game.entity.enemy.screen_x = mouse_pos.x
		game.entity.enemy.screen_y = mouse_pos.y
	}

	// Player input -> movement
	player_desire_move_x: f32
	player_desire_move_y: f32
	player_final_move_x: f32
	player_final_move_y: f32
	{
		if .player_move_up in game.input {player_desire_move_y -= 1.0}
		if .player_move_down in game.input {player_desire_move_y += 1.0}
		if .player_move_left in game.input {player_desire_move_x -= 1.0}
		if .player_move_right in game.input {player_desire_move_x += 1.0}

		player_final_move_x =
		cast(f32)(cast(f64)player_desire_move_x *
			cast(f64)game.cfg.entity.player.player_move_speed_x_axis)
		player_final_move_y =
		cast(f32)(cast(f64)player_desire_move_y *
			cast(f64)game.cfg.entity.player.player_move_speed_y_axis)
	}

	game_do_enemy_behavior(game)
	when FRAME_DEBUG {
		log.debugf("Enemy active: {}", game.entity.enemy.active)
		if game.entity.enemy.active {log.debugf("Enemy: {}", game.entity.enemy)}
	}

	// Apply player movement
	game.entity.player.screen_x += player_final_move_x
	game.entity.player.screen_y += player_final_move_y

	// Apply player state
	if player_final_move_x == 0 && player_final_move_y == 0 {
		game.entity.player.action = .idle
	} else {
		game.entity.player.action = .running
	}

	if player_final_move_x < 0 {
		game.entity.player.facing = .left
	} else if player_final_move_x > 0 {
		game.entity.player.facing = .right
	}

	// Apply player screen bounds
	{
		bounds_x: f32 = cast(f32)sdl.window.size_curr.x - game.entity.player.screen_w
		bounds_y: f32 = cast(f32)sdl.window.size_curr.y - game.entity.player.screen_h
		if game.entity.player.screen_x < 0.0 {game.entity.player.screen_x = 0.0}
		if game.entity.player.screen_y < 0.0 {game.entity.player.screen_y = 0.0}
		if game.entity.player.screen_x > bounds_x {game.entity.player.screen_x = bounds_x}
		if game.entity.player.screen_y > bounds_y {game.entity.player.screen_y = bounds_y}
	}

	// when FRAME_DEBUG {
	// 	log.debugf("player desire move: {}, {}", player_desire_move_x, player_desire_move_y)
	// 	log.debugf("player final move: {}, {}", player_final_move_x, player_final_move_y)
	// 	log.debugf(
	// 		"player position: {}, {}",
	// 		game.entity.player.screen_x,
	// 		game.entity.player.screen_y,
	// 	)
	// }

	game.frame_count += 1
}

game_draw :: proc(game: ^Game, r: ^SDL_Renderer) {
	context = game.ctx

	// Drawing logic for the game module
	when FRAME_DEBUG {log.debug("Begin drawing game frame")}
	when FRAME_DEBUG {defer log.debug("End drawing game frame")}

	{
		// Draw level tilemap
		for x in 0 ..< len(game.level.layers[0].tile) {

			game_draw_tilemap_tile(
				game,
				r,
				{
					r.tilemaps.terrain.color1,
					game.level.layers[0].tile[x],
					sdl3.FRect {
						cast(f32)(cast(i32)x %
							game.level.layers[0].size.x *
							r.tilemaps.terrain.color1.tile_size.x),
						cast(f32)(cast(i32)x /
							game.level.layers[0].size.x *
							r.tilemaps.terrain.color1.tile_size.y),
						cast(f32)r.tilemaps.terrain.color1.tile_size.x,
						cast(f32)r.tilemaps.terrain.color1.tile_size.y,
					},
				},
			)

		}
	}

	// demo_draw_tilemap_atlas(game, r)
	// demo_draw_idle_atlas(game, r)
	// demo_draw_player_animations(game, r)

	{
		// Draw player()
		dst := sdl3.FRect {
			cast(f32)game.entity.player.screen_x,
			cast(f32)game.entity.player.screen_y,
			cast(f32)game.entity.player.screen_w,
			cast(f32)game.entity.player.screen_h,
		}

		mirror_x := false if game.entity.player.facing == .right else true

		switch game.entity.player.action {
		case .idle:
			game_draw_animation(game, r, {animation_player_idle, dst, mirror_x})
		case .running:
			game_draw_animation(game, r, {animation_player_run, dst, mirror_x})
		case .guard:
		case .attack:
		}
	}

	{
		if !game.entity.enemy.active {return}

		// Draw enemy()
		dst := sdl3.FRect {
			cast(f32)game.entity.enemy.screen_x,
			cast(f32)game.entity.enemy.screen_y,
			cast(f32)game.entity.enemy.screen_w,
			cast(f32)game.entity.enemy.screen_h,
		}

		switch game.entity.enemy.behavior.state {
		case .idle:
			game_draw_sprite(game, r, {sprite_archer_arrow, dst, 0, false})
		case .active:
			// TODO: Rotate to face player
			game_draw_sprite(game, r, {sprite_archer_arrow, dst, 0, false})
		}
	}
}

game_bind_control_to_key :: proc(game: ^Game, ctrl: game_control, key: sdl3.Keycode) {
	game.cfg.control_key[ctrl] = key
}

game_bind_control_to_mouse_button :: proc(
	game: ^Game,
	ctrl: game_control,
	button: sdl3.MouseButtonFlag,
) {
	game.cfg.control_button[ctrl] = button
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

	// when FRAME_DEBUG {log.debugf(
	// 		"Render tilemap tile {}: src: {}, dest: {}",
	// 		cmd.tile_idx,
	// 		src,
	// 		dst,
	// 	)}

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
	// 	log.debugf("animation {} frame: {}", cmd.anim.name, frame)
	// 	log.debugf("elapsed_ms: {}, delay_ms: {}", elapsed_ms, cmd.anim.delay_ms)
	// 	log.debugf("total frames: {}", len(cmd.anim.frame))
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
	dst_local.x -= cmd.anim.world_offset.x
	dst_local.y -= cmd.anim.world_offset.y
	dst: Maybe(^sdl3.FRect) = &dst_local

	// when FRAME_DEBUG {log.debugf(
	// 		"Render {} animation frame {}: src: {}, dest: {}",
	// 		cmd.anim.name,
	// 		frame,
	// 		src,
	// 		dst,
	// 	)}

	sdl3.RenderTextureRotated(
		r.ptr,
		cmd.anim.texture.texture,
		src,
		dst,
		0,
		{0, 0},
		.NONE if !cmd.mirror_x else .HORIZONTAL,
	)
}


game_draw_sprite :: proc(game: ^Game, r: ^SDL_Renderer, cmd: struct {
		sprite:       game_sprite,
		dest:         sdl3.FRect,
		rotation_rad: f32,
		mirror_x:     bool,
	}) {
	clip: sdl3.Rect
	sdl3.GetSurfaceClipRect(cmd.sprite.texture.surface, &clip)

	src: Maybe(^sdl3.FRect) = &sdl3.FRect {
		cast(f32)clip.x,
		cast(f32)clip.y,
		cast(f32)clip.w,
		cast(f32)clip.h,
	}

	dst_local := cmd.dest
	dst_local.x -= cmd.sprite.world_offset.x
	dst_local.y -= cmd.sprite.world_offset.y
	dst: Maybe(^sdl3.FRect) = &dst_local

	// when FRAME_DEBUG {log.debugf(
	// 		"Render sprite {}: src: {}, dest: {}, rotation_rad: {}, mirror_x: {} world_offset: ({}, {})",
	// 		cmd.sprite.texture.name,
	// 		src,
	// 		dst,
	// 		cmd.rotation_rad,
	// 		cmd.mirror_x,
	// 		cmd.sprite.world_offset.x,
	// 		cmd.sprite.world_offset.y,
	// 	)}

	sdl3.RenderTextureRotated(
		r.ptr,
		cmd.sprite.texture.texture,
		src,
		dst,
		cast(f64)cmd.rotation_rad,
		{0, 0},
		.NONE if !cmd.mirror_x else .HORIZONTAL,
	)
}


game_do_enemy_behavior :: proc(game: ^Game) {
	// Enemy behavior

	if !game.entity.enemy.active {return}

	curr_time := cast(f64)game.frame_count * game.frame_step_ms

	switch game.entity.enemy.behavior.state {
	case .idle:
		if range_activated_missile_check_trigger(
			&game.entity.enemy.behavior,
			{game.entity.enemy.screen_x, game.entity.enemy.screen_y},
			{game.entity.player.screen_x, game.entity.player.screen_y},
			curr_time,
		) {
			when FRAME_DEBUG {log.debug("Enemy missile triggered!")}
		}
	case .active:
		if range_activated_missile_is_lifetime_expired(
			game.entity.enemy.behavior,
			cast(f64)game.frame_count * game.frame_step_ms,
		) {
			when FRAME_DEBUG {log.debug("Enemy missile lifetime expired!")}
			game.entity.enemy.active = false
			game.entity.enemy.behavior.state = {}
			game.entity.enemy.behavior.trigger_time = {}
			game.entity.enemy.behavior.flying_dir = {}
			return
		}

		next_pos := range_activated_missile_next_position(
			game.entity.enemy.behavior,
			{game.entity.enemy.screen_x, game.entity.enemy.screen_y},
			{game.entity.enemy.velocity.x, game.entity.enemy.velocity.y},
			curr_time,
		)
		game.entity.enemy.screen_x, game.entity.enemy.screen_y = next_pos.x, next_pos.y
	}
}

