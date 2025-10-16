package data

import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"

// Minimal SQLite3 bindings for asset database
// Link with -lsqlite3

when ODIN_OS == .Darwin {
	foreign import sqlite3 "system:sqlite3"
} else when ODIN_OS == .Linux {
	foreign import sqlite3 "system:sqlite3"
} else when ODIN_OS == .Windows {
	foreign import sqlite3 "system:sqlite3.lib"
}

@(default_calling_convention = "c")
foreign sqlite3 {
	sqlite3_open :: proc(filename: cstring, db: ^^Sqlite3) -> c.int ---
	sqlite3_close :: proc(db: ^Sqlite3) -> c.int ---
	sqlite3_exec :: proc(db: ^Sqlite3, sql: cstring, callback: rawptr, arg: rawptr, errmsg: ^cstring) -> c.int ---
	sqlite3_prepare_v2 :: proc(db: ^Sqlite3, sql: cstring, nByte: c.int, stmt: ^^Sqlite3_Stmt, tail: ^cstring) -> c.int ---
	sqlite3_step :: proc(stmt: ^Sqlite3_Stmt) -> c.int ---
	sqlite3_finalize :: proc(stmt: ^Sqlite3_Stmt) -> c.int ---
	sqlite3_reset :: proc(stmt: ^Sqlite3_Stmt) -> c.int ---
	sqlite3_bind_int :: proc(stmt: ^Sqlite3_Stmt, idx: c.int, value: c.int) -> c.int ---
	sqlite3_bind_int64 :: proc(stmt: ^Sqlite3_Stmt, idx: c.int, value: c.longlong) -> c.int ---
	sqlite3_bind_double :: proc(stmt: ^Sqlite3_Stmt, idx: c.int, value: c.double) -> c.int ---
	sqlite3_bind_text :: proc(stmt: ^Sqlite3_Stmt, idx: c.int, value: cstring, n: c.int, destructor: rawptr) -> c.int ---
	sqlite3_column_int :: proc(stmt: ^Sqlite3_Stmt, idx: c.int) -> c.int ---
	sqlite3_column_int64 :: proc(stmt: ^Sqlite3_Stmt, idx: c.int) -> c.longlong ---
	sqlite3_column_double :: proc(stmt: ^Sqlite3_Stmt, idx: c.int) -> c.double ---
	sqlite3_column_text :: proc(stmt: ^Sqlite3_Stmt, idx: c.int) -> cstring ---
	sqlite3_errmsg :: proc(db: ^Sqlite3) -> cstring ---
}

Sqlite3 :: struct {}
Sqlite3_Stmt :: struct {}

SQLITE_OK :: 0
SQLITE_ROW :: 100
SQLITE_DONE :: 101
SQLITE_TRANSIENT :: rawptr(uintptr(max(int)))

// Asset Database Handle
Asset_DB :: struct {
	db: ^Sqlite3,
}

// Core Asset Types
Tileset :: struct {
	id:          i32,
	source_id:   i32,
	name:        string,
	image_path:  string,
	tile_width:  i32,
	tile_height: i32,
	columns:     i32,
	tile_count:  i32,
	spacing:     i32,
	margin:      i32,
}

Tile :: struct {
	id:            i32,
	tileset_id:    i32,
	local_id:      i32,
	has_collision: bool,
	has_animation: bool,
}

Tile_Collision :: struct {
	id:         i32,
	tile_id:    i32,
	shape_type: string,
	x:          f32,
	y:          f32,
	width:      f32,
	height:     f32,
	points:     string, // JSON
}

Sprite_Sheet :: struct {
	id:             i32,
	name:           string,
	image_path:     string,
	frame_width:    i32,
	frame_height:   i32,
	frame_count:    i32,
	columns:        i32,
	world_offset_x: f32,
	world_offset_y: f32,
}

Animation :: struct {
	id:              i32,
	name:            string,
	sprite_sheet_id: i32,
	frame_delay_ms:  i32,
	loop:            bool,
}

