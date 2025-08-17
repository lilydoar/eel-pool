package slotmap

import "base:intrinsics"
import "base:runtime"
import "core:log"
import "core:math/rand"
import "core:testing"

SlotMap_Handle :: struct {
	idx: u32,
	gen: u32,
}

SlotMap_Fixed :: struct($T: typeid, $N: u32) {
	num_data:  u32,
	num_free:  u32,
	data:      [N]T,
	gens:      [N]u32,
	free_list: [N]u32,
}

SlotMap_Fixed_Iter :: struct($T: typeid, $N: u32) {
	sm:  ^SlotMap_Fixed(T, N),
	idx: u32,
}

slotmap_fixed_empty :: proc($T: typeid, $N: u32) -> (sm: SlotMap_Fixed(T, N)) {
	sm = SlotMap_Fixed(T, N){}
	return
}

slotmap_fixed_clear :: proc(m: ^SlotMap_Fixed($T, $N)) {
	intrinsics.mem_zero(m, size_of(m^))
}

slotmap_fixed_insert :: proc(
	m: ^SlotMap_Fixed($T, $N),
	v: T,
) -> (
	handle: SlotMap_Handle,
	ok: bool,
) {
	// If we have any free slots open, we should use them first
	if m.num_free > 0 {
		idx := m.free_list[m.num_free - 1]

		m.num_data += 1
		m.num_free -= 1
		m.data[idx] = v
		m.gens[idx] += 1

		return SlotMap_Handle{idx = idx, gen = m.gens[idx]}, true
	}

	// If we have no free slots and are at max capacity, we cannot insert an item
	if m.num_data >= len(m.data) {return}

	// Insert a new item
	idx := m.num_data

	m.num_data += 1
	m.data[idx] = v
	m.gens[idx] += 1

	return SlotMap_Handle{idx = idx, gen = m.gens[idx]}, true
}

slotmap_fixed_remove :: proc(
	m: ^SlotMap_Fixed($T, $N),
	handle: SlotMap_Handle,
) -> (
	data: T,
	ok: bool,
) {
	assert(slotmap_fixed_is_valid(m, handle))

	idx := handle.idx
	gen := handle.gen

	m.num_data -= 1
	data = m.data[idx]
	m.data[idx] = T{}
	m.gens[idx] += 1

	m.free_list[m.num_free] = idx
	m.num_free += 1

	return data, true
}

slotmap_fixed_get :: proc(m: ^SlotMap_Fixed($T, $N), handle: SlotMap_Handle) -> (v: ^T, ok: bool) {
	assert(slotmap_fixed_is_valid(m, handle))
	return &m.data[handle.idx], true
}

slotmap_fixed_is_valid :: proc(m: ^SlotMap_Fixed($T, $N), handle: SlotMap_Handle) -> (ok: bool) {
	if handle.idx >= N {return false}
	if m.gens[handle.idx] != handle.gen {return false}
	return true
}

slotmap_fixed_capacity :: proc(m: ^SlotMap_Fixed($T, $N)) -> (cap: u32) {
	return len(m.data)
}

slotmap_fixed_len :: proc(m: ^SlotMap_Fixed($T, $N)) -> (len: u32) {
	return m.num_data
}

slotmap_fixed_make_iter :: proc(m: ^SlotMap_Fixed($T, $N)) -> (iter: SlotMap_Fixed_Iter(T, N)) {
	iter = SlotMap_Fixed_Iter(T, N) {
		sm = m,
	}

	log.panic("Not implemented")
	return
}

@(test)
slotmap_do_tests :: proc(t: ^testing.T) {
	// Test 11: Iterator Functionality
	// - Create iterator with slotmap_fixed_make_iter
	// - Iterate through populated slotmap
	// - Verify iteration visits all valid elements exactly once
	// - Verify iteration skips removed/invalid slots
	// - Test iteration on empty slotmap
	// - Test iteration after removes create gaps
	// test_smap_iterator_functionality(t)

	// Test 12: Stress Testing
	// - Perform many insert/remove operations in random order
	// - Verify invariants maintained throughout:
	//   - num_data + num_free <= N
	//   - All valid handles point to correct data
	//   - Free list contains only removed slots
	//   - Generations increment properly on reuse
	// test_smap_stress_testing(t)
}

