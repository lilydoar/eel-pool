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
	textures:          map[string]Texture,
	bind_group_layout: wgpu.BindGroupLayout,
}

texture_repository_init :: proc(w: ^WGPU, r: ^Render, repo: ^Texture_Repository) {
	log.debug("Begin initializing texture repository")
	defer log.debugf("End initializing texture repository: {}", repo)

	repo.textures = map[string]Texture{}

	// TODO: Move the creation of the default texture into the Render init
	// Then just register that here
	// Load the default white texture into the repository
	{
		t: Texture
		t.name = "default"
		t.wgpu.texture = must(
			wgpu.DeviceCreateTexture(
				w.device,
				&wgpu.TextureDescriptor {
					label = t.name,
					usage = {.CopyDst, .TextureBinding},
					dimension = ._2D,
					size = {1, 1, 1},
					format = w.default.texture_format,
					mipLevelCount = 1,
					sampleCount = 1,
				},
			),
		)

		t.wgpu.view = must(
			wgpu.TextureCreateView(
				t.wgpu.texture,
				&wgpu.TextureViewDescriptor {
					label = "default",
					format = w.default.texture_format,
					dimension = ._2DArray,
					mipLevelCount = 1,
					arrayLayerCount = 1,
					aspect = .All,
				},
			),
		)

		t.wgpu.bindgroup = must(
			wgpu.DeviceCreateBindGroup(
				w.device,
				&wgpu.BindGroupDescriptor {
					label = t.name,
					layout = w.default.texture_bind_group_layout,
					entryCount = 2,
					entries = raw_data(
						[]wgpu.BindGroupEntry {
							{binding = 0, textureView = t.wgpu.view},
							{binding = 1, sampler = r.default.sampler},
						},
					),
				},
			),
		)

		data: []u8 = {255, 255, 255, 255}

		wgpu.QueueWriteTexture(
			w.queue,
			&wgpu.TexelCopyTextureInfo{texture = t.wgpu.texture, aspect = .All, mipLevel = 0},
			raw_data(data),
			len(data),
			&wgpu.TexelCopyBufferLayout{bytesPerRow = 4, rowsPerImage = 1},
			&wgpu.Extent3D{width = 1, height = 1, depthOrArrayLayers = 1},
		)

		texture_repository_register(repo, t.name, t)
	}
}

texture_repository_deinit :: proc(repo: ^Texture_Repository) {
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

