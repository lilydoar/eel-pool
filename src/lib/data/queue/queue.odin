package queue

import "base:intrinsics"
import virtual "core:mem/virtual"

Queue_Circular :: struct($T: typeid, $N: u32) {
	data:  [N]T,
	first: u32,
	last:  u32,
}

// Used to iterate the items in the queue without altering the queue
Queue_Circular_Iter :: struct($T: typeid, $N: u32) {
	q:   ^Queue_Circular,
	idx: u32,
}

queue_circular_empty :: proc($T: typeid, $N: u32) {
	return Queue_Circular(T, N){}
}

queue_circular_clear :: proc(q: ^Queue_Circular($T, $N)) {
	intrinsics.mem_zero(q, size_of(q^))
}

queue_circular_push :: proc(q: ^Queue_Circular($T, $N), item: T) -> (ok: bool) {
	idx = (q.last + 1) % N
	if idx == q.first {return}

	q.data[idx] = item
	q.last = idx

	return true
}

queue_circular_peek :: proc(q: ^Queue_Circular($T, $N)) -> (item: T, ok: bool) {
	if q.first == q.last {return}

	return q.data[q.first], true
}

queue_circular_pop :: proc(q: ^Queue_Circular($T, $N)) -> (item: T, ok: bool) {
	if q.first == q.last {return}

	item = q.data[q.first]
	q.first += 1

	return item, true
}

queue_circular_idx_is_valid :: proc(q: ^Queue_Circular($T, $N), idx: u32) -> (ok: bool) {
	if q.first == q.last {return false}
	if idx >= N {return false}

	// Handle is valid if it is between first and last, wrapping around if necessary
	if q.first < q.last {
		return idx >= q.first && idx < q.last
	} else {
		return idx >= q.first || idx < q.last
	}
}

queue_circular_len :: proc(q: ^Queue_Circular($T, $N)) -> (len: u32) {
	if q.first <= q.last {
		return q.last - q.first
	} else {
		return (N - q.first) + q.last
	}
}

queue_circular_make_iter :: proc(q: ^Queue_Circular($T, $N)) -> (iter: Queue_Circular_Iter(T, N)) {
	return Queue_Circular_Iter(T, N){.q = q, .idx = q.first}
}

queue_circular_iter_next :: proc(iter: ^Queue_Circular_Iter($T, $N)) -> (item: T, ok: bool) {
	if !queue_circular_idx_is_valid(iter.q, iter.idx) {return}

	item = iter.q.data[iter.idx]
	iter.idx = (iter.idx + 1) % N

	return item, true
}

// TODO: Tests
// @(test)
// slotmap_do_tests :: proc(t: ^testing.T) {
// 	// Test 11: Iterator Functionality
// 	// - Create iterator with slotmap_fixed_make_iter
// 	// - Iterate through populated slotmap
// 	// - Verify iteration visits all valid elements exactly once
// 	// - Verify iteration skips removed/invalid slots
// 	// - Test iteration on empty slotmap
// 	// - Test iteration after removes create gaps
// 	// test_smap_iterator_functionality(t)
//
// 	// Test 12: Stress Testing
// 	// - Perform many insert/remove operations in random order
// 	// - Verify invariants maintained throughout:
// 	//   - num_data + num_free <= N
// 	//   - All valid handles point to correct data
// 	//   - Free list contains only removed slots
// 	//   - Generations increment properly on reuse
// 	// test_smap_stress_testing(t)
// }

// virtual.Arena

// mem.Arena

// mem.Arena

// // Initialization of an `Arena` to be a `.Static` variant.
// // A static arena contains a single `Memory_Block` allocated with virtual memory.
// @(require_results, no_sanitize_address)
// arena_init_static :: proc(arena: ^Arena, reserved: uint = DEFAULT_ARENA_STATIC_RESERVE_SIZE, commit_size: uint = DEFAULT_ARENA_STATIC_COMMIT_SIZE) -> (err: Allocator_Error) {
// 	arena.kind           = .Static
// 	arena.curr_block     = memory_block_alloc(commit_size, reserved, {}) or_return
// 	arena.total_used     = 0
// 	arena.total_reserved = arena.curr_block.reserved
// 	// sanitizer.address_poison(arena.curr_block.base[:arena.curr_block.committed])
// 	return
// }
