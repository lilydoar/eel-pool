package data

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:mem"
import os "core:os/os2"
import "core:path/filepath"
import "core:strings"
import sdl3 "vendor:sdl3"
import sdl3img "vendor:sdl3/image"

Data :: struct {
	// Data contains any "global" data values that are used in the application
}

// Forward declarations for game types
SDL_Texture :: struct {
	name: string,
	surface: ^sdl3.Surface,
	texture: ^sdl3.Texture,
}

SDL_Tilemap :: struct {
	name: string,
	dimension: [2]i32,
	tile_size: [2]i32,
	texture: ^sdl3.Texture,
	tile: []^sdl3.Surface,
	tile_rects: []sdl3.Rect, // Clip rects for each tile
}

SDL_Renderer :: struct {
	renderer: ^sdl3.Renderer,
}

// Asset manager - bridges asset database with game runtime
Asset_Manager :: struct {
	db: Asset_DB,

	// Loaded tilesets (indexed by tileset source path for Tiled GID mapping)
	tilesets: map[string]Loaded_Tileset,

	// Tiled map cache
	tiled_maps: map[string]^Tiled_Map_Data,
}

// Runtime tileset with loaded SDL textures
Loaded_Tileset :: struct {
	db_id: i32,
	firstgid: u32, // First GID in Tiled map
	texture: SDL_Texture,
	tilemap: SDL_Tilemap,
	tile_width: i32,
	tile_height: i32,
	columns: i32,
	tile_count: i32,
}

// Loaded Tiled map data
Tiled_Map_Data :: struct {
	width: u32,
	height: u32,
	tile_width: u32,
	tile_height: u32,
	layers: []Tiled_Layer,
	tilesets: []Loaded_Tileset,
}

Tiled_Layer :: struct {
	id: u32,
	name: string,
	width: u32,
	height: u32,
	data: []u32, // Tile GIDs
	type: enum {
		tile_layer,
		object_layer,
	},
}

// Initialize asset manager and database
asset_manager_init :: proc(allocator := context.allocator) -> (Asset_Manager, bool) {
	context.allocator = allocator

	manager := Asset_Manager{}
	manager.tilesets = make(map[string]Loaded_Tileset)
	manager.tiled_maps = make(map[string]^Tiled_Map_Data)

	// Initialize database
	db_path := "data/assets.db"
	schema_path := "src/data/asset_schema.sql"

	db, ok := asset_db_init(db_path, schema_path)
	if !ok {
		log.error("Failed to initialize asset database")
		return manager, false
	}

	manager.db = db
	log.info("Asset manager initialized")
	return manager, true
}

// Cleanup asset manager
asset_manager_deinit :: proc(manager: ^Asset_Manager) {
	// Unload all tiled maps
	for key, map_data in manager.tiled_maps {
		tiled_map_unload(map_data)
		free(map_data)
	}
	delete(manager.tiled_maps)

	// Unload all tilesets
	for key, tileset in manager.tilesets {
		// TODO: Free SDL textures
	}
	delete(manager.tilesets)

	asset_db_close(&manager.db)
	log.info("Asset manager deinitialized")
}

// SDL handle (pass renderer from game)
SDL :: struct {
	renderer: SDL_Renderer,
}

