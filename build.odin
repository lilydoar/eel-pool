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

BUILD_DIR: string : "bin/"

RELEASE_DIR: string : BUILD_DIR + "release/"
RELEASE_EXE: string : RELEASE_DIR + "eel-pool"

DEVELOP_DIR: string : BUILD_DIR + "develop"
DEVELOP_EXE: string : DEVELOP_DIR + "eel-pool"

GAMELIB_DIR: string : BUILD_DIR + "gamelib/"

TEST_DIR: string : BUILD_DIR + "test"

main :: proc() {
	opt: Options
	flags.parse_or_exit(&opt, os.args)

	level := log.Level.Info
	if opt.verbose {level = log.Level.Debug}
	context.logger = log.create_console_logger(level)

	if opt.clean {
		log.info("Cleaning the build directory")

		must_run([]string{"rm", "-rf", BUILD_DIR})
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

		must_run([]string{"mkdir", "-p", RELEASE_DIR})

		release_cmd := []string {
			"odin",
			"build",
			"src/entry/release",
			"-out:" + RELEASE_EXE,
			"-disable-assert",
			"-o:speed",
			"-warnings-as-errors",
		}
		must_run(release_cmd)
	}

	if opt.develop {
		log.info("Building a development build")

		must_run([]string{"mkdir", "-p", DEVELOP_DIR})

		develop_cmd := []string {
			"odin",
			"build",
			"src/entry/develop",
			"-out:" + DEVELOP_EXE,
			"-debug",
		}
		must_run(develop_cmd)
	}

	if opt.gamelib {
		log.info("Building the game as a dynamic library")

		must_run([]string{"mkdir", "-p", GAMELIB_DIR})

		gamelib_out := filepath.join({GAMELIB_DIR, "game"})
		gamelib_cmd := []string {
			"odin",
			"build",
			"src/game",
			strings.concatenate({"-out:", gamelib_out}),
			"-debug",
			"-build-mode:dll",
		}
		must_run(gamelib_cmd)
	}

	if opt.test {
		log.info("Running tests")

		must_run([]string{"mkdir", "-p", TEST_DIR})

		test_build_cmd := []string {
			"odin",
			"build",
			"build.odin",
			"-file",
			strings.concatenate({"-out:", filepath.join({TEST_DIR, "build"})}),
		}
		must_run(test_build_cmd)

		dirs: []string = {"tests"}
		for dir in dirs {
			test_cmd := []string {
				"odin",
				"test",
				filepath.join({"src", dir}),
				strings.concatenate({"-out:", filepath.join({BUILD_DIR, "test", dir})}),
				"-debug",
				"-warnings-as-errors",
			}
			must_run(test_cmd)
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

