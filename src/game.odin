package game

import "base:runtime"
import "core:container/queue"
import "core:encoding/json"
import "core:log"
import "core:math/rand"
import os "core:os/os2"
import "data"
import sdl3 "vendor:sdl3"

Game :: struct {
	ctx:                   runtime.Context,
	cfg:                   Game_Config,
	assets:                ^Game_Assets,
	frame_count:           u64,
	frame_step_ms:         f64, // ms per game frame (fixed step)

	//
	input:                 bit_set[game_control],
	event_system:          Event_System,

	//
	state:                 enum {
		Playing,
		Win,
		Lose,
	},

	//
	tile_screen_size:      Vec2u, // Size of a tile on screen in pixels
	level:                 Level,
	entity_pool:           Entity_Pool,
	camera:                Camera,
	camera_viewport_scale: f32,
	timers:                struct {
		win_lose_reset_time:  f32,
		win_lose_reset_timer: f32,
		//
		enemy_spawn_interval: f32,
		enemy_spawn_timer:    f32,
	},
	score:                 u32,
	entity:                struct {
		player: struct {
			world_x:  f32,
			world_y:  f32,
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
			behavior: Behavior_Range_Activated_Missile,
		},
	},

	// Debug-related state
	debug:                 Game_Debug,
}

Game_Debug :: struct {
	capture_feedback_time:      f32, // Time remaining for capture feedback indicator (0 = inactive)
	capture_screenshot_pending: bool, // Screenshot requested, will be captured at end of frame
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
	editor_zoom_in,
	editor_zoom_out,
	editor_place_player,
	editor_place_enemy,
	editor_capture_screen,
}

