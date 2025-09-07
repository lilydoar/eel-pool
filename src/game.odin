package game

import "base:runtime"
import "core:log"

import sdl3 "vendor:sdl3"

Game :: struct {
	ctx:           runtime.Context,
	frame_count:   u64,
	frame_step_ms: u64, // ms per game frame (fixed step)
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
		frame := game.frame_count % cast(u64)len(r.animations.player.idle.frame)

		clip: sdl3.Rect
		sdl3.GetSurfaceClipRect(r.animations.player.idle.frame[frame], &clip)

		src: Maybe(^sdl3.FRect) = &sdl3.FRect {
			cast(f32)clip.x,
			cast(f32)clip.y,
			cast(f32)clip.w,
			cast(f32)clip.h,
		}
		dst: Maybe(^sdl3.FRect) = &sdl3.FRect{0, cast(f32)clip.h, cast(f32)clip.w, cast(f32)clip.h}

		when FRAME_DEBUG {log.debugf(
				"Render {} frame {}: src: {}, dest: {}",
				r.animations.player.idle.name,
				frame,
				src,
				dst,
			)}
		sdl3.RenderTexture(r.ptr, r.animations.player.idle.texture, src, dst)
	}

	{
		// Draw run animation
		frame := game.frame_count % cast(u64)len(r.animations.player.run.frame)

		clip: sdl3.Rect
		sdl3.GetSurfaceClipRect(r.animations.player.run.frame[frame], &clip)

		src: Maybe(^sdl3.FRect) = &sdl3.FRect {
			cast(f32)clip.x,
			cast(f32)clip.y,
			cast(f32)clip.w,
			cast(f32)clip.h,
		}
		dst: Maybe(^sdl3.FRect) = &sdl3.FRect {
			0,
			cast(f32)clip.h * 2,
			cast(f32)clip.w,
			cast(f32)clip.h,
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

