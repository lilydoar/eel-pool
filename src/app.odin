package game

import "base:runtime"
import "core:log"
import os "core:os/os2"

App :: struct {
	ctx:         runtime.Context,
	opts:        Options,
	cfg:         Config,
	sdl:         SDL,
	wgpu:        WGPU,
	game_api:    GameAPI,

	// Runtime
	frame_count: u64,
}

app_init :: proc(app: ^App, ctx: runtime.Context) {
	context = ctx

	app.opts = cli_parse()
	app.cfg = config_load(app.opts)

	app.ctx = ctx
	app.ctx.logger = app_create_logger(app)

	context = app.ctx

	// TODO: Load from dev/release config
	sdl_opts := SDL_Options {
		window_title = "eel-pool",
		window_size  = {1280, 720},
		window_flags = {.RESIZABLE},
	}
	sdl_init(&app.sdl, sdl_opts)

	wgpu_init(&app.wgpu, &app.sdl)

	// TODO: Load game API path from config
	app.game_api = game_api_init("./bin/gamelib").api
	app.game_api.init()

	// TODO: Initialize other subsystems (e.g., game, job, ...)
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

app_deinit :: proc(app: ^App) {
	context = app.ctx

	app.game_api.deinit()

	wgpu_deinit(&app.wgpu)
	sdl_deinit(&app.sdl)
}

should_loop: proc(a: ^App) -> bool = proc(a: ^App) -> bool {return true}

app_run :: proc(app: ^App) {
	context = app.ctx

	if app.opts.check {
		log.info("App initialized successfully, exiting.")
		return
	}

	if app.opts.run_for > 0 {
		log.infof("Running App for %d frames then exiting.", app.opts.run_for)
		should_loop = proc(a: ^App) -> bool {return a.frame_count < a.opts.run_for}
	}

	quit: bool
	for should_loop(app) {
		defer app.frame_count += 1
		quit = app_update(app)
		if quit {break}

		app.game_api.update()
	}
}

app_update :: proc(app: ^App) -> (quit: bool) {
	quit = sdl_begin_frame(&app.sdl)
	if quit {return}

	if sdl_is_window_resized(&app.sdl) {
		wgpu_resize(&app.wgpu, app.sdl.window.size_curr)
	}

	frame := wgpu_frame_begin(&app.wgpu, sdl_get_window_size(&app.sdl))
	defer wgpu_frame_end(&app.wgpu, frame)

	return
}

