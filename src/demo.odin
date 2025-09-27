package game

import sdl3 "vendor:sdl3"

demo_draw_idle_atlas :: proc(game: ^Game, r: ^SDL_Renderer) {
	for frame in 0 ..< len(animation_player_idle.frame) {
		clip: sdl3.Rect
		sdl3.GetSurfaceClipRect(animation_player_idle.frame[frame], &clip)

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

		sdl3.RenderTexture(r.ptr, animation_player_idle.texture.texture, src, dst)
	}
}

demo_draw_player_animations :: proc(game: ^Game, r: ^SDL_Renderer) {
	game_draw_animation(game, r, {animation_player_idle, sdl3.FRect{0, 192, 192, 192}, false})
	game_draw_animation(game, r, {animation_player_run, sdl3.FRect{192, 192, 192, 192}, false})
	game_draw_animation(
		game,
		r,
		{animation_player_guard, sdl3.FRect{192 * 2, 192, 192, 192}, false},
	)
	game_draw_animation(
		game,
		r,
		{animation_player_attack1, sdl3.FRect{192 * 3, 192, 192, 192}, false},
	)
	game_draw_animation(
		game,
		r,
		{animation_player_attack2, sdl3.FRect{192 * 4, 192, 192, 192}, false},
	)
}

demo_draw_tilemap_atlas :: proc(game: ^Game, r: ^SDL_Renderer) {
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

