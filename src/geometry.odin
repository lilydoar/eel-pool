package game

import "core:math"

DEG_TO_RAD: f32 : math.PI / 180.0
RAD_TO_DEG: f32 : 180.0 / math.PI

deg_to_rad :: proc(deg: f32) -> f32 {return deg * DEG_TO_RAD}
rad_to_deg :: proc(rad: f32) -> f32 {return rad * RAD_TO_DEG}

lerp :: proc(a: f32, b: f32, t: f32) -> f32 {
	return a + (b - a) * t
}

clamp :: proc(v: f32, min: f32, max: f32) -> f32 {
	if v < min {
		return min
	} else if v > max {
		return max
	}
	return v
}

Line2 :: struct {
	a: Vec2,
	b: Vec2,
}

line2_new :: proc(a: Vec2, b: Vec2) -> Line2 {
	return Line2{a = a, b = b}
}

line2_len :: proc(line: Line2) -> f32 {
	return vec2_dst(line.a, line.b)
}

line2_center :: proc(line: Line2) -> Vec2 {
	return vec2_scale(vec2_add(line.a, line.b), 0.5)
}

line2_dir :: proc(line: Line2) -> Vec2 {
	return vec2_norm_safe(vec2_sub(line.b, line.a))
}

line2_at :: proc(line: Line2, t: f32) -> Vec2 {
	return vec2_add(line.a, vec2_scale(vec2_sub(line.b, line.a), t))
}

Line2i :: struct {
	a: Vec2i,
	b: Vec2i,
}

line2i_new :: proc(a: Vec2i, b: Vec2i) -> Line2i {
	return Line2i{a = a, b = b}
}

line2i_len :: proc(line: Line2i) -> f32 {
	return vec2i_dst(line.a, line.b)
}

line2i_center :: proc(line: Line2i) -> Vec2 {
	return vec2_scale(
		vec2_add(Vec2{f32(line.a.x), f32(line.a.y)}, Vec2{f32(line.b.x), f32(line.b.y)}),
		0.5,
	)
}

line2i_dir :: proc(line: Line2i) -> Vec2 {
	return vec2i_norm_safe(vec2i_sub(line.b, line.a))
}

line2i_at :: proc(line: Line2i, t: f32) -> Vec2 {
	return vec2_add(
		Vec2{f32(line.a.x), f32(line.a.y)},
		vec2_scale(
			vec2_sub(Vec2{f32(line.b.x), f32(line.b.y)}, Vec2{f32(line.a.x), f32(line.a.y)}),
			t,
		),
	)
}

Line3 :: struct {
	a: Vec3,
	b: Vec3,
}

line3_new :: proc(a: Vec3, b: Vec3) -> Line3 {
	return Line3{a = a, b = b}
}

line3_len :: proc(line: Line3) -> f32 {
	return vec3_dst(line.a, line.b)
}

line3_center :: proc(line: Line3) -> Vec3 {
	return vec3_scale(vec3_add(line.a, line.b), 0.5)
}

line3_dir :: proc(line: Line3) -> Vec3 {
	return vec3_norm_safe(vec3_sub(line.b, line.a))
}

line3_at :: proc(line: Line3, t: f32) -> Vec3 {
	return vec3_add(line.a, vec3_scale(vec3_sub(line.b, line.a), t))
}

Line3i :: struct {
	a: Vec3i,
	b: Vec3i,
}

line3i_new :: proc(a: Vec3i, b: Vec3i) -> Line3i {
	return Line3i{a = a, b = b}
}

line3i_len :: proc(line: Line3i) -> f32 {
	return vec3i_dst(line.a, line.b)
}

line3i_center :: proc(line: Line3i) -> Vec3 {
	return vec3_scale(
		vec3_add(
			Vec3{f32(line.a.x), f32(line.a.y), f32(line.a.z)},
			Vec3{f32(line.b.x), f32(line.b.y), f32(line.b.z)},
		),
		0.5,
	)
}

line3i_dir :: proc(line: Line3i) -> Vec3 {
	return vec3i_norm_safe(vec3i_sub(line.b, line.a))
}