@(test)
test_smap_basic_creation_and_initialization :: proc(t: ^testing.T) {
	smap := slotmap_fixed_empty(int, 10)

	testing.expect(t, slotmap_fixed_len(&smap) == 0, "num_data to be 0 on creation")
	testing.expect(t, smap.num_free == 0, "num_free to be 0 on creation")

	for i in 0 ..< slotmap_fixed_capacity(&smap) {
		testing.expect(t, smap.gens[i] == 0, "all generations to start at 0")
	}
}

@(test)
test_smap_single_insert_operation :: proc(t: ^testing.T) {
	smap := slotmap_fixed_empty(int, 10)

	handle, ok := slotmap_fixed_insert(&smap, 42)

	testing.expect(t, ok, "insert to succeed")
	testing.expect(t, handle.idx == 0, "first handle idx to be 0")
	testing.expect(t, handle.gen == 1, "first handle gen to be 1")
	testing.expect(t, slotmap_fixed_len(&smap) == 1, "num_data to be 1 after insert")

	is_valid := slotmap_fixed_is_valid(&smap, handle)
	testing.expect(t, is_valid, "handle to be valid")

	value, get_ok := slotmap_fixed_get(&smap, handle)
	testing.expect(t, get_ok, "get to succeed")
	testing.expect(t, value^ == 42, "retrieved value to match inserted value")
}

@(test)
test_smap_multiple_insert_operations :: proc(t: ^testing.T) {
	smap := slotmap_fixed_empty(int, 10)

	// Insert multiple elements
	handle1, ok1 := slotmap_fixed_insert(&smap, 100)
	testing.expect(t, ok1, "first insert to succeed")
	testing.expect(t, handle1.idx == 0, "first handle idx to be 0")
	testing.expect(t, handle1.gen == 1, "first handle gen to be 1")

	handle2, ok2 := slotmap_fixed_insert(&smap, 200)
	testing.expect(t, ok2, "second insert to succeed")
	testing.expect(t, handle2.idx == 1, "second handle idx to be 1")
	testing.expect(t, handle2.gen == 1, "second handle gen to be 1")

	handle3, ok3 := slotmap_fixed_insert(&smap, 300)
	testing.expect(t, ok3, "third insert to succeed")
	testing.expect(t, handle3.idx == 2, "third handle idx to be 2")
	testing.expect(t, handle3.gen == 1, "third handle gen to be 1")

	handle4, ok4 := slotmap_fixed_insert(&smap, 400)
	testing.expect(t, ok4, "fourth insert to succeed")
	testing.expect(t, handle4.idx == 3, "fourth handle idx to be 3")
	testing.expect(t, handle4.gen == 1, "fourth handle gen to be 1")

	// Verify num_data increases correctly
	testing.expect(t, slotmap_fixed_len(&smap) == 4, "num_data to be 4 after inserts")

	// Verify all handles remain valid
	testing.expect(t, slotmap_fixed_is_valid(&smap, handle1), "handle1 to be valid")
	testing.expect(t, slotmap_fixed_is_valid(&smap, handle2), "handle2 to be valid")
	testing.expect(t, slotmap_fixed_is_valid(&smap, handle3), "handle3 to be valid")
	testing.expect(t, slotmap_fixed_is_valid(&smap, handle4), "handle4 to be valid")

	// Verify all elements can be retrieved correctly
	value1, get_ok1 := slotmap_fixed_get(&smap, handle1)
	testing.expect(t, get_ok1 && value1^ == 100, "handle1 to retrieve correct value")

	value2, get_ok2 := slotmap_fixed_get(&smap, handle2)
	testing.expect(t, get_ok2 && value2^ == 200, "handle2 to retrieve correct value")

	value3, get_ok3 := slotmap_fixed_get(&smap, handle3)
	testing.expect(t, get_ok3 && value3^ == 300, "handle3 to retrieve correct value")

	value4, get_ok4 := slotmap_fixed_get(&smap, handle4)
	testing.expect(t, get_ok4 && value4^ == 400, "handle4 to retrieve correct value")
}

