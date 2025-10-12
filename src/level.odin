package game

import "data"

Level :: struct {
	map_data:      ^data.Tiled_Map_Data,
	playable_area: AABB2,
}

