package game

import "base:runtime"
import "core:log"
import os "core:os/os2"

App :: struct {
	ctx:         runtime.Context,
	opts:        Options,
	cfg:         Config,
	sdl:         SDL,
	game:        Game,

	// Runtime
	frame_count: u64,
	// game_api:    GameAPI,
}

app_create_logger :: proc(app: ^App) -> (l: log.Logger) {
	cfg := app.cfg.logger

	if cfg.to_file == "" {
		return log.create_console_logger(opt = cfg.opts)
	}

	// TODO: Support file logging
	// f, err := os.open(cfg.logger.to_file)
	// l = log.create_file_logger(f, opt = cfg.logger.opts)

	return
}

app_init :: proc(app: ^App, ctx: runtime.Context) {
	context = ctx

	app.opts = cli_parse()
	app.cfg = config_load(app.opts)

	app.ctx = ctx
	app.ctx.logger = app_create_logger(app)

	context = app.ctx

	log.info("Initializing Application...")
	defer log.info("Application initialized")

	// TODO: Load from dev/release config
	sdl_opts := SDL_Options {
		window_title = "eel-pool",
		window_size  = {1280, 720},
		window_flags = {.RESIZABLE},
	}
	sdl_init(&app.sdl, sdl_opts)

	game_init(&app.game, app.ctx, app.ctx.logger)

	// TODO: Initialize other subsystems (e.g., job system, ...)
}

app_deinit :: proc(app: ^App) {
	context = app.ctx

	log.info("Deinitializing Application...")
	defer log.info("Application deinitialized")

	game_deinit(&app.game)
	sdl_deinit(&app.sdl)
}

should_loop: proc(a: ^App) -> bool = proc(a: ^App) -> bool {return true}

app_run :: proc(app: ^App) {
	context = app.ctx

	if app.opts.check {
		log.info("App initialized successfully and -check flag is enabled, exiting.")
		return
	}

	if app.opts.diagnose {
		log.infof("Running in diagnose mode")
		diagnose_frames := 30
		app.opts.run_for = cast(u64)diagnose_frames
	}

	if app.opts.run_for > 0 {
		log.infof("Running App for {} frames then exiting.", app.opts.run_for)
		should_loop = proc(a: ^App) -> bool {
			return a.frame_count < a.opts.run_for
		}
	}

	quit: bool
	for should_loop(app) {
		defer app.frame_count += 1
		quit = app_update(app)
		if quit {break}
	}
}

app_update :: proc(app: ^App) -> (quit: bool) {
	context = app.ctx

	quit = sdl_frame_begin(&app.sdl)
	if quit {return}
	defer sdl_frame_end(&app.sdl)

	game_update(&app.game)
	game_draw(&app.game, &app.sdl.renderer)

	return
}

