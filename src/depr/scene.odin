package game

// I think scene represents world scenes, menu scenes, etc
// Not sure if these should actually be separate because world scenes have level layout, win/lose state, story state, etc
// While menu scenes have UI elements, etc
// Maybe not the right place for this

Scene :: struct {
	player:    Player,
	// TODO: These fields will be pools/handle maps
	objects:   []rawptr,
	entities:  []rawptr,
	particles: []rawptr,
}

