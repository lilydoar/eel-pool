package game

import "core:flags"
import os "core:os/os2"

Options :: struct {
	check:      bool `usage:"Run app initialization then exit"`,
	game_frame: u32 `usage:"Run a finite number of game frames then exit"`,
}

opt: Options

cli_parse :: proc() {flags.parse_or_exit(&opt, os.args)}

cli_options :: proc() -> Options {return opt}

