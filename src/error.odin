package game

import "core:log"
import "core:mem"

must_msg: string = "Must function assertion failed"

must :: proc {
	must_bool,
	must_val,
	must_val_allocation_err,
}

must_bool :: proc(ok: bool, msg: string = must_msg) {
	if ok {return}
	log.panic(msg)
}

must_val :: proc(value: $T, msg: string = must_msg) -> T {
	if value != {} {return value}
	log.panic(msg)
}

must_val_allocation_err :: proc(value: $T, err: mem.Allocator_Error, msg: string = must_msg) -> T {
	if err != .None {return value}
	log.panic(msg)
}