// Initialize database from schema file
asset_db_init :: proc(db_path: string, schema_path: string) -> (Asset_DB, bool) {
	db := Asset_DB{}

	db_cstr := strings.clone_to_cstring(db_path)
	defer delete(db_cstr)

	result := sqlite3_open(db_cstr, &db.db)
	if result != SQLITE_OK {
		fmt.eprintln("Failed to open database:", db_path)
		return db, false
	}

	// Load and execute schema
	schema_data, ok := os.read_entire_file(schema_path)
	if !ok {
		fmt.eprintln("Failed to read schema file:", schema_path)
		sqlite3_close(db.db)
		return db, false
	}
	defer delete(schema_data)

	schema_cstr := strings.clone_to_cstring(string(schema_data))
	defer delete(schema_cstr)

	errmsg: cstring
	result = sqlite3_exec(db.db, schema_cstr, nil, nil, &errmsg)
	if result != SQLITE_OK {
		fmt.eprintln("Failed to execute schema:", errmsg)
		sqlite3_close(db.db)
		return db, false
	}

	return db, true
}

// Close database connection
asset_db_close :: proc(db: ^Asset_DB) {
	if db.db != nil {
		sqlite3_close(db.db)
		db.db = nil
	}
}

// Query tileset by ID
asset_db_get_tileset :: proc(db: ^Asset_DB, tileset_id: i32) -> (Tileset, bool) {
	sql := "SELECT id, source_id, name, image_path, tile_width, tile_height, columns, tile_count, spacing, margin FROM tilesets WHERE id = ?"

	stmt: ^Sqlite3_Stmt
	result := sqlite3_prepare_v2(db.db, strings.clone_to_cstring(sql), -1, &stmt, nil)
	if result != SQLITE_OK {
		return {}, false
	}
	defer sqlite3_finalize(stmt)

	sqlite3_bind_int(stmt, 1, c.int(tileset_id))

	if sqlite3_step(stmt) == SQLITE_ROW {
		tileset := Tileset {
			id          = i32(sqlite3_column_int(stmt, 0)),
			source_id   = i32(sqlite3_column_int(stmt, 1)),
			name        = strings.clone_from_cstring(sqlite3_column_text(stmt, 2)),
			image_path  = strings.clone_from_cstring(sqlite3_column_text(stmt, 3)),
			tile_width  = i32(sqlite3_column_int(stmt, 4)),
			tile_height = i32(sqlite3_column_int(stmt, 5)),
			columns     = i32(sqlite3_column_int(stmt, 6)),
			tile_count  = i32(sqlite3_column_int(stmt, 7)),
			spacing     = i32(sqlite3_column_int(stmt, 8)),
			margin      = i32(sqlite3_column_int(stmt, 9)),
		}
		return tileset, true
	}

	return {}, false
}

// Query sprite sheet by name
asset_db_get_sprite_sheet :: proc(db: ^Asset_DB, name: string) -> (Sprite_Sheet, bool) {
	sql := "SELECT id, name, image_path, frame_width, frame_height, frame_count, columns, world_offset_x, world_offset_y FROM sprite_sheets WHERE name = ?"

	stmt: ^Sqlite3_Stmt
	result := sqlite3_prepare_v2(db.db, strings.clone_to_cstring(sql), -1, &stmt, nil)
	if result != SQLITE_OK {
		return {}, false
	}
	defer sqlite3_finalize(stmt)

	name_cstr := strings.clone_to_cstring(name)
	defer delete(name_cstr)
	sqlite3_bind_text(stmt, 1, name_cstr, -1, SQLITE_TRANSIENT)

	if sqlite3_step(stmt) == SQLITE_ROW {
		sheet := Sprite_Sheet {
			id             = i32(sqlite3_column_int(stmt, 0)),
			name           = strings.clone_from_cstring(sqlite3_column_text(stmt, 1)),
			image_path     = strings.clone_from_cstring(sqlite3_column_text(stmt, 2)),
			frame_width    = i32(sqlite3_column_int(stmt, 3)),
			frame_height   = i32(sqlite3_column_int(stmt, 4)),
			frame_count    = i32(sqlite3_column_int(stmt, 5)),
			columns        = i32(sqlite3_column_int(stmt, 6)),
			world_offset_x = f32(sqlite3_column_double(stmt, 7)),
			world_offset_y = f32(sqlite3_column_double(stmt, 8)),
		}
		return sheet, true
	}

	return {}, false
}

