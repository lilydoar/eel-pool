package app

import shared "../"
import "../game"
import "vendor:wgpu"
import "core:log"

MAX_SPRITES :: 8192

SpriteData :: struct {
	position:   shared.Vec3, // x, y, z
	rotation:   f32, // rotation in radians
	scale:      shared.Vec2, // width, height scale
	tex_coords: [4]f32, // u0, v0, u1, v1 (texture atlas coordinates)
	color:      [4]f32, // r, g, b, a
}

ScreenUniforms :: struct {
	screen_size: [2]f32, // width, height in pixels
	_padding:    [2]f32, // pad to 16 bytes for uniform buffer alignment
}

SpriteBatcher :: struct {
	sprite_buffer:      wgpu.Buffer,
	index_buffer:       wgpu.Buffer,
	uniform_buffer:     wgpu.Buffer,
	bind_group:         wgpu.BindGroup,
	bind_group_layout:  wgpu.BindGroupLayout,
	pipeline_layout:    wgpu.PipelineLayout,
	render_pipeline:    wgpu.RenderPipeline,
	shader_module:      wgpu.ShaderModule,
	sprites:            [MAX_SPRITES]SpriteData,
	sprite_count:       i32,

	// Screen uniforms
	screen_uniforms:    ScreenUniforms,

	// Dummy white texture for now - can be enhanced later
	white_texture:      wgpu.Texture,
	white_texture_view: wgpu.TextureView,
	texture_sampler:    wgpu.Sampler,
}

sprite_batcher: SpriteBatcher

