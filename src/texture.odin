package game

import "core:log"
import "vendor:wgpu"

// TODO: Handle into a texture directory
// register/deregister textures
Texture :: struct {
	name: string,
	wgpu: WGPU_Texture,
}

Texture_Repository :: struct {
	textures: map[string]Texture,
}

texture_repository_init :: proc(w: ^WGPU, r: ^Render, repo: ^Texture_Repository) {
	log.debug("Begin initializing texture repository")
	defer log.debugf("End initializing texture repository: {}", repo)

	repo.textures = map[string]Texture{}
}

texture_repository_deinit :: proc(repo: ^Texture_Repository) {
	delete(repo.textures)
}

texture_repository_register :: proc(repo: ^Texture_Repository, name: string, texture: Texture) {
	_, exists := repo.textures[name]
	if exists {
		log.warn("Texture already registered: %", name)
		return
	}
	repo.textures[name] = texture
	log.debugf("Registered texture: {}", name)
}

texture_repository_deregister :: proc(repo: ^Texture_Repository, name: string) {
	_, exists := repo.textures[name]
	if !exists {
		log.warn("Texture not found for deregistration: %", name)
		return
	}

	// TODO: Release texture resources

	delete_key(&repo.textures, name)
	log.debugf("Deregistered texture: {}", name)
}

// texture_repository_register_from_file :: proc(
// 	repo: ^Texture_Repository,
// 	name: string,
// 	filepath: string,
// 	w: ^WGPU,
// 	bindgroup_layout: wgpu.BindGroupLayout,
// ) -> Texture {
// 	_, exists := repo.textures[name]
// 	if exists {
// 		log.warn("Texture already registered: %", name)
// 		return repo.textures[name]
// 	}
//
// 	// TODO: Load texture from file
//
// 	texture := wgpu_create_texture_from_file(wgpu, filepath, bindgroup_layout)
// 	repo.textures[name] = texture
// 	return texture
// }

texture_repository_get :: proc(repo: ^Texture_Repository, name: string) -> Texture {
	texture, exists := repo.textures[name]
	if !exists {
		log.warn("Texture not found: %", name)
		return Texture{}
	}
	return texture
}

texture_repository_count :: proc(repo: ^Texture_Repository) -> int {
	return len(repo.textures)
}

