#+feature dynamic-literals

package build

import "core:flags"
import "core:log"
import os "core:os/os2"
import "core:path/filepath"
import "core:slice"
import "core:strings"

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
	run_env: [dynamic]string `usage:"Environment to pass to the application when running"`,
	verbose: bool `usage:"Enable verbose output"`,
	debug:   bool `usage:"Enable debug mode"`,
}

Config :: struct {
	src:     string,
	out:     string,
	release: struct {
		entry: string,
		out:   string,
		flags: [dynamic]string,
		env:   [dynamic]string,
	},
	dev:     struct {
		entry: string,
		out:   string,
		flags: [dynamic]string,
		env:   [dynamic]string,
	},
	gamelib: struct {
		lib:   string,
		out:   string,
		flags: [dynamic]string,
	},
	docs:    struct {
		out: string,
	},
}

cmd_failed := false

main :: proc() {
	opt: Options
	flags.parse_or_exit(&opt, os.args)

	level := log.Level.Info
	if opt.verbose {level = log.Level.Debug}

	context.logger = log.create_console_logger(level, log_opts)

	if len(os.args) == 1 {
		// TODO: Call help command
		return
	}

	cfg := Config {
		src = "src",
		out = "bin/",
		release = {
			entry = "entry/game/",
			out = "release/game",
			flags = {"-warnings-as-errors", "-disable-assert", "-o:speed"},
		},
		dev = {
			entry = "entry/game/",
			out = "develop/game",
			flags = {"-debug"},
			env = {"RUST_BACKTRACE=1"},
		},
		gamelib = {lib = "lib/game/", out = "gamelib/game", flags = {"-debug"}},
		docs = {out = "docs/gen/"},
	}

	for str in opt.run_arg {append(&cfg.release.env, str)}
	for str in opt.run_arg {append(&cfg.dev.env, str)}

	if opt.debug {
		append(&cfg.dev.flags, "-define:FRAME_DEBUG=true")
	}

	if opt.clean {
		log.info("Cleaning the build directory")
		must_run_proc({command = {"rm", "-rf", cfg.out}})
	}

	if opt.check {check(cfg)}
	if opt.docs {docs(cfg)}
	if opt.test {tests()}
	if opt.gamelib {gamelib(opt, cfg)}
	if opt.dev {dev(opt, cfg)}
	if opt.release {release(opt, cfg)}

	if cmd_failed {
		log.warn("A command failed. Run with -verbose for more information")
		os.exit(1)
	}
}

run_proc :: proc(desc: os.Process_Desc, timeout := os.TIMEOUT_INFINITE) -> bool {
	assert(len(desc.command) > 0)

	log.debugf("Running process: {}", strings.join(desc.command, " "))
	if len(desc.env) > 0 {
		log.debugf("With environment:")
		for e in desc.env {log.debugf("  {}", e)}
	}

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

	return state.exit_code == 0
}

must_run_proc :: proc(desc: os.Process_Desc, timeout := os.TIMEOUT_INFINITE) {
	assert(run_proc(desc, timeout))
}

check :: proc(cfg: Config) {
	log.info("Checking code for compilation errors")

	ok := run_proc(
		{command = {"odin", "check", cfg.src, "-no-entry-point", "-warnings-as-errors"}},
	)
	if !ok {cmd_failed = true}
}

docs :: proc(cfg: Config) {
	out_dir := filepath.join({cfg.out, cfg.docs.out})

	log.infof("Generating documentation to {}", out_dir)
	must_run_proc({command = {"mkdir", "-p", out_dir}})

	// build.odin
	path := filepath.join({out_dir, "build.odin-doc"})
	file_build_doc, err_build_doc := os.create(path)
	assert(err_build_doc == os.ERROR_NONE)
	defer os.close(file_build_doc)

	ok := run_proc({command = {"odin", "doc", "build.odin", "-file"}, stdout = file_build_doc})
	if !ok {cmd_failed = true}

	// game package
	path = filepath.join({out_dir, "game.odin-doc"})
	file_game_doc, err_game_doc := os.create(path)
	assert(err_game_doc == os.ERROR_NONE)
	defer os.close(file_game_doc)

	ok = run_proc({command = {"odin", "doc", cfg.src, "-no-entry-point"}, stdout = file_game_doc})
	if !ok {cmd_failed = true}
}


tests :: proc() {
	log.info("Running tests")
	log.warn("tests not implemented")
}

gamelib :: proc(opt: Options, cfg: Config) {
	entry := filepath.join({cfg.src, cfg.gamelib.lib})
	out := filepath.join({cfg.out, cfg.gamelib.out})

	log.info("Building game code as a dynamic library")
	must_run_proc({command = {"mkdir", "-p", filepath.dir(out)}})

	cmd_build := [dynamic]string {
		"odin",
		"build",
		entry,
		strings.concatenate({"-out:", out}),
		"-build-mode:dll",
	}

	for flag in cfg.gamelib.flags {
		append(&cmd_build, flag)
	}

	ok := run_proc({command = cmd_build[:]})
	if !ok {cmd_failed = true}
}

dev :: proc(opt: Options, cfg: Config) {
	entry := filepath.join({cfg.src, cfg.dev.entry})
	out := filepath.join({cfg.out, cfg.dev.out})

	log.info("Building a development build")
	must_run_proc({command = {"mkdir", "-p", filepath.dir(out)}})

	cmd_build := [dynamic]string{"odin", "build", entry, strings.concatenate({"-out:", out})}

	for flag in cfg.dev.flags {
		append(&cmd_build, flag)
	}

	ok := run_proc({command = cmd_build[:]})
	if !ok {cmd_failed = true}

	if opt.run || opt.check && ok {
		log.info("Running development build")

		cmd_run := [dynamic]string{out}

		if opt.check {
			log.debug("Checking development build for successful initialization")
			append(&cmd_run, "-check")
		}

		append(&cmd_run, ..opt.run_arg[:])

		ok = run_proc({command = cmd_run[:], env = cfg.dev.env[:]})
		if !ok {cmd_failed = true}
	}
}

release :: proc(opt: Options, cfg: Config) {
	entry := filepath.join({cfg.src, cfg.release.entry})
	out := filepath.join({cfg.out, cfg.release.out})

	log.info("Building a release build")
	must_run_proc({command = {"mkdir", "-p", filepath.dir(out)}})

	cmd_build := [dynamic]string{"odin", "build", entry, strings.concatenate({"-out:", out})}

	for flag in cfg.release.flags {
		append(&cmd_build, flag)
	}

	ok := run_proc({command = cmd_build[:]})
	if !ok {cmd_failed = true}

	if opt.run || opt.check && ok {
		log.info("Running release build")

		cmd_run := [dynamic]string{out}

		if opt.check {
			log.debug("Checking release build for successful initialization")
			append(&cmd_run, "-check")
		}

		append(&cmd_run, ..opt.run_arg[:])

		ok = run_proc({command = cmd_run[:], env = cfg.release.env[:]})
		if !ok {cmd_failed = true}
	}
}

