package game

import "core:log"
import "vendor:wgpu"

sprite_batcher_shader_source := #load("sprite_batcher.wgsl", string)
sprite_batcher_label := "Sprite Batcher"

Render :: struct {
	render_pass:    RenderPass,
	sprite_batcher: Sprite_Batcher,
}

RenderPass :: struct {
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
		// uniform and sprites
		frame_data:  wgpu.BindGroupLayout,
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

	assert(!r.sprite_batcher.initialized)
	defer r.sprite_batcher.initialized = true

	sprite_batcher_init(w, &r.sprite_batcher)
}

render_deinit :: proc(w: ^WGPU, r: ^Render) {
	log.info("Deinitializing Render...")
	defer log.info("Render deinitialized.")

	assert(r.sprite_batcher.initialized)

	sprite_batcher_deinit(&r.sprite_batcher)
}

renderpass_begin :: proc(w: ^WGPU, r: ^Render, pass: ^RenderPass, window_size: Vec2i) {
	assert(w != nil)

	when FRAME_DEBUG {log.debug("Beginning render pass...")}

	pass.wgpu.surface = wgpu.SurfaceGetCurrentTexture(w.surface)
	#partial switch pass.wgpu.surface.status {
	case .Timeout, .Outdated, .Lost:
		log.warnf("WebGPU: surface texture status: {}", pass.wgpu.surface.status)
		wgpu_resize(w, window_size)
		return
	case .OutOfMemory, .DeviceLost, .Error:
		log.error("WebGPU: surface texture status: {}", pass.wgpu.surface.status)
		pass.wgpu.surface = wgpu.SurfaceTexture{}
		return
	}

	render_pass := w.default.render_pass
	render_pass.colorAttachments[0].view = pass.wgpu.surface_view

	pass.wgpu.surface_view = wgpu.TextureCreateView(pass.wgpu.surface.texture, nil)
	pass.wgpu.command_encoder = wgpu.DeviceCreateCommandEncoder(w.device, nil)
	pass.wgpu.render_encoder = wgpu.CommandEncoderBeginRenderPass(
		pass.wgpu.command_encoder,
		&render_pass,
	)

	when FRAME_DEBUG {wgpu.RenderPassEncoderInsertDebugMarker(pass.wgpu.render_encoder, "begin")}

	return
}

renderpass_end :: proc(w: ^WGPU, r: ^Render, pass: ^RenderPass) {
	when FRAME_DEBUG {log.debug("Ending render pass...")}
	when FRAME_DEBUG {wgpu.RenderPassEncoderInsertDebugMarker(pass.wgpu.render_encoder, "end")}

	assert(w != nil)
	assert(r != nil)
	assert(pass != nil)

	sprite_batcher_draw(w, pass, &r.sprite_batcher)

	// Submit
	wgpu.RenderPassEncoderEnd(pass.wgpu.render_encoder)
	wgpu.RenderPassEncoderRelease(pass.wgpu.render_encoder)

	cmd_buf := wgpu.CommandEncoderFinish(pass.wgpu.command_encoder, nil)
	wgpu.QueueSubmit(w.queue, {cmd_buf})
	wgpu.CommandEncoderRelease(pass.wgpu.command_encoder)

	wgpu.SurfacePresent(w.surface)

	wgpu.TextureViewRelease(pass.wgpu.surface_view)
	wgpu.TextureRelease(pass.wgpu.surface.texture)
}

sprite_batcher_init :: proc(w: ^WGPU, s: ^Sprite_Batcher, cfg: struct {
		sprite_buffer_size: u64,
	} = {sprite_buffer_size = size_of(Sprite_Raw) * 1000}) {

	log.info("Initializing Sprite Batcher...")
	defer log.info("Sprite Batcher initialized.")

	assert(!s.initialized)
	defer s.initialized = true

	s.uniform = wgpu.DeviceCreateBuffer(
		w.device,
		&wgpu.BufferDescriptor {
			label = sprite_batcher_label,
			size = size_of(Sprite_Batcher_Uniform),
			usage = {.CopyDst, .Vertex, .Uniform},
		},
	)
	assert(s.uniform != nil, "Create uniform buffer for Sprite Batcher")

	s.sprites = wgpu.DeviceCreateBuffer(
		w.device,
		&wgpu.BufferDescriptor {
			label = sprite_batcher_label,
			size = cfg.sprite_buffer_size,
			usage = {.CopyDst, .Vertex, .Storage},
		},
	)
	assert(s.sprites != nil, "Create sprite buffer for Sprite Batcher")

	s.bindgroup_layouts.frame_data = wgpu.DeviceCreateBindGroupLayout(
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
	)
	assert(s.bindgroup_layouts.frame_data != nil, "Create bind group layout for Frame Data")

	s.bindgroups.frame_data = wgpu.DeviceCreateBindGroup(
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
	)
	assert(s.bindgroups.frame_data != nil, "Create bind group for Frame Data")

	s.bindgroup_layouts.atlas_array = wgpu.DeviceCreateBindGroupLayout(
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
	)
	assert(s.bindgroup_layouts.atlas_array != nil, "Create bind group layout for Atlas Array")

	s.shader = wgpu.DeviceCreateShaderModule(
		w.device,
		&wgpu.ShaderModuleDescriptor {
			label = sprite_batcher_label,
			nextInChain = &wgpu.ShaderSourceWGSL {
				sType = .ShaderSourceWGSL,
				code = sprite_batcher_shader_source,
			},
		},
	)
	assert(s.shader != nil, "Create shader module for Sprite Batcher")

	s.pipeline_layout = wgpu.DeviceCreatePipelineLayout(
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
	)
	assert(s.pipeline_layout != nil, "Create pipeline layout for Sprite Batcher")

	s.pipeline = wgpu.DeviceCreateRenderPipeline(
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
			depthStencil = &wgpu.DepthStencilState{format = w.default.depth_format},
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
	)
	assert(s.pipeline != nil, "Create render pipeline for Sprite Batcher")

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

sprite_batcher_draw :: proc(w: ^WGPU, r: ^RenderPass, s: ^Sprite_Batcher) {
	when FRAME_DEBUG {
		log.debug("Begin Sprite Batcher Draw...")
		defer log.debug("End Sprite Batcher Draw.")
	}

	assert(s.initialized)

	sprite_count := len(r.sprite_batcher.batch)
	if sprite_count == 0 {return}

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
		&r.sprite_batcher.batch,
		cast(uint)(size_of(Sprite_Raw) * sprite_count),
	)

	wgpu.RenderPassEncoderSetPipeline(r.wgpu.render_encoder, s.pipeline)
	wgpu.RenderPassEncoderSetBindGroup(r.wgpu.render_encoder, 0, s.bindgroups.frame_data)
	wgpu.RenderPassEncoderSetBindGroup(r.wgpu.render_encoder, 1, r.sprite_batcher.atlas_bindgroup)
	wgpu.RenderPassEncoderDraw(r.wgpu.render_encoder, 4, cast(u32)sprite_count, 0, 0)
}

