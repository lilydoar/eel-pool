package game

import "core:fmt"
import "core:slice"

GOLBoard :: struct {
	size:                 int,
	grid_double_buff:     [2][dynamic]int,
	grid_double_buff_idx: int,
}

gol_board_init :: proc(size: int) -> GOLBoard {
	board := GOLBoard {
		size                 = size,
		grid_double_buff_idx = 0,
	}

	for buffer_idx in 0 ..< 2 {
		board.grid_double_buff[buffer_idx] = make([dynamic]int, size * size)
		for i in 0 ..< size * size {
			board.grid_double_buff[buffer_idx][i] = 0
		}
	}

	return board
}

gol_board_set :: proc(board: ^GOLBoard, x: int, y: int, value: int) {
	if x < 0 || x >= board.size || y < 0 || y >= board.size {
		return
	}
	current_grid := &board.grid_double_buff[board.grid_double_buff_idx]
	current_grid[x + y * board.size] = value
}

gol_board_get :: proc(board: ^GOLBoard, x: int, y: int) -> int {
	if x < 0 || x >= board.size || y < 0 || y >= board.size {
		return 0
	}
	current_grid := &board.grid_double_buff[board.grid_double_buff_idx]
	return current_grid[x + y * board.size]
}

count_neighbors :: proc(board: ^GOLBoard, x: int, y: int) -> int {
	count := 0
	for dx in -1 ..= 1 {
		for dy in -1 ..= 1 {
			if dx == 0 && dy == 0 {
				continue
			}
			count += gol_board_get(board, x + dx, y + dy)
		}
	}
	return count
}

gol_board_update :: proc(board: ^GOLBoard) {
	current_idx := board.grid_double_buff_idx
	next_idx := 1 - current_idx

	current_grid := &board.grid_double_buff[current_idx]
	next_grid := &board.grid_double_buff[next_idx]

	for x in 0 ..< board.size {
		for y in 0 ..< board.size {
			neighbors := count_neighbors(board, x, y)
			current := current_grid[x + y * board.size]
			idx := x + y * board.size

			if current == 1 {
				if neighbors < 2 || neighbors > 3 {
					next_grid[idx] = 0 // Cell dies
				} else {
					next_grid[idx] = 1 // Cell lives
				}
			} else {
				if neighbors == 3 {
					next_grid[idx] = 1 // Cell becomes alive
				} else {
					next_grid[idx] = 0 // Cell remains dead
				}
			}
		}
	}

	board.grid_double_buff_idx = next_idx
}

gol_board_print :: proc(board: ^GOLBoard) {
	for y in 0 ..< board.size {
		for x in 0 ..< board.size {
			if gol_board_get(board, x, y) == 1 {
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
	gol_board_set(board, x + 1, y, 1)
	gol_board_set(board, x + 2, y + 1, 1)
	gol_board_set(board, x, y + 2, 1)
	gol_board_set(board, x + 1, y + 2, 1)
	gol_board_set(board, x + 2, y + 2, 1)
}