line3i_at :: proc(line: Line3i, t: f32) -> Vec3 {
	return vec3_add(
		Vec3{f32(line.a.x), f32(line.a.y), f32(line.a.z)},
		vec3_scale(
			vec3_sub(
				Vec3{f32(line.b.x), f32(line.b.y), f32(line.b.z)},
				Vec3{f32(line.a.x), f32(line.a.y), f32(line.a.z)},
			),
			t,
		),
	)
}

Ray2 :: struct {
	origin:    Vec2,
	direction: Vec2,
}

ray2_new :: proc(origin: Vec2, dir: Vec2) -> Ray2 {
	return Ray2{origin = origin, direction = dir}
}

ray2_new_safe :: proc(origin: Vec2, dir: Vec2) -> Ray2 {
	return Ray2{origin = origin, direction = vec2_norm_safe(dir)}
}

ray2_at :: proc(ray: Ray2, t: f32) -> Vec2 {
	return vec2_add(ray.origin, vec2_scale(ray.direction, t))
}

Ray3 :: struct {
	origin:    Vec3,
	direction: Vec3,
}

ray3_new :: proc(origin: Vec3, dir: Vec3) -> Ray3 {
	return Ray3{origin = origin, direction = dir}
}

ray3_new_safe :: proc(origin: Vec3, dir: Vec3) -> Ray3 {
	return Ray3{origin = origin, direction = vec3_norm_safe(dir)}
}

ray3_at :: proc(ray: Ray3, t: f32) -> Vec3 {
	return vec3_add(ray.origin, vec3_scale(ray.direction, t))
}

Circle :: struct {
	center: Vec2,
	radius: f32,
}

circle_new :: proc(center: Vec2, radius: f32) -> Circle {
	return Circle{center = center, radius = radius}
}

circle_contains :: proc(circle: Circle, point: Vec2) -> bool {
	return vec2_dst(circle.center, point) <= circle.radius
}

circle_intersects :: proc(a: Circle, b: Circle) -> bool {
	return vec2_dst(a.center, b.center) <= a.radius + b.radius
}

Sphere :: struct {
	center: Vec3,
	radius: f32,
}

sphere_new :: proc(center: Vec3, radius: f32) -> Sphere {
	return Sphere{center = center, radius = radius}
}

sphere_contains :: proc(sphere: Sphere, point: Vec3) -> bool {
	return vec3_dst(sphere.center, point) <= sphere.radius
}

sphere_intersects :: proc(a: Sphere, b: Sphere) -> bool {
	return vec3_dst(a.center, b.center) <= a.radius + b.radius
}

AABB2 :: struct {
	min: Vec2,
	max: Vec2,
}

aabb2_new :: proc(min: Vec2, max: Vec2) -> AABB2 {
	return AABB2{min = min, max = max}
}

aabb2_new_safe :: proc(a: Vec2, b: Vec2) -> AABB2 {
	min := Vec2 {
		x = math.min(a.x, b.x),
		y = math.min(a.y, b.y),
	}
	max := Vec2 {
		x = math.max(a.x, b.x),
		y = math.max(a.y, b.y),
	}
	return AABB2{min = min, max = max}
}

aabb2_center :: proc(aabb: AABB2) -> Vec2 {
	return vec2_scale(vec2_add(aabb.min, aabb.max), 0.5)
}

aabb2_contains :: proc(aabb: AABB2, point: Vec2) -> bool {
	return(
		point.x >= aabb.min.x &&
		point.x <= aabb.max.x &&
		point.y >= aabb.min.y &&
		point.y <= aabb.max.y \
	)
}

aabb2_intersects :: proc(a: AABB2, b: AABB2) -> bool {
	return a.min.x <= b.max.x && a.max.x >= b.min.x && a.min.y <= b.max.y && a.max.y >= b.min.y
}

aabb2_intersection :: proc(a: AABB2, b: AABB2) -> (bool, AABB2) {
	if !aabb2_intersects(a, b) {
		return false, {}
	}

	min := Vec2 {
		x = math.max(a.min.x, b.min.x),
		y = math.max(a.min.y, b.min.y),
	}
	max := Vec2 {
		x = math.min(a.max.x, b.max.x),
		y = math.min(a.max.y, b.max.y),
	}
	return true, AABB2{min = min, max = max}
}

