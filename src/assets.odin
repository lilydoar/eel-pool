package game

import "core:encoding/json"
import "core:log"
import os "core:os/os2"

// Game_Assets holds all loaded sprite and animation resources.
// This struct lives in App (non-reloadable) to keep SDL texture pointers
// valid across hot-reloads of game code.
Game_Assets :: struct {
	// Animations
	animation_player_idle:    SDL_Animation,
	animation_player_run:     SDL_Animation,
	animation_player_dash:    SDL_Animation,
	animation_player_guard:   SDL_Animation,
	animation_player_attack1: SDL_Animation,
	animation_player_attack2: SDL_Animation,
	// Sprites
	sprite_archer_arrow:      Game_Sprite,
}

// Initialize all game assets (animations and sprites)
game_assets_init :: proc(assets: ^Game_Assets, s: ^SDL) {
	animations_init_into(assets, s)
	sprites_init_into(assets, s)
}

// Deinitialize all game assets
game_assets_deinit :: proc(assets: ^Game_Assets, s: ^SDL) {
	animations_deinit_from(assets, s)
	sprites_deinit_from(assets, s)
}

// Sprites Util Procs
data_sprites_path := "data/assets/sprites.json"

sprites_init_into :: proc(assets: ^Game_Assets, s: ^SDL) {
	log.debug("Loading sprites...")
	defer log.debug("Sprites loaded")

	bytes, err := os.read_entire_file_from_path(data_sprites_path, context.allocator)
	if err != nil {
		log.panicf("Failed to read sprite asset file: %v", err)
	}

	sprite_data_list: []asset_sprite
	if err := json.unmarshal(bytes, &sprite_data_list); err != nil {
		log.panicf("Failed to parse sprite asset file: %v", err)
	}

	sprite_data := make(map[string]asset_sprite)
	for anim in sprite_data_list {sprite_data[anim.name] = anim}

	assets.sprite_archer_arrow = asset_sprite_load(s, sprite_data["archer_arrow"])
}

sprites_deinit_from :: proc(assets: ^Game_Assets, s: ^SDL) {
	asset_sprite_unload(assets.sprite_archer_arrow)
}

// Animations Util Procs
data_animations_path := "data/assets/animations.json"

animations_init_into :: proc(assets: ^Game_Assets, s: ^SDL) {
	log.debug("Loading animations...")
	defer log.debug("Animations loaded")

	bytes, err := os.read_entire_file_from_path(data_animations_path, context.allocator)
	if err != nil {
		log.panicf("Failed to read animation asset file: %v", err)
	}

	animation_data_list: []asset_animation
	if err := json.unmarshal(bytes, &animation_data_list); err != nil {
		log.panicf("Failed to parse animation asset file: %v", err)
	}

	animation_data := make(map[string]asset_animation)
	for anim in animation_data_list {animation_data[anim.name] = anim}

	assets.animation_player_idle = asset_animation_load(s, animation_data["player_idle"])
	assets.animation_player_run = asset_animation_load(s, animation_data["player_run"])
	assets.animation_player_dash = asset_animation_load(s, animation_data["player_dash"])
	assets.animation_player_guard = asset_animation_load(s, animation_data["player_guard"])
	assets.animation_player_attack1 = asset_animation_load(s, animation_data["player_attack1"])
	assets.animation_player_attack2 = asset_animation_load(s, animation_data["player_attack2"])
}

animations_deinit_from :: proc(assets: ^Game_Assets, s: ^SDL) {
	log.debug("Unloading animations...")
	defer log.debug("Animations unloaded")

	asset_animation_unload(assets.animation_player_idle)
	asset_animation_unload(assets.animation_player_run)
	asset_animation_unload(assets.animation_player_dash)
	asset_animation_unload(assets.animation_player_guard)
	asset_animation_unload(assets.animation_player_attack1)
	asset_animation_unload(assets.animation_player_attack2)
}

