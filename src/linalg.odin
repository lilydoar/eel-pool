package game

Vec2 :: struct {
	x: f32,
	y: f32,
}

Vec3 :: struct {
	x: f32,
	y: f32,
	z: f32,
}

Vec4 :: struct {
	x: f32,
	y: f32,
	z: f32,
	w: f32,
}

Vec2i :: struct {
	x: i32,
	y: i32,
}

Vec3i :: struct {
	x: i32,
	y: i32,
	z: i32,
}

Vec4i :: struct {
	x: i32,
	y: i32,
	z: i32,
	w: i32,
}

Mat3 :: struct {
	x: Vec3,
	y: Vec3,
	z: Vec3,
}

Mat4 :: struct {
	x: Vec4,
	y: Vec4,
	z: Vec4,
	w: Vec4,
}