@(test)
test_smap_capacity_limits :: proc(t: ^testing.T) {
	smap := slotmap_fixed_empty(int, 3)

	// Fill slotmap to capacity
	handle1, ok1 := slotmap_fixed_insert(&smap, 10)
	testing.expect(t, ok1, "first insert to succeed")

	handle2, ok2 := slotmap_fixed_insert(&smap, 20)
	testing.expect(t, ok2, "second insert to succeed")

	handle3, ok3 := slotmap_fixed_insert(&smap, 30)
	testing.expect(t, ok3, "third insert to succeed")

	testing.expect(
		t,
		slotmap_fixed_len(&smap) == slotmap_fixed_capacity(&smap),
		"num_data to be at capacity",
	)

	// Attempt to insert one more element
	handle4, ok4 := slotmap_fixed_insert(&smap, 40)
	testing.expect(t, !ok4, "insert beyond capacity to fail")
	testing.expect(
		t,
		slotmap_fixed_len(&smap) == slotmap_fixed_capacity(&smap),
		"num_data to stay at capacity",
	)

	// Verify existing handles still work
	testing.expect(t, slotmap_fixed_is_valid(&smap, handle1), "handle1 to remain valid")
	testing.expect(t, slotmap_fixed_is_valid(&smap, handle2), "handle2 to remain valid")
	testing.expect(t, slotmap_fixed_is_valid(&smap, handle3), "handle3 to remain valid")
}

@(test)
test_smap_remove_operation :: proc(t: ^testing.T) {
	smap := slotmap_fixed_empty(int, 10)

	// Insert several elements
	handle1, _ := slotmap_fixed_insert(&smap, 10)
	handle2, _ := slotmap_fixed_insert(&smap, 20)
	handle3, _ := slotmap_fixed_insert(&smap, 30)

	testing.expect(t, slotmap_fixed_len(&smap) == 3, "num_data to be 3 before removal")
	testing.expect(t, smap.num_free == 0, "num_free to be 0 before removal")

	// Remove middle element
	data, ok := slotmap_fixed_remove(&smap, handle2)
	testing.expect(t, ok, "remove to succeed")
	testing.expect(t, data == 20, "removed data to match inserted value")

	// Verify handle becomes invalid
	testing.expect(t, !slotmap_fixed_is_valid(&smap, handle2), "removed handle to be invalid")

	// Verify counters updated
	testing.expect(t, slotmap_fixed_len(&smap) == 2, "num_data to decrease to 2 after removal")
	testing.expect(t, smap.num_free == 1, "num_free to increase after removal")

	// Verify other handles still valid
	testing.expect(t, slotmap_fixed_is_valid(&smap, handle1), "handle1 to remain valid")
	testing.expect(t, slotmap_fixed_is_valid(&smap, handle3), "handle3 to remain valid")

	// Verify other elements still accessible
	value1, ok1 := slotmap_fixed_get(&smap, handle1)
	testing.expect(t, ok1 && value1^ == 10, "handle1 to retrieve correct value")

	value3, ok3 := slotmap_fixed_get(&smap, handle3)
	testing.expect(t, ok3 && value3^ == 30, "handle3 to retrieve correct value")
}

