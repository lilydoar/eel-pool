package game

import "core:log"
import "vendor:wgpu"

sprite_shader_source :: `
struct SpriteData {
	position: vec4<f32>, // Storing rotation in the w component
	tex_coords: vec4<f32>,
	color: vec4<f32>,
	scale: vec2<f32>,
	tex_idx: u32,
	_padding: f32,
}

struct Uniforms {
	view_proj: mat4x4<f32>,
}

struct VertexOutput {
	@builtin(position) position: vec4<f32>,
	@location(0) color: vec4<f32>,
	@location(1) tex_coord: vec2<f32>,
	@location(2) tex_index: u32,
}

const QUAD_VERTICES = array<vec2<f32>, 4>(
vec2<f32>(0.0, 1.0),  // 0: Bottom-left
vec2<f32>(1.0, 1.0),  // 1: Bottom-right
vec2<f32>(0.0, 0.0),  // 2: Top-left
vec2<f32>(1.0, 0.0),  // 3: Top-right
);

const QUAD_UVS = array<vec2<f32>, 4>(
vec2<f32>(0.0, 1.0),  // 0: Bottom-left UV
vec2<f32>(1.0, 1.0),  // 1: Bottom-right UV
vec2<f32>(0.0, 0.0),  // 2: Top-left UV
vec2<f32>(1.0, 0.0),  // 3: Top-right UV
);

@group(0) @binding(0) var<storage, read> sprites: array<SpriteData>;
@group(1) @binding(0) var<uniform> uniforms: Uniforms;
@group(2) @binding(0) var atlas_texture_array: texture_2d_array<f32>;
@group(2) @binding(1) var atlas_texture_sampler: sampler;

@vertex
fn vs_main(@builtin(vertex_index) vertex_id: u32, @builtin(instance_index) instance_id: u32) -> VertexOutput {
	let sprite_id = instance_id;
	let corner_id = vertex_id;

	let sprite = sprites[sprite_id];

	// Lookup vertex data from constant arrays
	let vertex_pos = QUAD_VERTICES[corner_id];
	let vertex_uv = QUAD_UVS[corner_id];

	// Build 2D transformation matrix
	let rotation = sprite.position.w;
	let cos_r = cos(rotation);
	let sin_r = sin(rotation);

	// Transform: scale, rotate, then translate
	let centered_pos = (vertex_pos - 0.5) * sprite.scale;
	let rotated = vec2<f32>(
		centered_pos.x * cos_r - centered_pos.y * sin_r,
		centered_pos.x * sin_r + centered_pos.y * cos_r
	);
	let world_pos = vec3<f32>(sprite.position.xy + rotated, sprite.position.z);

	// Apply view-projection matrix
	let clip_pos = uniforms.view_proj * vec4<f32>(world_pos, 1.0);

	// Map UVs to sprite's texture rectangle
	let tex_coord = mix(
		sprite.tex_coords.xy,
		sprite.tex_coords.zw,
		vertex_uv
	);

	var out: VertexOutput;
	out.position = clip_pos;
	out.color = sprite.color;
	out.tex_coord = tex_coord;
	out.tex_index = sprite.tex_idx;
	return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
	let tex_color = textureSample(atlas_texture_array, atlas_texture_sampler, in.tex_coord, i32(in.tex_index));
	return tex_color * in.color;
}
`


SpriteData :: struct {
	// Using w component of position for rotation in radians
	position:   [4]f32,
	tex_coords: [4]f32,
	color:      [4]f32,
	scale:      [2]f32,
	tex_idx:    u32,
	_padding:   f32,
}

Uniforms :: struct {
	view_proj: [16]f32,
}

MAX_SPRITES :: 2048
MAX_ATLAS_TEXTURES :: 4

// TODO: Set this to max atlas size something like 4096x4096
ATLAS_SIZE :: 1

SpriteBatcher :: struct {
	shader:                        wgpu.ShaderModule,
	data_buf:                      wgpu.Buffer,
	uniform_buf:                   wgpu.Buffer,
	bind_group_layout_storage_buf: wgpu.BindGroupLayout,
	bind_group_layout_uniform_buf: wgpu.BindGroupLayout,
	bind_group_layout_atlas_array: wgpu.BindGroupLayout,
	bind_group_storage_buf:        wgpu.BindGroup,
	bind_group_uniform_buf:        wgpu.BindGroup,
	bind_group_atlas_array:        wgpu.BindGroup,
	pipeline_layout:               wgpu.PipelineLayout,
	pipeline:                      wgpu.RenderPipeline,
	atlas_texture:                 wgpu.Texture,
	atlas_view:                    wgpu.TextureView,
	atlas_sampler:                 wgpu.Sampler,
	sprites:                       [dynamic]SpriteData,
}

