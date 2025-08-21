package game

import "core:log"
import "vendor:wgpu"

sprite_batcher_shader_source := #load("sprite_batcher.wgsl", string)
sprite_batcher_label := "Sprite Batcher"

Sprite_Raw :: struct {
	position: Vec4,
	atlas_uv: Vec4,
	color:    Vec4,
	scale:    Vec2,
	atlas_id: u32,
}

Sprite_Batch :: []Sprite_Raw

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

Sprite_batcher_Uniform :: struct {
	view_projection: Mat4,
}

sprite_batcher_init :: proc(w: ^WGPU, s: ^Sprite_Batcher, cfg: struct {
		sprite_buffer_size: u64,
	} = {sprite_buffer_size = size_of(Sprite_Raw) * 1000}) {

	log.info("Initializing Sprite Batcher...")
	defer log.info("Sprite Batcher initialized.")

	assert(!s.initialized)
	defer s.initialized = true

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
					{binding = 0, buffer = s.uniform, size = size_of(Sprite_batcher_Uniform)},
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
					{binding = 0, visibility = {.Fragment}, texture = {sampleType = .Float}},
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
			vertex = wgpu.VertexState{module = s.shader},
			primitive = wgpu.PrimitiveState {
				topology = .TriangleStrip,
				frontFace = .CCW,
				cullMode = .None,
			},
			depthStencil = &wgpu.DepthStencilState{},
			multisample = {count = 1, mask = 0xFFFFFFFF},
			fragment = &wgpu.FragmentState {
				module = s.shader,
				targetCount = 1,
				targets = &wgpu.ColorTargetState {
					format = WGPU_Texture_Format_Default,
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

	s.uniform = wgpu.DeviceCreateBuffer(
		w.device,
		&wgpu.BufferDescriptor {
			label = sprite_batcher_label,
			size = size_of(Sprite_batcher_Uniform),
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