// Query tiles with collision data for a tileset
asset_db_get_tiles_with_collision :: proc(
	db: ^Asset_DB,
	tileset_id: i32,
	allocator := context.allocator,
) -> []Tile {
	sql := "SELECT id, tileset_id, local_id, has_collision, has_animation FROM tiles WHERE tileset_id = ? AND has_collision = 1"

	stmt: ^Sqlite3_Stmt
	result := sqlite3_prepare_v2(db.db, strings.clone_to_cstring(sql), -1, &stmt, nil)
	if result != SQLITE_OK {
		return nil
	}
	defer sqlite3_finalize(stmt)

	sqlite3_bind_int(stmt, 1, c.int(tileset_id))

	tiles := make([dynamic]Tile, allocator)
	for sqlite3_step(stmt) == SQLITE_ROW {
		tile := Tile {
			id            = i32(sqlite3_column_int(stmt, 0)),
			tileset_id    = i32(sqlite3_column_int(stmt, 1)),
			local_id      = i32(sqlite3_column_int(stmt, 2)),
			has_collision = sqlite3_column_int(stmt, 3) != 0,
			has_animation = sqlite3_column_int(stmt, 4) != 0,
		}
		append(&tiles, tile)
	}

	return tiles[:]
}

// Query collision shapes for a tile
asset_db_get_tile_collisions :: proc(
	db: ^Asset_DB,
	tile_id: i32,
	allocator := context.allocator,
) -> []Tile_Collision {
	sql := "SELECT id, tile_id, shape_type, x, y, width, height, points FROM tile_collisions WHERE tile_id = ?"

	stmt: ^Sqlite3_Stmt
	result := sqlite3_prepare_v2(db.db, strings.clone_to_cstring(sql), -1, &stmt, nil)
	if result != SQLITE_OK {
		return nil
	}
	defer sqlite3_finalize(stmt)

	sqlite3_bind_int(stmt, 1, c.int(tile_id))

	collisions := make([dynamic]Tile_Collision, allocator)
	for sqlite3_step(stmt) == SQLITE_ROW {
		collision := Tile_Collision {
			id         = i32(sqlite3_column_int(stmt, 0)),
			tile_id    = i32(sqlite3_column_int(stmt, 1)),
			shape_type = strings.clone_from_cstring(sqlite3_column_text(stmt, 2)),
			x          = f32(sqlite3_column_double(stmt, 3)),
			y          = f32(sqlite3_column_double(stmt, 4)),
			width      = f32(sqlite3_column_double(stmt, 5)),
			height     = f32(sqlite3_column_double(stmt, 6)),
			points     = strings.clone_from_cstring(sqlite3_column_text(stmt, 7)),
		}
		append(&collisions, collision)
	}

	return collisions[:]
}

// Query animation by name
asset_db_get_animation :: proc(db: ^Asset_DB, name: string) -> (Animation, bool) {
	sql := "SELECT id, name, sprite_sheet_id, frame_delay_ms, loop FROM animations WHERE name = ?"

	stmt: ^Sqlite3_Stmt
	result := sqlite3_prepare_v2(db.db, strings.clone_to_cstring(sql), -1, &stmt, nil)
	if result != SQLITE_OK {
		return {}, false
	}
	defer sqlite3_finalize(stmt)

	name_cstr := strings.clone_to_cstring(name)
	defer delete(name_cstr)
	sqlite3_bind_text(stmt, 1, name_cstr, -1, SQLITE_TRANSIENT)

	if sqlite3_step(stmt) == SQLITE_ROW {
		anim := Animation {
			id              = i32(sqlite3_column_int(stmt, 0)),
			name            = strings.clone_from_cstring(sqlite3_column_text(stmt, 1)),
			sprite_sheet_id = i32(sqlite3_column_int(stmt, 2)),
			frame_delay_ms  = i32(sqlite3_column_int(stmt, 3)),
			loop            = sqlite3_column_int(stmt, 4) != 0,
		}
		return anim, true
	}

	return {}, false
}
