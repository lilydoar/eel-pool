package game

import "core:log"
import "vendor:wgpu"

atlas_width: u32 = 4096
atlas_height: u32 = 4096
atlas_layers: u32 = 4

sprite_batcher_shader_source := #load("sprite_batcher.wgsl", string)
sprite_batcher_label := "Sprite Batcher"

Render :: struct {
	textures:       Texture_Repository,
	sprite_batcher: Sprite_Batcher,
	default:        struct {
		texture:         Texture,
		sampler:         wgpu.Sampler,
		view_projection: Mat4,
	},

	//
	render_pass:    RenderPass,
}

RenderPass :: struct {
	active:         bool,
	wgpu:           WGPU_RenderPass,
	sprite_batcher: Sprite_Batcher_RenderPass,
}

Sprite_Raw :: struct {
	position: Vec4, // rotation stored in radians in w component
	atlas_uv: Vec4,
	color:    Vec4,
	scale:    Vec2,
	atlas_id: u32,
}

Sprite_Batcher :: struct {
	initialized:       bool,
	shader:            wgpu.ShaderModule,
	bindgroup_layouts: struct {
		frame_data:  wgpu.BindGroupLayout, // uniform and sprites
		atlas_array: wgpu.BindGroupLayout,
	},
	bindgroups:        struct {
		frame_data: wgpu.BindGroup,
		// atlas_array is passed during render
	},
	pipeline_layout:   wgpu.PipelineLayout,
	pipeline:          wgpu.RenderPipeline,
	uniform:           wgpu.Buffer,
	sprites:           wgpu.Buffer,
}

Sprite_Batcher_RenderPass :: struct {
	atlas:   Texture,
	uniform: Sprite_Batcher_Uniform,
	batch:   [dynamic]Sprite_Raw,
	default: struct {
		sprite: Sprite_Raw,
	},
}

Sprite_Batcher_Uniform :: struct {
	view_projection: Mat4,
}

