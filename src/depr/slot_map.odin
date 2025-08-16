package game

import "base:intrinsics"

SlotMapHandle :: struct {
	idx: u32,
	gen: u32,
}

SlotMapItem :: struct($T: typeid) {
	handle: SlotMapHandle,
	item:   T,
}

SlotMapFixed :: struct($T: typeid, $N: int) {
	// There's always a "dummy element" at index 0.
	// This way, a Handle with `idx == 0` means "no Handle".
	items:      [N + 1]SlotMapItem(T),
	num_items:  u32,
	free_items: [N]u32,
	num_free:   u32,
}

clear :: proc(m: ^SlotMapFixed($T, $N)) {
	intrinsics.mem_zero(m, size_of(m^))
}

add :: proc(m: ^SlotMapFixed($T, $N), v: T) -> (SlotMapHandle, bool) {
	// Use a free slot if available.
	if m.num_free > 0 {
		idx := m.free_items[m.num_free - 1]
		gen := m.items[idx].handle.gen

		m.items[idx].handle.gen = gen + 1
		m.items[idx].item = v
		m.num_free -= 1

		return m.items[idx].handle, true
	}

	// Return false if we are at capacity.
	if m.num_items + 1 == len(m.items) {return {}, false}

	// Ensure we always have a "dummy item" at index zero.
	if m.num_items == 0 {
		m.items[0] = {}
		m.num_items += 1
	}

	// Add a new item.
	idx := m.num_items + 1
	gen := m.items[idx].handle.gen

	m.items[idx].item = v
	m.items[idx].handle.gen += 1
	m.num_items += 1

	return item.handle, true
}

get :: proc(m: ^SlotMapFixed($T, $N), h: SlotMapHandle) -> ^T {
	if h.idx <= 0 || h.idx >= m.num_items {return nil}
	if m.items[h.idx].handle != h {return nil}
	return &m.items[h.idx].item
}

remove :: proc(m: ^SlotMapFixed($T, $N), h: SlotMapHandle) {
	if h.idx <= 0 || h.idx >= m.num_items {return}
	if m.items[h.idx].handle != h {return}

	m.free_items[m.num_free] = h.idx
	m.num_free += 1
	m.items[h.idx].handle.gen += 1
}

valid :: proc(m: SlotMapFixed($T, $N), h: SlotMapHandle) -> bool {
	if h.idx <= 0 || h.idx >= m.num_items {return false}
	if m.items[h.idx].handle != h {return false}
	return true
}

cap :: proc(m: SlotMapFixed($T, $N)) -> int {
	return N
}

// For iterating a handle map. Create using `make_iter`.
SlotMapFixedIterator :: struct($T: typeid, $N: int) {
	m:     ^SlotMapFixed(T, N),
	index: u32,
}

make_iter :: proc(m: ^SlotMapFixed($T, $N)) -> SlotMapFixedIterator(T, N) {
	return {m = m, index = 1}
}

// Iterate over the handle map. Skips unused slots, meaning that it skips slots
// with handle.idx == 0.
//
// Usage:
//     my_iter := hm.make_iter(&my_handle_map)
//     for e in hm.iter(&my_iter) {}
// 
// Instead of using an iterator you can also loop over `items` and check if
// `item.handle.idx == 0` and in that case skip that item.
iter :: proc(it: ^SlotMapFixedIterator($T, $N)) -> (^T, SlotMapHandle, bool) {
	for _ in it.index ..< it.m.num_items {
		// item := &it.m.items[it.index]
		it.index += 1

		// if item.handle.idx != 0 {
		// 	return item, item.handle, true
		// }
	}

	// TODO
	// Since I'm not editing the idx field on the how am I going to efficiently do the check of whether or not the slot is in use?
	// The example implementation sets the idx to 0 when not in use
	// I could do something similar. Set to 0 when not in use, set to actual idx when in use.
	// Maybe it is worth it to just have the type include the handle field itself. Could be a good pattern. Not sure though

	return nil, {}, false
}