aabb2_bounding :: proc(a: AABB2, b: AABB2) -> AABB2 {
	min := Vec2 {
		x = math.min(a.min.x, b.min.x),
		y = math.min(a.min.y, b.min.y),
	}
	max := Vec2 {
		x = math.max(a.max.x, b.max.x),
		y = math.max(a.max.y, b.max.y),
	}
	return AABB2{min = min, max = max}
}

AABB2i :: struct {
	min: Vec2i,
	max: Vec2i,
}

aabb2i_new :: proc(min: Vec2i, max: Vec2i) -> AABB2i {
	return AABB2i{min = min, max = max}
}

aabb2i_new_safe :: proc(a: Vec2i, b: Vec2i) -> AABB2i {
	min := Vec2i {
		x = math.min(a.x, b.x),
		y = math.min(a.y, b.y),
	}
	max := Vec2i {
		x = math.max(a.x, b.x),
		y = math.max(a.y, b.y),
	}
	return AABB2i{min = min, max = max}
}

aabb2i_center :: proc(aabb: AABB2i) -> Vec2 {
	return vec2_scale(
		vec2_add(Vec2{f32(aabb.min.x), f32(aabb.min.y)}, Vec2{f32(aabb.max.x), f32(aabb.max.y)}),
		0.5,
	)
}

aabb2i_contains :: proc(aabb: AABB2i, point: Vec2i) -> bool {
	return(
		point.x >= aabb.min.x &&
		point.x <= aabb.max.x &&
		point.y >= aabb.min.y &&
		point.y <= aabb.max.y \
	)
}

aabb2i_intersects :: proc(a: AABB2i, b: AABB2i) -> bool {
	return a.min.x <= b.max.x && a.max.x >= b.min.x && a.min.y <= b.max.y && a.max.y >= b.min.y
}

aabb2i_intersection :: proc(a: AABB2i, b: AABB2i) -> (bool, AABB2i) {
	if !aabb2i_intersects(a, b) {
		return false, {}
	}

	min := Vec2i {
		x = math.max(a.min.x, b.min.x),
		y = math.max(a.min.y, b.min.y),
	}
	max := Vec2i {
		x = math.min(a.max.x, b.max.x),
		y = math.min(a.max.y, b.max.y),
	}
	return true, AABB2i{min = min, max = max}
}

aabb2i_bounding :: proc(a: AABB2i, b: AABB2i) -> AABB2i {
	min := Vec2i {
		x = math.min(a.min.x, b.min.x),
		y = math.min(a.min.y, b.min.y),
	}
	max := Vec2i {
		x = math.max(a.max.x, b.max.x),
		y = math.max(a.max.y, b.max.y),
	}
	return AABB2i{min = min, max = max}
}

AABB3 :: struct {
	min: Vec3,
	max: Vec3,
}

aabb3_new :: proc(min: Vec3, max: Vec3) -> AABB3 {
	return AABB3{min = min, max = max}
}

aabb3_new_safe :: proc(a: Vec3, b: Vec3) -> AABB3 {
	min := Vec3 {
		x = math.min(a.x, b.x),
		y = math.min(a.y, b.y),
		z = math.min(a.z, b.z),
	}
	max := Vec3 {
		x = math.max(a.x, b.x),
		y = math.max(a.y, b.y),
		z = math.max(a.z, b.z),
	}
	return AABB3{min = min, max = max}
}

aabb3_center :: proc(aabb: AABB3) -> Vec3 {
	return vec3_scale(vec3_add(aabb.min, aabb.max), 0.5)
}

aabb3_contains :: proc(aabb: AABB3, point: Vec3) -> bool {
	return(
		point.x >= aabb.min.x &&
		point.x <= aabb.max.x &&
		point.y >= aabb.min.y &&
		point.y <= aabb.max.y &&
		point.z >= aabb.min.z &&
		point.z <= aabb.max.z \
	)
}