render_init :: proc(w: ^WGPU, r: ^Render) {
	log.info("Initializing Render...")
	defer log.info("Render initialized.")

	texture_repository_init(w, r, &r.textures)

	sprite_batcher_init(w, &r.sprite_batcher)

	r.default.texture.name = "default"
	r.default.texture.wgpu.format = w.default.texture_format

	r.default.texture.wgpu.texture = must(
		wgpu.DeviceCreateTexture(
			w.device,
			&wgpu.TextureDescriptor {
				label = "default",
				usage = {.CopyDst, .TextureBinding},
				dimension = ._2D,
				size = wgpu.Extent3D {
					width = atlas_width,
					height = atlas_height,
					depthOrArrayLayers = atlas_layers,
				},
				format = w.default.texture_format,
				mipLevelCount = 1,
				sampleCount = 1,
			},
		),
	)

	data: []u8 = {255, 255, 255, 255}
	when FRAME_DEBUG {log.debugf(
			"Writing white pixel data to texture: {} bytes at layer 0",
			len(data),
		)}

	wgpu.QueueWriteTexture(
		w.queue,
		&wgpu.TexelCopyTextureInfo {
			texture = r.default.texture.wgpu.texture,
			mipLevel = 0,
			origin = wgpu.Origin3D{x = 0, y = 0, z = 0},
			aspect = .All,
		},
		raw_data(data),
		len(data),
		&wgpu.TexelCopyBufferLayout{bytesPerRow = 4, rowsPerImage = 1},
		&wgpu.Extent3D{width = 1, height = 1, depthOrArrayLayers = 1},
	)
	when FRAME_DEBUG {log.debugf("Texture data written successfully to layer 0")}

	r.default.texture.wgpu.view = must(
		wgpu.TextureCreateView(
			r.default.texture.wgpu.texture,
			&wgpu.TextureViewDescriptor {
				label = r.default.texture.name,
				format = r.default.texture.wgpu.format,
				dimension = ._2DArray,
				mipLevelCount = 1,
				arrayLayerCount = 4,
				aspect = .All,
			},
		),
	)
	when FRAME_DEBUG {log.debugf(
			"Created texture view as 2D array with {} layers, format: {}",
			4,
			r.default.texture.wgpu.format,
		)}

	r.default.sampler = must(
		wgpu.DeviceCreateSampler(
			w.device,
			&wgpu.SamplerDescriptor {
				label = "default",
				addressModeU = .MirrorRepeat,
				addressModeV = .MirrorRepeat,
				addressModeW = .MirrorRepeat,
				magFilter = .Linear,
				minFilter = .Linear,
				mipmapFilter = .Nearest,
				maxAnisotropy = 1,
			},
		),
	)
	when FRAME_DEBUG {log.debugf("Created texture sampler")}

	// r.render_pass.sprite_batcher.atlas.bindgroup = must(
	r.default.texture.wgpu.bindgroup = must(
		wgpu.DeviceCreateBindGroup(
			w.device,
			&wgpu.BindGroupDescriptor {
				label = sprite_batcher_label,
				layout = r.sprite_batcher.bindgroup_layouts.atlas_array,
				entryCount = 2,
				entries = raw_data(
					[]wgpu.BindGroupEntry {
						{binding = 0, textureView = r.default.texture.wgpu.view},
						{binding = 1, sampler = r.default.sampler},
					},
				),
			},
		),
	)
	when FRAME_DEBUG {log.debugf(
			"Created bind group for texture array with view: {}, sampler: {}",
			r.default.texture.wgpu.view != nil,
			r.default.sampler != nil,
		)}

	r.default.view_projection = Mat4 {
		Vec4{1.0, 0.0, 0.0, 0.0},
		Vec4{0.0, 1.0, 0.0, 0.0},
		Vec4{0.0, 0.0, 1.0, 0.0},
		Vec4{0.0, 0.0, 0.0, 1.0},
	}

	r.render_pass.sprite_batcher.uniform = Sprite_Batcher_Uniform {
		view_projection = r.default.view_projection,
	}

	r.render_pass.sprite_batcher.atlas = r.default.texture

	r.render_pass.sprite_batcher.default.sprite = Sprite_Raw {
		position = Vec4{0.0, 0.0, 0.0, 1.0},
		atlas_uv = Vec4{0.0, 0.0, 1.0, 1.0},
		color    = Vec4{1.0, 1.0, 1.0, 1.0},
		scale    = Vec2{1.0, 1.0},
		atlas_id = 0,
	}

	when FRAME_DEBUG {
		log.debugf("Default texture before registration:")
		log.debugf("  - name: '{}'", r.default.texture.name)
		log.debugf("  - texture ptr: {}", r.default.texture.wgpu.texture != nil)
		log.debugf("  - format: {}", r.default.texture.wgpu.format)
		log.debugf("  - view ptr: {}", r.default.texture.wgpu.view != nil)
		log.debugf("  - bindgroup ptr: {}", r.default.texture.wgpu.bindgroup != nil)
	}
	texture_repository_register(&r.textures, r.default.texture.name, r.default.texture)
	when FRAME_DEBUG {log.debugf(
			"Registered default texture '{}' in repository",
			r.default.texture.name,
		)}
}

render_deinit :: proc(w: ^WGPU, r: ^Render) {
	log.info("Deinitializing Render...")
	defer log.info("Render deinitialized.")

	sprite_batcher_deinit(&r.sprite_batcher)

	texture_repository_deinit(&r.textures)

	wgpu.SamplerRelease(r.default.sampler)
	// wgpu.TextureViewRelease(r.default.texture_view)
	// wgpu.TextureRelease(r.default.texture)
}

