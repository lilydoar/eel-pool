struct Sprite {
	position: vec4<f32>, // position=xyz, rotation=w (radians)
	atlas_coords: vec4<f32>, // uv_min=xy, uv_max=zw (origin top-left)
	color: vec4<f32>, // RGBA normalized
	scale: vec2<f32>, // scale_x, scale_y
	atlas_idx: u32, // index into texture array
	_padding: f32,
}

struct Uniform {
	view_proj: mat4x4<f32>,
}

struct VertexOutput {
	@builtin(position) position: vec4<f32>,
	@location(0) color: vec4<f32>,
	@location(1) tex_coord: vec2<f32>,
	@location(2) tex_idx: u32,
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

@group(0) @binding(0) var<uniform> uniform: Uniform;
@group(0) @binding(1) var<storage, read> sprites: array<Sprite>;
@group(1) @binding(0) var atlas_texture_array: texture_2d_array<f32>;
@group(1) @binding(1) var atlas_texture_sampler: sampler;

@vertex
fn vertex_main(@builtin(vertex_index) vertex: u32, @builtin(instance_index) instance: u32) -> VertexOutput {
	let sprite = sprites[instance];

	// Lookup vertex data from constant arrays
	let vertex_pos = QUAD_VERTICES[vertex];
	let vertex_uv = QUAD_UVS[vertex];

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
	let clip_pos = uniform.view_proj * vec4<f32>(world_pos, 1.0);

	// Map UVs to sprite's texture rectangle
	let tex_coord = mix(
		sprite.atlas_coords.xy,
		sprite.atlas_coords.zw,
		vertex_uv
	);

	var out: VertexOutput;
	out.position = clip_pos;
	out.color = sprite.color;
	out.tex_coord = tex_coord;
	out.tex_idx = sprite.atlas_idx;
	return out;
}

@fragment
fn fragment_main(in: VertexOutput) -> @location(0) vec4<f32> {
	let tex_color = textureSample(atlas_texture_array, atlas_texture_sampler, in.tex_coord, i32(in.tex_idx));
	return tex_color * in.color;
}
