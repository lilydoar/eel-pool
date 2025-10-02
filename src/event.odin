package game

import "core:container/queue"

EventType :: enum {
	Invalid,
	TextUpdate,
	PositionChange,
}

EventPayloadTextUpdate :: struct {
	text: string,
	// some relevant data..
}

EventPayloadPositionChange :: struct {
	pos: [2]f32,
}

EventPayload :: union {
	EventPayloadTextUpdate,
	EventPayloadPositionChange,
}

Event :: struct {
	type:    EventType,
	payload: EventPayload,
}

TimedEvent :: struct {
	using event: Event,
	timer:       f32,
}

EventCallbackProc :: proc(event: Event)

Event_System :: struct {
	// Event callback type
	event_listeners:   map[EventType][dynamic]EventCallbackProc,
	event_queue:       queue.Queue(Event),
	timed_event_queue: [dynamic]TimedEvent,
}

event_publish :: proc(e: ^Event_System, type: EventType, payload: EventPayload) {
	queue.enqueue(&e.event_queue, Event{type = type, payload = payload})
}

event_publish_timed :: proc(
	e: ^Event_System,
	type: EventType,
	payload: EventPayload,
	seconds: f32,
) {
	append(&e.timed_event_queue, TimedEvent{type = type, payload = payload, timer = seconds})
}

event_subscribe_type :: proc(e: ^Event_System, type: EventType, callback: EventCallbackProc) {
	if type not_in e.event_listeners {
		e.event_listeners[type] = make([dynamic]EventCallbackProc)
	}

	append(&e.event_listeners[type], callback)
}

event_system_process :: proc(e: ^Event_System) {
	for queue.len(e.event_queue) > 0 {
		event := queue.dequeue(&e.event_queue)

		if listeners, ok := e.event_listeners[event.type]; ok {
			for callback in listeners {
				callback(event)
			}
		}
	}
}

event_system_process_timed :: proc(e: ^Event_System, delta_time: f32) {
	// Reverse iteration so we can use unordered_remove
	for i := len(e.timed_event_queue) - 1; i >= 0; i -= 1 {
		event := &e.timed_event_queue[i]

		event.timer -= delta_time

		if event.timer <= 0 {
			if listeners, ok := e.event_listeners[event.type]; ok {
				for callback in listeners {
					callback(event)
				}
			}

			unordered_remove(&e.timed_event_queue, i)
		}
	}
}

