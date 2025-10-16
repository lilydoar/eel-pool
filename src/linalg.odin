package game

import "core:math"

Vec2 :: struct {
	x: f32,
	y: f32,
}

vec2_new :: proc(x: f32, y: f32) -> Vec2 {
	return Vec2{x = x, y = y}
}

vec2_zero :: proc() -> Vec2 {
	return Vec2{x = 0.0, y = 0.0}
}

vec2_one :: proc() -> Vec2 {
	return Vec2{x = 1.0, y = 1.0}
}

vec2_add :: proc(a: Vec2, b: Vec2) -> Vec2 {
	return Vec2{x = a.x + b.x, y = a.y + b.y}
}

vec2_sub :: proc(a: Vec2, b: Vec2) -> Vec2 {
	return Vec2{x = a.x - b.x, y = a.y - b.y}
}

vec2_mul :: proc(a: Vec2, b: Vec2) -> Vec2 {
	return Vec2{x = a.x * b.x, y = a.y * b.y}
}

vec2_div :: proc(a: Vec2, b: Vec2) -> Vec2 {
	return Vec2{x = a.x / b.x, y = a.y / b.y}
}

vec2_scale :: proc(v: Vec2, s: f32) -> Vec2 {
	return Vec2{x = v.x * s, y = v.y * s}
}

vec2_dot :: proc(a: Vec2, b: Vec2) -> f32 {
	return a.x * b.x + a.y * b.y
}

vec2_len :: proc(v: Vec2) -> f32 {
	return math.sqrt(vec2_dot(v, v))
}

vec2_dst :: proc(a: Vec2, b: Vec2) -> f32 {
	return vec2_len(vec2_sub(a, b))
}

vec2_dst_sqr :: proc(a: Vec2, b: Vec2) -> f32 {
	diff := vec2_sub(a, b)
	return vec2_dot(diff, diff)
}

vec2_dst_l1 :: proc(a: Vec2, b: Vec2) -> f32 {
	return abs(a.x - b.x) + abs(a.y - b.y)
}

vec2_norm :: proc(v: Vec2) -> Vec2 {
	return vec2_scale(v, 1.0 / vec2_len(v))
}

vec2_norm_safe :: proc(v: Vec2) -> Vec2 {
	len := vec2_len(v)
	if len == 0.0 {
		return vec2_zero()
	}
	return vec2_scale(v, 1.0 / len)
}

// Range [-π, π]
vec2_angle :: proc(a: Vec2) -> f32 {
	return math.atan2(a.y, a.x)
}

// Range: [0, π]
vec2_angle_between_unsigned :: proc(a: Vec2, b: Vec2) -> f32 {
	cos_angle := vec2_dot(a, b) / (vec2_len(a) * vec2_len(b))
	return math.acos(cos_angle)
}

// Range: [-π, π]
vec2_angle_between_signed :: proc(a: Vec2, b: Vec2) -> f32 {
	return math.atan2(a.x * b.y - a.y * b.x, vec2_dot(a, b))
}

vec2_from_angle :: proc(angle: f32) -> Vec2 {
	return Vec2{x = math.cos(angle), y = math.sin(angle)}
}

Vec3 :: struct {
	x: f32,
	y: f32,
	z: f32,
}

vec3_new :: proc(x: f32, y: f32, z: f32) -> Vec3 {
	return Vec3{x = x, y = y, z = z}
}

vec3_zero :: proc() -> Vec3 {
	return Vec3{x = 0.0, y = 0.0, z = 0.0}
}

vec3_one :: proc() -> Vec3 {
	return Vec3{x = 1.0, y = 1.0, z = 1.0}
}

vec3_add :: proc(a: Vec3, b: Vec3) -> Vec3 {
	return Vec3{x = a.x + b.x, y = a.y + b.y, z = a.z + b.z}
}

vec3_sub :: proc(a: Vec3, b: Vec3) -> Vec3 {
	return Vec3{x = a.x - b.x, y = a.y - b.y, z = a.z - b.z}
}

vec3_mul :: proc(a: Vec3, b: Vec3) -> Vec3 {
	return Vec3{x = a.x * b.x, y = a.y * b.y, z = a.z * b.z}
}

vec3_div :: proc(a: Vec3, b: Vec3) -> Vec3 {
	return Vec3{x = a.x / b.x, y = a.y / b.y, z = a.z / b.z}
}

