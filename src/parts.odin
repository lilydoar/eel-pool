package game

// Parts are the unit of composition for game entities.

Part_World_Position :: distinct Vec3

Part_World_Collision :: union {
	AABB2,
	Circle,
}

Part_Sprite :: struct {
	world_size:   Vec2,
	world_offset: Vec2,
}
