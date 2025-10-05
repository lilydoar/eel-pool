-- Asset Database Schema
-- For use with SQLite in game runtime
-- Focuses on Tiled Editor assets, resource packs, and 3D source files

-- Source files that assets are derived from
CREATE TABLE IF NOT EXISTS asset_sources (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_type TEXT NOT NULL CHECK(source_type IN ('tileset', 'tilemap', 'sprite', 'animation', 'blend', 'aseprite', 'kra')),
    file_path TEXT NOT NULL UNIQUE,
    file_hash TEXT,
    last_modified INTEGER,
    metadata TEXT
);

-- Tiled Editor tilesets
CREATE TABLE IF NOT EXISTS tilesets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    image_path TEXT NOT NULL,
    tile_width INTEGER NOT NULL,
    tile_height INTEGER NOT NULL,
    columns INTEGER NOT NULL,
    tile_count INTEGER NOT NULL,
    spacing INTEGER DEFAULT 0,
    margin INTEGER DEFAULT 0,
    FOREIGN KEY (source_id) REFERENCES asset_sources(id) ON DELETE CASCADE
);

-- Individual tiles within tilesets
CREATE TABLE IF NOT EXISTS tiles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tileset_id INTEGER NOT NULL,
    local_id INTEGER NOT NULL,
    has_collision INTEGER DEFAULT 0,
    has_animation INTEGER DEFAULT 0,
    properties TEXT,
    FOREIGN KEY (tileset_id) REFERENCES tilesets(id) ON DELETE CASCADE,
    UNIQUE(tileset_id, local_id)
);

-- Collision shapes for tiles (from Tiled object groups)
CREATE TABLE IF NOT EXISTS tile_collisions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tile_id INTEGER NOT NULL,
    shape_type TEXT NOT NULL CHECK(shape_type IN ('rect', 'polygon', 'ellipse')),
    x REAL NOT NULL,
    y REAL NOT NULL,
    width REAL,
    height REAL,
    points TEXT,
    FOREIGN KEY (tile_id) REFERENCES tiles(id) ON DELETE CASCADE
);

-- Tile animations (frame sequences)
CREATE TABLE IF NOT EXISTS tile_animations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tile_id INTEGER NOT NULL,
    frame_order INTEGER NOT NULL,
    frame_tile_id INTEGER NOT NULL,
    duration_ms INTEGER NOT NULL,
    FOREIGN KEY (tile_id) REFERENCES tiles(id) ON DELETE CASCADE,
    FOREIGN KEY (frame_tile_id) REFERENCES tiles(id) ON DELETE CASCADE
);

-- Sprite sheets (single images or frame strips)
CREATE TABLE IF NOT EXISTS sprite_sheets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_id INTEGER,
    name TEXT NOT NULL UNIQUE,
    image_path TEXT NOT NULL,
    frame_width INTEGER NOT NULL,
    frame_height INTEGER NOT NULL,
    frame_count INTEGER DEFAULT 1,
    columns INTEGER DEFAULT 1,
    world_offset_x REAL DEFAULT 0,
    world_offset_y REAL DEFAULT 0,
    FOREIGN KEY (source_id) REFERENCES asset_sources(id) ON DELETE SET NULL
);

-- Named animation sequences
CREATE TABLE IF NOT EXISTS animations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    sprite_sheet_id INTEGER,
    frame_delay_ms INTEGER DEFAULT 100,
    loop INTEGER DEFAULT 1,
    FOREIGN KEY (sprite_sheet_id) REFERENCES sprite_sheets(id) ON DELETE CASCADE
);

-- Blender project files
CREATE TABLE IF NOT EXISTS blend_projects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    exported_assets TEXT,
    FOREIGN KEY (source_id) REFERENCES asset_sources(id) ON DELETE CASCADE
);

-- Resource pack groupings (e.g., Tiny_Swords)
CREATE TABLE IF NOT EXISTS resource_packs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    base_path TEXT NOT NULL,
    description TEXT
);

-- Many-to-many relationship between packs and assets
CREATE TABLE IF NOT EXISTS pack_assets (
    pack_id INTEGER NOT NULL,
    asset_type TEXT NOT NULL CHECK(asset_type IN ('tileset', 'sprite_sheet', 'blend_project')),
    asset_id INTEGER NOT NULL,
    FOREIGN KEY (pack_id) REFERENCES resource_packs(id) ON DELETE CASCADE,
    PRIMARY KEY (pack_id, asset_type, asset_id)
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_tiles_tileset ON tiles(tileset_id);
CREATE INDEX IF NOT EXISTS idx_tiles_collision ON tiles(has_collision) WHERE has_collision = 1;
CREATE INDEX IF NOT EXISTS idx_tile_collisions_tile ON tile_collisions(tile_id);
CREATE INDEX IF NOT EXISTS idx_tile_animations_tile ON tile_animations(tile_id);
CREATE INDEX IF NOT EXISTS idx_sprite_sheets_name ON sprite_sheets(name);
CREATE INDEX IF NOT EXISTS idx_animations_name ON animations(name);
CREATE INDEX IF NOT EXISTS idx_pack_assets_pack ON pack_assets(pack_id);
CREATE INDEX IF NOT EXISTS idx_asset_sources_path ON asset_sources(file_path);
