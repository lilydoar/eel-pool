package game

import "base:runtime"
import "core:log"
import os "core:os/os2"
import "core:time"

App :: struct {
	ctx:  runtime.Context,
	opts: Options,
	cfg:  Config,
	sdl:  SDL,
	time: App_Time,
	game: Game,
}

App_Time :: struct {
	curr:                 time.Time,
	prev:                 time.Time,
	frame_count:          u64,
	// The number of game updates performed in the current frame
	frame_updates:        u32,
	frame_accumulator_ms: f64,
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

	animations_init(&app.sdl)

	game_init(&app.game, app.ctx, app.ctx.logger)

	// TODO: Initialize other subsystems (e.g., job system, ...)
}

app_deinit :: proc(app: ^App) {
	context = app.ctx

	log.info("Deinitializing Application...")
	defer log.info("Application deinitialized")

	game_deinit(&app.game)

	animations_deinit(&app.sdl)

	sdl_deinit(&app.sdl)
}

should_loop: proc(a: ^App) -> bool = proc(a: ^App) -> bool {return true}

should_update: proc(a: ^App) -> bool = proc(a: ^App) -> bool {
	if a.time.frame_updates >= a.cfg.max_updates_per_frame {
		log.warn("Dropping accumulated time")
		a.time.frame_accumulator_ms = 0
		return false
	}

	ok := a.time.frame_accumulator_ms >= a.game.frame_step_ms
	if ok {a.time.frame_accumulator_ms -= a.game.frame_step_ms}

	return ok
}

app_run :: proc(app: ^App) {
	context = app.ctx

	if app.opts.check {
		log.info("App initialized successfully and -check flag is enabled, exiting...")
		return
	}

	if app.opts.run_for > 0 {
		log.infof("Running App for {} frames then exiting.", app.opts.run_for)
		should_loop = proc(a: ^App) -> bool {
			return a.time.frame_count < a.opts.run_for
		}
	}

	app.time.curr = time.now()

	quit: bool
	for should_loop(app) {
		app.time.prev = app.time.curr
		app.time.curr = time.now()
		app.time.frame_count += 1

		quit = app_update(app)
		if quit {break}
	}
}

app_update :: proc(app: ^App) -> (quit: bool) {
	context = app.ctx

	when FRAME_DEBUG {log.debug("Begin app frame")}
	when FRAME_DEBUG {defer log.debug("End app frame")}

	quit = sdl_frame_begin(&app.sdl)
	if quit {return}
	defer sdl_frame_end(&app.sdl)

	time_delta := time.diff(app.time.prev, app.time.curr)
	app.time.frame_accumulator_ms += time.duration_milliseconds(time_delta)
	app.time.frame_updates = 0

	when FRAME_DEBUG {
		log.debugf(
			"App frame {}: dt=%fms, accumulator=%fms",
			app.time.frame_count,
			time.duration_milliseconds(time_delta),
			app.time.frame_accumulator_ms,
		)
	}

	for should_update(app) {game_update(&app.sdl, &app.game)}
	game_draw(&app.game, &app.sdl.renderer)
	sdl_draw_debug(&app.sdl)

	return
}