sprite_batcher: SpriteBatcher

sprite_batcher_init :: proc() -> bool {
	log.info("Initializing SpriteBatcher...")

	// Create shader module
	sprite_shader_desc: wgpu.ShaderModuleDescriptor = wgpu.ShaderModuleDescriptor {
		label       = "Sprite Shader Module",
		nextInChain = &wgpu.ShaderSourceWGSL {
			sType = .ShaderSourceWGSL,
			code = sprite_shader_source,
		},
	}
	sprite_batcher.shader = wgpu.DeviceCreateShaderModule(app.wgpu.device, &sprite_shader_desc)

	// Create data buffers 
	sprite_buf_desc: wgpu.BufferDescriptor = wgpu.BufferDescriptor {
		label = "Sprite Data Buffer",
		usage = {.Storage, .CopyDst},
		size  = cast(u64)(size_of(SpriteData) * MAX_SPRITES),
	}
	sprite_batcher.data_buf = wgpu.DeviceCreateBuffer(app.wgpu.device, &sprite_buf_desc)

	uniform_buf_desc := wgpu.BufferDescriptor {
		label = "Uniform Buffer",
		usage = {.Uniform, .CopyDst},
		size  = size_of(Uniforms),
	}
	sprite_batcher.uniform_buf = wgpu.DeviceCreateBuffer(app.wgpu.device, &uniform_buf_desc)

	// Create atlas texture, view, and sampler
	texture_desc := wgpu.TextureDescriptor {
		label         = "Sprite Atlas Texture",
		usage         = {.TextureBinding, .CopyDst},
		dimension     = ._2D,
		size          = {ATLAS_SIZE, ATLAS_SIZE, MAX_ATLAS_TEXTURES},
		format        = .RGBA8Unorm,
		mipLevelCount = 1,
		sampleCount   = 1,
	}
	sprite_batcher.atlas_texture = wgpu.DeviceCreateTexture(app.wgpu.device, &texture_desc)

	texture_view_desc := wgpu.TextureViewDescriptor {
		label           = "Sprite Atlas Texture View",
		format          = .RGBA8Unorm,
		dimension       = ._2DArray,
		mipLevelCount   = 1,
		arrayLayerCount = MAX_ATLAS_TEXTURES,
		aspect          = .All,
	}
	sprite_batcher.atlas_view = wgpu.TextureCreateView(
		sprite_batcher.atlas_texture,
		&texture_view_desc,
	)

	sampler_desc := wgpu.SamplerDescriptor {
		label         = "Sprite Atlas Sampler",
		addressModeU  = .ClampToEdge,
		addressModeV  = .ClampToEdge,
		addressModeW  = .ClampToEdge,
		magFilter     = .Linear,
		minFilter     = .Linear,
		mipmapFilter  = .Nearest,
		maxAnisotropy = 1,
	}
	sprite_batcher.atlas_sampler = wgpu.DeviceCreateSampler(app.wgpu.device, &sampler_desc)

	// Create bind group layouts
	bgl_storage_buf := []wgpu.BindGroupLayoutEntry {
		wgpu.BindGroupLayoutEntry {
			binding = 0,
			visibility = {.Vertex},
			buffer = {type = .ReadOnlyStorage, hasDynamicOffset = false},
		},
	}
	sprite_batcher.bind_group_layout_storage_buf = wgpu.DeviceCreateBindGroupLayout(
		app.wgpu.device,
		&wgpu.BindGroupLayoutDescriptor {
			label = "Sprite Data Bind Group Layout",
			entryCount = 1,
			entries = raw_data(bgl_storage_buf),
		},
	)

	bgl_uniform_buf := []wgpu.BindGroupLayoutEntry {
		wgpu.BindGroupLayoutEntry {
			binding = 0,
			visibility = {.Vertex},
			buffer = {type = .Uniform, hasDynamicOffset = false},
		},
	}
	sprite_batcher.bind_group_layout_uniform_buf = wgpu.DeviceCreateBindGroupLayout(
		app.wgpu.device,
		&wgpu.BindGroupLayoutDescriptor {
			label = "Uniforms Bind Group Layout",
			entryCount = 1,
			entries = raw_data(bgl_uniform_buf),
		},
	)

	bgl_atlas_array := []wgpu.BindGroupLayoutEntry {
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
	}
	sprite_batcher.bind_group_layout_atlas_array = wgpu.DeviceCreateBindGroupLayout(
		app.wgpu.device,
		&wgpu.BindGroupLayoutDescriptor {
			label = "Atlas Bind Group Layout",
			entryCount = 2,
			entries = raw_data(bgl_atlas_array),
		},
	)

	// Create bind groups
	bind_group_storage_buf := []wgpu.BindGroupEntry {
		{binding = 0, buffer = sprite_batcher.data_buf, offset = 0, size = wgpu.WHOLE_SIZE},
	}
	sprite_batcher.bind_group_storage_buf = wgpu.DeviceCreateBindGroup(
		app.wgpu.device,
		&wgpu.BindGroupDescriptor {
			label = "Sprite Data Bind Group",
			layout = sprite_batcher.bind_group_layout_storage_buf,
			entryCount = 1,
			entries = raw_data(bind_group_storage_buf),
		},
	)

	bind_group_uniform_buf := []wgpu.BindGroupEntry {
		{binding = 0, buffer = sprite_batcher.uniform_buf, offset = 0, size = wgpu.WHOLE_SIZE},
	}
	sprite_batcher.bind_group_uniform_buf = wgpu.DeviceCreateBindGroup(
		app.wgpu.device,
		&wgpu.BindGroupDescriptor {
			label = "Uniforms Bind Group",
			layout = sprite_batcher.bind_group_layout_uniform_buf,
			entryCount = 1,
			entries = raw_data(bind_group_uniform_buf),
		},
	)

	bind_group_atlas_array := []wgpu.BindGroupEntry {
		{binding = 0, textureView = sprite_batcher.atlas_view},
		{binding = 1, sampler = sprite_batcher.atlas_sampler},
	}
	sprite_batcher.bind_group_atlas_array = wgpu.DeviceCreateBindGroup(
		app.wgpu.device,
		&wgpu.BindGroupDescriptor {
			label = "Atlas Bind Group",
			layout = sprite_batcher.bind_group_layout_atlas_array,
			entryCount = 2,
			entries = raw_data(bind_group_atlas_array),
		},
	)

	// Create sprite pipeline
	pipeline_layout_desc: wgpu.PipelineLayoutDescriptor = wgpu.PipelineLayoutDescriptor {
		label                = "Sprite Pipeline Layout",
		bindGroupLayoutCount = 3,
		bindGroupLayouts     = raw_data(
			[]wgpu.BindGroupLayout {
				sprite_batcher.bind_group_layout_storage_buf,
				sprite_batcher.bind_group_layout_uniform_buf,
				sprite_batcher.bind_group_layout_atlas_array,
			},
		),
	}
	sprite_batcher.pipeline_layout = wgpu.DeviceCreatePipelineLayout(
		app.wgpu.device,
		&pipeline_layout_desc,
	)

	blend_state := wgpu.BlendState {
		color = {srcFactor = .SrcAlpha, dstFactor = .OneMinusSrcAlpha, operation = .Add},
		alpha = {srcFactor = .One, dstFactor = .OneMinusSrcAlpha, operation = .Add},
	}

	pipeline_desc := wgpu.RenderPipelineDescriptor {
		label = "Sprite Render Pipeline",
		layout = sprite_batcher.pipeline_layout,
		vertex = wgpu.VertexState{module = sprite_batcher.shader, entryPoint = "vs_main"},
		fragment = &{
			module = sprite_batcher.shader,
			entryPoint = "fs_main",
			targetCount = 1,
			targets = &wgpu.ColorTargetState {
				format = .BGRA8Unorm,
				blend = &blend_state,
				writeMask = wgpu.ColorWriteMaskFlags_All,
			},
		},
		primitive = wgpu.PrimitiveState {
			topology = .TriangleStrip,
			frontFace = .CCW,
			cullMode = .None,
		},
		multisample = {count = 1, mask = 0xFFFFFFFF},
	}
	sprite_batcher.pipeline = wgpu.DeviceCreateRenderPipeline(app.wgpu.device, &pipeline_desc)

	// Upload the default white texture to the first atlas slot
	sprite_batcher_upload_atlas({255, 255, 255, 255}, 0)

	return true
}

