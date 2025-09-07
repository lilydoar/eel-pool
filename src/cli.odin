package game

import "core:flags"
import os "core:os/os2"

Options :: struct {
	verbose: bool `usage:"Enable verbose logging output"`,
	check:   bool `usage:"Run app initialization then exit"`,
	run_for: u64 `usage:"Run a fixed number of game frames then exit"`,
}

cli_parse :: proc() -> (opts: Options) {
	flags.parse_or_exit(&opts, os.args)
	return
}

