package game

import "core:fmt"
import "core:simd/x86"
import "core:slice"

import shared "../."

// GOAL:
// Implement large universe GOL with sparse representation.
//
// Need an unordered set data type to store active cells and active cell history

GOLBoard :: struct {
	active_cells:         map[shared.Vec2i]bool,
	active_cells_next:    map[shared.Vec2i]bool,
	potential_cells:      map[shared.Vec2i]bool,
	potential_cells_next: map[shared.Vec2i]bool,
}

gol_board_init :: proc(size: int) -> GOLBoard {
	board := GOLBoard {
		active_cells      = map[shared.Vec2i]bool{},
		active_cells_next = map[shared.Vec2i]bool{},
	}

	return board
}

gol_board_set :: proc(board: ^GOLBoard, coord: shared.Vec2i, value: int) {
	if value == 1 {
		board.active_cells[coord] = true
		board.potential_cells[coord] = true

		for x in -1 ..= 1 {
			for y in -1 ..= 1 {
				neighbor_coord := shared.Vec2i{coord[0] + cast(i32)x, coord[1] + cast(i32)y}
				board.potential_cells[neighbor_coord] = true
			}
		}

		return
	}

	if _, ok := board.active_cells[coord]; ok {
		delete_key(&board.active_cells, coord)
	}
}

gol_board_get :: proc(board: ^GOLBoard, coord: shared.Vec2i) -> int {
	cell, ok := board.active_cells[coord]
	if !ok {return 0}
	if cell do return 1
	else {return 0}
}

count_neighbors :: proc(board: ^GOLBoard, coord: shared.Vec2i) -> int {
	count := 0
	for dx in -1 ..= 1 {
		for dy in -1 ..= 1 {
			if dx == 0 && dy == 0 {
				continue
			}
			count += gol_board_get(
				board,
				shared.Vec2i{coord[0] + cast(i32)dx, coord[1] + cast(i32)dy},
			)
		}
	}
	return count
}

gol_board_update :: proc(board: ^GOLBoard) {
	for coord, cell in board.potential_cells {
		active := board.active_cells[coord]
		neighbors := count_neighbors(board, coord)

		if active {
			if neighbors < 2 || neighbors > 3 {
				// cell dies, but stimulate neighbors
				for x in -1 ..= 1 {
					for y in -1 ..= 1 {
						neighbor_coord := shared.Vec2i {
							coord[0] + cast(i32)x,
							coord[1] + cast(i32)y,
						}
						board.potential_cells_next[neighbor_coord] = true
					}
				}
			} else {
				board.active_cells_next[coord] = true
			}
		} else {
			if neighbors == 3 {
				board.active_cells_next[coord] = true

				for x in -1 ..= 1 {
					for y in -1 ..= 1 {
						neighbor_coord := shared.Vec2i {
							coord[0] + cast(i32)x,
							coord[1] + cast(i32)y,
						}
						board.potential_cells_next[neighbor_coord] = true
					}
				}
			} else {
				// Cell dies
			}
		}
	}

	board.active_cells = map_clone(board.active_cells_next)
	clear(&board.active_cells_next)

	board.potential_cells = board.potential_cells_next
	board.potential_cells_next = map_clone(board.active_cells)
}

map_clone :: proc(m: map[shared.Vec2i]bool) -> map[shared.Vec2i]bool {
	new_map := map[shared.Vec2i]bool{}
	for k, v in m {
		new_map[k] = v
	}
	return new_map
}

gol_board_print :: proc(board: ^GOLBoard, viewport_min: shared.Vec2i, viewport_max: shared.Vec2i) {
	for y in 0 ..< viewport_max[1] {
		for x in 0 ..< viewport_max[0] {
			neighbor_coord := shared.Vec2i{cast(i32)x, cast(i32)y}
			if gol_board_get(board, neighbor_coord) == 1 {
				fmt.print("█") // Alive cell
			} else {
				fmt.print(" ") // Dead cell
			}
		}
		fmt.println()
	}
	fmt.println()
}

gol_board_set_glider :: proc(board: ^GOLBoard, x: int, y: int) {
	p0 := shared.Vec2i{cast(i32)x + 1, cast(i32)y}
	p1 := shared.Vec2i{cast(i32)x + 2, cast(i32)y + 1}
	p2 := shared.Vec2i{cast(i32)x, cast(i32)y + 2}
	p3 := shared.Vec2i{cast(i32)x + 1, cast(i32)y + 2}
	p4 := shared.Vec2i{cast(i32)x + 2, cast(i32)y + 2}

	gol_board_set(board, p0, 1)
	gol_board_set(board, p1, 1)
	gol_board_set(board, p2, 1)
	gol_board_set(board, p3, 1)
	gol_board_set(board, p4, 1)
}