@(test)
test_smap_multiple_remove_operations :: proc(t: ^testing.T) {
	smap := slotmap_fixed_empty(int, 10)

	// Insert 5 elements
	handle1, _ := slotmap_fixed_insert(&smap, 10)
	handle2, _ := slotmap_fixed_insert(&smap, 20)
	handle3, _ := slotmap_fixed_insert(&smap, 30)
	handle4, _ := slotmap_fixed_insert(&smap, 40)
	handle5, _ := slotmap_fixed_insert(&smap, 50)

	testing.expect(t, slotmap_fixed_len(&smap) == 5, "num_data to be 5 after inserts")
	testing.expect(t, smap.num_free == 0, "num_free to be 0 before removals")

	// Remove multiple elements in different order
	data2, ok2 := slotmap_fixed_remove(&smap, handle2) // Remove index 1
	testing.expect(t, ok2, "remove handle2 to succeed")
	testing.expect(t, data2 == 20, "removed data2 to match inserted value")
	testing.expect(t, !slotmap_fixed_is_valid(&smap, handle2), "handle2 to be invalid")
	testing.expect(
		t,
		slotmap_fixed_len(&smap) == 4,
		"num_data to decrease to 4 after first removal",
	)
	testing.expect(t, smap.num_free == 1, "num_free to be 1 after first removal")

	data4, ok4 := slotmap_fixed_remove(&smap, handle4) // Remove index 3
	testing.expect(t, ok4, "remove handle4 to succeed")
	testing.expect(t, data4 == 40, "removed data4 to match inserted value")
	testing.expect(t, !slotmap_fixed_is_valid(&smap, handle4), "handle4 to be invalid")
	testing.expect(
		t,
		slotmap_fixed_len(&smap) == 3,
		"num_data to decrease to 3 after second removal",
	)
	testing.expect(t, smap.num_free == 2, "num_free to be 2 after second removal")

	data1, ok1 := slotmap_fixed_remove(&smap, handle1) // Remove index 0
	testing.expect(t, ok1, "remove handle1 to succeed")
	testing.expect(t, data1 == 10, "removed data1 to match inserted value")
	testing.expect(t, !slotmap_fixed_is_valid(&smap, handle1), "handle1 to be invalid")
	testing.expect(
		t,
		slotmap_fixed_len(&smap) == 2,
		"num_data to decrease to 2 after third removal",
	)
	testing.expect(t, smap.num_free == 3, "num_free to be 3 after third removal")

	// Verify remaining handles are still valid
	testing.expect(t, slotmap_fixed_is_valid(&smap, handle3), "handle3 to remain valid")
	testing.expect(t, slotmap_fixed_is_valid(&smap, handle5), "handle5 to remain valid")

	// Verify remaining elements can be accessed
	value3, ok3 := slotmap_fixed_get(&smap, handle3)
	testing.expect(t, ok3 && value3^ == 30, "handle3 to retrieve correct value")

	value5, ok5 := slotmap_fixed_get(&smap, handle5)
	testing.expect(t, ok5 && value5^ == 50, "handle5 to retrieve correct value")

	// Verify free list contains removed slots (most recent removal first)
	testing.expect(t, smap.free_list[2] == handle1.idx, "handle1 idx to be at free_list[2]")
	testing.expect(t, smap.free_list[1] == handle4.idx, "handle4 idx to be at free_list[1]")
	testing.expect(t, smap.free_list[0] == handle2.idx, "handle2 idx to be at free_list[0]")
}

@(test)
test_smap_generation_tracking :: proc(t: ^testing.T) {
	smap := slotmap_fixed_empty(int, 10)

	// Insert element at slot 0
	handle1, ok1 := slotmap_fixed_insert(&smap, 100)
	testing.expect(t, ok1, "first insert to succeed")
	testing.expect(t, handle1.idx == 0, "first handle idx to be 0")
	testing.expect(t, slotmap_fixed_is_valid(&smap, handle1), "handle1 to be valid")
	gen1 := handle1.gen

	// Remove it (generation should change)
	data1, remove_ok1 := slotmap_fixed_remove(&smap, handle1)
	testing.expect(t, remove_ok1, "first remove to succeed")
	testing.expect(t, data1 == 100, "removed data to match inserted value")
	testing.expect(
		t,
		!slotmap_fixed_is_valid(&smap, handle1),
		"handle1 to be invalid after removal",
	)
	testing.expect(t, slotmap_fixed_len(&smap) == 0, "num_data to decrease to 0 after removal")
	testing.expect(t, smap.gens[0] != gen1, "generation at slot 0 to have changed after removal")

	// Insert new element at same slot
	handle2, ok2 := slotmap_fixed_insert(&smap, 200)
	testing.expect(t, ok2, "second insert to succeed")
	testing.expect(t, handle2.idx == 0, "second handle idx to reuse slot 0")
	testing.expect(t, handle2.gen != gen1, "second handle gen to be different from first")
	testing.expect(t, slotmap_fixed_is_valid(&smap, handle2), "handle2 to be valid")
	testing.expect(t, slotmap_fixed_len(&smap) == 1, "num_data to increase to 1 after reinsert")
	gen2 := handle2.gen

	// Verify old handle is invalid, new handle is valid
	testing.expect(t, !slotmap_fixed_is_valid(&smap, handle1), "old handle1 to remain invalid")
	testing.expect(t, slotmap_fixed_is_valid(&smap, handle2), "new handle2 to be valid")

	// Test another cycle: remove and reinsert again
	data2, remove_ok2 := slotmap_fixed_remove(&smap, handle2)
	testing.expect(t, remove_ok2, "second remove to succeed")
	testing.expect(t, data2 == 200, "second removed data to match inserted value")
	testing.expect(
		t,
		!slotmap_fixed_is_valid(&smap, handle2),
		"handle2 to be invalid after removal",
	)
	testing.expect(
		t,
		slotmap_fixed_len(&smap) == 0,
		"num_data to decrease to 0 after second removal",
	)
	testing.expect(
		t,
		smap.gens[0] != gen2,
		"generation at slot 0 to have changed after second removal",
	)

	// Insert third element at same slot
	handle3, ok3 := slotmap_fixed_insert(&smap, 300)
	testing.expect(t, ok3, "third insert to succeed")
	testing.expect(t, handle3.idx == 0, "third handle idx to reuse slot 0")
	testing.expect(t, handle3.gen != gen1, "third handle gen to be different from first")
	testing.expect(t, handle3.gen != gen2, "third handle gen to be different from second")
	testing.expect(t, slotmap_fixed_is_valid(&smap, handle3), "handle3 to be valid")
	testing.expect(
		t,
		slotmap_fixed_len(&smap) == 1,
		"num_data to increase to 1 after third insert",
	)

	// Verify all previous handles are invalid
	testing.expect(t, !slotmap_fixed_is_valid(&smap, handle1), "handle1 to be invalid")
	testing.expect(t, !slotmap_fixed_is_valid(&smap, handle2), "handle2 to be invalid")

	// Verify current handle works correctly
	value3, get_ok3 := slotmap_fixed_get(&smap, handle3)
	testing.expect(t, get_ok3 && value3^ == 300, "handle3 to retrieve correct value")
}


