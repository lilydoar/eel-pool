package app

import "core:flags"
import os "core:os/os2"

Options :: struct {
	check:       bool `usage:"Run app initialization then exit"`,
	// TODO
	frame_count: int `usage:"Number of frames to run before exiting"`,
}

opt: Options

cli_parse :: proc() {flags.parse_or_exit(&opt, os.args)}

cli_options :: proc() -> Options {return opt}