renderpass_begin :: proc(w: ^WGPU, r: ^Render, window_size: Vec2i) {
	assert(w != nil)
	assert(r != nil)
	assert(!r.render_pass.active)

	when FRAME_DEBUG {log.debug("Beginning render pass...")}

	r.render_pass.wgpu.surface = wgpu.SurfaceGetCurrentTexture(w.surface)
	#partial switch r.render_pass.wgpu.surface.status {
	case .Timeout, .Outdated, .Lost:
		log.warnf("WebGPU: surface texture status: {}", r.render_pass.wgpu.surface.status)
		wgpu_resize(w, window_size)
		return
	case .OutOfMemory, .DeviceLost, .Error:
		log.error("WebGPU: surface texture status: {}", r.render_pass.wgpu.surface.status)
		if r.render_pass.wgpu.surface.texture != nil {
			wgpu.TextureRelease(r.render_pass.wgpu.surface.texture)
		}
		return
	}

	r.render_pass.wgpu.surface_view = wgpu.TextureCreateView(
		r.render_pass.wgpu.surface.texture,
		nil,
	)

	r.render_pass.wgpu.command_encoder = wgpu.DeviceCreateCommandEncoder(w.device, nil)

	r.render_pass.wgpu.render_encoder = wgpu.CommandEncoderBeginRenderPass(
		r.render_pass.wgpu.command_encoder,
		&wgpu.RenderPassDescriptor {
			colorAttachmentCount = 1,
			colorAttachments = &wgpu.RenderPassColorAttachment {
				view = r.render_pass.wgpu.surface_view,
				depthSlice = wgpu.DEPTH_SLICE_UNDEFINED,
				loadOp = .Clear,
				storeOp = .Store,
				clearValue = wgpu.Color{0.0, 0.0, 0.0, 1.0},
			},
		},
	)

	when FRAME_DEBUG {wgpu.RenderPassEncoderInsertDebugMarker(
			r.render_pass.wgpu.render_encoder,
			"begin",
		)}

	r.render_pass.active = true

	sprite_batcher_begin(w, r)

	return
}

renderpass_end :: proc(w: ^WGPU, r: ^Render) {
	when FRAME_DEBUG {
		log.debug("Ending render pass, submitting all draw calls...")
		defer log.debug("Render pass ended.")
		wgpu.RenderPassEncoderInsertDebugMarker(r.render_pass.wgpu.render_encoder, "end")
	}

	assert(w != nil)
	assert(r != nil)
	assert(r.render_pass.active)
	defer r.render_pass.active = false

	sprite_batcher_draw(w, r)

	// Submit
	wgpu.RenderPassEncoderEnd(r.render_pass.wgpu.render_encoder)
	wgpu.RenderPassEncoderRelease(r.render_pass.wgpu.render_encoder)

	cmd_buf := wgpu.CommandEncoderFinish(r.render_pass.wgpu.command_encoder, nil)
	wgpu.QueueSubmit(w.queue, {cmd_buf})
	wgpu.CommandEncoderRelease(r.render_pass.wgpu.command_encoder)

	wgpu.SurfacePresent(w.surface)

	wgpu.TextureViewRelease(r.render_pass.wgpu.surface_view)
	wgpu.TextureRelease(r.render_pass.wgpu.surface.texture)
}