@(test)
test_smap_invalid_handle_detection :: proc(t: ^testing.T) {
	smap := slotmap_fixed_empty(int, 5)

	// Test handle with idx >= N
	bad_idx_handle := SlotMap_Handle {
		idx = 10,
		gen = 0,
	}
	testing.expect(
		t,
		!slotmap_fixed_is_valid(&smap, bad_idx_handle),
		"handle with idx >= N to be invalid",
	)

	// Test handle with wrong generation
	handle, _ := slotmap_fixed_insert(&smap, 100)
	bad_gen_handle := SlotMap_Handle {
		idx = handle.idx,
		gen = handle.gen + 1,
	}
	testing.expect(
		t,
		!slotmap_fixed_is_valid(&smap, bad_gen_handle),
		"handle with wrong generation to be invalid",
	)

	// Test handle after element removal
	removed_data, remove_ok := slotmap_fixed_remove(&smap, handle)
	testing.expect(t, remove_ok, "remove operation to succeed")
	testing.expect(t, removed_data == 100, "removed data to match inserted value")
	testing.expect(t, !slotmap_fixed_is_valid(&smap, handle), "handle to be invalid after removal")
}

@(test)
test_smap_clear_operation :: proc(t: ^testing.T) {
	smap := slotmap_fixed_empty(int, 10)

	// Insert several elements
	handle1, _ := slotmap_fixed_insert(&smap, 10)
	handle2, _ := slotmap_fixed_insert(&smap, 20)
	handle3, _ := slotmap_fixed_insert(&smap, 30)

	testing.expect(t, slotmap_fixed_len(&smap) == 3, "3 elements before clear")

	// Clear the slotmap
	slotmap_fixed_clear(&smap)

	// Verify state after clear
	testing.expect(t, slotmap_fixed_len(&smap) == 0, "num_data to be 0 after clear")
	testing.expect(t, smap.num_free == 0, "num_free to be 0 after clear")

	// Verify all generations reset to 0
	for i in 0 ..< slotmap_fixed_capacity(&smap) {
		testing.expect(t, smap.gens[i] == 0, "all generations to reset to 0")
	}

	// Verify all previous handles become invalid
	testing.expect(t, !slotmap_fixed_is_valid(&smap, handle1), "handle1 to be invalid after clear")
	testing.expect(t, !slotmap_fixed_is_valid(&smap, handle2), "handle2 to be invalid after clear")
	testing.expect(t, !slotmap_fixed_is_valid(&smap, handle3), "handle3 to be invalid after clear")
}