// Load a Tiled map from JSON file
tiled_map_load :: proc(manager: ^Asset_Manager, sdl: ^SDL, map_path: string) -> (^Tiled_Map_Data, bool) {
	// Check cache
	if cached, exists := manager.tiled_maps[map_path]; exists {
		return cached, true
	}

	log.infof("Loading Tiled map: {}", map_path)

	// Read and parse Tiled JSON
	data, read_err := os.read_entire_file_from_path(map_path, context.allocator)
	if read_err != nil {
		log.errorf("Failed to read Tiled map file {}: {}", map_path, read_err)
		return nil, false
	}
	defer delete(data)

	raw_map: struct {
		width: u32,
		height: u32,
		tilewidth: u32,
		tileheight: u32,
		tilesets: []struct {
			source: string,
			firstgid: u32,
		},
		layers: []struct {
			id: u32,
			name: string,
			width: u32,
			height: u32,
			data: []u32,
			type: string,
		},
	}

	if err := json.unmarshal(data, &raw_map); err != nil {
		log.errorf("Failed to parse Tiled map JSON {}: {}", map_path, err)
		return nil, false
	}

	// Create map data structure
	map_data := new(Tiled_Map_Data)
	map_data.width = raw_map.width
	map_data.height = raw_map.height
	map_data.tile_width = raw_map.tilewidth
	map_data.tile_height = raw_map.tileheight

	// Load tilesets
	map_dir := filepath.dir(map_path)
	map_data.tilesets = make([]Loaded_Tileset, len(raw_map.tilesets))

	for ts, i in raw_map.tilesets {
		// Resolve tileset path relative to map
		tileset_path := filepath.join({map_dir, ts.source})

		loaded_ts, ok := tiled_tileset_load(manager, sdl, tileset_path, ts.firstgid)
		if !ok {
			log.errorf("Failed to load tileset: {}", tileset_path)
			// Continue anyway - some tiles might not render
			continue
		}

		map_data.tilesets[i] = loaded_ts
	}

	// Load layers
	map_data.layers = make([]Tiled_Layer, len(raw_map.layers))
	for layer, i in raw_map.layers {
		map_data.layers[i] = Tiled_Layer{
			id = layer.id,
			name = strings.clone(layer.name),
			width = layer.width,
			height = layer.height,
			data = make([]u32, len(layer.data)),
			type = .tile_layer if layer.type == "tilelayer" else .object_layer,
		}
		copy(map_data.layers[i].data, layer.data)
	}

	// Cache the map
	manager.tiled_maps[map_path] = map_data

	log.infof("Loaded Tiled map: {} ({}x{} tiles, {} tilesets, {} layers)",
		map_path, map_data.width, map_data.height,
		len(map_data.tilesets), len(map_data.layers))

	return map_data, true
}

// Load a Tiled tileset from external JSON file
tiled_tileset_load :: proc(manager: ^Asset_Manager, sdl: ^SDL, tileset_path: string, firstgid: u32) -> (Loaded_Tileset, bool) {
	// Check cache
	if cached, exists := manager.tilesets[tileset_path]; exists {
		return cached, true
	}

	log.debugf("Loading Tiled tileset: {}", tileset_path)

	// Read tileset JSON
	data, read_err := os.read_entire_file_from_path(tileset_path, context.allocator)
	if read_err != nil {
		log.errorf("Failed to read tileset file {}: {}", tileset_path, read_err)
		return {}, false
	}
	defer delete(data)

	raw_tileset: struct {
		name: string,
		image: string,
		imagewidth: u32,
		imageheight: u32,
		tilecount: u32,
		tilewidth: u32,
		tileheight: u32,
		columns: u32,
		spacing: u32,
		margin: u32,
	}

	if err := json.unmarshal(data, &raw_tileset); err != nil {
		log.errorf("Failed to parse tileset JSON {}: {}", tileset_path, err)
		return {}, false
	}

	// Resolve image path relative to tileset file
	tileset_dir := filepath.dir(tileset_path)
	image_path := filepath.join({tileset_dir, raw_tileset.image})

	// Load texture using SDL_image
	surface := sdl3img.Load(strings.clone_to_cstring(image_path, context.temp_allocator))
	if surface == nil {
		log.errorf("Failed to load image: {}", image_path)
		return {}, false
	}

	sdl_texture := sdl3.CreateTextureFromSurface(sdl.renderer.renderer, surface)
	if sdl_texture == nil {
		log.errorf("Failed to create texture from surface: {}", image_path)
		sdl3.DestroySurface(surface)
		return {}, false
	}

	texture := SDL_Texture{
		name = raw_tileset.name,
		surface = surface,
		texture = sdl_texture,
	}

	// Create tilemap (for tile indexing)
	columns := i32(raw_tileset.columns)
	rows := i32(raw_tileset.tilecount) / columns
	if i32(raw_tileset.tilecount) % columns != 0 {
		rows += 1
	}

	tilemap := SDL_Tilemap{
		name = raw_tileset.name,
		dimension = {columns, rows},
		tile_size = {i32(raw_tileset.tilewidth), i32(raw_tileset.tileheight)},
		texture = texture.texture,
		tile = make([]^sdl3.Surface, raw_tileset.tilecount),
		tile_rects = make([]sdl3.Rect, raw_tileset.tilecount),
	}

	// Pre-slice tiles
	for y in 0..<rows {
		for x in 0..<columns {
			idx := y * columns + x
			if idx >= i32(raw_tileset.tilecount) {
				break
			}

			tilemap.tile_rects[idx] = sdl3.Rect{
				tilemap.tile_size.x * x,
				tilemap.tile_size.y * y,
				tilemap.tile_size.x,
				tilemap.tile_size.y,
			}

			rect: Maybe(^sdl3.Rect) = &tilemap.tile_rects[idx]
			tile := sdl3.DuplicateSurface(texture.surface)
			sdl3.SetSurfaceClipRect(tile, rect)
			tilemap.tile[idx] = tile
		}
	}

	loaded := Loaded_Tileset{
		db_id = -1, // Not in DB yet
		firstgid = firstgid,
		texture = texture,
		tilemap = tilemap,
		tile_width = i32(raw_tileset.tilewidth),
		tile_height = i32(raw_tileset.tileheight),
		columns = i32(raw_tileset.columns),
		tile_count = i32(raw_tileset.tilecount),
	}

	// Cache tileset
	manager.tilesets[tileset_path] = loaded

	log.debugf("Loaded tileset: {} ({} tiles, {}x{} each)",
		raw_tileset.name, raw_tileset.tilecount,
		raw_tileset.tilewidth, raw_tileset.tileheight)

	return loaded, true
}

