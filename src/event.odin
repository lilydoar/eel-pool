package game

import "core:container/queue"
import "core:log"

EventType :: enum {
	Invalid,
	EntityDestroyed,
}

EventPayloadTextUpdate :: struct {
	text: string,
	// some relevant data..
}

EventPayloadPositionChange :: struct {
	pos: [2]f32,
}

EventPayloadEntityDestroyed :: struct {
	entity_id: Entity_ID,
}

EventPayload :: union {
	EventPayloadTextUpdate,
	EventPayloadPositionChange,
	EventPayloadEntityDestroyed,
}

Event :: struct {
	type:    EventType,
	payload: EventPayload,
}

EventTimed :: struct {
	using event: Event,
	timer:       f32,
}

// Event callback type
EventCallbackProc :: proc(ctx: rawptr, event: Event)

Event_System :: struct {
	event_listeners:   map[EventType][dynamic]EventCallbackProc,
	event_queue:       queue.Queue(Event),
	event_queue_timed: [dynamic]EventTimed,
}

event_system_publish :: proc(e: ^Event_System, type: EventType, payload: EventPayload) {
	queue.enqueue(&e.event_queue, Event{type = type, payload = payload})
	when DEBUG_GAME {log.debugf("Event published: %d", type)}
}

event_system_publish_timed :: proc(
	e: ^Event_System,
	type: EventType,
	payload: EventPayload,
	seconds: f32,
) {
	append(&e.event_queue_timed, EventTimed{type = type, payload = payload, timer = seconds})
}

event_system_subscribe_to_type :: proc(
	e: ^Event_System,
	type: EventType,
	callback: EventCallbackProc,
) {
	if type not_in e.event_listeners {
		e.event_listeners[type] = make([dynamic]EventCallbackProc)
	}

	append(&e.event_listeners[type], callback)
}

// TODO
// I need some way to decouple events and when in a frame they are processed/consumed/the callback is run
// I think I want to process events and queue up callbacks to run during the next frame.
// This way they can be sorted into categories and can be run at different points during the game update.
event_system_process :: proc(ctx: rawptr, e: ^Event_System) {
	for queue.len(e.event_queue) > 0 {
		event := queue.dequeue(&e.event_queue)

		if listeners, ok := e.event_listeners[event.type]; ok {
			for callback in listeners {
				callback(ctx, event)
			}
		}
	}
}

event_system_process_timed :: proc(ctx: rawptr, e: ^Event_System, delta_time: f32) {
	// Reverse iteration so we can use unordered_remove
	for i := len(e.event_queue_timed) - 1; i >= 0; i -= 1 {
		event := &e.event_queue_timed[i]

		event.timer -= delta_time

		if event.timer <= 0 {
			if listeners, ok := e.event_listeners[event.type]; ok {
				for callback in listeners {
					callback(ctx, event)
				}
			}

			unordered_remove(&e.event_queue_timed, i)
		}
	}
}