@(test)
test_smap_edge_cases :: proc(t: ^testing.T) {
	// Boundary Conditions

	// Zero capacity SlotMap
	{
		smap := slotmap_fixed_empty(int, 0)
		testing.expect(t, slotmap_fixed_len(&smap) == 0, "zero capacity slotmap length to be 0")
		testing.expect(
			t,
			slotmap_fixed_capacity(&smap) == 0,
			"zero capacity slotmap capacity to be 0",
		)

		// Attempt insert on zero capacity
		handle, ok := slotmap_fixed_insert(&smap, 42)
		testing.expect(t, !ok, "insert on zero capacity to fail")
		testing.expect(t, slotmap_fixed_len(&smap) == 0, "length to remain 0 after failed insert")
	}

	// Single capacity SlotMap with insert/remove cycles
	{
		smap := slotmap_fixed_empty(int, 1)
		testing.expect(
			t,
			slotmap_fixed_capacity(&smap) == 1,
			"single capacity slotmap capacity to be 1",
		)

		// First insert
		handle1, ok1 := slotmap_fixed_insert(&smap, 100)
		testing.expect(t, ok1, "first insert to succeed")
		testing.expect(t, slotmap_fixed_len(&smap) == 1, "length to be 1 after insert")
		testing.expect(t, handle1.idx == 0, "single slot index to be 0")

		// Attempt second insert (should fail)
		handle2, ok2 := slotmap_fixed_insert(&smap, 200)
		testing.expect(t, !ok2, "second insert to fail on single capacity")
		testing.expect(t, slotmap_fixed_len(&smap) == 1, "length to remain 1 after failed insert")

		// Remove and reinsert cycle
		data1, remove_ok1 := slotmap_fixed_remove(&smap, handle1)
		testing.expect(t, remove_ok1, "remove to succeed")
		testing.expect(t, data1 == 100, "removed data to match")
		testing.expect(t, slotmap_fixed_len(&smap) == 0, "length to be 0 after remove")

		// Reinsert after remove
		handle3, ok3 := slotmap_fixed_insert(&smap, 300)
		testing.expect(t, ok3, "reinsert to succeed")
		testing.expect(t, handle3.idx == 0, "reinsert to use same slot")
		testing.expect(t, handle3.gen != handle1.gen, "reinsert to have different generation")
		testing.expect(t, slotmap_fixed_len(&smap) == 1, "length to be 1 after reinsert")
	}

	// Maximum generation wraparound (simulate with manual generation setting)
	{
		smap := slotmap_fixed_empty(int, 2)

		// Insert and cycle many times to test generation behavior
		handle, _ := slotmap_fixed_insert(&smap, 42)
		prev_gen := handle.gen

		// Cycle through several generations
		for i in 0 ..< 10 {
			data, _ := slotmap_fixed_remove(&smap, handle)
			testing.expect(t, data == 42, "removed data to match across generations")

			handle, _ = slotmap_fixed_insert(&smap, 42)
			testing.expect(t, handle.gen != prev_gen, "generation to change after remove/reinsert")
			testing.expect(
				t,
				!slotmap_fixed_is_valid(&smap, SlotMap_Handle{idx = handle.idx, gen = prev_gen}),
				"old generation to be invalid",
			)

			prev_gen = handle.gen
		}
	}

	// Data Type Edge Cases

	// Zero-sized types
	{
		Empty :: struct {}
		smap := slotmap_fixed_empty(Empty, 5)

		handle, ok := slotmap_fixed_insert(&smap, Empty{})
		testing.expect(t, ok, "insert zero-sized type to succeed")
		testing.expect(t, slotmap_fixed_len(&smap) == 1, "length to increase with zero-sized type")

		value, get_ok := slotmap_fixed_get(&smap, handle)
		testing.expect(t, get_ok, "get zero-sized type to succeed")

		data, remove_ok := slotmap_fixed_remove(&smap, handle)
		testing.expect(t, remove_ok, "remove zero-sized type to succeed")
		testing.expect(
			t,
			slotmap_fixed_len(&smap) == 0,
			"length to decrease after removing zero-sized type",
		)
	}

	// Large types (larger than typical cache lines)
	{
		LargeStruct :: struct {
			data:  [128]u64, // 1024 bytes, much larger than typical 64-byte cache line
			extra: [64]f64, // Additional 512 bytes
		}

		smap := slotmap_fixed_empty(LargeStruct, 3)
		large_value := LargeStruct{}
		large_value.data[0] = 0xDEADBEEF
		large_value.data[127] = 0xCAFEBABE
		large_value.extra[0] = 3.14159
		large_value.extra[63] = 2.71828

		handle, ok := slotmap_fixed_insert(&smap, large_value)
		testing.expect(t, ok, "insert large type to succeed")

		retrieved, get_ok := slotmap_fixed_get(&smap, handle)
		testing.expect(t, get_ok, "get large type to succeed")
		testing.expect(t, retrieved.data[0] == 0xDEADBEEF, "large type data integrity start")
		testing.expect(t, retrieved.data[127] == 0xCAFEBABE, "large type data integrity end")
		testing.expect(t, retrieved.extra[0] == 3.14159, "large type extra data start")
		testing.expect(t, retrieved.extra[63] == 2.71828, "large type extra data end")

		removed_data, remove_ok := slotmap_fixed_remove(&smap, handle)
		testing.expect(t, remove_ok, "remove large type to succeed")
		testing.expect(t, removed_data.data[0] == 0xDEADBEEF, "removed large type data integrity")
	}

	// Memory/State Edge Cases

	// Insert after failed capacity
	{
		smap := slotmap_fixed_empty(int, 2)

		// Fill to capacity
		handle1, ok1 := slotmap_fixed_insert(&smap, 10)
		handle2, ok2 := slotmap_fixed_insert(&smap, 20)
		testing.expect(t, ok1 && ok2, "filling to capacity to succeed")

		// Attempt insert beyond capacity
		handle3, ok3 := slotmap_fixed_insert(&smap, 30)
		testing.expect(t, !ok3, "insert beyond capacity to fail")

		// Remove one element
		data1, remove_ok := slotmap_fixed_remove(&smap, handle1)
		testing.expect(t, remove_ok && data1 == 10, "remove to succeed and return correct data")
		testing.expect(t, slotmap_fixed_len(&smap) == 1, "length to decrease after remove")

		// Retry insert after making space
		handle4, ok4 := slotmap_fixed_insert(&smap, 40)
		testing.expect(t, ok4, "insert after making space to succeed")
		testing.expect(t, handle4.idx == handle1.idx, "new insert to reuse freed slot")
		testing.expect(t, handle4.gen != handle1.gen, "new insert to have different generation")
		testing.expect(t, slotmap_fixed_len(&smap) == 2, "length to be back at capacity")
	}

	// Free list exhaustion
	{
		smap := slotmap_fixed_empty(int, 3)

		// Fill completely
		handles: [3]SlotMap_Handle
		handles[0], _ = slotmap_fixed_insert(&smap, 10)
		handles[1], _ = slotmap_fixed_insert(&smap, 20)
		handles[2], _ = slotmap_fixed_insert(&smap, 30)
		testing.expect(t, slotmap_fixed_len(&smap) == 3, "slotmap to be full")

		// Remove all elements
		for i in 0 ..< 3 {
			expected_value := (i + 1) * 10
			data, ok := slotmap_fixed_remove(&smap, handles[i])
			testing.expect(t, ok && data == expected_value, "remove all elements to succeed")
		}

		testing.expect(t, slotmap_fixed_len(&smap) == 0, "length to be 0 after removing all")
		testing.expect(t, smap.num_free == 3, "free list to contain all slots")

		// Verify free list contains all indices (order may vary due to LIFO)
		free_indices: [3]bool
		for i in 0 ..< smap.num_free {
			free_idx := smap.free_list[i]
			testing.expect(t, free_idx < 3, "free list index to be valid")
			free_indices[free_idx] = true
		}
		for i in 0 ..< 3 {
			testing.expect(t, free_indices[i], "all indices to be in free list")
		}

		// Verify all old handles are invalid
		for i in 0 ..< 3 {
			testing.expect(
				t,
				!slotmap_fixed_is_valid(&smap, handles[i]),
				"all old handles to be invalid",
			)
		}
	}
}