sprite_batcher_init :: proc(w: ^WGPU, s: ^Sprite_Batcher, cfg: struct {
		sprite_buffer_size: u64,
	} = {sprite_buffer_size = size_of(Sprite_Raw) * 1000}) {

	log.info("Initializing Sprite Batcher...")
	defer log.info("Sprite Batcher initialized.")

	assert(!s.initialized)
	defer s.initialized = true

	s.uniform = must(
		wgpu.DeviceCreateBuffer(
			w.device,
			&wgpu.BufferDescriptor {
				label = sprite_batcher_label,
				size = size_of(Sprite_Batcher_Uniform),
				usage = {.CopyDst, .Vertex, .Uniform},
			},
		),
	)

	s.sprites = must(
		wgpu.DeviceCreateBuffer(
			w.device,
			&wgpu.BufferDescriptor {
				label = sprite_batcher_label,
				size = cfg.sprite_buffer_size,
				usage = {.CopyDst, .Vertex, .Storage},
			},
		),
	)

	s.bindgroup_layouts.frame_data = must(
		wgpu.DeviceCreateBindGroupLayout(
			w.device,
			&wgpu.BindGroupLayoutDescriptor {
				label = sprite_batcher_label,
				entryCount = 2,
				entries = raw_data(
					[]wgpu.BindGroupLayoutEntry {
						{binding = 0, visibility = {.Vertex}, buffer = {type = .Uniform}},
						{binding = 1, visibility = {.Vertex}, buffer = {type = .ReadOnlyStorage}},
					},
				),
			},
		),
	)

	s.bindgroups.frame_data = must(
		wgpu.DeviceCreateBindGroup(
			w.device,
			&wgpu.BindGroupDescriptor {
				label = sprite_batcher_label,
				layout = s.bindgroup_layouts.frame_data,
				entryCount = 2,
				entries = raw_data(
					[]wgpu.BindGroupEntry {
						{binding = 0, buffer = s.uniform, size = size_of(Sprite_Batcher_Uniform)},
						{binding = 1, buffer = s.sprites, size = cfg.sprite_buffer_size},
					},
				),
			},
		),
	)

	s.bindgroup_layouts.atlas_array = must(
		wgpu.DeviceCreateBindGroupLayout(
			w.device,
			&wgpu.BindGroupLayoutDescriptor {
				label = sprite_batcher_label,
				entryCount = 2,
				entries = raw_data(
					[]wgpu.BindGroupLayoutEntry {
						{
							binding = 0,
							visibility = {.Fragment},
							texture = {
								sampleType = .Float,
								viewDimension = ._2DArray,
								multisampled = false,
							},
						},
						{binding = 1, visibility = {.Fragment}, sampler = {type = .Filtering}},
					},
				),
			},
		),
	)

	s.shader = must(
		wgpu.DeviceCreateShaderModule(
			w.device,
			&wgpu.ShaderModuleDescriptor {
				label = sprite_batcher_label,
				nextInChain = &wgpu.ShaderSourceWGSL {
					sType = .ShaderSourceWGSL,
					code = sprite_batcher_shader_source,
				},
			},
		),
	)

	s.pipeline_layout = must(
		wgpu.DeviceCreatePipelineLayout(
			w.device,
			&wgpu.PipelineLayoutDescriptor {
				label = sprite_batcher_label,
				bindGroupLayoutCount = 2,
				bindGroupLayouts = raw_data(
					[]wgpu.BindGroupLayout {
						s.bindgroup_layouts.frame_data,
						s.bindgroup_layouts.atlas_array,
					},
				),
			},
		),
	)

	s.pipeline = must(
		wgpu.DeviceCreateRenderPipeline(
			w.device,
			&wgpu.RenderPipelineDescriptor {
				label = sprite_batcher_label,
				layout = s.pipeline_layout,
				vertex = wgpu.VertexState{module = s.shader, entryPoint = "vertex_main"},
				primitive = wgpu.PrimitiveState {
					topology = .TriangleStrip,
					frontFace = .CCW,
					cullMode = .None,
				},
				multisample = {count = 1, mask = 0xFFFFFFFF},
				fragment = &wgpu.FragmentState {
					module = s.shader,
					entryPoint = "fragment_main",
					targetCount = 1,
					targets = &wgpu.ColorTargetState {
						format = w.default.texture_format,
						blend = &wgpu.BlendState {
							color = {
								srcFactor = .SrcAlpha,
								dstFactor = .OneMinusSrcAlpha,
								operation = .Add,
							},
							alpha = {
								srcFactor = .One,
								dstFactor = .OneMinusSrcAlpha,
								operation = .Add,
							},
						},
						writeMask = wgpu.ColorWriteMaskFlags_All,
					},
				},
			},
		),
	)
}

sprite_batcher_deinit :: proc(s: ^Sprite_Batcher) {
	log.info("Deinitializing Sprite Batcher...")
	defer log.info("Sprite Batcher deinitialized.")

	assert(s.initialized)

	wgpu.BufferRelease(s.sprites)
	wgpu.BufferRelease(s.uniform)

	wgpu.RenderPipelineRelease(s.pipeline)
	wgpu.PipelineLayoutRelease(s.pipeline_layout)

	wgpu.BindGroupRelease(s.bindgroups.frame_data)
	wgpu.BindGroupLayoutRelease(s.bindgroup_layouts.atlas_array)
	wgpu.BindGroupLayoutRelease(s.bindgroup_layouts.frame_data)

	wgpu.ShaderModuleRelease(s.shader)
}