game_level :: struct {
	layers: []struct {
		name:      string,
		size:      Vec2u,
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

game_init :: proc(
	game: ^Game,
	ctx: runtime.Context,
	logger: log.Logger,
	sdl: ^SDL,
	asset_manager: ^data.Asset_Manager,
	assets: ^Game_Assets,
) {
	context = ctx

	// Initialization code for the game module
	log.debug("Begin initializing game module")
	defer log.debug("End initializing game module")

	game.ctx = ctx
	game.ctx.logger = logger
	game.assets = assets

	game.frame_step_ms = 1000 / 60 // 16.666 ms per frame at 60 FPS

	game.entity_pool = entity_pool_init()


	game.timers.enemy_spawn_interval = 2000 // Spawn an enemy every 2 seconds
	game.timers.enemy_spawn_timer = game.timers.enemy_spawn_interval

	game.timers.win_lose_reset_time = 10000 // 10 seconds 

	// Load level-1 using asset manager
	level_path := "data/levels/level-1.json"
	sdl_wrapper := data.SDL {
		renderer = {renderer = sdl.renderer.ptr},
	}
	map_data, ok := data.tiled_map_load(asset_manager, &sdl_wrapper, level_path)
	if ok {
		game.level.map_data = map_data
		log.infof("Loaded level: {} ({}x{} tiles)", level_path, map_data.width, map_data.height)
	} else {
		log.errorf("Failed to load level: {}", level_path)
	}

	// log.debugf("%v", game.level.map_data)

	// TODO: Bound to the middle platform of the level
	game.level.playable_area = AABB2 {
		min = Vec2{300, 680},
		max = Vec2{1780, 1360},
	}

	game.entity.player.world_x =
		(game.level.playable_area.min.x + game.level.playable_area.max.x) * 0.5
	game.entity.player.world_y =
		(game.level.playable_area.min.y + game.level.playable_area.max.y) * 0.5

	game.entity.player.screen_w = 192
	game.entity.player.screen_h = 192


	game.entity.enemy.behavior.cfg = {
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
	game_bind_control_to_key(game, .editor_capture_screen, sdl3.K_0)
	game_bind_control_to_key(game, .editor_zoom_in, sdl3.K_EQUALS)
	game_bind_control_to_key(game, .editor_zoom_out, sdl3.K_MINUS)

	game.cfg.entity.player.player_move_speed_x_axis = 4
	game.cfg.entity.player.player_move_speed_y_axis = 4

	game.tile_screen_size = {32, 32}

	game.state = .Playing

	event_subscribe_type(&game.event_system, .EntityDestroyed, proc(ctx: rawptr, e: Event) {
		game: ^Game = cast(^Game)ctx

		when DEBUG_GAME {log.debugf("Event received: EntityDestroyed, payload: {}", e.payload)}

		if e.payload == nil {return}

		#partial switch v in e.payload {
		case EventPayloadEntityDestroyed:
			game.score += 1
			when DEBUG_GAME {log.debugf("Entity destroyed! New score: {}", game.score)}
		}
	})

	game.camera_viewport_scale = 3.2
	game.camera = Camera {
		position        = Vec2{game.entity.player.world_x, game.entity.player.world_y},
		view_size       = Vec2 {
			cast(f32)(RenderTargetSize.x) * game.camera_viewport_scale,
			cast(f32)(RenderTargetSize.y) * game.camera_viewport_scale,
		},
		target_position = Vec2{game.entity.player.world_x, game.entity.player.world_y},
		follow_mode     = .with_leash,
	}
	camera_update(&game.camera)
}

game_reset :: proc(game: ^Game, sdl: ^SDL, asset: ^data.Asset_Manager, assets: ^Game_Assets) {
	assets_backup := game.assets
	game^ = Game{}
	game_init(game, context, context.logger, sdl, asset, assets_backup)
}

game_deinit :: proc(game: ^Game) {
	context = game.ctx

	// Cleanup code for the game module
	log.debug("Begin deinitializing game module")
	defer log.debug("End deinitializing game module")

	entity_pool_deinit(&game.entity_pool)

	delete(game.cfg.control_key)
	delete(game.cfg.control_button)
}

game_update :: proc(sdl: ^SDL, game: ^Game, asset_manager: ^data.Asset_Manager) {
	context = game.ctx

	// Update logic for the game module
	when DEBUG_FRAME {log.debugf(
			"Begin game update: frame_count: {}, game time: {}ms",
			game.frame_count,
			cast(f64)game.frame_count * game.frame_step_ms,
		)}
	when DEBUG_FRAME {defer log.debug("End game update")}

	game.input = {}
	for k, keycode in game.cfg.control_key {
		if sdl.keyboard.keycodes_curr[keycode] {game.input = game.input + {k}}
	}
	for k, v in game.cfg.control_button {
		if sdl_mouse_button_is_down(sdl, v) {game.input = game.input + {k}}
	}
	when DEBUG_FRAME {log.debugf("Current game input: {}", game.input)}

	mouse_pos := sdl_mouse_get_render_position(sdl)

	game_update_timers(game, sdl, asset_manager)

	event_system_process(game, &game.event_system)
	event_system_process_timed(game, &game.event_system, cast(f32)game.frame_step_ms)

	switch game.state {
	case .Playing:
		if game.score >= 10 {
			game.state = .Win
			game.timers.win_lose_reset_timer = game.timers.win_lose_reset_time
		}

		time_limit_ms: f64 = 60_000 // 60 seconds
		if cast(f64)game.frame_count * game.frame_step_ms >= time_limit_ms {
			game.state = .Lose
			game.timers.win_lose_reset_timer = game.timers.win_lose_reset_time
		}
	case .Win:
		return
	case .Lose:
		return
	}

	// Update debug timers
	if game.debug.capture_feedback_time > 0 {
		game.debug.capture_feedback_time -= f32(game.frame_step_ms)
		if game.debug.capture_feedback_time < 0 {
			game.debug.capture_feedback_time = 0
		}
	}

	// Editor actions (trigger on key release to avoid multiple captures)
	if capture_key, ok := game.cfg.control_key[.editor_capture_screen]; ok {
		if sdl_key_was_released(sdl, capture_key) {
			// Set flag to capture screenshot at end of frame (after drawing)
			game.debug.capture_screenshot_pending = true
		}
	}

	if .editor_zoom_in in game.input {
		camera_zoom_by_factor(&game.camera, 1.1)
	} else if .editor_zoom_out in game.input {
		camera_zoom_by_factor(&game.camera, 1 / 1.1)
	}

	if .editor_place_player in game.input {
		game.entity.player.world_x = mouse_pos.x
		game.entity.player.world_y = mouse_pos.y
	} else if .editor_place_enemy in game.input {
		entity_pool_create_entity(
			&game.entity_pool,
			Entity {
				position = C_World_Position{mouse_pos.x, mouse_pos.y, 0},
				collision = C_World_Collision(
					AABB2 {
						min = Vec2{mouse_pos.x, mouse_pos.y},
						max = Vec2{mouse_pos.x + 64, mouse_pos.y + 64},
					},
				),
				sprite = C_Sprite {
					world_size   = Vec2{64, 64},
					// Center the sprite on the entity position
					world_offset = Vec2{32, 32},
				},
				variant = Entity_Enemy{behavior = {cfg = game.entity.enemy.behavior.cfg}},
			},
		)
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

	game_entity_do_behavior(game)

	// Apply player movement
	game.entity.player.world_x += player_final_move_x
	game.entity.player.world_y += player_final_move_y

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

	// Apply player bounds
	{
		game.entity.player.world_x = clamp(
			game.entity.player.world_x,
			game.level.playable_area.min.x,
			game.level.playable_area.max.x,
		)
		game.entity.player.world_y = clamp(
			game.entity.player.world_y,
			game.level.playable_area.min.y,
			game.level.playable_area.max.y,
		)
	}

	// when DEBUG_FRAME {
	// 	log.debugf("player desire move: {}, {}", player_desire_move_x, player_desire_move_y)
	// 	log.debugf("player final move: {}, {}", player_final_move_x, player_final_move_y)
	// 	log.debugf(
	// 		"player position: {}, {}",
	// 		game.entity.player.screen_x,
	// 		game.entity.player.screen_y,
	// 	)
	// }

	camera_set_target(&game.camera, Vec2{game.entity.player.world_x, game.entity.player.world_y})
	target_visible := camera_update(&game.camera)
	when DEBUG_GAME {
		if !target_visible {log.warn("Camera target (player) is outside of the camera view!")}
	}

	game.frame_count += 1
}

game_draw :: proc(game: ^Game, r: ^SDL_Renderer) {
	context = game.ctx

	// Drawing logic for the game module
	when DEBUG_FRAME {log.debug("Begin drawing game frame")}
	when DEBUG_FRAME {defer log.debug("End drawing game frame")}

	// Draw all level layers
	if game.level.map_data != nil && len(game.level.map_data.layers) > 0 {
		for layer, layer_idx in game.level.map_data.layers {
			switch layer.type {
			case .tile_layer:
				when DEBUG_GAME {
					log.debugf(
						"Drawing layer {} ({}x{}, {} tiles)",
						layer.name,
						layer.width,
						layer.height,
						len(layer.data),
					)
				}

				// Draw each tile in the layer
				for y in 0 ..< layer.height {
					for x in 0 ..< layer.width {
						idx := y * layer.width + x
						gid := layer.data[idx]

						if gid == 0 {
							continue // Empty tile
						}

						// Parse GID to extract tile ID and rendering parameters
						gid_info := data.tiled_gid_parse(gid)

						// Find which tileset this GID belongs to (use cleaned tile_id)
						tileset_idx := -1
						local_id := gid_info.tile_id

						for ts, i in game.level.map_data.tilesets {
							if gid_info.tile_id >= ts.firstgid &&
							   (i == len(game.level.map_data.tilesets) - 1 ||
									   gid_info.tile_id <
										   game.level.map_data.tilesets[i + 1].firstgid) {
								tileset_idx = i
								local_id = gid_info.tile_id - ts.firstgid
								break
							}
						}

						if tileset_idx < 0 || tileset_idx >= len(game.level.map_data.tilesets) {
							continue
						}

						tileset := game.level.map_data.tilesets[tileset_idx]

						screen_pos := camera_world_to_screen(
							&game.camera,
							Vec2 {
								cast(f32)(x * game.level.map_data.tile_width),
								cast(f32)(y * game.level.map_data.tile_height),
							},
							Vec2{cast(f32)RenderTargetSize.x, cast(f32)RenderTargetSize.y},
						)

						tile_screen_size := camera_world_size_to_screen(
							&game.camera,
							Vec2 {
								f32(game.level.map_data.tile_width),
								f32(game.level.map_data.tile_height),
							},
							Vec2{cast(f32)RenderTargetSize.x, cast(f32)RenderTargetSize.y},
						)

						if tileset.is_collection {
							// Image collection tileset - use individual tile texture
							if local_id >= u32(len(tileset.tile_textures)) {
								continue
							}

							tile_tex := tileset.tile_textures[local_id]

							dst := sdl3.FRect {
								screen_pos.x,
								screen_pos.y,
								tile_screen_size.x,
								tile_screen_size.y,
							}

							// Render entire tile texture with flip/rotation from GID
							if gid_info.use_rotated {
								sdl3.RenderTextureRotated(
									r.ptr,
									tile_tex.texture,
									nil,
									&dst,
									gid_info.rotation,
									sdl3.FPoint{},
									gid_info.flip_mode,
								)
							} else {
								sdl3.RenderTexture(r.ptr, tile_tex.texture, nil, &dst)
							}
						} else {
							// Single image tileset - use clip rects
							if local_id >= u32(len(tileset.tilemap.tile)) {
								continue
							}

							// Get tile clip rect
							if local_id >= u32(len(tileset.tilemap.tile_rects)) {
								continue
							}

							clip_rect := tileset.tilemap.tile_rects[local_id]

							dst := sdl3.FRect {
								screen_pos.x,
								screen_pos.y,
								tile_screen_size.x,
								tile_screen_size.y,
							}

							src := sdl3.FRect {
								f32(clip_rect.x),
								f32(clip_rect.y),
								f32(clip_rect.w),
								f32(clip_rect.h),
							}

							// Render tile from spritesheet with flip/rotation from GID
							if gid_info.use_rotated {
								sdl3.RenderTextureRotated(
									r.ptr,
									tileset.texture.texture,
									&src,
									&dst,
									gid_info.rotation,
									sdl3.FPoint{},
									gid_info.flip_mode,
								)
							} else {
								sdl3.RenderTexture(r.ptr, tileset.texture.texture, &src, &dst)
							}
						}
					}
				}
			case .object_layer:
				when DEBUG_GAME {
					log.debugf("Drawing object layer {} ({})", layer.name, len(layer.objects))
				}

				// Draw objects
				for obj in layer.objects {
					if obj.gid == 0 {
						log.debugf("Skipping object {} without GID", obj.id)
						continue // Skip objects without a tile
					}

					// Parse GID to extract tile ID and rendering parameters
					gid_info := data.tiled_gid_parse(obj.gid)

					// Find which tileset this GID belongs to (use cleaned tile_id)
					tileset_idx := -1
					local_id := gid_info.tile_id

					for ts, i in game.level.map_data.tilesets {
						if gid_info.tile_id >= ts.firstgid &&
						   (i == len(game.level.map_data.tilesets) - 1 ||
								   gid_info.tile_id <
									   game.level.map_data.tilesets[i + 1].firstgid) {
							tileset_idx = i
							local_id = gid_info.tile_id - ts.firstgid
							break
						}
					}

					if tileset_idx < 0 || tileset_idx >= len(game.level.map_data.tilesets) {
						log.debugf(
							"Skipping object {} with invalid tileset index {}",
							obj.id,
							tileset_idx,
						)
						continue
					}

					tileset := game.level.map_data.tilesets[tileset_idx]

					if local_id >= u32(tileset.tile_count) {
						log.debugf(
							"Skipping object {} with invalid local tile ID {} (is_collection: {})",
							obj.id,
							local_id,
							tileset.is_collection,
						)
						continue
					}

					// Objects use world coordinates directly
					// Tiled positions objects at their bottom-left corner
					screen_pos := camera_world_to_screen(
						&game.camera,
						Vec2{obj.position.x, obj.position.y - obj.height},
						Vec2{cast(f32)RenderTargetSize.x, cast(f32)RenderTargetSize.y},
					)

					obj_screen_size := camera_world_size_to_screen(
						&game.camera,
						Vec2{obj.width, obj.height},
						Vec2{cast(f32)RenderTargetSize.x, cast(f32)RenderTargetSize.y},
					)

					dst := sdl3.FRect {
						screen_pos.x,
						screen_pos.y,
						obj_screen_size.x,
						obj_screen_size.y,
					}

					when DEBUG_GAME {
						log.debugf(
							"Drawing object {} ({}) at ({}, {})",
							obj.id,
							obj.gid,
							dst.x,
							dst.y,
						)
					}

					// Render object tile with flip/rotation from GID
					if tileset.is_collection {
						// Image collection - use individual tile texture
						if local_id >= u32(len(tileset.tile_textures)) {
							log.debugf(
								"Skipping image collection object {} with invalid local tile ID {}",
								obj.id,
								local_id,
							)
							continue
						}

						tile_tex := tileset.tile_textures[local_id]
						if gid_info.use_rotated {
							sdl3.RenderTextureRotated(
								r.ptr,
								tile_tex.texture,
								nil,
								&dst,
								gid_info.rotation,
								sdl3.FPoint{},
								gid_info.flip_mode,
							)
						} else {
							sdl3.RenderTexture(r.ptr, tile_tex.texture, nil, &dst)
						}
					} else {
						// Single image tileset - use clip rect
						if local_id >= u32(len(tileset.tilemap.tile_rects)) {
							log.debugf(
								"Skipping single image object {} with invalid local tile ID {}",
								obj.id,
								local_id,
							)
							continue
						}

						clip_rect := tileset.tilemap.tile_rects[local_id]

						src := sdl3.FRect {
							f32(clip_rect.x),
							f32(clip_rect.y),
							f32(clip_rect.w),
							f32(clip_rect.h),
						}

						if gid_info.use_rotated {
							sdl3.RenderTextureRotated(
								r.ptr,
								tileset.texture.texture,
								&src,
								&dst,
								gid_info.rotation,
								sdl3.FPoint{},
								gid_info.flip_mode,
							)
						} else {
							sdl3.RenderTexture(r.ptr, tileset.texture.texture, &src, &dst)
						}
					}
				}
			}
		}
	}

	// demo_draw_tilemap_atlas(game, r)
	// demo_draw_idle_atlas(game, r)
	// demo_draw_player_animations(game, r)

	{
		// Draw player()
		if game.state == .Playing {
			screen_pos := camera_world_to_screen(
				&game.camera,
				Vec2{game.entity.player.world_x, game.entity.player.world_y},
				Vec2{cast(f32)RenderTargetSize.x, cast(f32)RenderTargetSize.y},
			)

			player_screen_size := camera_world_size_to_screen(
				&game.camera,
				Vec2{game.entity.player.screen_w, game.entity.player.screen_h},
				Vec2{cast(f32)RenderTargetSize.x, cast(f32)RenderTargetSize.y},
			)

			dst := sdl3.FRect {
				screen_pos.x,
				screen_pos.y,
				player_screen_size.x,
				player_screen_size.y,
			}

			mirror_x := false if game.entity.player.facing == .right else true

			switch game.entity.player.action {
			case .idle:
				game_draw_animation(game, r, {game.assets.animation_player_idle, dst, 0, mirror_x})
			case .running:
				game_draw_animation(game, r, {game.assets.animation_player_run, dst, 0, mirror_x})
			case .guard:
			case .attack:
			}
		}
	}

	{
		// Draw enemy()
		if game.state == .Playing {
			for e in game.entity_pool.entities {
				if !(.Is_Active in e.flags) {continue}

				#partial switch v in e.variant {
				case Entity_Enemy:
					screen_pos := camera_world_to_screen(
						&game.camera,
						Vec2{e.position.x, e.position.y},
						Vec2{cast(f32)RenderTargetSize.x, cast(f32)RenderTargetSize.y},
					)

					enemy_screen_size := camera_world_size_to_screen(
						&game.camera,
						e.sprite.world_size,
						Vec2{cast(f32)RenderTargetSize.x, cast(f32)RenderTargetSize.y},
					)

					dst := sdl3.FRect {
						screen_pos.x,
						screen_pos.y,
						enemy_screen_size.x,
						enemy_screen_size.y,
					}

					// rotate the enemy to face the player
					player_screen_pos := camera_world_to_screen(
						&game.camera,
						Vec2{game.entity.player.world_x, game.entity.player.world_y},
						Vec2{cast(f32)RenderTargetSize.x, cast(f32)RenderTargetSize.y},
					)

					vec_enemy_to_player := Vec2 {
						player_screen_pos.x - screen_pos.x,
						player_screen_pos.y - screen_pos.y,
					}

					rotation := rad_to_deg(vec2_angle(vec_enemy_to_player))

					switch game.entity.enemy.behavior.state {
					case .idle:
						game_draw_sprite(game, r, {game.assets.sprite_archer_arrow, dst, rotation, false})
					case .active:
						// TODO: Rotate to face player
						game_draw_sprite(game, r, {game.assets.sprite_archer_arrow, dst, rotation, false})
					}

				}
			}
		}
	}

	when DEBUG_GAME {
		// Draw Debug ()

		// // Draw player bounding box
		// // NOTE: This AABB is drawn offset because the interaction between anim world_offset and screen size vars is not correct
		// anim_offset := animation_player_idle.world_offset
		// debug_draw_aabb(
		// 	r,
		// 	AABB2 {
		// 		min = Vec2 {
		// 			game.entity.player.screen_x -
		// 			game.entity.player.screen_w * 0.5 -
		// 			anim_offset.x,
		// 			game.entity.player.screen_y -
		// 			game.entity.player.screen_h * 0.5 -
		// 			anim_offset.y,
		// 		},
		// 		max = Vec2 {
		// 			game.entity.player.screen_x +
		// 			game.entity.player.screen_w * 0.5 -
		// 			anim_offset.x,
		// 			game.entity.player.screen_y +
		// 			game.entity.player.screen_h * 0.5 -
		// 			anim_offset.y,
		// 		},
		// 	},
		// 	color_new(0, 0, 255, 255),
		// )

		for e in game.entity_pool.entities {
			if !(.Is_Active in e.flags) {continue}
			#partial switch v in e.variant {
			case Entity_Enemy:
				e_screen_pos := camera_world_to_screen(
					&game.camera,
					Vec2{e.position.x, e.position.y},
					Vec2{cast(f32)RenderTargetSize.x, cast(f32)RenderTargetSize.y},
				)

				// Convert trigger radius from world to screen space
				trigger_radius_screen :=
					camera_world_size_to_screen(&game.camera, Vec2{cast(f32)game.entity.enemy.behavior.cfg.trigger_radius, 0}, Vec2{cast(f32)RenderTargetSize.x, cast(f32)RenderTargetSize.y}).x

				// Draw trigger radius circle around enemy
				debug_draw_circle(
					r,
					Circle{e_screen_pos, trigger_radius_screen},
					color_new(255, 0, 0, 255),
				)

				// Draw line from enemy to player
				player_screen_pos := camera_world_to_screen(
					&game.camera,
					Vec2{game.entity.player.world_x, game.entity.player.world_y},
					Vec2{cast(f32)RenderTargetSize.x, cast(f32)RenderTargetSize.y},
				)

				debug_draw_line(
					r,
					Line2{e_screen_pos, player_screen_pos},
					color_new(255, 255, 0, 255),
				)
			}

		}

		{
			scalex, scaley: f32
			sdl3.GetRenderScale(r.ptr, &scalex, &scaley)
			defer sdl3.SetRenderScale(r.ptr, scalex, scaley)

			sdl3.SetRenderScale(r.ptr, 1.5, 1.5)
			sdl3.SetRenderDrawColor(r.ptr, 255, 255, 255, 255)

			sdl3.RenderDebugTextFormat(
				r.ptr,
				10,
				20,
				"World Pos: (%f, %f)",
				game.entity.player.world_x,
				game.entity.player.world_y,
			)

			screen_pos := camera_world_to_screen(
				&game.camera,
				Vec2{game.entity.player.world_x, game.entity.player.world_y},
				Vec2{cast(f32)RenderTargetSize.x, cast(f32)RenderTargetSize.y},
			)

			sdl3.RenderDebugTextFormat(
				r.ptr,
				10,
				30,
				"Screen Pos: (%f, %f)",
				screen_pos.x,
				screen_pos.y,
			)
		}

		// Draw debug feedback indicators
		game_draw_debug_feedback(game, r)
	}

	{
		scalex, scaley: f32
		sdl3.GetRenderScale(r.ptr, &scalex, &scaley)
		defer sdl3.SetRenderScale(r.ptr, scalex, scaley)

		sdl3.SetRenderScale(r.ptr, 1.5, 1.5)
		sdl3.SetRenderDrawColor(r.ptr, 255, 255, 255, 255)

		switch game.state {
		case .Playing:
			sdl3.RenderDebugTextFormat(r.ptr, 10, 10, "Score: %d", game.score)
		case .Win:
			sdl3.RenderDebugTextFormat(r.ptr, 10, 40, "You Win!")
		case .Lose:
			sdl3.RenderDebugTextFormat(r.ptr, 10, 40, "Time's up. You Lose!")
		}
	}
}

// Draw debug visual feedback (screenshot indicator, etc.)
game_draw_debug_feedback :: proc(game: ^Game, r: ^SDL_Renderer) {
	// Update and draw capture feedback indicator
	if game.debug.capture_feedback_time > 0 {
		// Calculate fade: 1.0 at start, 0.0 at end
		fade := game.debug.capture_feedback_time / 2000.0

		// Red fades to grey: interpolate from (255, 0, 0) to (128, 128, 128)
		red := u8(128 + 127 * fade)
		green := u8(128 * (1.0 - fade))
		blue := u8(128 * (1.0 - fade))

		// Draw 16x16 square in bottom-right corner
		indicator_rect := sdl3.FRect {
			f32(RenderTargetSize.x) - 20, // 4px from right edge
			f32(RenderTargetSize.y) - 20, // 4px from bottom edge
			16,
			16,
		}

		sdl3.SetRenderDrawColor(r.ptr, red, green, blue, 255)
		sdl3.RenderFillRect(r.ptr, &indicator_rect)
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

	// when DEBUG_FRAME {log.debugf(
	// 		"Render tilemap tile {}: src: {}, dest: {}",
	// 		cmd.tile_idx,
	// 		src,
	// 		dst,
	// 	)}

	sdl3.RenderTexture(r.ptr, cmd.tilemap.texture, src, dst)
}

game_draw_animation :: proc(game: ^Game, r: ^SDL_Renderer, cmd: struct {
		anim:         SDL_Animation,
		dest:         sdl3.FRect,
		rotation_deg: f32,
		mirror_x:     bool,
	}) {
	elapsed_ms: u64 = game.frame_count
	frame := (elapsed_ms / cast(u64)cmd.anim.delay_ms) % cast(u64)len(cmd.anim.frame)
	// when DEBUG_FRAME {
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

	// Convert world offset to screen space
	screen_offset := camera_world_size_to_screen(
		&game.camera,
		cmd.anim.world_offset,
		Vec2{cast(f32)RenderTargetSize.x, cast(f32)RenderTargetSize.y},
	)

	dst_local := cmd.dest
	dst_local.x -= screen_offset.x
	dst_local.y -= screen_offset.y
	dst: Maybe(^sdl3.FRect) = &dst_local

	// when DEBUG_FRAME {log.debugf(
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
		cast(f64)cmd.rotation_deg,
		sdl3.FPoint{cast(f32)(cmd.dest.w / 2), cast(f32)(cmd.dest.h / 2)},
		.NONE if !cmd.mirror_x else .HORIZONTAL,
	)
}

game_draw_sprite :: proc(game: ^Game, r: ^SDL_Renderer, cmd: struct {
		sprite:       game_sprite,
		dest:         sdl3.FRect,
		rotation_deg: f32,
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

	// Convert world offset to screen space
	screen_offset := camera_world_size_to_screen(
		&game.camera,
		cmd.sprite.world_offset,
		Vec2{cast(f32)RenderTargetSize.x, cast(f32)RenderTargetSize.y},
	)

	dst_local := cmd.dest
	dst_local.x -= screen_offset.x
	dst_local.y -= screen_offset.y
	dst: Maybe(^sdl3.FRect) = &dst_local

	// when DEBUG_FRAME {log.debugf(
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
		cast(f64)cmd.rotation_deg,
		sdl3.FPoint{cast(f32)(cmd.dest.w / 2), cast(f32)(cmd.dest.h / 2)},
		.NONE if !cmd.mirror_x else .HORIZONTAL,
	)
}

game_entity_do_behavior :: proc(game: ^Game) {

	curr_time := cast(f64)game.frame_count * game.frame_step_ms

	for &e in game.entity_pool.entities {
		if !(.Is_Active in e.flags) {continue}

		when DEBUG_GAME {log.debugf("Updating entity: {}", e)}

		switch &v in e.variant {

		case Entity_Player:
			continue

		case Entity_Enemy:
			switch v.behavior.state {
			case .idle:
				when DEBUG_GAME {log.debugf("Enemy missile idle: {}", v.behavior)}
				if range_activated_missile_check_trigger(
					&v.behavior,
					{e.position.x, e.position.y},
					{game.entity.player.world_x, game.entity.player.world_y},
					curr_time,
				) {
					when DEBUG_FRAME {log.debug("Enemy missile triggered!")}
				}
			case .active:
				if range_activated_missile_is_lifetime_expired(
					v.behavior,
					cast(f64)game.frame_count * game.frame_step_ms,
				) {
					when DEBUG_FRAME {log.debug("Enemy missile lifetime expired!")}
					entity_pool_destroy_entity(&game.entity_pool, e)
					event_publish(
						&game.event_system,
						.EntityDestroyed,
						EventPayloadEntityDestroyed{e.id},
					)
					continue
				}

				next_pos := range_activated_missile_next_position(
					v.behavior,
					{e.position.x, e.position.y},
					{e.variant.(Entity_Enemy).velocity.x, e.variant.(Entity_Enemy).velocity.y},
					curr_time,
				)
				e.position.x, e.position.y = next_pos.x, next_pos.y
			}
		}
	}
}

game_update_timers :: proc(game: ^Game, sdl: ^SDL, asset: ^data.Asset_Manager) {
	game.timers.enemy_spawn_timer -= f32(game.frame_step_ms)

	#partial switch game.state {
	case .Win:
		game.timers.win_lose_reset_timer -= f32(game.frame_step_ms)
	case .Lose:
		game.timers.win_lose_reset_timer -= f32(game.frame_step_ms)
	}

	if game.timers.enemy_spawn_timer <= 0 {
		game.timers.enemy_spawn_timer += game.timers.enemy_spawn_interval

		// Spawn an enemy at a random position
		enemy_pos := Vec2 {
			lerp(game.level.playable_area.min.x, game.level.playable_area.max.x, rand.float32()),
			lerp(game.level.playable_area.min.y, game.level.playable_area.max.y, rand.float32()),
		}

		dst_to_player := vec2_dst(
			enemy_pos,
			Vec2{game.entity.player.world_x, game.entity.player.world_y},
		)

		if dst_to_player >= game.entity.enemy.behavior.cfg.trigger_radius * 1.1 {
			entity_pool_create_entity(
				&game.entity_pool,
				Entity {
					position = C_World_Position{enemy_pos.x, enemy_pos.y, 0},
					collision = C_World_Collision(
						AABB2 {
							min = Vec2{enemy_pos.x, enemy_pos.y},
							max = Vec2{enemy_pos.x + 64, enemy_pos.y + 64},
						},
					),
					sprite = C_Sprite {
						world_size   = Vec2{64, 64},
						// Center the sprite on the entity position
						world_offset = Vec2{32, 32},
					},
					variant = Entity_Enemy{behavior = {cfg = game.entity.enemy.behavior.cfg}},
				},
			)
		}
	}

	#partial switch game.state {
	case .Win:
		if game.timers.win_lose_reset_timer <= 0 {game_reset(game, sdl, asset, game.assets)}
	case .Lose:
		if game.timers.win_lose_reset_timer <= 0 {game_reset(game, sdl, asset, game.assets)}
	}
}