vec3_scale :: proc(v: Vec3, s: f32) -> Vec3 {
	return Vec3{x = v.x * s, y = v.y * s, z = v.z * s}
}

vec3_dot :: proc(a: Vec3, b: Vec3) -> f32 {
	return a.x * b.x + a.y * b.y + a.z * b.z
}

vec3_len :: proc(v: Vec3) -> f32 {
	return math.sqrt(vec3_dot(v, v))
}

vec3_dst :: proc(a: Vec3, b: Vec3) -> f32 {
	return vec3_len(vec3_sub(a, b))
}

vec3_dst_sqr :: proc(a: Vec3, b: Vec3) -> f32 {
	diff := vec3_sub(a, b)
	return vec3_dot(diff, diff)
}

vec3_dst_l1 :: proc(a: Vec3, b: Vec3) -> f32 {
	return abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z)
}

vec3_norm :: proc(v: Vec3) -> Vec3 {
	return vec3_scale(v, 1.0 / vec3_len(v))
}

vec3_norm_safe :: proc(v: Vec3) -> Vec3 {
	len := vec3_len(v)
	if len == 0.0 {
		return vec3_zero()
	}
	return vec3_scale(v, 1.0 / len)
}

vec3_cross :: proc(a: Vec3, b: Vec3) -> Vec3 {
	return Vec3{x = a.y * b.z - a.z * b.y, y = a.z * b.x - a.x * b.z, z = a.x * b.y - a.y * b.x}
}

// Range: [0, π]
vec3_angle_between_unsigned :: proc(a: Vec3, b: Vec3) -> f32 {
	cos_angle := vec3_dot(a, b) / (vec3_len(a) * vec3_len(b))
	return math.acos(cos_angle)
}

Vec4 :: struct {
	x: f32,
	y: f32,
	z: f32,
	w: f32,
}

vec4_new :: proc(x: f32, y: f32, z: f32, w: f32) -> Vec4 {
	return Vec4{x = x, y = y, z = z, w = w}
}

vec4_zero :: proc() -> Vec4 {
	return Vec4{x = 0.0, y = 0.0, z = 0.0, w = 0.0}
}

vec4_one :: proc() -> Vec4 {
	return Vec4{x = 1.0, y = 1.0, z = 1.0, w = 1.0}
}

vec4_add :: proc(a: Vec4, b: Vec4) -> Vec4 {
	return Vec4{x = a.x + b.x, y = a.y + b.y, z = a.z + b.z, w = a.w + b.w}
}

vec4_sub :: proc(a: Vec4, b: Vec4) -> Vec4 {
	return Vec4{x = a.x - b.x, y = a.y - b.y, z = a.z - b.z, w = a.w - b.w}
}

vec4_mul :: proc(a: Vec4, b: Vec4) -> Vec4 {
	return Vec4{x = a.x * b.x, y = a.y * b.y, z = a.z * b.z, w = a.w * b.w}
}

vec4_div :: proc(a: Vec4, b: Vec4) -> Vec4 {
	return Vec4{x = a.x / b.x, y = a.y / b.y, z = a.z / b.z, w = a.w / b.w}
}

vec4_scale :: proc(v: Vec4, s: f32) -> Vec4 {
	return Vec4{x = v.x * s, y = v.y * s, z = v.z * s, w = v.w * s}
}

vec4_dot :: proc(a: Vec4, b: Vec4) -> f32 {
	return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w
}

vec4_len :: proc(v: Vec4) -> f32 {
	return math.sqrt(vec4_dot(v, v))
}

vec4_dst :: proc(a: Vec4, b: Vec4) -> f32 {
	return vec4_len(vec4_sub(a, b))
}

vec4_dst_sqr :: proc(a: Vec4, b: Vec4) -> f32 {
	diff := vec4_sub(a, b)
	return vec4_dot(diff, diff)
}

vec4_dst_l1 :: proc(a: Vec4, b: Vec4) -> f32 {
	return abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z) + abs(a.w - b.w)
}

vec4_norm :: proc(v: Vec4) -> Vec4 {
	return vec4_scale(v, 1.0 / vec4_len(v))
}

vec4_norm_safe :: proc(v: Vec4) -> Vec4 {
	len := vec4_len(v)
	if len == 0.0 {
		return vec4_zero()
	}
	return vec4_scale(v, 1.0 / len)
}

