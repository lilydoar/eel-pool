package build

import "core:flags"
import "core:log"
import os "core:os/os2"
import "core:path/filepath"
import "core:slice"
import "core:strings"


Options :: struct {
	release: bool `usage:"Produce a release build"`,
	develop: bool `usage:"Produce a development build"`,
	gamelib: bool `usage:"Build the game code as a dynamic library"`,
	verbose: bool `usage:"Enable verbose output"`,
	clean:   bool `usage:"Clean the build directory before building"`,
	watch:   bool `usage:"Watch for changes and rebuild automatically (game library only)"`,
}

main :: proc() {
	opt: Options
	flags.parse_or_exit(&opt, os.args)

	level := log.Level.Info
	if opt.verbose {level = log.Level.Debug}
	context.logger = log.create_console_logger(level)

	if opt.clean {
		log.info("Cleaning the build directory")

		run("rm -rf bin")
	}

	if !opt.release && !opt.develop && !opt.gamelib && !opt.clean {
		log.errorf("No build option specified. Use -release or -develop")
		return
	}

	if opt.release {
		log.info("Building a release build")

		run("mkdir -p bin/release")
		run(
			"odin build src/entry/release -out:bin/release/eel-pool -disable-assert -o:speed -warnings-as-errors",
		)
	}

	if opt.develop {
		log.info("Building a development build")

		run("mkdir -p bin/develop")
		run("odin build src/entry/develop -out:bin/develop/eel-pool -debug -ignore-warnings")
	}

	if opt.gamelib {
		log.info("Building the game as a dynamic library")

		run("mkdir -p bin/gamelib")
		run("odin build src/game -out:bin/gamelib/game -debug -build-mode:dynamic")
	}

	if opt.watch {
		log.info("Watching for changes in the game library")

		watch_cmd := "odin build src/game -out:bin/gamelib/game -debug -build-mode:shared -watch"
		run(watch_cmd)
	}
}

run :: proc(cmd: string) -> (int, os.Error) {
	log.debugf("Running: {}", cmd)

	code, err := exec(strings.split(cmd, " "))
	if err != nil {log.errorf("Executing process: {}", err)}
	if code != 0 {log.errorf("Process exited with non-zero code: {}", code)}

	return code, err
}

exec :: proc(cmd: []string) -> (code: int, error: os.Error) {
	process := os.process_start(
		{command = cmd, stdin = os.stdin, stdout = os.stdout, stderr = os.stderr},
	) or_return
	state := os.process_wait(process) or_return
	os.process_close(process) or_return
	return state.exit_code, nil
}