sprite_batcher_begin :: proc(w: ^WGPU, r: ^Render) {
	when FRAME_DEBUG {log.debug("Begin Sprite Batcher...")}

	assert(w != nil)
	assert(r != nil)
	assert(r.render_pass.active)
	assert(r.sprite_batcher.initialized)

	clear(&r.render_pass.sprite_batcher.batch)
}

sprite_batcher_append :: proc(r: ^RenderPass, sprite: Sprite_Raw) {
	assert(r != nil)
	assert(r.active)

	when FRAME_DEBUG {
		log.debugf("Appending sprite: {}", sprite)
	}

	append(&r.sprite_batcher.batch, sprite)
}

sprite_batcher_draw :: proc(w: ^WGPU, r: ^Render) {
	when FRAME_DEBUG {
		log.debug("Begin Sprite Batcher Draw...")
		defer log.debug("End Sprite Batcher Draw.")
	}

	s := r.sprite_batcher
	p := r.render_pass

	assert(w != nil)
	assert(r != nil)
	assert(s.initialized)

	sprite_count := len(p.sprite_batcher.batch)
	if sprite_count == 0 {return}

	when FRAME_DEBUG {
		log.debugf("Uniform: view_projection = {}", p.sprite_batcher.uniform.view_projection)

		log.debugf("Drawing {} sprites", sprite_count)

		truncate_at := 10
		idx := 0
		for s in p.sprite_batcher.batch {
			if idx >= truncate_at {log.debug("...");break}
			idx += 1
			log.debugf("{}. {}", idx, s)
		}
	}

	wgpu.QueueWriteBuffer(
		w.queue,
		s.uniform,
		0,
		&p.sprite_batcher.uniform,
		size_of(Sprite_Batcher_Uniform),
	)
	when FRAME_DEBUG {log.debugf(
			"Writing uniform buffer: {} bytes",
			size_of(Sprite_Batcher_Uniform),
		)}

	wgpu.QueueWriteBuffer(
		w.queue,
		s.sprites,
		0,
		&p.sprite_batcher.batch,
		cast(uint)(size_of(Sprite_Raw) * sprite_count),
	)
	when FRAME_DEBUG {log.debugf(
			"Writing sprite buffer: {} bytes ({} sprites)",
			size_of(Sprite_Raw) * sprite_count,
			sprite_count,
		)}

	when FRAME_DEBUG {log.debugf("Setting render pipeline: {}", s.pipeline != nil)}
	wgpu.RenderPassEncoderSetPipeline(p.wgpu.render_encoder, s.pipeline)
	when FRAME_DEBUG {log.debugf(
			"Setting bind group 0 (uniforms): {}",
			s.bindgroups.frame_data != nil,
		)}
	wgpu.RenderPassEncoderSetBindGroup(p.wgpu.render_encoder, 0, s.bindgroups.frame_data)

	when FRAME_DEBUG {
		log.debugf(
			"Setting bind group 1 (texture): bindgroup={}, atlas_name='{}'",
			p.sprite_batcher.atlas.wgpu.bindgroup != nil,
			p.sprite_batcher.atlas.name,
		)
		log.debugf(
			"Atlas texture details: texture={}, view={}, format={}",
			p.sprite_batcher.atlas.wgpu.texture != nil,
			p.sprite_batcher.atlas.wgpu.view != nil,
			p.sprite_batcher.atlas.wgpu.format,
		)
	}
	wgpu.RenderPassEncoderSetBindGroup(
		p.wgpu.render_encoder,
		1,
		p.sprite_batcher.atlas.wgpu.bindgroup,
	)

	when FRAME_DEBUG {log.debugf("Issuing draw call: {} vertices, {} instances", 4, sprite_count)}
	wgpu.RenderPassEncoderDraw(p.wgpu.render_encoder, 4, cast(u32)sprite_count, 0, 0)
	when FRAME_DEBUG {log.debugf("Draw call completed")}
}

