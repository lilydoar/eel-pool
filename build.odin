package build

import "core:flags"
import "core:log"
import os "core:os/os2"
import "core:path/filepath"
import "core:slice"
import "core:strings"


Options :: struct {
	release:  bool `usage:Produce a release build`,
	develop:  bool `usage:Produce a development build`,
	game_lib: bool `usage:Build the game code as a dynamic library`,
}

main :: proc() {
	context.logger = log.create_console_logger()

	opt: Options
	flags.parse_or_exit(&opt, os.args)

	if !opt.release && !opt.develop && !opt.game_lib {
		log.errorf("No build option specified. Use -release, -develop, or -game_lib.")
		return
	}

	if opt.release {
		log.info("Building a release build")

		run("mkdir -p bin/release")
		run("odin build src -out:bin/release/eel-pool")
	}

	if opt.develop {
		log.info("Building a development build")

		run("mkdir -p bin/develop")
		run("odin build src -out:bin/release/eel-pool -debug")
	}

	if opt.game_lib {
		log.info("Building the game as a dynamic library")

		run("mkdir -p bin/game_lib")
	}
}

run :: proc(cmd: string) -> (int, os.Error) {
	log.infof("Running: {}", cmd)

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