// Range: [0, π]
vec4_angle_between_unsigned :: proc(a: Vec4, b: Vec4) -> f32 {
	cos_angle := vec4_dot(a, b) / (vec4_len(a) * vec4_len(b))
	return math.acos(cos_angle)
}

Vec2i :: struct {
	x: i32,
	y: i32,
}

vec2i_new :: proc(x: i32, y: i32) -> Vec2i {
	return Vec2i{x = x, y = y}
}

vec2i_zero :: proc() -> Vec2i {
	return Vec2i{x = 0, y = 0}
}

vec2i_one :: proc() -> Vec2i {
	return Vec2i{x = 1, y = 1}
}

vec2i_add :: proc(a: Vec2i, b: Vec2i) -> Vec2i {
	return Vec2i{x = a.x + b.x, y = a.y + b.y}
}

vec2i_sub :: proc(a: Vec2i, b: Vec2i) -> Vec2i {
	return Vec2i{x = a.x - b.x, y = a.y - b.y}
}

vec2i_mul :: proc(a: Vec2i, b: Vec2i) -> Vec2i {
	return Vec2i{x = a.x * b.x, y = a.y * b.y}
}

vec2i_div :: proc(a: Vec2i, b: Vec2i) -> Vec2i {
	return Vec2i{x = a.x / b.x, y = a.y / b.y}
}

vec2i_scale :: proc(v: Vec2i, s: i32) -> Vec2i {
	return Vec2i{x = v.x * s, y = v.y * s}
}

vec2i_dot :: proc(a: Vec2i, b: Vec2i) -> i32 {
	return a.x * b.x + a.y * b.y
}

vec2i_len :: proc(v: Vec2i) -> f32 {
	return math.sqrt(f32(vec2i_dot(v, v)))
}

vec2i_dst :: proc(a: Vec2i, b: Vec2i) -> f32 {
	return vec2i_len(vec2i_sub(a, b))
}

vec2i_dst_sqr :: proc(a: Vec2i, b: Vec2i) -> i32 {
	diff := vec2i_sub(a, b)
	return vec2i_dot(diff, diff)
}

vec2i_dst_l1 :: proc(a: Vec2i, b: Vec2i) -> i32 {
	return abs(a.x - b.x) + abs(a.y - b.y)
}

vec2i_norm :: proc(v: Vec2i) -> Vec2 {
	len := vec2i_len(v)
	return Vec2{x = f32(v.x) / len, y = f32(v.y) / len}
}

vec2i_norm_safe :: proc(v: Vec2i) -> Vec2 {
	len := vec2i_len(v)
	if len == 0.0 {
		return vec2_zero()
	}
	return Vec2{x = f32(v.x) / len, y = f32(v.y) / len}
}

// Range: [0, π]
vec2i_angle_between_unsigned :: proc(a: Vec2i, b: Vec2i) -> f32 {
	cos_angle := f32(vec2i_dot(a, b)) / (vec2i_len(a) * vec2i_len(b))
	return math.acos(cos_angle)
}

Vec3i :: struct {
	x: i32,
	y: i32,
	z: i32,
}

vec3i_new :: proc(x: i32, y: i32, z: i32) -> Vec3i {
	return Vec3i{x = x, y = y, z = z}
}

vec3i_zero :: proc() -> Vec3i {
	return Vec3i{x = 0, y = 0, z = 0}
}

vec3i_one :: proc() -> Vec3i {
	return Vec3i{x = 1, y = 1, z = 1}
}

vec3i_add :: proc(a: Vec3i, b: Vec3i) -> Vec3i {
	return Vec3i{x = a.x + b.x, y = a.y + b.y, z = a.z + b.z}
}

vec3i_sub :: proc(a: Vec3i, b: Vec3i) -> Vec3i {
	return Vec3i{x = a.x - b.x, y = a.y - b.y, z = a.z - b.z}
}

vec3i_mul :: proc(a: Vec3i, b: Vec3i) -> Vec3i {
	return Vec3i{x = a.x * b.x, y = a.y * b.y, z = a.z * b.z}
}

vec3i_div :: proc(a: Vec3i, b: Vec3i) -> Vec3i {
	return Vec3i{x = a.x / b.x, y = a.y / b.y, z = a.z / b.z}
}

