package data

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:mem"
import os "core:os/os2"
import "core:path/filepath"
import "core:slice"
import "core:strings"
import sdl3 "vendor:sdl3"
import sdl3img "vendor:sdl3/image"

// Tiled GID flip flags (top 4 bits of 32-bit GID)
// See: https://doc.mapeditor.org/en/stable/reference/global-tile-ids/
TILED_GID_FLIP_HORIZONTAL :: 0x80000000
TILED_GID_FLIP_VERTICAL :: 0x40000000
TILED_GID_FLIP_DIAGONAL :: 0x20000000 // Diagonal flip for orthogonal/isometric, 60° rotation for hexagonal
TILED_GID_FLIP_ROTATION :: 0x10000000 // 120° rotation for hexagonal maps
TILED_GID_MASK :: 0x0FFFFFFF // Mask to extract tile ID (clears all flip flags)

// Parsed GID information ready for rendering
Tiled_GID_Info :: struct {
	tile_id:     u32, // The actual tile ID with flip flags removed
	flip_mode:   sdl3.FlipMode, // SDL3 flip mode for rendering
	rotation:    f64, // Rotation in degrees (for diagonal flip)
	use_rotated: bool, // Whether to use RenderTextureRotated
}

// Extract tile ID and convert Tiled flip flags to SDL3 rendering parameters
tiled_gid_parse :: proc(gid: u32) -> Tiled_GID_Info {
	info := Tiled_GID_Info {
		tile_id = gid & TILED_GID_MASK,
	}

	flip_h := (gid & TILED_GID_FLIP_HORIZONTAL) != 0
	flip_v := (gid & TILED_GID_FLIP_VERTICAL) != 0
	flip_d := (gid & TILED_GID_FLIP_DIAGONAL) != 0

	// Convert Tiled flip flags to SDL3 rendering parameters
	// Tiled's diagonal flip is equivalent to rotating 90° CCW then flipping horizontally
	// For simplicity, we handle the common cases with SDL3's FlipMode
	if flip_d {
		// Diagonal flip: rotate and flip
		info.rotation = 90.0
		info.use_rotated = true
		if flip_h && flip_v {
			info.flip_mode = .NONE
		} else if flip_h {
			info.flip_mode = .VERTICAL
		} else if flip_v {
			info.flip_mode = .HORIZONTAL
		} else {
			info.flip_mode = .HORIZONTAL
		}
	} else {
		// No diagonal flip: just use horizontal/vertical flips
		info.rotation = 0.0
		info.use_rotated = flip_h || flip_v
		if flip_h && flip_v {
			// Both flips = 180° rotation
			info.rotation = 180.0
			info.flip_mode = .NONE
		} else if flip_h {
			info.flip_mode = .HORIZONTAL
		} else if flip_v {
			info.flip_mode = .VERTICAL
		} else {
			info.flip_mode = .NONE
		}
	}

	return info
}

Data :: struct {
	// Data contains any "global" data values that are used in the application
}

// Forward declarations for game types
SDL_Texture :: struct {
	name:    string,
	surface: ^sdl3.Surface,
	texture: ^sdl3.Texture,
}

SDL_Tilemap :: struct {
	name:       string,
	dimension:  [2]i32,
	tile_size:  [2]i32,
	texture:    ^sdl3.Texture,
	tile:       []^sdl3.Surface,
	tile_rects: []sdl3.Rect, // Clip rects for each tile
}

SDL_Renderer :: struct {
	renderer: ^sdl3.Renderer,
}

// Asset manager - bridges asset database with game runtime
Asset_Manager :: struct {
	db:         Asset_DB,

	// Loaded tilesets (indexed by tileset source path for Tiled GID mapping)
	tilesets:   map[string]Loaded_Tileset,

	// Tiled map cache
	tiled_maps: map[string]^Tiled_Map_Data,
}

// Runtime tileset with loaded SDL textures
Loaded_Tileset :: struct {
	db_id:         i32,
	firstgid:      u32, // First GID in Tiled map
	texture:       SDL_Texture, // For single image tilesets
	tilemap:       SDL_Tilemap,
	tile_width:    i32,
	tile_height:   i32,
	columns:       i32,
	tile_count:    i32,
	// For image collection tilesets
	is_collection: bool,
	tile_textures: []SDL_Texture, // Individual textures per tile
	tile_sizes:    [][2]i32, // Individual sizes per tile (width, height)
}

// Loaded Tiled map data
Tiled_Map_Data :: struct {
	width:       u32,
	height:      u32,
	tile_width:  u32,
	tile_height: u32,
	layers:      []Tiled_Layer,
	tilesets:    []Loaded_Tileset,
}

