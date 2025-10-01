package game

import "core:log"

Entity :: struct {
	id:       uint,
	active:   bool,
	position: Vec3,
	size:     Vec3,
	variant:  Entity_Variant,
}

Entity_Variant :: union {
	Entity_Player,
	Entity_Enemy,
}

Entity_Player :: struct {
	facing: enum {
		right,
		left,
	},
	action: enum {
		idle,
		running,
		guard,
		attack,
	},
}

Entity_Enemy :: struct {
	velocity: Vec2,
	behavior: Behavior_Range_Activated_Missile,
}

Entity_Pool :: struct {
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

entity_pool_new_entity :: proc(pool: ^Entity_Pool, entity: Entity) -> ^Entity {
	when FRAME_DEBUG {log.debugf("Spawning entity: {}", entity)}

	idx: int
	if len(pool.free_list) > 0 {
		idx = pop(&pool.free_list)
		pool.entities[idx] = entity
	} else {
		idx = len(pool.entities)
		append(&pool.entities, entity)
	}

	log.debugf("Idx: {}, len: {}", idx, len(pool.entities))

	pool.entities[idx].id = uint(idx)
	pool.entities[idx].active = true

	return &pool.entities[idx]
}

entity_pool_remove_entity :: proc(pool: ^Entity_Pool, entity: Entity) {
	log.debugf("Removing entity: {}", entity)

	append(&pool.free_list, int(entity.id))

	// Set everything to zero value, but retain the ID
	pool.entities[entity.id] = Entity{}
	pool.entities[entity.id].id = entity.id
}

