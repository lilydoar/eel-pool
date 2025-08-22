package game

import "core:log"
import "vendor:wgpu"

sprite_batcher_shader_source := #load("sprite_batcher.wgsl", string)
sprite_batcher_label := "Sprite Batcher"

Render :: struct {
	sprite_batcher: Sprite_Batcher,
	default:        struct {
		texture:      wgpu.Texture,
		texture_view: wgpu.TextureView,
		sampler:      wgpu.Sampler,
		sprite:       Sprite_Raw,
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
	position: Vec4,
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
	atlas_bindgroup: wgpu.BindGroup,
	uniform:         Sprite_Batcher_Uniform,
	batch:           [dynamic]Sprite_Raw,
}

Sprite_Batcher_Uniform :: struct {
	view_projection: Mat4,
}

render_init :: proc(w: ^WGPU, r: ^Render) {
	log.info("Initializing Render...")
	defer log.info("Render initialized.")

	sprite_batcher_init(w, &r.sprite_batcher)

	r.default.sprite = Sprite_Raw {
		position = Vec4{0.0, 0.0, 0.0, 1.0},
		atlas_uv = Vec4{0.0, 0.0, 1.0, 1.0},
		color    = Vec4{1.0, 1.0, 1.0, 1.0},
		scale    = Vec2{1.0, 1.0},
		atlas_id = 0,
	}

	r.default.texture = must(
		wgpu.DeviceCreateTexture(
			w.device,
			&wgpu.TextureDescriptor {
				label = "default",
				usage = {.CopyDst, .TextureBinding},
				dimension = ._2D,
				size = wgpu.Extent3D{width = 1, height = 1, depthOrArrayLayers = 1},
				format = w.default.texture_format,
				mipLevelCount = 1,
				sampleCount = 1,
			},
		),
	)

	r.default.texture_view = must(
		wgpu.TextureCreateView(
			r.default.texture,
			&wgpu.TextureViewDescriptor {
				label = "default",
				format = w.default.texture_format,
				dimension = ._2DArray,
				mipLevelCount = 1,
				arrayLayerCount = 1,
				aspect = .All,
				usage = {.CopyDst, .TextureBinding},
			},
		),
	)

	r.default.sampler = must(
		wgpu.DeviceCreateSampler(
			w.device,
			&wgpu.SamplerDescriptor {
				label = "default",
				addressModeU = .Repeat,
				addressModeV = .Repeat,
				addressModeW = .Repeat,
				magFilter = .Linear,
				minFilter = .Linear,
				mipmapFilter = .Nearest,
				maxAnisotropy = 1,
			},
		),
	)


	r.render_pass.sprite_batcher.atlas_bindgroup = must(
		wgpu.DeviceCreateBindGroup(
			w.device,
			&wgpu.BindGroupDescriptor {
				label = sprite_batcher_label,
				layout = r.sprite_batcher.bindgroup_layouts.atlas_array,
				entryCount = 2,
				entries = raw_data(
					[]wgpu.BindGroupEntry {
						{binding = 0, textureView = r.default.texture_view},
						{binding = 1, sampler = r.default.sampler},
					},
				),
			},
		),
	)

	r.render_pass.sprite_batcher.uniform = Sprite_Batcher_Uniform {
		view_projection = Mat4 {
			Vec4{1.0, 0.0, 0.0, 0.0},
			Vec4{0.0, 1.0, 0.0, 0.0},
			Vec4{0.0, 0.0, 1.0, 0.0},
			Vec4{0.0, 0.0, 0.0, 1.0},
		},
	}
}

render_deinit :: proc(w: ^WGPU, r: ^Render) {
	log.info("Deinitializing Render...")
	defer log.info("Render deinitialized.")

	sprite_batcher_deinit(&r.sprite_batcher)

	wgpu.SamplerRelease(r.default.sampler)
	wgpu.TextureViewRelease(r.default.texture_view)
	wgpu.TextureRelease(r.default.texture)
}

renderpass_begin :: proc(w: ^WGPU, r: ^Render, window_size: Vec2i) {
	assert(w != nil)
	assert(r != nil)
	assert(!r.render_pass.active)
	defer r.render_pass.active = true

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

	return
}

renderpass_end :: proc(w: ^WGPU, r: ^Render) {
	when FRAME_DEBUG {
		log.debug("Ending render pass...")
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
							texture = {sampleType = .Float, viewDimension = ._2DArray},
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

	log.debugf("Drawing {} sprites", sprite_count)

	wgpu.QueueWriteBuffer(
		w.queue,
		s.uniform,
		0,
		&r.sprite_batcher.uniform,
		size_of(Sprite_Batcher_Uniform),
	)

	wgpu.QueueWriteBuffer(
		w.queue,
		s.sprites,
		0,
		&p.sprite_batcher.batch,
		cast(uint)(size_of(Sprite_Raw) * sprite_count),
	)

	wgpu.RenderPassEncoderSetPipeline(p.wgpu.render_encoder, s.pipeline)
	wgpu.RenderPassEncoderSetBindGroup(p.wgpu.render_encoder, 0, s.bindgroups.frame_data)
	wgpu.RenderPassEncoderSetBindGroup(p.wgpu.render_encoder, 1, p.sprite_batcher.atlas_bindgroup)
	wgpu.RenderPassEncoderDraw(p.wgpu.render_encoder, 4, cast(u32)sprite_count, 0, 0)

	clear(&r.render_pass.sprite_batcher.batch)
}