sprite_batcher_deinit :: proc() {
	log.info("Deinitializing SpriteBatcher...")
	wgpu.RenderPipelineRelease(sprite_batcher.pipeline)
	wgpu.PipelineLayoutRelease(sprite_batcher.pipeline_layout)
	wgpu.BufferRelease(sprite_batcher.data_buf)
	wgpu.BufferRelease(sprite_batcher.uniform_buf)
	wgpu.SamplerRelease(sprite_batcher.atlas_sampler)
	wgpu.TextureViewRelease(sprite_batcher.atlas_view)
	wgpu.TextureRelease(sprite_batcher.atlas_texture)
	wgpu.BindGroupRelease(sprite_batcher.bind_group_atlas_array)
	wgpu.BindGroupRelease(sprite_batcher.bind_group_uniform_buf)
	wgpu.BindGroupRelease(sprite_batcher.bind_group_storage_buf)
	wgpu.BindGroupLayoutRelease(sprite_batcher.bind_group_layout_atlas_array)
	wgpu.BindGroupLayoutRelease(sprite_batcher.bind_group_layout_uniform_buf)
	wgpu.BindGroupLayoutRelease(sprite_batcher.bind_group_layout_storage_buf)
	wgpu.ShaderModuleRelease(sprite_batcher.shader)
	delete(sprite_batcher.sprites)
}

