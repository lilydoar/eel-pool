package game

// C_ prefix stands for "Component"

C_World_Position :: distinct Vec3

C_World_Collision :: union {
	AABB2,
	Circle,
}

C_Sprite :: struct {
	world_size:   Vec2,
	world_offset: Vec2,
}

