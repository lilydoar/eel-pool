package game

// player_move_up :: struct {
// 	pos: sdl3.Keycode,
// }
// player_move_down :: struct {
// 	pos: sdl3.Keycode,
// }
// player_move_left :: struct {
// 	pos: sdl3.Keycode,
// }
// player_move_right :: struct {
// 	pos: sdl3.Keycode,
// }

// game_control_variant :: union {
// 	game_control,
// 	editor_place_player,
// 	editor_place_enemy,
// }
//
// editor_place_player :: struct {
// 	world_pos: Vec2,
// }
//
// editor_place_enemy :: struct {
// 	world_pos: Vec2,
// }

// Example: use of union and struct
// Entity :: struct {
// 	position: [2]f32,
// 	// texture:  Texture,
// 	variant:  Entity_Variant,
// }
//
// Entity_Player :: struct {
// 	can_jump: bool,
// }
//
// Entity_Rocket :: struct {
// 	time_in_space: f32,
// }
//
// Entity_Variant :: union {
// 	Entity_Player,
// 	Entity_Rocket,
// }

// Example: using union and switch
// Foo :: union {int, bool}
// f: Foo = 123
// switch _ in f {
// case int:  fmt.println("int")
// case bool: fmt.println("bool")
// case:
// }
//
// #partial switch _ in f {
// case bool: fmt.println("bool")
// }

