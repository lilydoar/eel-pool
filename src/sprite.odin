package game

import "core:log"
import "vendor:wgpu"

SPRITE_BATCH_SHADER_SRC := #load("sprite_batch_shader.wgsl", string)

SPRITE_BATCH_SHADER_LABEL := "sprite_batch_shader"
SPRITE_BATCH_BUFFER_LABEL := "sprite_batch_buffer"
SPRITE_BATCH_PIPELINE_LABEL := "sprite_batch_pipeline"
SPRITE_BATCH_PIPELINE_LAYOUT_LABEL := "sprite_batch_pipeline_layout"
SPRITE_BATCH_FRAME_DATA_BGL_LABEL := "sprite_batch_frame_data_bgl"
SPRITE_BATCH_ATLAS_ARRAY_BGL_LABEL := "sprite_batch_atlas_array_bgl"

SPRITE_BATCH_VERTEX_ENTRY_POINT := "vertex_main"
SPRITE_BATCH_FRAGMENT_ENTRY_POINT := "fs_main"

SPRITE_BATCH_DEFAULT_BUFFER_SIZE :: size_of(Sprite_Raw) * 2048

Sprite_Raw :: struct {
	position: Vec4,
	atlas_uv: Vec4,
	color:    Vec4,
	scale:    Vec2,
	atlas_id: u32,
}

Sprite_Batch :: []Sprite_Raw

Sprite_Batcher :: struct {
	initialized:        bool,
	desc:               SpriteBatcher_Desc,
	shader:             wgpu.ShaderModule,
	buffer:             wgpu.Buffer,
	// atlas:              wgpu.Texture,
	pipeline:           wgpu.RenderPipeline,
	pipeline_layout:    wgpu.PipelineLayout,
	bind_groups:        [2]wgpu.BindGroup, // [0]=frame_data, [1]=atlas_array
	bind_group_layouts: [2]wgpu.BindGroupLayout, // [0]=frame_data, [1]=atlas_array
}

SpriteBatcher_Desc :: struct {
	shader:              wgpu.ShaderModuleDescriptor,
	shader_source:       wgpu.ShaderSourceWGSL, // Persistent storage for shader source
	buffer:              wgpu.BufferDescriptor,
	pipeline:            wgpu.RenderPipelineDescriptor,
	pipeline_layout:     wgpu.PipelineLayoutDescriptor,
	frame_data_bgl:      wgpu.BindGroupLayoutDescriptor,
	frame_data_entries:  [2]wgpu.BindGroupLayoutEntry,
	atlas_array_bgl:     wgpu.BindGroupLayoutDescriptor,
	atlas_array_entries: [2]wgpu.BindGroupLayoutEntry,
	// Persistent storage for pipeline fragment state
	blend_state:         wgpu.BlendState,
	color_target_state:  wgpu.ColorTargetState,
	fragment_state:      wgpu.FragmentState,
	// atlas:                []Texture,
}

SpriteBatcher_Options :: struct {
	buffer_size: u64,
}

SpriteBatcherDescriptor_Default :: proc() -> (sb: SpriteBatcher_Desc) {
	sb = SpriteBatcher_Desc {
		shader_source = wgpu.ShaderSourceWGSL {
			sType = .ShaderSourceWGSL,
			code = SPRITE_BATCH_SHADER_SRC,
		},
		shader = wgpu.ShaderModuleDescriptor {
			label = SPRITE_BATCH_SHADER_LABEL,
			// nextInChain: Set during init to point to shader_source
		},
		buffer = wgpu.BufferDescriptor {
			label = SPRITE_BATCH_BUFFER_LABEL,
			usage = {.Storage, .CopyDst},
			size = SPRITE_BATCH_DEFAULT_BUFFER_SIZE,
		},
		pipeline = wgpu.RenderPipelineDescriptor {
			label = SPRITE_BATCH_PIPELINE_LABEL,
			// layout: Set during init after pipeline_layout is created
			vertex = wgpu.VertexState {
				// module: Set during init after shader module is created
				entryPoint = SPRITE_BATCH_VERTEX_ENTRY_POINT,
			},
			// fragment: Set during init to point to fragment_state
			primitive = wgpu.PrimitiveState {
				topology = .TriangleList,
				frontFace = .CCW,
				cullMode = .None,
			},
			multisample = wgpu.MultisampleState{count = 1, mask = 0xFFFFFFFF},
		},
		// Configure persistent blend and color target states
		blend_state = wgpu.BlendState {
			color = {srcFactor = .SrcAlpha, dstFactor = .OneMinusSrcAlpha, operation = .Add},
			alpha = {srcFactor = .One, dstFactor = .OneMinusSrcAlpha, operation = .Add},
		},
		color_target_state = wgpu.ColorTargetState {
			// format: Set during init from surface configuration
			// blend: Set during init to point to blend_state
			writeMask = wgpu.ColorWriteMaskFlags_All,
		},
		fragment_state = wgpu.FragmentState {
			// module: Set during init after shader module is created
			entryPoint  = SPRITE_BATCH_FRAGMENT_ENTRY_POINT,
			targetCount = 1,
			// targets: Set during init to point to color_target_state
		},
		pipeline_layout = wgpu.PipelineLayoutDescriptor {
			label                = SPRITE_BATCH_PIPELINE_LAYOUT_LABEL,
			bindGroupLayoutCount = 2,
			// bindGroupLayouts: Set during init after bind group layouts are created
		},
		frame_data_bgl = wgpu.BindGroupLayoutDescriptor {
			label      = SPRITE_BATCH_FRAME_DATA_BGL_LABEL,
			entryCount = 2,
			// entries: Set during init to point to frame_data_entries
		},
		atlas_array_bgl = wgpu.BindGroupLayoutDescriptor {
			label      = SPRITE_BATCH_ATLAS_ARRAY_BGL_LABEL,
			entryCount = 2,
			// entries: Set during init to point to atlas_array_entries
		},
		frame_data_entries = {
			wgpu.BindGroupLayoutEntry {
				binding = 0,
				visibility = {.Vertex},
				buffer = {type = .Uniform, hasDynamicOffset = false},
			},
			wgpu.BindGroupLayoutEntry {
				binding = 1,
				visibility = {.Vertex},
				buffer = {type = .ReadOnlyStorage, hasDynamicOffset = false},
			},
		},
		atlas_array_entries = {
			wgpu.BindGroupLayoutEntry {
				binding = 0,
				visibility = {.Fragment},
				texture = {sampleType = .Float, viewDimension = ._2DArray},
			},
			wgpu.BindGroupLayoutEntry {
				binding = 1,
				visibility = {.Fragment},
				sampler = {type = .Filtering},
			},
		},
	}
	return
}