Tiled_Layer :: struct {
	id:      u32,
	name:    string,
	width:   u32,
	height:  u32,
	data:    []u32, // Tile GIDs
	objects: []Tiled_Object,
	type:    enum {
		tile_layer,
		object_layer,
	},
}

Tiled_Object :: struct {
	id:       u32,
	gid:      u32,
	name:     string,
	height:   f32,
	width:    f32,
	rotation: f32,
	position: [2]f32,
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
tiled_map_load :: proc(
	manager: ^Asset_Manager,
	sdl: ^SDL,
	map_path: string,
) -> (
	^Tiled_Map_Data,
	bool,
) {
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
		width:      u32,
		height:     u32,
		tilewidth:  u32,
		tileheight: u32,
		tilesets:   []struct {
			source:   string,
			firstgid: u32,
		},
		layers:     []struct {
			id:      u32,
			name:    string,
			width:   u32,
			height:  u32,
			data:    []u32,
			objects: []struct {
				id:       u32,
				gid:      u32,
				name:     string,
				height:   f32,
				width:    f32,
				rotation: f32,
				x:        f32,
				y:        f32,
			},
			type:    string,
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
		map_data.layers[i] = Tiled_Layer {
			id      = layer.id,
			name    = strings.clone(layer.name),
			width   = layer.width,
			height  = layer.height,
			data    = make([]u32, len(layer.data)),
			objects = make([]Tiled_Object, len(layer.objects)),
		}

		copy(map_data.layers[i].data, layer.data)

		for obj, j in layer.objects {
			map_data.layers[i].objects[j] = Tiled_Object {
				id       = obj.id,
				gid      = obj.gid,
				name     = strings.clone(obj.name),
				height   = obj.height,
				width    = obj.width,
				rotation = obj.rotation,
				position = [2]f32{obj.x, obj.y},
			}
		}

		// Sort objects by Y position for correct draw order (top to bottom)
		// Objects with smaller Y values (top of screen) drawn first, larger Y (bottom) drawn last
		slice.sort_by(map_data.layers[i].objects, proc(a, b: Tiled_Object) -> bool {
			return a.position.y < b.position.y
		})

		if len(map_data.layers[i].data) > 0 {
			map_data.layers[i].type = .tile_layer
		} else {
			map_data.layers[i].type = .object_layer
		}

	}

	// Cache the map
	manager.tiled_maps[map_path] = map_data

	log.infof(
		"Loaded Tiled map: {} ({}x{} tiles, {} tilesets, {} layers)",
		map_path,
		map_data.width,
		map_data.height,
		len(map_data.tilesets),
		len(map_data.layers),
	)

	return map_data, true
}

// Load a Tiled tileset from external JSON file
tiled_tileset_load :: proc(
	manager: ^Asset_Manager,
	sdl: ^SDL,
	tileset_path: string,
	firstgid: u32,
) -> (
	Loaded_Tileset,
	bool,
) {
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
		name:        string,
		image:       string,
		imagewidth:  u32,
		imageheight: u32,
		tilecount:   u32,
		tilewidth:   u32,
		tileheight:  u32,
		columns:     u32,
		spacing:     u32,
		margin:      u32,
		tiles:       []struct {
			id:          u32,
			image:       string,
			imagewidth:  u32,
			imageheight: u32,
		},
	}

	if err := json.unmarshal(data, &raw_tileset); err != nil {
		log.errorf("Failed to parse tileset JSON {}: {}", tileset_path, err)
		return {}, false
	}

	tileset_dir := filepath.dir(tileset_path)

	// Check if this is an image collection tileset
	is_collection := raw_tileset.image == "" || raw_tileset.columns == 0

	loaded: Loaded_Tileset

	if is_collection {
		// Image collection tileset - each tile has its own image
		log.debugf("Loading image collection tileset with {} tiles", len(raw_tileset.tiles))

		loaded.is_collection = true
		loaded.tile_count = i32(raw_tileset.tilecount)
		loaded.tile_textures = make([]SDL_Texture, raw_tileset.tilecount)
		loaded.tile_sizes = make([][2]i32, raw_tileset.tilecount)

		// Load each tile's image
		for tile_info in raw_tileset.tiles {
			if tile_info.id >= raw_tileset.tilecount {
				log.warnf("Tile id {} out of range (max {})", tile_info.id, raw_tileset.tilecount)
				continue
			}

			tile_image_path := filepath.join({tileset_dir, tile_info.image})

			// Load texture using SDL_image
			surface := sdl3img.Load(
				strings.clone_to_cstring(tile_image_path, context.temp_allocator),
			)
			if surface == nil {
				log.errorf("Failed to load tile image: {}", tile_image_path)
				continue
			}

			sdl_texture := sdl3.CreateTextureFromSurface(sdl.renderer.renderer, surface)
			if sdl_texture == nil {
				log.errorf("Failed to create texture from surface: {}", tile_image_path)
				sdl3.DestroySurface(surface)
				continue
			}

			loaded.tile_textures[tile_info.id] = SDL_Texture {
				name    = raw_tileset.name,
				surface = surface,
				texture = sdl_texture,
			}

			loaded.tile_sizes[tile_info.id] = {
				i32(tile_info.imagewidth),
				i32(tile_info.imageheight),
			}
		}

		// Set common dimensions (use the tileset's dimensions as defaults)
		loaded.tile_width = i32(raw_tileset.tilewidth)
		loaded.tile_height = i32(raw_tileset.tileheight)
		loaded.columns = 0 // No columns for collections

		// Create empty tilemap structure
		loaded.tilemap = SDL_Tilemap {
			name       = raw_tileset.name,
			dimension  = {0, 0},
			tile_size  = {loaded.tile_width, loaded.tile_height},
			texture    = nil,
			tile       = nil,
			tile_rects = nil,
		}

	} else {
		// Single image tileset - traditional spritesheet
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

		texture := SDL_Texture {
			name    = raw_tileset.name,
			surface = surface,
			texture = sdl_texture,
		}

		// Create tilemap (for tile indexing)
		columns := i32(raw_tileset.columns)
		rows := i32(raw_tileset.tilecount) / columns
		if i32(raw_tileset.tilecount) % columns != 0 {
			rows += 1
		}

		tilemap := SDL_Tilemap {
			name       = raw_tileset.name,
			dimension  = {columns, rows},
			tile_size  = {i32(raw_tileset.tilewidth), i32(raw_tileset.tileheight)},
			texture    = texture.texture,
			tile       = make([]^sdl3.Surface, raw_tileset.tilecount),
			tile_rects = make([]sdl3.Rect, raw_tileset.tilecount),
		}

		// Pre-slice tiles
		for y in 0 ..< rows {
			for x in 0 ..< columns {
				idx := y * columns + x
				if idx >= i32(raw_tileset.tilecount) {
					break
				}

				tilemap.tile_rects[idx] = sdl3.Rect {
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

		loaded = Loaded_Tileset {
			db_id         = -1, // Not in DB yet
			firstgid      = firstgid,
			texture       = texture,
			tilemap       = tilemap,
			tile_width    = i32(raw_tileset.tilewidth),
			tile_height   = i32(raw_tileset.tileheight),
			columns       = i32(raw_tileset.columns),
			tile_count    = i32(raw_tileset.tilecount),
			is_collection = false,
			tile_textures = nil,
			tile_sizes    = nil,
		}
	}

	loaded.db_id = -1
	loaded.firstgid = firstgid

	// Cache tileset
	manager.tilesets[tileset_path] = loaded

	log.debugf(
		"Loaded tileset: {} ({} tiles, {}x{} each)",
		raw_tileset.name,
		raw_tileset.tilecount,
		raw_tileset.tilewidth,
		raw_tileset.tileheight,
	)

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
tiled_map_draw_layer :: proc(
	map_data: ^Tiled_Map_Data,
	layer_index: int,
	renderer: ^SDL_Renderer,
	tile_screen_size: [2]u32,
) {
	if layer_index < 0 || layer_index >= len(map_data.layers) {
		return
	}

	layer := map_data.layers[layer_index]
	if layer.type != .tile_layer {
		return
	}

	for y in 0 ..< layer.height {
		for x in 0 ..< layer.width {
			idx := y * layer.width + x
			gid := layer.data[idx]

			if gid == 0 {
				continue // Empty tile
			}

			// Find which tileset this GID belongs to
			tileset_idx := -1
			local_id := gid

			for ts, i in map_data.tilesets {
				if gid >= ts.firstgid &&
				   (i == len(map_data.tilesets) - 1 || gid < map_data.tilesets[i + 1].firstgid) {
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
			dst := sdl3.FRect {
				f32(x * tile_screen_size.x),
				f32(y * tile_screen_size.y),
				f32(tile_screen_size.x),
				f32(tile_screen_size.y),
			}

			// Render tile
			sdl3.RenderTexture(
				renderer.renderer,
				tileset.texture.texture,
				&sdl3.FRect {
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

