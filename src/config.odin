package game

import "core:log"

FRAME_DEBUG :: #config(FRAME_DEBUG, false)
VERBOSE_LOGGING :: #config(VERBOSE_LOGGING, false)

Config :: struct {
	logger: Config_Logger,
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

	return
}

