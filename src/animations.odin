package game

import "core:encoding/json"
import "core:log"
import os "core:os/os2"

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
	assets.animation_player_guard = asset_animation_load(s, animation_data["player_guard"])
	assets.animation_player_attack1 = asset_animation_load(s, animation_data["player_attack1"])
	assets.animation_player_attack2 = asset_animation_load(s, animation_data["player_attack2"])
}

animations_deinit_from :: proc(assets: ^Game_Assets, s: ^SDL) {
	log.debug("Unloading animations...")
	defer log.debug("Animations unloaded")

	asset_animation_unload(assets.animation_player_idle)
	asset_animation_unload(assets.animation_player_run)
	asset_animation_unload(assets.animation_player_guard)
	asset_animation_unload(assets.animation_player_attack1)
	asset_animation_unload(assets.animation_player_attack2)
}