sprite_batcher_init :: proc(w: ^WGPU, sb: ^Sprite_Batcher) {
	log.info("Initializing SpriteBatcher...")
	defer log.info("SpriteBatcher initialized")

	when VERBOSE_LOGGING {log.infof("Sprite Batch Shader Source:\n{}", SPRITE_BATCH_SHADER_SRC)}

	assert(len(SPRITE_BATCH_SHADER_SRC) > 0)

	assert(!sb.initialized)
	defer sb.initialized = true

	log.info("Creating descriptor...")
	sb.desc = SpriteBatcherDescriptor_Default()
	log.info("Descriptor created successfully")

	// Create shader module with persistent shader source reference
	log.info("Creating shader module...")
	sb.desc.shader.nextInChain = &sb.desc.shader_source
	sb.shader = wgpu.DeviceCreateShaderModule(w.device, &sb.desc.shader)
	wgpu_panic(sb.shader != nil, "create sprite batch shader module")
	log.info("Shader module created successfully")

	// Create sprite data buffer
	sb.buffer = wgpu.DeviceCreateBuffer(w.device, &sb.desc.buffer)
	wgpu_panic(sb.buffer != nil, "create sprite batch buffer")

	// Create bind group layouts with persistent entry pointers
	sb.desc.frame_data_bgl.entries = raw_data(sb.desc.frame_data_entries[:])
	sb.bind_group_layouts[0] = wgpu.DeviceCreateBindGroupLayout(w.device, &sb.desc.frame_data_bgl)
	wgpu_panic(sb.bind_group_layouts[0] != nil, "create frame data bind group layout")

	sb.desc.atlas_array_bgl.entries = raw_data(sb.desc.atlas_array_entries[:])
	sb.bind_group_layouts[1] = wgpu.DeviceCreateBindGroupLayout(w.device, &sb.desc.atlas_array_bgl)
	wgpu_panic(sb.bind_group_layouts[1] != nil, "create atlas array bind group layout")

	// Create pipeline layout using persistent bind group layout array
	sb.desc.pipeline_layout.bindGroupLayouts = raw_data(sb.bind_group_layouts[:])
	sb.pipeline_layout = wgpu.DeviceCreatePipelineLayout(w.device, &sb.desc.pipeline_layout)
	wgpu_panic(sb.pipeline_layout != nil, "create sprite batch pipeline layout")

	// Update pipeline descriptor with persistent references
	sb.desc.pipeline.layout = sb.pipeline_layout
	sb.desc.pipeline.vertex.module = sb.shader
	sb.desc.color_target_state.format = .BGRA8Unorm // TODO: Get from surface configuration
	sb.desc.color_target_state.blend = &sb.desc.blend_state
	sb.desc.fragment_state.module = sb.shader
	sb.desc.fragment_state.targets = &sb.desc.color_target_state
	sb.desc.pipeline.fragment = &sb.desc.fragment_state

	// Create render pipeline 
	sb.pipeline = wgpu.DeviceCreateRenderPipeline(w.device, &sb.desc.pipeline)
	wgpu_panic(sb.pipeline != nil, "create sprite batch render pipeline")

	// TODO: Create bind groups after uniform buffer and texture resources are available
	// sb.frame_data_bg = wgpu.DeviceCreateBindGroup(...)
	// sb.atlas_array_bg = wgpu.DeviceCreateBindGroup(...)
}

sprite_batcher_deinit :: proc(sb: ^Sprite_Batcher) {
	log.info("Deinitializing SpriteBatcher...")
	defer log.info("Deinitialized SpriteBatcher...")

	assert(sb.initialized)
	defer sb.initialized = false

	wgpu.RenderPipelineRelease(sb.pipeline)
	wgpu.PipelineLayoutRelease(sb.pipeline_layout)
	// TODO: Only release bind groups when they are created
	// wgpu.BindGroupRelease(sb.bind_groups[1]) // atlas_array
	// wgpu.BindGroupRelease(sb.bind_groups[0]) // frame_data
	wgpu.BindGroupLayoutRelease(sb.bind_group_layouts[1]) // atlas_array
	wgpu.BindGroupLayoutRelease(sb.bind_group_layouts[0]) // frame_data
	wgpu.BufferRelease(sb.buffer)
	wgpu.ShaderModuleRelease(sb.shader)
}

