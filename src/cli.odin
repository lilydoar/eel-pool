package game

import "core:flags"
import os "core:os/os2"

Options :: struct {
	verbose: bool `usage:"Enable verbose logging output"`,
	check:   bool `usage:"Run app initialization then exit"`,
	run_for: u64 `usage:"Run a fixed number of game frames then exit"`,
	capture: string `usage:"Capture screenshots at specified frames (comma-separated, supports 'exit')"`,
}

cli_parse :: proc() -> (opts: Options) {
	flags.parse_or_exit(&opts, os.args)
	return
}

// TODO: Ingame CLI
// Make /commands <command> to set named variables. Simple key:value setter functionality
// Example: /set player_speed 200
// Example: /set player_speed={ player_speed * 1.2 }
// IDEA: Probably would want to hook into a lua interface.
// KISS: Minimal but core CLI cmds will do what I want. Don't even need the math example above
// /set
// - debug opts, entity vars, scene vars(time, playback step, etc)
// /get 
// - query entities, entity systems, scene vars, debug reports, etc
// /list
// - query collections of entities, entity systems, debug reports, etc
// /watch
// - add a named variable to a text stack that displays constantly updating information that is currently relevant
// Example: /watch player_position player_screen_position entity_count nil_entity_count
// /unwatch
// - remove a named variable from the watch stack
// Commands to interact with engine logs
// - Colored output, filtering, etc

