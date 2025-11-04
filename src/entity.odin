package game

import "core:log"

Entity_ID :: distinct int

Entity_Flag :: enum {
	Is_Active,
}

Entity_Flags :: bit_set[Entity_Flag]

Entity :: struct {
	id:        Entity_ID,
	flags:     Entity_Flags,
	variant:   Entity_Variant,

	// Parts
	position:  Part_World_Position,
	collision: Part_World_Collision,
	sprite:    Part_Sprite,
	velocity:  Part_Velocity,

	// TODO
	// Fields in scratch are zeroed every frame
	// scratch:   struct {},
}

Entity_Variant :: union {
	Entity_Player,
	Entity_Enemy,
	Entity_Missile,
	Entity_Archer,
}

Entity_Player :: struct {
	facing:         enum {
		right,
		left,
	},
	action:         enum {
		idle,
		running,
		dashing,
		guard,
		attack,
	},
	dash_direction: Vec2,
	movement:       Behavior_Player_Movement,
	dash:           Behavior_Player_Dash,
	mount:          Behavior_Player_Mount,
}

Entity_Enemy :: struct {
	velocity: Vec2,
	behavior: Behavior_Range_Activated_Missile,
}

Entity_Missile :: struct {
	direction: Vec2,
	behavior:  Behavior_Missile,
}

Entity_Archer :: struct {
	behavior: Behavior_Range_Activated_Missle_Spawner,
	facing:   enum {
		right,
		left,
	},
	action:   enum {
		idle,
		running,
		shoot,
	},
}

Entity_Pool :: struct {
	// TODO: Slotmap
	// src/lib/slotmap/slotmap.odin
	entities:  [dynamic]Entity,
	free_list: [dynamic]int,
}

entity_pool_init :: proc() -> Entity_Pool {
	pool: Entity_Pool
	pool.entities = make([dynamic]Entity, 0, 100)
	return pool
}

entity_pool_deinit :: proc(pool: ^Entity_Pool) {
	delete(pool.entities)
}

entity_pool_get_entity :: proc(pool: ^Entity_Pool, id: Entity_ID) -> Entity {
	assert(int(id) >= 0 && int(id) < len(pool.entities))
	return pool.entities[id]
}

entity_pool_get_entity_mut :: proc(pool: ^Entity_Pool, id: Entity_ID) -> ^Entity {
	assert(int(id) >= 0 && int(id) < len(pool.entities))
	return &pool.entities[id]
}

entity_pool_create_entity :: proc(pool: ^Entity_Pool, entity: Entity) -> ^Entity {
	when DEBUG_FRAME {log.debugf("Spawning entity: {}", entity)}

	idx: int
	if len(pool.free_list) > 0 {
		idx = pop(&pool.free_list)
		pool.entities[idx] = entity
	} else {
		idx = len(pool.entities)
		append(&pool.entities, entity)
	}

	when DEBUG_GAME {log.debugf("Idx: {}, len: {}", idx, len(pool.entities))}

	pool.entities[idx].id = Entity_ID(idx)
	pool.entities[idx].flags += {.Is_Active}

	return &pool.entities[idx]
}

entity_pool_destroy_entity :: proc(pool: ^Entity_Pool, entity: Entity) {
	when DEBUG_GAME {log.debugf("Removing entity: {}", entity)}

	append(&pool.free_list, int(entity.id))

	// Set everything to zero value, but retain the ID
	pool.entities[entity.id] = Entity{}
	pool.entities[entity.id].id = entity.id
}

