package tests

import "core:log"
import os "core:os/os2"
import "core:strings"
import "core:testing"

BUILD_DIR: string : "bin/"
BUILD_EXE: string : BUILD_DIR + "test/build"

RELEASE_DIR: string : BUILD_DIR + "release/"
RELEASE_EXE: string : RELEASE_DIR + "eel-pool"

@(test)
check_latest_release :: proc(t: ^testing.T) {
	must_run([]string{BUILD_EXE, "-release", "-verbose"})
	must_run([]string{RELEASE_EXE, "-check"})
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

// fd, open_error := os.open("test_data")
// if !testing.expect_value(t, open_error, os.ERROR_NONE) {
// 	return
// }

// testing.cleanup(t, proc(raw_handle: rawptr) {
// 		handle := cast(^os.Handle)raw_handle
// 		os.close(handle)
// 	}, &fd)

