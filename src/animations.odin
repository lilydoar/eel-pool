package game

import "core:encoding/json"
import "core:log"
import os "core:os/os2"

data_animations_path := "data/assets/animations.json"

animation_player_idle: SDL_Animation
animation_player_run: SDL_Animation
animation_player_guard: SDL_Animation
animation_player_attack1: SDL_Animation
animation_player_attack2: SDL_Animation

animations_init :: proc(s: ^SDL) {
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

	animation_player_idle = asset_animation_load(s, animation_data["player_idle"])
	animation_player_run = asset_animation_load(s, animation_data["player_run"])
	animation_player_guard = asset_animation_load(s, animation_data["player_guard"])
	animation_player_attack1 = asset_animation_load(s, animation_data["player_attack1"])
	animation_player_attack2 = asset_animation_load(s, animation_data["player_attack2"])
}

animations_deinit :: proc(s: ^SDL) {
	log.debug("Unloading animations...")
	defer log.debug("Animations unloaded")

	asset_animation_unload(animation_player_idle)
	asset_animation_unload(animation_player_run)
	asset_animation_unload(animation_player_guard)
	asset_animation_unload(animation_player_attack1)
	asset_animation_unload(animation_player_attack2)
}

