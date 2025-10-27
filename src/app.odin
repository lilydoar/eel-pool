package game

import "base:runtime"
import "core:log"
import os "core:os/os2"
import "core:strconv"
import "core:strings"
import "core:time"
import "data"

App :: struct {
	ctx:             runtime.Context,
	opts:            Options,
	cfg:             Config,
	sdl:             SDL,
	time:            App_Time,

	//
	game_config:     Game_Config,
	game_state:      Game_State,
	game_head:       Maybe(Game_Head),

	//
	asset_manager:   data.Asset_Manager,
	assets:          Game_Assets,
	capture_frames:  [dynamic]u64, // Frame numbers to capture
	capture_on_exit: bool, // Capture on application exit
}

App_Time :: struct {
	curr:                         time.Time,
	prev:                         time.Time,
	frame_count:                  u64,
	// The number of game updates performed in the current frame
	game_updates:                 u32,
	// The accumulator collects time and when it has enough time, it performs game updates 
	game_updates_accumulator_sec: f64,
}

app_create_logger :: proc(app: ^App) -> (l: log.Logger) {
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

	// Parse capture option
	app_parse_capture_option(app)

	// TODO: Load from dev/release config
	sdl_opts := SDL_Options {
		window_title = "eel-pool",
		window_size  = {1280, 720},
		window_flags = {.RESIZABLE},
		clear_color  = {71, 171, 169, 255},
	}
	sdl_init(&app.sdl, sdl_opts)

	// Initialize asset manager
	app.asset_manager, _ = data.asset_manager_init()

	game_assets_init(&app.assets, &app.sdl)

	// Initialize game_head
	app.game_head = Game_Head{}

	game_init(
		&app.game_config,
		&app.game_state,
		&app.game_head.?,
		app.ctx,
		app.ctx.logger,
		&app.sdl,
		&app.asset_manager,
		&app.assets,
	)

	// TODO: Initialize other subsystems (e.g., job system, ...)
}

app_deinit :: proc(app: ^App) {
	context = app.ctx

	log.info("Deinitializing Application...")
	defer log.info("Application deinitialized")

	if head, ok := app.game_head.?; ok {
		game_deinit(&app.game_config, &app.game_state, &head)
	}

	game_assets_deinit(&app.assets, &app.sdl)

	data.asset_manager_deinit(&app.asset_manager)

	sdl_deinit(&app.sdl)

	delete(app.capture_frames)
}

should_loop: proc(a: ^App) -> bool = proc(a: ^App) -> bool {return true}

should_update: proc(a: ^App) -> bool = proc(a: ^App) -> bool {
	if a.time.game_updates >= a.cfg.max_updates_per_frame {
		log.warn("Dropping accumulated time")
		a.time.game_updates_accumulator_sec = 0
		return false
	}

	frame_step_sec := 1.0 / a.game_config.game.update_hz
	ok := a.time.game_updates_accumulator_sec >= frame_step_sec
	if ok {a.time.game_updates_accumulator_sec -= frame_step_sec}

	return ok
}

should_capture_on_exit: proc(a: ^App) -> bool = proc(a: ^App) -> bool {return false}

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

	if app.capture_on_exit {
		should_capture_on_exit = proc(a: ^App) -> bool {
			// Capture if we're about to exit (next iteration won't loop)
			return a.time.frame_count > 0 && !should_loop(a)
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

	when DEBUG_FRAME {log.debug("Begin app frame")}
	when DEBUG_FRAME {defer log.debug("End app frame")}

	time_delta := time.diff(app.time.prev, app.time.curr)
	delta_ms := f32(time.duration_milliseconds(time_delta))

	quit = sdl_frame_begin(&app.sdl, delta_ms)
	if quit {return}

	// Check if we should capture a screenshot this frame
	capture_screen := false
	for frame in app.capture_frames {
		if app.time.frame_count == frame {
			capture_screen = true
			break
		}
	}

	defer {
		if capture_screen {
			sdl_capture_screenshot(&app.sdl)
			// TODO: app.game_instance.debug.capture_feedback_time = 2000.0
		}

		// Capture from interactive key press (0 key)
		// TODO: if app.game_instance.debug.capture_screenshot_pending {
		if false {
			sdl_capture_screenshot(&app.sdl)
			// TODO: app.game_instance.debug.capture_feedback_time = 2000.0
			// TODO: app.game_instance.debug.capture_screenshot_pending = false
		}

		// Capture on exit if this is the last frame
		if should_capture_on_exit(app) {
			log.info("Capturing screenshot on exit")
			sdl_capture_screenshot(&app.sdl)
		}

		sdl_frame_end(&app.sdl)
	}

	app.time.game_updates_accumulator_sec += time.duration_seconds(time_delta)
	app.time.game_updates = 0

	when DEBUG_FRAME {
		log.debugf(
			"App frame {}: dt=%fsec, accumulator=%fsec",
			app.time.frame_count,
			time.duration_seconds(time_delta),
			app.time.game_updates_accumulator_sec,
		)
	}

	for should_update(app) {
		game_update(&app.sdl, &app.game_config, &app.game_state, &app.asset_manager)
	}
	if head, ok := app.game_head.?; ok {
		game_draw(&app.game_config, &app.game_state, &head, &app.sdl.renderer)
	}

	return
}

// Parse the -capture option to extract frame numbers and 'exit' keyword
app_parse_capture_option :: proc(app: ^App) {
	if len(app.opts.capture) == 0 {
		return
	}

	app.capture_frames = make([dynamic]u64)

	// Split by comma
	parts := strings.split(app.opts.capture, ",", context.temp_allocator)

	for part in parts {
		trimmed := strings.trim_space(part)

		if trimmed == "exit" {
			app.capture_on_exit = true
			log.debugf("Capture enabled: on exit")
		} else {
			// Try to parse as frame number
			frame, ok := strconv.parse_u64(trimmed)
			if ok {
				append(&app.capture_frames, frame)
				log.debugf("Capture enabled: frame {}", frame)
			} else {
				log.warnf("Invalid capture value, ignoring: '{}'", trimmed)
			}
		}
	}
}