vec3i_scale :: proc(v: Vec3i, s: i32) -> Vec3i {
	return Vec3i{x = v.x * s, y = v.y * s, z = v.z * s}
}

vec3i_dot :: proc(a: Vec3i, b: Vec3i) -> i32 {
	return a.x * b.x + a.y * b.y + a.z * b.z
}

vec3i_len :: proc(v: Vec3i) -> f32 {
	return math.sqrt(f32(vec3i_dot(v, v)))
}

vec3i_dst :: proc(a: Vec3i, b: Vec3i) -> f32 {
	return vec3i_len(vec3i_sub(a, b))
}

vec3i_dst_sqr :: proc(a: Vec3i, b: Vec3i) -> i32 {
	diff := vec3i_sub(a, b)
	return vec3i_dot(diff, diff)
}

vec3i_dst_l1 :: proc(a: Vec3i, b: Vec3i) -> i32 {
	return abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z)
}

vec3i_norm :: proc(v: Vec3i) -> Vec3 {
	len := vec3i_len(v)
	return Vec3{x = f32(v.x) / len, y = f32(v.y) / len, z = f32(v.z) / len}
}

vec3i_norm_safe :: proc(v: Vec3i) -> Vec3 {
	len := vec3i_len(v)
	if len == 0.0 {
		return vec3_zero()
	}
	return Vec3{x = f32(v.x) / len, y = f32(v.y) / len, z = f32(v.z) / len}
}

vec3i_cross :: proc(a: Vec3i, b: Vec3i) -> Vec3i {
	return Vec3i{x = a.y * b.z - a.z * b.y, y = a.z * b.x - a.x * b.z, z = a.x * b.y - a.y * b.x}
}

// Range: [0, π]
vec3i_angle_between_unsigned :: proc(a: Vec3i, b: Vec3i) -> f32 {
	cos_angle := f32(vec3i_dot(a, b)) / (vec3i_len(a) * vec3i_len(b))
	return math.acos(cos_angle)
}

Vec4i :: struct {
	x: i32,
	y: i32,
	z: i32,
	w: i32,
}

vec4i_new :: proc(x: i32, y: i32, z: i32, w: i32) -> Vec4i {
	return Vec4i{x = x, y = y, z = z, w = w}
}

vec4i_zero :: proc() -> Vec4i {
	return Vec4i{x = 0, y = 0, z = 0, w = 0}
}

vec4i_one :: proc() -> Vec4i {
	return Vec4i{x = 1, y = 1, z = 1, w = 1}
}

vec4i_add :: proc(a: Vec4i, b: Vec4i) -> Vec4i {
	return Vec4i{x = a.x + b.x, y = a.y + b.y, z = a.z + b.z, w = a.w + b.w}
}

vec4i_sub :: proc(a: Vec4i, b: Vec4i) -> Vec4i {
	return Vec4i{x = a.x - b.x, y = a.y - b.y, z = a.z - b.z, w = a.w - b.w}
}

vec4i_mul :: proc(a: Vec4i, b: Vec4i) -> Vec4i {
	return Vec4i{x = a.x * b.x, y = a.y * b.y, z = a.z * b.z, w = a.w * b.w}
}

vec4i_div :: proc(a: Vec4i, b: Vec4i) -> Vec4i {
	return Vec4i{x = a.x / b.x, y = a.y / b.y, z = a.z / b.z, w = a.w / b.w}
}

vec4i_scale :: proc(v: Vec4i, s: i32) -> Vec4i {
	return Vec4i{x = v.x * s, y = v.y * s, z = v.z * s, w = v.w * s}
}

vec4i_dot :: proc(a: Vec4i, b: Vec4i) -> i32 {
	return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w
}

vec4i_len :: proc(v: Vec4i) -> f32 {
	return math.sqrt(f32(vec4i_dot(v, v)))
}

vec4i_dst :: proc(a: Vec4i, b: Vec4i) -> f32 {
	return vec4i_len(vec4i_sub(a, b))
}

vec4i_dst_sqr :: proc(a: Vec4i, b: Vec4i) -> i32 {
	diff := vec4i_sub(a, b)
	return vec4i_dot(diff, diff)
}

vec4i_dst_l1 :: proc(a: Vec4i, b: Vec4i) -> i32 {
	return abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z) + abs(a.w - b.w)
}

