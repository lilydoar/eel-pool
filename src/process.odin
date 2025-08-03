package shared

import "core:log"
import os "core:os/os2"
import "core:strings"

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

must_run :: proc(cmd: []string, stdout: ^os.File = os.stdout, stderr: ^os.File = os.stderr) {
	assert(run(cmd, stdout, stderr), "proc run failed")
}

run :: proc(cmd: []string) -> bool {
	a := context.allocator
	defer context.allocator = a

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

must_run :: proc(cmd: []string) {assert(run(cmd), "Process failed")}

