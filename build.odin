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
	docs:    bool `usage:"Generate documentation"`,
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

DOCS_DIR: string : "docs/"
DOCS_GEN_DIR: string : DOCS_DIR + "gen/"

main :: proc() {
	opt: Options
	flags.parse_or_exit(&opt, os.args)

	level := log.Level.Info
	if opt.verbose {level = log.Level.Debug}
	context.logger = log.create_console_logger(level)

	if opt.clean {
		log.info("Cleaning the build directory")

		must_run([]string{"rm", "-rf", BUILD_DIR})
		must_run([]string{"rm", "-rf", DOCS_GEN_DIR})
	}

	if opt.all {
		log.info("Building all targets")
		opt.release = true
		opt.develop = true
		opt.gamelib = true
		opt.docs = true
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

	if opt.docs {
		log.info("Generating documentation")

		must_run([]string{"mkdir", "-p", DOCS_GEN_DIR})

		path := filepath.join({DOCS_GEN_DIR, strings.concatenate({"build", ".odin-doc"})})
		file, err := os.create(path);assert(err == os.ERROR_NONE, "Create doc file")
		defer os.close(file)

		doc_cmd := []string{"odin", "doc", "build.odin", "-file"}
		must_run(doc_cmd, stdout = file)

		dirs: []string = {"app", "game", "tests"}
		for dir in dirs {
			path := filepath.join({DOCS_GEN_DIR, strings.concatenate({dir, ".odin-doc"})})
			file, err := os.create(path);assert(err == os.ERROR_NONE, "Create doc file")
			defer os.close(file)

			doc_cmd := []string{"odin", "doc", filepath.join({"src", dir})}
			must_run(doc_cmd, stdout = file)
		}
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

run :: proc(cmd: []string, stdout: ^os.File = os.stdout, stderr: ^os.File = os.stderr) -> bool {
	context.allocator = context.temp_allocator

	log.debugf("Running: {}", strings.join(cmd, " "))

	process, err_start := os.process_start(
		{command = cmd, stdin = os.stdin, stdout = stdout, stderr = stderr},
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

must_run :: proc(
	cmd: []string,
	stdout: ^os.File = os.stdout,
	stderr: ^os.File = os.stderr,
) {assert(run(cmd, stdout, stderr), "Process failed")}