vec4i_norm :: proc(v: Vec4i) -> Vec4 {
	len := vec4i_len(v)
	return Vec4{x = f32(v.x) / len, y = f32(v.y) / len, z = f32(v.z) / len, w = f32(v.w) / len}
}

vec4i_norm_safe :: proc(v: Vec4i) -> Vec4 {
	len := vec4i_len(v)
	if len == 0.0 {
		return vec4_zero()
	}
	return Vec4{x = f32(v.x) / len, y = f32(v.y) / len, z = f32(v.z) / len, w = f32(v.w) / len}
}

// Range: [0, π]
vec4i_angle_between_unsigned :: proc(a: Vec4i, b: Vec4i) -> f32 {
	cos_angle := f32(vec4i_dot(a, b)) / (vec4i_len(a) * vec4i_len(b))
	return math.acos(cos_angle)
}

Vec2u :: struct {
	x: u32,
	y: u32,
}

vec2u_new :: proc(x: u32, y: u32) -> Vec2u {
	return Vec2u{x = x, y = y}
}

vec2u_zero :: proc() -> Vec2u {
	return Vec2u{x = 0, y = 0}
}

vec2u_one :: proc() -> Vec2u {
	return Vec2u{x = 1, y = 1}
}

vec2u_add :: proc(a: Vec2u, b: Vec2u) -> Vec2u {
	return Vec2u{x = a.x + b.x, y = a.y + b.y}
}

vec2u_sub :: proc(a: Vec2u, b: Vec2u) -> Vec2u {
	return Vec2u{x = a.x - b.x, y = a.y - b.y}
}

vec2u_mul :: proc(a: Vec2u, b: Vec2u) -> Vec2u {
	return Vec2u{x = a.x * b.x, y = a.y * b.y}
}

vec2u_div :: proc(a: Vec2u, b: Vec2u) -> Vec2u {
	return Vec2u{x = a.x / b.x, y = a.y / b.y}
}

vec2u_scale :: proc(v: Vec2u, s: u32) -> Vec2u {
	return Vec2u{x = v.x * s, y = v.y * s}
}

vec2u_dot :: proc(a: Vec2u, b: Vec2u) -> u32 {
	return a.x * b.x + a.y * b.y
}

vec2u_len :: proc(v: Vec2u) -> f32 {
	return math.sqrt(f32(vec2u_dot(v, v)))
}

vec2u_dst :: proc(a: Vec2u, b: Vec2u) -> f32 {
	return vec2u_len(vec2u_sub(a, b))
}

vec2u_dst_sqr :: proc(a: Vec2u, b: Vec2u) -> u32 {
	diff := vec2u_sub(a, b)
	return vec2u_dot(diff, diff)
}

vec2u_dst_l1 :: proc(a: Vec2u, b: Vec2u) -> u32 {
	return abs(a.x - b.x) + abs(a.y - b.y)
}

vec2u_norm :: proc(v: Vec2u) -> Vec2 {
	len := vec2u_len(v)
	return Vec2{x = f32(v.x) / len, y = f32(v.y) / len}
}

vec2u_norm_safe :: proc(v: Vec2u) -> Vec2 {
	len := vec2u_len(v)
	if len == 0.0 {
		return vec2_zero()
	}
	return Vec2{x = f32(v.x) / len, y = f32(v.y) / len}
}

// Range: [0, π]
vec2u_angle_between_unsigned :: proc(a: Vec2u, b: Vec2u) -> f32 {
	cos_angle := f32(vec2u_dot(a, b)) / (vec2u_len(a) * vec2u_len(b))
	return math.acos(cos_angle)
}

Vec3u :: struct {
	x: u32,
	y: u32,
	z: u32,
}

vec3u_new :: proc(x: u32, y: u32, z: u32) -> Vec3u {
	return Vec3u{x = x, y = y, z = z}
}

vec3u_zero :: proc() -> Vec3u {
	return Vec3u{x = 0, y = 0, z = 0}
}

vec3u_one :: proc() -> Vec3u {
	return Vec3u{x = 1, y = 1, z = 1}
}

vec3u_add :: proc(a: Vec3u, b: Vec3u) -> Vec3u {
	return Vec3u{x = a.x + b.x, y = a.y + b.y, z = a.z + b.z}
}

vec3u_sub :: proc(a: Vec3u, b: Vec3u) -> Vec3u {
	return Vec3u{x = a.x - b.x, y = a.y - b.y, z = a.z - b.z}
}

