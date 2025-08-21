package build

import "core:flags"
import "core:log"
import os "core:os/os2"
import "core:path/filepath"
import "core:slice"
import "core:strings"

// TODO: move constants into a cfg file for build profiles
//
// {
//   "directories": {
//     "build": "bin/",
//     "src": "src/",
//     "docs": "docs/gen"
//   },
//   "targets": {
//     "release": {
//       "dir": "bin/release/",
//       "entry": "src/entry/release/",
//       "docs": "bin/release/docs/"
//     },
//     "develop": {
//       "dir": "bin/develop/",
//       "entry": "src/entry/develop/"
//     },
//     "gamelib": {
//       "dir": "bin/gamelib/"
//     },
//     "test": {
//       "dir": "bin/test"
//     }
//   },
//   "exe_name": "game"
// }

BUILD_DIR: string : "bin/"
EXE: string : "game"

RELEASE_DIR: string : BUILD_DIR + "release/"
RELEASE_DIR_DOCS: string : RELEASE_DIR + "docs/"
DEVELOP_DIR: string : BUILD_DIR + "develop/"
GAMELIB_DIR: string : BUILD_DIR + "gamelib/"
TEST_DIR: string : BUILD_DIR + "test"

DOCS_DIR: string : "docs/gen"

SRC_DIR: string : "src/"
ENTRY_DIR: string : SRC_DIR + "entry/"
ENTRY_DIR_RELEASE: string : ENTRY_DIR + "release/"
ENTRY_DIR_DEVELOP: string : ENTRY_DIR + "develop/"
GAME_DIR: string : SRC_DIR + "game/"

cmds_have_failed: bool = false
tests_have_run: bool = false

Options :: struct {
	all:      bool `usage:"Build all targets"`,
	release:  bool `usage:"Produce a release build"`,
	develop:  bool `usage:"Produce a development build"`,
	gamelib:  bool `usage:"Build the game code as a dynamic library"`,
	docs:     bool `usage:"Generate documentation"`,
	test:     bool `usage:"Build and run all test functions"`,
	check:    bool `usage:"Check for compilation errors and successful initialization"`,
	run:      bool `usage:"Run the targets after building"`,
	run_arg:  [dynamic]string `usage:"Arguments to pass to the application when running"`,
	verbose:  bool `usage:"Enable verbose output"`,
	clean:    bool `usage:"Clean the build directory before building"`,
	no_tests: bool `usage:"Do not run tests (release builds default to running tests)"`,
}

main :: proc() {
	opt: Options
	flags.parse_or_exit(&opt, os.args)

	level := log.Level.Info
	if opt.verbose {level = log.Level.Debug}
	context.logger = log.create_console_logger(level)

	if opt.clean {
		log.info("Cleaning the build directory")
		must_run_proc({command = []string{"rm", "-rf", BUILD_DIR}})
	}

	if opt.all {
		log.info("Building all targets")
		opt.release = true
		opt.develop = true
		opt.gamelib = true
		opt.docs = true
		opt.test = true
		opt.check = true
	}

	if opt.check {
		log.info("Checking code for compilation errors")

		dirs: [dynamic]string
		append(&dirs, "tests", "app", "game")
		if opt.develop {append(&dirs, "entry/develop")}
		if opt.release {append(&dirs, "entry/release")}

		for dir in dirs {
			check_cmd := []string {
				"odin",
				"check",
				filepath.join({SRC_DIR, dir}),
				"-no-entry-point",
				"-warnings-as-errors",
			}
			must_run_proc({command = check_cmd})
		}
	}

	if opt.gamelib {
		log.info("Building the game as a dynamic library")

		must_run_proc({command = {"mkdir", "-p", GAMELIB_DIR}})

		gamelib_cmd := []string {
			"odin",
			"build",
			GAME_DIR,
			strings.concatenate({"-out:", filepath.join({GAMELIB_DIR, "game"})}),
			"-debug",
			"-build-mode:dll",
		}
		must_run_proc({command = gamelib_cmd})
	}

	if opt.docs {do_doc_gen()}

	if opt.test && !opt.no_tests {do_tests()}

	// TODO: Lint

	// TODO: Format

	// TODO: Other CI tasks: building images for testing environments, pushing builds to repositories, etc.

	if opt.develop {
		log.info("Building a development build")

		must_run_proc({command = {"mkdir", "-p", DEVELOP_DIR}})

		develop_cmd := []string {
			"odin",
			"build",
			ENTRY_DIR_DEVELOP,
			"-out:" + DEVELOP_DIR + EXE,
			"-debug",
		}
		must_run_proc({command = develop_cmd})

		if opt.check {
			log.info("Checking development build for successful initialization")
			must_run_proc({command = {DEVELOP_DIR + EXE, "-check"}})
		}

		if opt.run {
			log.info("Running development build")

			cmd := [dynamic]string{}
			append(&cmd, DEVELOP_DIR + EXE)
			append(&cmd, ..opt.run_arg[:])
			must_run_proc({command = cmd[:]})
		}
	}

	if opt.release {
		if !opt.no_tests {do_tests()}

		do_doc_gen(out = RELEASE_DIR_DOCS)

		log.info("Building a release build")

		must_run_proc({command = {"mkdir", "-p", RELEASE_DIR}})


		release_cmd := []string {
			"odin",
			"build",
			ENTRY_DIR_RELEASE,
			"-out:" + RELEASE_DIR + EXE,
			"-disable-assert",
			"-o:speed",
			"-warnings-as-errors",
		}
		must_run_proc({command = release_cmd})

		if opt.check {
			log.info("Checking release build for successful initialization")
			must_run_proc({command = {RELEASE_DIR + EXE, "-check"}})
		}

		if opt.run {
			log.info("Running release build")
			must_run_proc({command = {RELEASE_DIR + EXE}})
		}
	}

	if cmds_have_failed {
		log.info("Run with -verbose to see more details")
		os.exit(1)
	}
}