sprite_batcher_upload_atlas :: proc(data: []u8, idx: u32) {
	log.debugf("SpriteBatcher: Uploading atlas texture data to slot {}...", idx)

	wgpu.QueueWriteTexture(
		app.wgpu.queue,
		&wgpu.TexelCopyTextureInfo {
			texture = sprite_batcher.atlas_texture,
			aspect = .All,
			mipLevel = 0,
			origin = {0, 0, idx},
		},
		raw_data(data),
		len(data),
		&wgpu.TexelCopyBufferLayout {
			bytesPerRow = size_of(u8) * ATLAS_SIZE * 4,
			rowsPerImage = ATLAS_SIZE,
		},
		&wgpu.Extent3D{width = ATLAS_SIZE, height = ATLAS_SIZE, depthOrArrayLayers = 1},
	)
}

sprite_batcher_add_sprite :: proc(data: SpriteData) {
	if len(sprite_batcher.sprites) >= MAX_SPRITES {
		log.warn("SpriteBatcher: Max sprite count reached, cannot add more sprites.")
		return
	}
	// log.debugf(
	// 	"Adding sprite to batcher: position=({}, {}, {}), scale=({}, {}), rotation={}",
	// 	data.position[0],
	// 	data.position[1],
	// 	data.position[2],
	// 	data.scale[0],
	// 	data.scale[1],
	// 	data.position[3], // rotation stored in w component
	// )
	append(&sprite_batcher.sprites, data)
}

sprite_batcher_clear :: proc() {
	clear(&sprite_batcher.sprites)
}

sprite_batcher_frame :: proc(render_pass: wgpu.RenderPassEncoder, view_proj_matrix: [16]f32) {
	// log.debugf("SpriteBatcher: Rendering {} sprites", len(sprite_batcher.sprites))

	sprite_count := len(sprite_batcher.sprites)
	if sprite_count == 0 {return}

	wgpu.QueueWriteBuffer(
		app.wgpu.queue,
		sprite_batcher.data_buf,
		0,
		&sprite_batcher.sprites[0],
		cast(uint)(size_of(SpriteData) * sprite_count),
	)

	uniforms := Uniforms {
		view_proj = view_proj_matrix,
	}
	wgpu.QueueWriteBuffer(
		app.wgpu.queue,
		sprite_batcher.uniform_buf,
		0,
		&uniforms,
		size_of(Uniforms),
	)

	// Draw all sprites
	wgpu.RenderPassEncoderSetPipeline(render_pass, sprite_batcher.pipeline)
	wgpu.RenderPassEncoderSetBindGroup(render_pass, 0, sprite_batcher.bind_group_storage_buf)
	wgpu.RenderPassEncoderSetBindGroup(render_pass, 1, sprite_batcher.bind_group_uniform_buf)
	wgpu.RenderPassEncoderSetBindGroup(render_pass, 2, sprite_batcher.bind_group_atlas_array)
	wgpu.RenderPassEncoderDraw(render_pass, 4, cast(u32)(sprite_count), 0, 0)
}

