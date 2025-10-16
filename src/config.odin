package game

import "core:log"

// Enable in-game debug behavior
DEBUG_GAME :: #config(DEBUG_GAME, false)

// Enable per-frame logs
DEBUG_FRAME :: #config(DEBUG_FRAME, false)

Config :: struct {
	logger:                Config_Logger,
	max_updates_per_frame: u32,
}

Config_Logger :: struct {
	level:      log.Level,
	opts:       log.Options,
	identifier: string,
	to_file:    string,
}

config_logger_default := Config_Logger {
	level      = .Info,
	opts       = {
		.Level,
		// .Date,
		.Time,
		.Short_File_Path,
		// .Long_File_Path,
		.Line,
		.Procedure,
		.Terminal_Color,
		// .Thread_Id,
	},
	identifier = "",
	to_file    = "",
}

config_load :: proc(opts: Options) -> (cfg: Config) {
	cfg.logger = config_logger_default
	if opts.verbose {cfg.logger.level = .Debug}

	cfg.max_updates_per_frame = 5

	return
}
