package game

// Game_Assets holds all loaded sprite and animation resources.
// This struct lives in App (non-reloadable) to keep SDL texture pointers
// valid across hot-reloads of game code.
Game_Assets :: struct {
	// Animations
	animation_player_idle:    SDL_Animation,
	animation_player_run:     SDL_Animation,
	animation_player_guard:   SDL_Animation,
	animation_player_attack1: SDL_Animation,
	animation_player_attack2: SDL_Animation,
	// Sprites
	sprite_archer_arrow:      game_sprite,
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
