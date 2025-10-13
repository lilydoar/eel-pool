package game

import "core:encoding/json"
import "core:log"
import os "core:os/os2"

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