// test_smap_iterator_functionality :: proc(t: ^testing.T) {
// }

// test_smap_stress_testing :: proc(t: ^testing.T) {
// }

@(test)
test_smap_fuzzing_insert_remove :: proc(t: ^testing.T) {
	smap := slotmap_fixed_empty(int, 50) // Use reasonable capacity for fuzzing
	handles: [dynamic]SlotMap_Handle
	values: [dynamic]int
	defer delete(handles)
	defer delete(values)

	iterations := 10000
	for iteration in 0 ..< iterations {
		current_len := slotmap_fixed_len(&smap)
		capacity := slotmap_fixed_capacity(&smap)

		// Validate invariants before operation
		testing.expect(t, current_len == u32(len(handles)), "handle count to match slotmap length")
		testing.expect(t, current_len <= capacity, "length to not exceed capacity")
		testing.expect(
			t,
			smap.num_data + smap.num_free <= capacity,
			"data + free to not exceed capacity",
		)

		// Validate all stored handles are still valid
		for i in 0 ..< len(handles) {
			testing.expect(
				t,
				slotmap_fixed_is_valid(&smap, handles[i]),
				"stored handle to remain valid",
			)
			value, get_ok := slotmap_fixed_get(&smap, handles[i])
			testing.expect(
				t,
				get_ok && value^ == values[i],
				"stored handle to retrieve correct value",
			)
		}

		should_insert: bool
		if current_len == 0 {
			// Always insert if empty
			should_insert = true
		} else if current_len == capacity {
			// Always remove if full
			should_insert = false
		} else {
			// Random choice when neither empty nor full
			should_insert = rand.choice([]bool{true, false})
		}

		if should_insert {
			// Insert operation
			value_to_insert := iteration * 10 + 42 // Unique value for this iteration
			handle, ok := slotmap_fixed_insert(&smap, value_to_insert)

			testing.expect(t, ok, "insert operation to succeed")
			testing.expect(t, slotmap_fixed_is_valid(&smap, handle), "new handle to be valid")
			testing.expect(
				t,
				slotmap_fixed_len(&smap) == current_len + 1,
				"length to increase after insert",
			)

			// Verify inserted value can be retrieved
			retrieved_value, get_ok := slotmap_fixed_get(&smap, handle)
			testing.expect(
				t,
				get_ok && retrieved_value^ == value_to_insert,
				"inserted value to be retrievable",
			)

			// Store handle and value for future validation
			append(&handles, handle)
			append(&values, value_to_insert)

		} else {
			// Remove operation
			if len(handles) > 0 {
				// Choose random handle to remove
				remove_idx := rand.uint32() % cast(u32)len(handles)
				handle_to_remove := handles[remove_idx]
				expected_value := values[remove_idx]

				// Remove the element
				removed_data, remove_ok := slotmap_fixed_remove(&smap, handle_to_remove)

				testing.expect(t, remove_ok, "remove operation to succeed")
				testing.expect(
					t,
					removed_data == expected_value,
					"removed data to match expected value",
				)
				testing.expect(
					t,
					!slotmap_fixed_is_valid(&smap, handle_to_remove),
					"removed handle to be invalid",
				)
				testing.expect(
					t,
					slotmap_fixed_len(&smap) == current_len - 1,
					"length to decrease after remove",
				)

				// Remove from our tracking arrays
				ordered_remove(&handles, remove_idx)
				ordered_remove(&values, remove_idx)
			}
		}

		// Validate invariants after operation
		new_len := slotmap_fixed_len(&smap)
		testing.expect(
			t,
			new_len == u32(len(handles)),
			"handle count to match slotmap length after operation",
		)
		testing.expect(
			t,
			smap.num_data + smap.num_free <= capacity,
			"data + free to not exceed capacity after operation",
		)
	}

	// Final validation - all remaining handles should still be valid
	for i in 0 ..< len(handles) {
		testing.expect(t, slotmap_fixed_is_valid(&smap, handles[i]), "final handle to be valid")
		value, get_ok := slotmap_fixed_get(&smap, handles[i])
		testing.expect(t, get_ok && value^ == values[i], "final handle to retrieve correct value")
	}
}

