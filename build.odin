package build

import "core:flags"
import "core:log"
import os "core:os/os2"
import "core:path/filepath"
import "core:slice"
import "core:strings"

Options :: struct {
	all:     bool `usage:"Build all targets"`,
	release: bool `usage:"Produce a release build"`,
	develop: bool `usage:"Produce a development build"`,
	gamelib: bool `usage:"Build the game code as a dynamic library"`,
	test:    bool `usage:"Build and run all test functions"`,
	verbose: bool `usage:"Enable verbose output"`,
	clean:   bool `usage:"Clean the build directory before building"`,
}

main :: proc() {
	opt: Options
	flags.parse_or_exit(&opt, os.args)

	level := log.Level.Info
	if opt.verbose {level = log.Level.Debug}
	context.logger = log.create_console_logger(level)

	if opt.clean {
		log.info("Cleaning the build directory")

		must_run("rm -rf bin")
	}

	if opt.all {
		log.info("Building all targets")
		opt.release = true
		opt.develop = true
		opt.gamelib = true
		opt.test = true
	}

	if opt.release {
		log.info("Building a release build")

		must_run("mkdir -p bin/release")
		must_run(
			"odin build src/entry/release -out:bin/release/eel-pool -disable-assert -o:speed -warnings-as-errors",
		)
	}

	if opt.develop {
		log.info("Building a development build")

		must_run("mkdir -p bin/develop")
		must_run("odin build src/entry/develop -out:bin/develop/eel-pool -debug -ignore-warnings")
	}

	if opt.gamelib {
		log.info("Building the game as a dynamic library")

		must_run("mkdir -p bin/gamelib")
		must_run("odin build src/game -out:bin/gamelib/game -debug -build-mode:dynamic")
	}

	if opt.test {
		log.info("Running tests")

		must_run("mkdir -p bin/test")
		must_run("odin build build.odin -file -out:bin/test/build")

		dirs: []string = {"tests"}
		for dir in dirs {
			path := strings.join({"src", dir}, "/")
			must_run([]string{"odin", "test", path})
		}
	}
}

run :: proc {
	run_slice,
	run_string,
}

run_slice :: proc(cmd: []string) -> bool {
	context.allocator = context.temp_allocator

	log.debugf("Running: {}", strings.join(cmd, " "))

	process, err_start := os.process_start(
		{command = cmd, stdin = os.stdin, stdout = os.stdout, stderr = os.stderr},
	)
	if err_start != os.ERROR_NONE {
		log.errorf("Failed to start process: {}", err_start)
		return false
	}

	state, err_wait := os.process_wait(process)
	if err_wait != os.ERROR_NONE {
		log.errorf("Failed to wait for process: {}", err_wait)
		return false
	}

	return true
}

run_string :: proc(cmd: string) -> bool {return run_slice(strings.split(cmd, " "))}

must_run :: proc {
	must_run_slice,
	must_run_string,
}

must_run_slice :: proc(cmd: []string) {assert(run(cmd), "Process failed")}
must_run_string :: proc(cmd: string) {assert(run(cmd), "Process failed")}

