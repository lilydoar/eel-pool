package game

import "core:encoding/json"
import "core:log"
import os "core:os/os2"

data_sprites_path := "data/assets/sprites.json"

sprite_archer_arrow: game_sprite

sprites_init :: proc(s: ^SDL) {
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

	sprite_archer_arrow = asset_sprite_load(s, sprite_data["archer_arrow"])
}

sprites_deinit :: proc(s: ^SDL) {
	asset_sprite_unload(sprite_archer_arrow)
}