vec3u_mul :: proc(a: Vec3u, b: Vec3u) -> Vec3u {
	return Vec3u{x = a.x * b.x, y = a.y * b.y, z = a.z * b.z}
}

vec3u_div :: proc(a: Vec3u, b: Vec3u) -> Vec3u {
	return Vec3u{x = a.x / b.x, y = a.y / b.y, z = a.z / b.z}
}

vec3u_scale :: proc(v: Vec3u, s: u32) -> Vec3u {
	return Vec3u{x = v.x * s, y = v.y * s, z = v.z * s}
}

vec3u_dot :: proc(a: Vec3u, b: Vec3u) -> u32 {
	return a.x * b.x + a.y * b.y + a.z * b.z
}

vec3u_len :: proc(v: Vec3u) -> f32 {
	return math.sqrt(f32(vec3u_dot(v, v)))
}

vec3u_dst :: proc(a: Vec3u, b: Vec3u) -> f32 {
	return vec3u_len(vec3u_sub(a, b))
}

vec3u_dst_sqr :: proc(a: Vec3u, b: Vec3u) -> u32 {
	diff := vec3u_sub(a, b)
	return vec3u_dot(diff, diff)
}

vec3u_dst_l1 :: proc(a: Vec3u, b: Vec3u) -> u32 {
	return abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z)
}

vec3u_norm :: proc(v: Vec3u) -> Vec3 {
	len := vec3u_len(v)
	return Vec3{x = f32(v.x) / len, y = f32(v.y) / len, z = f32(v.z) / len}
}

vec3u_norm_safe :: proc(v: Vec3u) -> Vec3 {
	len := vec3u_len(v)
	if len == 0.0 {
		return vec3_zero()
	}
	return Vec3{x = f32(v.x) / len, y = f32(v.y) / len, z = f32(v.z) / len}
}

vec3u_cross :: proc(a: Vec3u, b: Vec3u) -> Vec3u {
	return Vec3u{x = a.y * b.z - a.z * b.y, y = a.z * b.x - a.x * b.z, z = a.x * b.y - a.y * b.x}
}

// Range: [0, π]
vec3u_angle_between_unsigned :: proc(a: Vec3u, b: Vec3u) -> f32 {
	cos_angle := f32(vec3u_dot(a, b)) / (vec3u_len(a) * vec3u_len(b))
	return math.acos(cos_angle)
}

Vec4u :: struct {
	x: u32,
	y: u32,
	z: u32,
	w: u32,
}

vec4u_new :: proc(x: u32, y: u32, z: u32, w: u32) -> Vec4u {
	return Vec4u{x = x, y = y, z = z, w = w}
}

vec4u_zero :: proc() -> Vec4u {
	return Vec4u{x = 0, y = 0, z = 0, w = 0}
}

vec4u_one :: proc() -> Vec4u {
	return Vec4u{x = 1, y = 1, z = 1, w = 1}
}

vec4u_add :: proc(a: Vec4u, b: Vec4u) -> Vec4u {
	return Vec4u{x = a.x + b.x, y = a.y + b.y, z = a.z + b.z, w = a.w + b.w}
}

vec4u_sub :: proc(a: Vec4u, b: Vec4u) -> Vec4u {
	return Vec4u{x = a.x - b.x, y = a.y - b.y, z = a.z - b.z, w = a.w - b.w}
}

vec4u_mul :: proc(a: Vec4u, b: Vec4u) -> Vec4u {
	return Vec4u{x = a.x * b.x, y = a.y * b.y, z = a.z * b.z, w = a.w * b.w}
}

vec4u_div :: proc(a: Vec4u, b: Vec4u) -> Vec4u {
	return Vec4u{x = a.x / b.x, y = a.y / b.y, z = a.z / b.z, w = a.w / b.w}
}

vec4u_scale :: proc(v: Vec4u, s: u32) -> Vec4u {
	return Vec4u{x = v.x * s, y = v.y * s, z = v.z * s, w = v.w * s}
}

vec4u_dot :: proc(a: Vec4u, b: Vec4u) -> u32 {
	return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w
}

vec4u_len :: proc(v: Vec4u) -> f32 {
	return math.sqrt(f32(vec4u_dot(v, v)))
}

vec4u_dst :: proc(a: Vec4u, b: Vec4u) -> f32 {
	return vec4u_len(vec4u_sub(a, b))
}