do_tests :: proc() {
	if tests_have_run {
		log.debug("Tests have already been run, skipping")
		return
	}
	tests_have_run = true

	log.info("Running tests")

	must_run_proc({command = {"mkdir", "-p", TEST_DIR}})

	test_build_cmd := []string {
		"odin",
		"build",
		"build.odin",
		"-file",
		strings.concatenate({"-out:", filepath.join({TEST_DIR, "build"})}),
	}
	must_run_proc({command = test_build_cmd})

	dirs: []string = {"tests"}
	for dir in dirs {
		test_cmd := []string {
			"odin",
			"test",
			filepath.join({SRC_DIR, dir}),
			strings.concatenate({"-out:", filepath.join({BUILD_DIR, "test", dir})}),
			"-debug",
			"-warnings-as-errors",
		}
		run_proc({command = test_cmd})
	}
}

do_doc_gen :: proc(out: string = DOCS_DIR) {
	log.infof("Generating documentation to {}", out)

	must_run_proc({command = {"mkdir", "-p", out}})

	path := filepath.join({out, strings.concatenate({"build", ".odin-doc"})})
	file, err := os.create(path);assert(err == os.ERROR_NONE, "Create doc file")
	defer os.close(file)

	doc_cmd := []string{"odin", "doc", "build.odin", "-file"}
	run_proc({command = doc_cmd, stdout = file})

	dirs: []string = {"app", "game", "tests"}
	for dir in dirs {
		path := filepath.join({out, strings.concatenate({dir, ".odin-doc"})})
		file, err := os.create(path);assert(err == os.ERROR_NONE, "Create doc file")
		defer os.close(file)

		doc_cmd := []string{"odin", "doc", filepath.join({SRC_DIR, dir})}
		run_proc({command = doc_cmd, stdout = file})
	}
}

run_proc :: proc(desc: os.Process_Desc, timeout := os.TIMEOUT_INFINITE) -> bool {
	assert(len(desc.command) > 0)

	log.debugf("Running process: {}", strings.join(desc.command, " "))

	process, start_err := os.process_start(desc)
	if start_err != os.ERROR_NONE {
		log.errorf("start process: {}", start_err)
		return false
	}

	state, wait_err := os.process_wait(process)
	if wait_err != os.ERROR_NONE {
		log.errorf("wait for process: {}", wait_err)
		return false
	}

	return true
}

must_run_proc :: proc(desc: os.Process_Desc, timeout := os.TIMEOUT_INFINITE) {
	assert(run_proc(desc, timeout))
}

