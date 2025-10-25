# Asset System Operations Guide

This document walks through the day-to-day tasks for maintaining the asset database (`data/assets.db`) and its companion JSON registries under `data/assets/`. Follow these workflows when adding new art, animations, or tilesets.

---

## Quick Reference
- All commands assume you run them from the repository root.
- Runtime code expects:
  - `data/assets.db` to exist and include the schema in `src/data/asset_schema.sql`.
  - JSON registries (`animations.json`, `sprites.json`, `tile_maps.json`, and Tiled exports) to remain in sync with the art in `/assets`.
- There is no automated importer yet—plan on manual SQL or scripted `.read` files.

---

## Database Operations (`data/assets.db`)

### 1. Back Up (Recommended)
```bash
cp data/assets.db data/assets.db.bak
```

### 2. Apply Schema Changes
Run after editing `src/data/asset_schema.sql` or when bootstrapping a fresh database:
```bash
sqlite3 data/assets.db < src/data/asset_schema.sql
```
The schema uses `CREATE TABLE IF NOT EXISTS`, so running it repeatedly is safe.

### 3. Inspect Current State
```bash
sqlite3 data/assets.db ".tables"
sqlite3 data/assets.db ".schema tilesets"
sqlite3 data/assets.db "SELECT COUNT(*) FROM tiles;"
```
Use ad-hoc `SELECT` queries to verify data before shipping changes.

### 4. Populate / Update Data
- Launch an interactive session:
  ```bash
  sqlite3 data/assets.db
  ```
- Or execute scripted inserts:
  ```bash
  sqlite3 data/assets.db < dev/sql/seed_assets.sql
  ```
  (Create your own `.sql` files in `dev/sql/` or similar; none exist yet.)
- Remember foreign-key relationships from `asset_schema.sql` (e.g., `tilesets.source_id` must reference `asset_sources.id`).

---

## JSON Registries (`data/assets/*.json`)
The game loads these files directly at runtime (`src/assets.odin`). Treat them as the source of truth for asset metadata.

### Animations – `data/assets/animations.json`
Purpose: configure sprite-sheet animations used by the game.

Each entry:
```jsonc
{
  "name": "player_idle",          // lookup key in code
  "path": "assets/.../Idle.png",  // relative to repo root
  "frame_count": 8,               // frames in the strip
  "delay_ms": 10,                 // per-frame delay
  "size": { "x": 192, "y": 192 }, // frame dimensions
  "world_offset": { "x": 96, "y": 96 } // draw pivot
}
```
Workflow:
1. Drop the sprite sheet into `assets/`.
2. Append a new object to the JSON file with the details above.
3. Ensure `name` matches the lookup in `src/assets.odin` (add new fields there if needed).

### Sprites – `data/assets/sprites.json`
Purpose: register static textures.

Fields mirror animations but omit `frame_count` and `delay_ms`:
```jsonc
{
  "name": "archer_arrow",
  "path": "assets/.../Arrow.png",
  "size": { "x": 64, "y": 64 },
  "world_offset": { "x": 32, "y": 32 }
}
```
Ensure every new entry has a corresponding consumer in game code.

### Tile Atlases – `data/assets/tile_maps.json`
Purpose: describe tilemap spritesheets used by map rendering.

Schema:
```jsonc
{
  "name": "tiny_swords_ground_color1",
  "path": "assets/.../Tilemap_color1.png",
  "size": { "x": 20, "y": 20 } // columns, rows
}
```
Update this file whenever you add new terrain atlases.

---

## Tiled Exports (`data/assets/*.json`, e.g., `Tree1.json`)
These files are raw exports from Tiled (TSX → JSON). The runtime reads them for tile animation/collision data.

Operational workflow:
1. Open the tileset in Tiled (`eel-pool.tiled-project` keeps references).
2. Make changes (tile animations, collision shapes, etc.).
3. Export → JSON, overwriting the existing file in `data/assets/`.
   - Tiled writes relative `image` paths like `../../assets/...`; keep those intact.
4. If collisions or metadata influence gameplay, mirror relevant info into `data/assets.db` via SQL so queries (see `asset_db.odin`) pick them up.

Keep the JSON untouched by hand whenever possible; let Tiled manage structure.

---

## Typical Asset Update Workflow
1. **Prepare art** in `/assets`.
2. **Update JSON registry** (`animations.json`, `sprites.json`, or `tile_maps.json`) or **export from Tiled**.
3. **Adjust database** entries if the asset manager needs structured data (tileset metadata, collision tables, etc.).
4. **Run the game** to validate loading. Errors will surface from `asset_db_init`, JSON parsing, or SDL load routines.
5. **Commit assets + JSON + DB** together to keep revisions aligned.

---

## Troubleshooting
- **Game fails to boot with DB error**: run the schema command, then inspect for missing required rows (e.g., `tilesets` referencing nonexistent `asset_sources`).
- **Missing sprite/animation at runtime**: confirm the `name` in JSON matches the field used in `src/assets.odin`.
- **Tiled tileset not animating**: verify the exported JSON contains the `tiles[].animation` block and that the matching IDs exist in the database if you rely on SQL queries.

---

## Future Enhancements (Ideas)
- Seed scripts in `dev/sql/` to preload reference data.
- CLI tool to sync JSON → SQLite automatically.
- Validation script to check file paths and schema consistency before commit.

Until then, use this guide to keep manual updates consistent. Happy asset wrangling!
