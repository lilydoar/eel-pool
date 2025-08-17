package game

must_msg: string = "Must function assertion failed"

must :: proc {
	must_bool,
	must_err,
}

must_bool :: proc(value: $T, ok: bool, msg: string = must_msg) -> T {
	if ok {return value}
	panic(msg)
}

must_err :: proc(value: $T, err: $E, msg: string = must_msg) -> T {
	if err == nil {return value}
	panic(msg)
}