sprite_batcher_init :: proc() -> bool {
	// Create index buffer for quad indices
	indices: [MAX_SPRITES * 6]u32
	for i in 0 ..< MAX_SPRITES {
		base_vertex := u32(i * 4)
		base_index := i * 6

		// First triangle: 0, 1, 2
		indices[base_index + 0] = base_vertex + 0
		indices[base_index + 1] = base_vertex + 1
		indices[base_index + 2] = base_vertex + 2

		// Second triangle: 2, 3, 0
		indices[base_index + 3] = base_vertex + 2
		indices[base_index + 4] = base_vertex + 3
		indices[base_index + 5] = base_vertex + 0
	}

	index_buffer_desc := wgpu.BufferDescriptor {
		usage = {.Index, .CopyDst},
		size  = size_of(indices),
	}
	sprite_batcher.index_buffer = wgpu.DeviceCreateBuffer(state.device, &index_buffer_desc)
	wgpu.QueueWriteBuffer(
		state.queue,
		sprite_batcher.index_buffer,
		0,
		raw_data(indices[:]),
		size_of(indices),
	)

	// Create sprite data buffer
	sprite_buffer_desc := wgpu.BufferDescriptor {
		usage = {.Storage, .CopyDst},
		size  = size_of(SpriteData) * MAX_SPRITES,
	}
	sprite_batcher.sprite_buffer = wgpu.DeviceCreateBuffer(state.device, &sprite_buffer_desc)

	// Create uniform buffer for screen size
	uniform_buffer_desc := wgpu.BufferDescriptor {
		usage = {.Uniform, .CopyDst},
		size  = size_of(ScreenUniforms),
	}
	sprite_batcher.uniform_buffer = wgpu.DeviceCreateBuffer(state.device, &uniform_buffer_desc)

	// Initialize screen uniforms
	sprite_batcher.screen_uniforms.screen_size = {f32(state.window_size.x), f32(state.window_size.y)}
	wgpu.QueueWriteBuffer(
		state.queue,
		sprite_batcher.uniform_buffer,
		0,
		&sprite_batcher.screen_uniforms,
		size_of(ScreenUniforms),
	)

	// Create 1x1 white texture
	white_pixel: [4]u8 = {255, 255, 255, 255}
	texture_desc := wgpu.TextureDescriptor {
		usage         = {.TextureBinding, .CopyDst},
		dimension     = ._2D,
		size          = {1, 1, 1},
		format        = .RGBA8Unorm,
		mipLevelCount = 1,
		sampleCount   = 1,
	}
	sprite_batcher.white_texture = wgpu.DeviceCreateTexture(state.device, &texture_desc)

	// Write white pixel data to texture
	image_copy := wgpu.TexelCopyTextureInfo{
		texture = sprite_batcher.white_texture,
	}
	data_layout := wgpu.TexelCopyBufferLayout{
		bytesPerRow = 4,
		rowsPerImage = 1,
	}
	copy_size := wgpu.Extent3D{width = 1, height = 1, depthOrArrayLayers = 1}
	
	wgpu.QueueWriteTexture(
		state.queue,
		&image_copy,
		raw_data(white_pixel[:]),
		size_of(white_pixel),
		&data_layout,
		&copy_size,
	)

	sprite_batcher.white_texture_view = wgpu.TextureCreateView(sprite_batcher.white_texture, nil)

	// Create sampler
	sampler_desc := wgpu.SamplerDescriptor {
		magFilter = .Nearest,
		minFilter = .Nearest,
		maxAnisotropy = 1,
	}
	sprite_batcher.texture_sampler = wgpu.DeviceCreateSampler(state.device, &sampler_desc)

	// Create shader module
	sprite_shader_source := `
struct SpriteData {
    position: vec3<f32>,
    rotation: f32,
    scale: vec2<f32>,
    tex_coords: vec4<f32>,
    color: vec4<f32>,
}

struct ScreenUniforms {
    screen_size: vec2<f32>,
    _padding: vec2<f32>,
}

@group(0) @binding(0) var<storage, read> sprites: array<SpriteData>;
@group(0) @binding(1) var atlas_texture: texture_2d<f32>;
@group(0) @binding(2) var atlas_sampler: sampler;
@group(0) @binding(3) var<uniform> screen: ScreenUniforms;

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) tex_coord: vec2<f32>,
    @location(1) color: vec4<f32>,
}

@vertex
fn vs_main(@builtin(vertex_index) vertex_id: u32) -> VertexOutput {
    let sprite_id = vertex_id / 4u;
    let corner_id = vertex_id % 4u;
    
    let sprite = sprites[sprite_id];
    
    // Generate quad corners: (0,0), (1,0), (1,1), (0,1)
    var corner = vec2<f32>(f32(corner_id & 1u), f32(corner_id >> 1u));
    
    // Center around origin, then scale
    corner = (corner - 0.5) * sprite.scale;
    
    // Apply rotation
    let cos_r = cos(sprite.rotation);
    let sin_r = sin(sprite.rotation);
    let rotated = vec2<f32>(
        corner.x * cos_r - corner.y * sin_r,
        corner.x * sin_r + corner.y * cos_r
    );
    
    // Translate to world position
    let world_pos = sprite.position.xy + rotated;
    
    // Convert to NDC using actual screen dimensions
    let ndc = vec2<f32>(
        world_pos.x / (screen.screen_size.x * 0.5), 
        -world_pos.y / (screen.screen_size.y * 0.5)
    );
    
    // Interpolate texture coordinates
    let tex_coord = mix(
        sprite.tex_coords.xy,
        sprite.tex_coords.zw,
        corner + 0.5
    );
    
    var out: VertexOutput;
    out.position = vec4<f32>(ndc, sprite.position.z, 1.0);
    out.tex_coord = tex_coord;
    out.color = sprite.color;
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let tex_color = textureSample(atlas_texture, atlas_sampler, in.tex_coord);
    return tex_color * in.color;
}`


	sprite_batcher.shader_module = wgpu.DeviceCreateShaderModule(
		state.device,
		&{
			nextInChain = &wgpu.ShaderSourceWGSL {
				sType = .ShaderSourceWGSL,
				code = sprite_shader_source,
			},
		},
	)

	// Create bind group layout
	layout_entries := [4]wgpu.BindGroupLayoutEntry {
		{
			binding = 0,
			visibility = {.Vertex},
			buffer = {type = .ReadOnlyStorage, hasDynamicOffset = false},
		},
		{
			binding = 1,
			visibility = {.Fragment},
			texture = {sampleType = .Float, viewDimension = ._2D},
		},
		{binding = 2, visibility = {.Fragment}, sampler = {type = .Filtering}},
		{
			binding = 3,
			visibility = {.Vertex},
			buffer = {type = .Uniform, hasDynamicOffset = false},
		},
	}

	bind_group_layout_desc := wgpu.BindGroupLayoutDescriptor {
		entryCount = len(layout_entries),
		entries    = raw_data(layout_entries[:]),
	}
	sprite_batcher.bind_group_layout = wgpu.DeviceCreateBindGroupLayout(
		state.device,
		&bind_group_layout_desc,
	)

	// Create bind group
	bind_group_entries := [4]wgpu.BindGroupEntry {
		{binding = 0, buffer = sprite_batcher.sprite_buffer, offset = 0, size = wgpu.WHOLE_SIZE},
		{binding = 1, textureView = sprite_batcher.white_texture_view},
		{binding = 2, sampler = sprite_batcher.texture_sampler},
		{binding = 3, buffer = sprite_batcher.uniform_buffer, offset = 0, size = wgpu.WHOLE_SIZE},
	}

	bind_group_desc := wgpu.BindGroupDescriptor {
		layout     = sprite_batcher.bind_group_layout,
		entryCount = len(bind_group_entries),
		entries    = raw_data(bind_group_entries[:]),
	}
	sprite_batcher.bind_group = wgpu.DeviceCreateBindGroup(state.device, &bind_group_desc)

	// Create pipeline layout
	pipeline_layout_desc := wgpu.PipelineLayoutDescriptor {
		bindGroupLayoutCount = 1,
		bindGroupLayouts     = &sprite_batcher.bind_group_layout,
	}
	sprite_batcher.pipeline_layout = wgpu.DeviceCreatePipelineLayout(
		state.device,
		&pipeline_layout_desc,
	)

	// Create render pipeline
	sprite_batcher.render_pipeline = wgpu.DeviceCreateRenderPipeline(
		state.device,
		&{
			layout = sprite_batcher.pipeline_layout,
			vertex = {module = sprite_batcher.shader_module, entryPoint = "vs_main"},
			fragment = &{
				module = sprite_batcher.shader_module,
				entryPoint = "fs_main",
				targetCount = 1,
				targets = &wgpu.ColorTargetState {
					format = .BGRA8Unorm,
					writeMask = wgpu.ColorWriteMaskFlags_All,
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
				},
			},
			primitive = {topology = .TriangleList},
			multisample = {count = 1, mask = 0xFFFFFFFF},
		},
	)

	return true
}