vec4u_dst_sqr :: proc(a: Vec4u, b: Vec4u) -> u32 {
	diff := vec4u_sub(a, b)
	return vec4u_dot(diff, diff)
}

vec4u_dst_l1 :: proc(a: Vec4u, b: Vec4u) -> u32 {
	return abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z) + abs(a.w - b.w)
}

vec4u_norm :: proc(v: Vec4u) -> Vec4 {
	len := vec4u_len(v)
	return Vec4{x = f32(v.x) / len, y = f32(v.y) / len, z = f32(v.z) / len, w = f32(v.w) / len}
}

vec4u_norm_safe :: proc(v: Vec4u) -> Vec4 {
	len := vec4u_len(v)
	if len == 0.0 {
		return vec4_zero()
	}
	return Vec4{x = f32(v.x) / len, y = f32(v.y) / len, z = f32(v.z) / len, w = f32(v.w) / len}
}

// Range: [0, π]
vec4u_angle_between_unsigned :: proc(a: Vec4u, b: Vec4u) -> f32 {
	cos_angle := f32(vec4u_dot(a, b)) / (vec4u_len(a) * vec4u_len(b))
	return math.acos(cos_angle)
}

Mat2 :: matrix[2, 2]f32

mat2_new :: proc(c0: Vec2, c1: Vec2) -> Mat2 {
	//odinfmt: disable
	return Mat2{
		c0.x, c0.y,
		c1.x, c1.y,
	}
	//odinfmt: enable
}

mat2_identity :: proc() -> Mat2 {
	//odinfmt: disable
	return Mat2{
		1.0, 0.0,
		0.0, 1.0,
	}
	//odinfmt: enable
}

mat2_scale :: proc(scale: Vec2) -> Mat2 {
	//odinfmt: disable
	return Mat2{
		scale.x, 0.0,
		0.0, scale.y,
	}
	//odinfmt: enable
}

mat2_rotation :: proc(angle: f32) -> Mat2 {
	c := math.cos(angle)
	s := math.sin(angle)
	//odinfmt: disable
	return Mat2{
		c, s,
		-s, c,
	}
	//odinfmt: enable
}

Mat3 :: matrix[3, 3]f32

mat3_new :: proc(c0: Vec3, c1: Vec3, c2: Vec3) -> Mat3 {
	//odinfmt: disable
	return Mat3{
		c0.x, c0.y, c0.z,
		c1.x, c1.y, c1.z,
		c2.x, c2.y, c2.z,
	}
	//odinfmt: enable
}

mat3_identity :: proc() -> Mat3 {
	//odinfmt: disable
	return Mat3{
		1.0, 0.0, 0.0,
		0.0, 1.0, 0.0,
		0.0, 0.0, 1.0,
	}
	//odinfmt: enable
}

mat3_scale :: proc(scale: Vec3) -> Mat3 {
	//odinfmt: disable
	return Mat3{
		scale.x, 0.0, 0.0,
		0.0, scale.y, 0.0,
		0.0, 0.0, scale.z,
	}
	//odinfmt: enable
}

Mat4 :: matrix[4, 4]f32

mat4_new :: proc(c0: Vec4, c1: Vec4, c2: Vec4, c3: Vec4) -> Mat4 {
	//odinfmt: disable
	return Mat4 {
		c0.x, c0.y, c0.z, c0.w,
		c1.x, c1.y, c1.z, c1.w,
		c2.x, c2.y, c2.z, c2.w,
		c3.x, c3.y, c3.z, c3.w,
	}
	//odinfmt: enable
}

mat4_identity :: proc() -> Mat4 {
	//odinfmt: disable
	return Mat4{
		1.0, 0.0, 0.0, 0.0,
		0.0, 1.0, 0.0, 0.0,
		0.0, 0.0, 1.0, 0.0,
		0.0, 0.0, 0.0, 1.0,
	}
	//odinfmt: enable
}

mat4_scale :: proc(scale: Vec4) -> Mat4 {
	//odinfmt: disable
	return Mat4{
		scale.x, 0.0, 0.0, 0.0,
		0.0, scale.y, 0.0, 0.0,
		0.0, 0.0, scale.z, 0.0,
		0.0, 0.0, 0.0, scale.w,
	}
	//odinfmt: enable
}