// Unload a Tiled map
tiled_map_unload :: proc(map_data: ^Tiled_Map_Data) {
	for layer in map_data.layers {
		delete(layer.name)
		delete(layer.data)
	}
	delete(map_data.layers)
	delete(map_data.tilesets)
}

// Draw a Tiled map layer
tiled_map_draw_layer :: proc(map_data: ^Tiled_Map_Data, layer_index: int, renderer: ^SDL_Renderer, tile_screen_size: [2]u32) {
	if layer_index < 0 || layer_index >= len(map_data.layers) {
		return
	}

	layer := map_data.layers[layer_index]
	if layer.type != .tile_layer {
		return
	}

	for y in 0..<layer.height {
		for x in 0..<layer.width {
			idx := y * layer.width + x
			gid := layer.data[idx]

			if gid == 0 {
				continue // Empty tile
			}

			// Find which tileset this GID belongs to
			tileset_idx := -1
			local_id := gid

			for ts, i in map_data.tilesets {
				if gid >= ts.firstgid && (i == len(map_data.tilesets)-1 || gid < map_data.tilesets[i+1].firstgid) {
					tileset_idx = i
					local_id = gid - ts.firstgid
					break
				}
			}

			if tileset_idx < 0 || tileset_idx >= len(map_data.tilesets) {
				continue
			}

			tileset := map_data.tilesets[tileset_idx]

			if local_id >= u32(tileset.tile_count) {
				continue
			}

			// Get tile clip rect
			if local_id >= u32(len(tileset.tilemap.tile_rects)) {
				continue
			}

			clip_rect := tileset.tilemap.tile_rects[local_id]

			// Calculate screen position
			dst := sdl3.FRect{
				f32(x * tile_screen_size.x),
				f32(y * tile_screen_size.y),
				f32(tile_screen_size.x),
				f32(tile_screen_size.y),
			}

			// Render tile
			sdl3.RenderTexture(
				renderer.renderer,
				tileset.texture.texture,
				&sdl3.FRect{
					f32(clip_rect.x),
					f32(clip_rect.y),
					f32(clip_rect.w),
					f32(clip_rect.h),
				},
				&dst,
			)
		}
	}
}