sprite_batcher_deinit :: proc() {
	if sprite_batcher.render_pipeline != nil do wgpu.RenderPipelineRelease(sprite_batcher.render_pipeline)
	if sprite_batcher.pipeline_layout != nil do wgpu.PipelineLayoutRelease(sprite_batcher.pipeline_layout)
	if sprite_batcher.bind_group != nil do wgpu.BindGroupRelease(sprite_batcher.bind_group)
	if sprite_batcher.bind_group_layout != nil do wgpu.BindGroupLayoutRelease(sprite_batcher.bind_group_layout)
	if sprite_batcher.shader_module != nil do wgpu.ShaderModuleRelease(sprite_batcher.shader_module)
	if sprite_batcher.texture_sampler != nil do wgpu.SamplerRelease(sprite_batcher.texture_sampler)
	if sprite_batcher.white_texture_view != nil do wgpu.TextureViewRelease(sprite_batcher.white_texture_view)
	if sprite_batcher.white_texture != nil do wgpu.TextureRelease(sprite_batcher.white_texture)
	if sprite_batcher.uniform_buffer != nil do wgpu.BufferRelease(sprite_batcher.uniform_buffer)
	if sprite_batcher.sprite_buffer != nil do wgpu.BufferRelease(sprite_batcher.sprite_buffer)
	if sprite_batcher.index_buffer != nil do wgpu.BufferRelease(sprite_batcher.index_buffer)
}

sprite_batcher_update_screen_size :: proc(width, height: u32) {
	sprite_batcher.screen_uniforms.screen_size = {f32(width), f32(height)}
	wgpu.QueueWriteBuffer(
		state.queue,
		sprite_batcher.uniform_buffer,
		0,
		&sprite_batcher.screen_uniforms,
		size_of(ScreenUniforms),
	)
	log.debugf("Updated sprite batcher screen size to: {}x{}", width, height)
}

