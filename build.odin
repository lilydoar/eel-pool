#+feature dynamic-literals

package build

import "core:flags"
import "core:log"
import os "core:os/os2"
import "core:path/filepath"
import "core:slice"
import "core:strings"

Options :: struct {
	clean:   bool `usage:"Clean the build directory"`,
	release: bool `usage:"Produce a release build"`,
	dev:     bool `usage:"Produce a development build"`,
	gamelib: bool `usage:"Build the game code as a dynamic library"`,
	test:    bool `usage:"Build and run all test functions"`,
	docs:    bool `usage:"Generate documentation"`,
	check:   bool `usage:"Check for compilation errors and successful initialization"`,
	run:     bool `usage:"Run the targets after building"`,
	run_arg: [dynamic]string `usage:"Arguments to pass to the application when running"`,
	verbose: bool `usage:"Enable verbose output"`,
	debug:   bool `usage:"Enable debug mode"`,
}

Config :: struct {
	game: struct {
		src:     string,
		out:     string,
		release: struct {
			entry: string,
			out:   string,
			flags: [dynamic]string,
		},
		dev:     struct {
			entry: string,
			out:   string,
			flags: [dynamic]string,
		},
		gamelib: struct {
			lib:   string,
			out:   string,
			flags: [dynamic]string,
		},
		docs:    struct {
			out: string,
		},
	},
}

log_opts :: log.Options {
	.Level,
	.Date,
	.Time,
	// .Short_File_Path,
	// .Long_File_Path,
	.Line,
	.Procedure,
	.Terminal_Color,
	// .Thread_Id,
}

main :: proc() {
	opt: Options
	flags.parse_or_exit(&opt, os.args)

	level := log.Level.Info
	if opt.verbose {level = log.Level.Debug}

	context.logger = log.create_console_logger(level, log_opts)

	cfg := Config {
		game = {
			src = "src",
			out = "bin/",
			release = {
				entry = "entry/game/",
				out = "release/game",
				flags = {"-warnings-as-errors", "-disable-assert", "-o:speed"},
			},
			dev = {entry = "entry/game/", out = "develop/game", flags = {"-debug"}},
			gamelib = {lib = "lib/game/", out = "gamelib/game", flags = {"-debug"}},
			docs = {out = "docs/gen/"},
		},
	}

	if opt.debug {
		append(&cfg.game.dev.flags, "-define:FRAME_DEBUG=true")
	}

	if opt.clean {
		log.info("Cleaning the build directory")
		must_run_proc({command = {"rm", "-rf", cfg.game.out}})
	}

	if opt.check {check(cfg)}
	if opt.docs {docs(cfg)}
	if opt.test {tests()}
	if opt.gamelib {gamelib(opt, cfg)}
	if opt.dev {dev(opt, cfg)}
	if opt.release {release(opt, cfg)}
}

run_proc :: proc(desc: os.Process_Desc, timeout := os.TIMEOUT_INFINITE) -> bool {
	assert(len(desc.command) > 0)

	log.debugf("Running process: {}", strings.join(desc.command, " "))
	desc := desc

	if desc.stdout == nil {desc.stdout = os.stdout}
	if desc.stderr == nil {desc.stderr = os.stderr}

	process, start_err := os.process_start(desc)
	if start_err != os.ERROR_NONE {
		log.errorf("start process: {}", start_err)
		return false
	}

	state, wait_err := os.process_wait(process, timeout)
	if wait_err != os.ERROR_NONE {
		log.errorf("wait for process: {}", wait_err)
		return false
	}

	return true
}

must_run_proc :: proc(desc: os.Process_Desc, timeout := os.TIMEOUT_INFINITE) {
	assert(run_proc(desc, timeout))
}

check :: proc(cfg: Config) {
	log.info("Checking code for compilation errors")

	must_run_proc(
		{command = {"odin", "check", cfg.game.src, "-no-entry-point", "-warnings-as-errors"}},
	)
}

docs :: proc(cfg: Config) {
	out_dir := filepath.join({cfg.game.out, cfg.game.docs.out})

	log.infof("Generating documentation to {}", out_dir)
	must_run_proc({command = {"mkdir", "-p", out_dir}})

	// build.odin
	path := filepath.join({out_dir, "build.odin-doc"})
	file_build_doc, err_build_doc := os.create(path)
	assert(err_build_doc == os.ERROR_NONE)
	defer os.close(file_build_doc)

	run_proc({command = {"odin", "doc", "build.odin", "-file"}, stdout = file_build_doc})

	// game package
	path = filepath.join({out_dir, "game.odin-doc"})
	file_game_doc, err_game_doc := os.create(path)
	assert(err_game_doc == os.ERROR_NONE)
	defer os.close(file_game_doc)

	run_proc({command = {"odin", "doc", cfg.game.src, "-no-entry-point"}, stdout = file_game_doc})
}


tests :: proc() {
	log.info("Running tests")
	log.warn("tests not implemented")
}

gamelib :: proc(opt: Options, cfg: Config) {
	entry := filepath.join({cfg.game.src, cfg.game.gamelib.lib})
	out := filepath.join({cfg.game.out, cfg.game.gamelib.out})

	log.info("Building game code as a dynamic library")
	must_run_proc({command = {"mkdir", "-p", filepath.dir(out)}})

	cmd_build := [dynamic]string {
		"odin",
		"build",
		entry,
		strings.concatenate({"-out:", out}),
		"-build-mode:dll",
	}

	for flag in cfg.game.gamelib.flags {
		append(&cmd_build, flag)
	}

	run_proc({command = cmd_build[:]})
}

dev :: proc(opt: Options, cfg: Config) {
	entry := filepath.join({cfg.game.src, cfg.game.dev.entry})
	out := filepath.join({cfg.game.out, cfg.game.dev.out})

	log.info("Building a development build")
	must_run_proc({command = {"mkdir", "-p", filepath.dir(out)}})

	cmd_build := [dynamic]string{"odin", "build", entry, strings.concatenate({"-out:", out})}

	for flag in cfg.game.dev.flags {
		append(&cmd_build, flag)
	}

	run_proc({command = cmd_build[:]})

	if opt.run || opt.check {
		log.info("Running development build")

		cmd_run := [dynamic]string{out}

		if opt.check {
			log.debug("Checking development build for successful initialization")
			append(&cmd_run, "-check")
		}

		append(&cmd_run, ..opt.run_arg[:])

		run_proc({command = cmd_run[:]})
	}
}

release :: proc(opt: Options, cfg: Config) {
	entry := filepath.join({cfg.game.src, cfg.game.release.entry})
	out := filepath.join({cfg.game.out, cfg.game.release.out})

	log.info("Building a release build")
	must_run_proc({command = {"mkdir", "-p", filepath.dir(out)}})

	cmd_build := [dynamic]string{"odin", "build", entry, strings.concatenate({"-out:", out})}

	for flag in cfg.game.release.flags {
		append(&cmd_build, flag)
	}

	run_proc({command = cmd_build[:]})

	if opt.run || opt.check {
		log.info("Running release build")

		cmd_run := [dynamic]string{out}

		if opt.check {
			log.debug("Checking release build for successful initialization")
			append(&cmd_run, "-check")
		}

		append(&cmd_run, ..opt.run_arg[:])

		run_proc({command = cmd_run[:]})
	}
}

