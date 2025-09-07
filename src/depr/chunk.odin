package game

import smap "./lib/slotmap"

Chunk :: struct {}

// Chunk Handle
Chunk_H :: struct {}

// Chunk Data
Chunk_Data :: smap.SlotMap_Fixed(Chunk, 1024)

// Chunk System
Chunk_S :: struct {
	// Store active chunks
	active_prev:    map[Vec3i]Chunk_H,
	active_curr:    map[Vec3i]Chunk_H,
	active_next:    map[Vec3i]Chunk_H,

	// Store chunks that "could" be active next frame
	potential_next: map[Vec3i]Chunk_H,

	// 
	data:           Chunk_Data,
}

chunk_system_init :: proc() -> (cs: Chunk_S) {
	cs = {
		active_prev    = make(map[Vec3i]Chunk_H),
		active_curr    = make(map[Vec3i]Chunk_H),
		active_next    = make(map[Vec3i]Chunk_H),
		potential_next = make(map[Vec3i]Chunk_H),
	}
	return
}

chunk_system_deinit :: proc(cs: ^Chunk_S) {
	delete(cs.active_prev)
	delete(cs.active_curr)
	delete(cs.active_next)

	delete(cs.potential_next)
}

chunk_system_update :: proc(cs: ^Chunk_S) {
	panic("Not implemented")
}

chunk_system_get :: proc(cs: ^Chunk_S, coord: Vec3i) -> (chunk: Chunk_H, ok: bool) {
	chunk, ok = cs.active_curr[coord]
	return
}

map_clone :: proc(m: map[Vec3i]Chunk_H) -> (out: map[Vec3i]Chunk_H) {
	out = map[Vec3i]Chunk_H{}
	for k, v in m {out[k] = v}
	return out
}