add_sprite :: proc(
	position: shared.Vec3,
	rotation: f32,
	scale: shared.Vec2,
	tex_coords: [4]f32,
	color: [4]f32,
) {
	if sprite_batcher.sprite_count >= MAX_SPRITES do return

	sprite := &sprite_batcher.sprites[sprite_batcher.sprite_count]
	sprite.position = position
	sprite.rotation = rotation
	sprite.scale = scale
	sprite.tex_coords = tex_coords
	sprite.color = color

	sprite_batcher.sprite_count += 1
}

add_white_square :: proc(x, y: f32, size: f32) {
	add_sprite(
		position = {x, y, 0.0},
		rotation = 0.0,
		scale = {size, size},
		tex_coords = {0.0, 0.0, 1.0, 1.0}, // Full texture (white pixel)
		color = {1.0, 1.0, 1.0, 1.0}, // White color
	)
}

clear_sprites :: proc() {
	sprite_batcher.sprite_count = 0
}

render_sprites :: proc(render_pass_encoder: wgpu.RenderPassEncoder) {
	if sprite_batcher.sprite_count == 0 {
		log.debug("No sprites to render")
		return
	}

	log.debugf("Rendering {} sprites", sprite_batcher.sprite_count)

	// Upload sprite data to GPU
	wgpu.QueueWriteBuffer(
		state.queue,
		sprite_batcher.sprite_buffer,
		0,
		raw_data(sprite_batcher.sprites[:]),
		uint(size_of(SpriteData) * int(sprite_batcher.sprite_count)),
	)

	// Set pipeline and bindings
	wgpu.RenderPassEncoderSetPipeline(render_pass_encoder, sprite_batcher.render_pipeline)
	wgpu.RenderPassEncoderSetBindGroup(render_pass_encoder, 0, sprite_batcher.bind_group)
	wgpu.RenderPassEncoderSetIndexBuffer(
		render_pass_encoder,
		sprite_batcher.index_buffer,
		.Uint32,
		0,
		wgpu.WHOLE_SIZE,
	)

	// Draw all sprites in a single call
	wgpu.RenderPassEncoderDrawIndexed(
		render_pass_encoder,
		indexCount = u32(sprite_batcher.sprite_count * 6), // 6 indices per sprite
		instanceCount = 1,
		firstIndex = 0,
		baseVertex = 0,
		firstInstance = 0,
	)
}

render_gol_board :: proc(board: ^game.GOLBoard) {
	cell_size: f32 = 20.0 // pixels per cell
	board_offset_x: f32 = -f32(board.size) * cell_size * 0.5 // center the board
	board_offset_y: f32 = -f32(board.size) * cell_size * 0.5

	clear_sprites()

	for y in 0 ..< board.size {
		for x in 0 ..< board.size {
			if game.gol_board_get(board, x, y) == 1 {
				world_x := f32(x) * cell_size + board_offset_x
				world_y := f32(y) * cell_size + board_offset_y
				add_white_square(world_x, world_y, cell_size)
			}
		}
	}
}

render_gol_board_from_packet :: proc(packet: ^shared.GOLBoardRenderPacket) {
	cell_size: f32 = 20.0 // pixels per cell
	board_size := int(packet.board_size)
	board_offset_x: f32 = -f32(board_size) * cell_size * 0.5 // center the board
	board_offset_y: f32 = -f32(board_size) * cell_size * 0.5

	clear_sprites()

	alive_cells := 0
	for y in 0 ..< board_size {
		for x in 0 ..< board_size {
			if packet.board_data[x + y * board_size] == 1 {
				alive_cells += 1
				world_x := f32(x) * cell_size + board_offset_x
				world_y := f32(y) * cell_size + board_offset_y
				add_white_square(world_x, world_y, cell_size)
			}
		}
	}
	log.debugf("GOL Board: {}x{}, {} alive cells, {} sprites added", board_size, board_size, alive_cells, sprite_batcher.sprite_count)
}

