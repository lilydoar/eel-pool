package game

import "core:log"
import "vendor:sdl3"

asset_sprite :: struct {
	name:         string,
	path:         string,
	size:         Vec2u,
	world_offset: Vec2,
}

asset_animation :: struct {
	name:         string,
	path:         string,
	frame_count:  u32,
	delay_ms:     u32,
	size:         Vec2u,
	world_offset: Vec2,
}

asset_tilemap :: struct {
	name: string,
	path: string,
	size: Vec2u,
}

asset_animation_load :: proc(s: ^SDL, a: asset_animation) -> (anim: SDL_Animation) {
	log.debugf("Loading animation: {}", a.name)
	defer log.debugf("Animation loaded: {}", a)

	assert(len(a.name) > 0)
	assert(len(a.path) > 0)
	assert(a.frame_count > 0)
	assert(a.size.x > 0)
	assert(a.size.y > 0)

	anim.name = a.name
	anim.texture = sdl_texture_load(&s.renderer, a.path, a.name)
	anim.frame = make([]^sdl3.Surface, a.frame_count)
	anim.delay_ms = a.delay_ms
	anim.world_offset = a.world_offset

	for idx in 0 ..< a.frame_count {
		rect: Maybe(^sdl3.Rect) = &sdl3.Rect {
			cast(i32)a.size.x * cast(i32)idx,
			0,
			cast(i32)a.size.x,
			cast(i32)a.size.y,
		}
		frame := sdl3.DuplicateSurface(anim.texture.surface)
		sdl3.SetSurfaceClipRect(frame, rect)
		anim.frame[idx] = frame
	}

	return anim
}

asset_animation_unload :: proc(a: SDL_Animation) {
	log.debugf("Unloading animation: {}", a.name)

	for frame in a.frame {sdl3.DestroySurface(frame)}
	sdl3.DestroyTexture(a.texture.texture)
}

asset_sprite_load :: proc(s: ^SDL, sprite: asset_sprite) -> (spr: game_sprite) {
	log.debugf("Loading sprite: {}", sprite.name)
	defer log.debugf("Sprite loaded: {}", sprite.name)

	assert(len(sprite.name) > 0)
	assert(len(sprite.path) > 0)

	spr.texture = sdl_texture_load(&s.renderer, sprite.path, sprite.name)
	spr.world_offset = sprite.world_offset
	return spr
}

asset_sprite_unload :: proc(sprite: game_sprite) {
	log.debugf("Unloading sprite {}", sprite.texture.name)
	sdl3.DestroyTexture(sprite.texture.texture)
}