aabb3_intersects :: proc(a: AABB3, b: AABB3) -> bool {
	return(
		a.min.x <= b.max.x &&
		a.max.x >= b.min.x &&
		a.min.y <= b.max.y &&
		a.max.y >= b.min.y &&
		a.min.z <= b.max.z &&
		a.max.z >= b.min.z \
	)
}

aabb3_intersection :: proc(a: AABB3, b: AABB3) -> (bool, AABB3) {
	if !aabb3_intersects(a, b) {
		return false, {}
	}

	min := Vec3 {
		x = math.max(a.min.x, b.min.x),
		y = math.max(a.min.y, b.min.y),
		z = math.max(a.min.z, b.min.z),
	}
	max := Vec3 {
		x = math.min(a.max.x, b.max.x),
		y = math.min(a.max.y, b.max.y),
		z = math.min(a.max.z, b.max.z),
	}
	return true, AABB3{min = min, max = max}
}

aabb3_bounding :: proc(a: AABB3, b: AABB3) -> AABB3 {
	min := Vec3 {
		x = math.min(a.min.x, b.min.x),
		y = math.min(a.min.y, b.min.y),
		z = math.min(a.min.z, b.min.z),
	}
	max := Vec3 {
		x = math.max(a.max.x, b.max.x),
		y = math.max(a.max.y, b.max.y),
		z = math.max(a.max.z, b.max.z),
	}
	return AABB3{min = min, max = max}
}

AABB3i :: struct {
	min: Vec3i,
	max: Vec3i,
}

aabb3i_new :: proc(min: Vec3i, max: Vec3i) -> AABB3i {
	return AABB3i{min = min, max = max}
}

aabb3i_new_safe :: proc(a: Vec3i, b: Vec3i) -> AABB3i {
	min := Vec3i {
		x = math.min(a.x, b.x),
		y = math.min(a.y, b.y),
		z = math.min(a.z, b.z),
	}
	max := Vec3i {
		x = math.max(a.x, b.x),
		y = math.max(a.y, b.y),
		z = math.max(a.z, b.z),
	}
	return AABB3i{min = min, max = max}
}

aabb3i_center :: proc(aabb: AABB3i) -> Vec3 {
	return vec3_scale(
		vec3_add(
			Vec3{f32(aabb.min.x), f32(aabb.min.y), f32(aabb.min.z)},
			Vec3{f32(aabb.max.x), f32(aabb.max.y), f32(aabb.max.z)},
		),
		0.5,
	)
}

aabb3i_contains :: proc(aabb: AABB3i, point: Vec3i) -> bool {
	return(
		point.x >= aabb.min.x &&
		point.x <= aabb.max.x &&
		point.y >= aabb.min.y &&
		point.y <= aabb.max.y &&
		point.z >= aabb.min.z &&
		point.z <= aabb.max.z \
	)
}

aabb3i_intersects :: proc(a: AABB3i, b: AABB3i) -> bool {
	return(
		a.min.x <= b.max.x &&
		a.max.x >= b.min.x &&
		a.min.y <= b.max.y &&
		a.max.y >= b.min.y &&
		a.min.z <= b.max.z &&
		a.max.z >= b.min.z \
	)
}

aabb3i_intersection :: proc(a: AABB3i, b: AABB3i) -> (bool, AABB3i) {
	if !aabb3i_intersects(a, b) {
		return false, {}
	}

	min := Vec3i {
		x = math.max(a.min.x, b.min.x),
		y = math.max(a.min.y, b.min.y),
		z = math.max(a.min.z, b.min.z),
	}
	max := Vec3i {
		x = math.min(a.max.x, b.max.x),
		y = math.min(a.max.y, b.max.y),
		z = math.min(a.max.z, b.max.z),
	}
	return true, AABB3i{min = min, max = max}
}

aabb3i_bounding :: proc(a: AABB3i, b: AABB3i) -> AABB3i {
	min := Vec3i {
		x = math.min(a.min.x, b.min.x),
		y = math.min(a.min.y, b.min.y),
		z = math.min(a.min.z, b.min.z),
	}
	max := Vec3i {
		x = math.max(a.max.x, b.max.x),
		y = math.max(a.max.y, b.max.y),
		z = math.max(a.max.z, b.max.z),
	}
	return AABB3i{min = min, max = max}
}

