package game

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:math"
import "core:strings"
import sdl3 "vendor:sdl3"

DEBUG_CIRCLE_SEGMENTS :: 64
DEBUG_CIRCLE_POINTS :: DEBUG_CIRCLE_SEGMENTS + 1

debug_draw_line :: proc(r: ^SDL_Renderer, line: Line2, color: Color) {
	sdl3.SetRenderDrawColor(r.ptr, color.r, color.g, color.b, color.a)
	sdl3.RenderLine(r.ptr, line.a.x, line.a.y, line.b.x, line.b.y)
}

debug_draw_lines :: proc(r: ^SDL_Renderer, points: []Line2, color: Color) {
	raw := transmute(runtime.Raw_Slice)points
	raw.len *= 2 // Each Line2 has 2 points

	sdl3.SetRenderDrawColor(r.ptr, color.r, color.g, color.b, color.a)
	sdl3.RenderLines(r.ptr, raw_data(transmute([]sdl3.FPoint)raw), cast(i32)len(points))
}

debug_draw_circle :: proc(r: ^SDL_Renderer, circle: Circle, color: Color) {
	points: [DEBUG_CIRCLE_POINTS]sdl3.FPoint

	for i in 0 ..= DEBUG_CIRCLE_SEGMENTS {
		theta := (cast(f32)i / cast(f32)DEBUG_CIRCLE_SEGMENTS) * math.TAU
		x := circle.center.x + circle.radius * math.cos(theta)
		y := circle.center.y + circle.radius * math.sin(theta)
		points[i] = sdl3.FPoint{x, y}
	}

	sdl3.SetRenderDrawColor(r.ptr, color.r, color.g, color.b, color.a)
	sdl3.RenderLines(r.ptr, &points[0], DEBUG_CIRCLE_POINTS)
}

debug_draw_aabb :: proc(r: ^SDL_Renderer, aabb: AABB2, color: Color) {
	rect := sdl3.FRect {
		x = aabb.min.x,
		y = aabb.min.y,
		w = aabb.max.x - aabb.min.x,
		h = aabb.max.y - aabb.min.y,
	}

	sdl3.SetRenderDrawColor(r.ptr, color.r, color.g, color.b, color.a)
	sdl3.RenderRect(r.ptr, &rect)
}

Debug_Text_Stack_Config :: struct {
	axis:      enum {
		horizontal,
		vertical,
	},
	step_size: i32,
	color:     Color,
}

Debug_Text_Stack :: struct {
	cfg:            Debug_Text_Stack_Config,
	string_builder: strings.Builder,
	stack_text:     [dynamic]string,
	stack_cursor:   Vec2i,
}

dbg_txt_stack_push :: proc(dbg: ^Debug_Text_Stack, text: string) {
	append(&dbg.stack_text, text)

	switch dbg.cfg.axis {
	case .horizontal:
		dbg.stack_cursor.x += dbg.cfg.step_size
	case .vertical:
		dbg.stack_cursor.y += dbg.cfg.step_size
	}
}

dbg_txt_stack_reset :: proc(dbg: ^Debug_Text_Stack) {
	clear(&dbg.stack_text)
	strings.builder_reset(&dbg.string_builder)
	dbg.stack_cursor = Vec2i{0, 0}
}

dbg_txt_stack_draw :: proc(r: ^SDL_Renderer, dbg: ^Debug_Text_Stack) {
	if len(dbg.stack_text) <= 0 {return}

	when FRAME_DEBUG {
		log.debugf("Drawing %d debug text lines", len(dbg.stack_text))
		log.debugf("%s", dbg.stack_text)
	}

	pos := dbg.stack_cursor

	for text in dbg.stack_text {
		when FRAME_DEBUG {
			log.debugf("Debug Text: '%s'", text)
			log.debugf(
				"Debug Color: r:%d g:%d b:%d a:%d",
				dbg.cfg.color.r,
				dbg.cfg.color.g,
				dbg.cfg.color.b,
				dbg.cfg.color.a,
			)
		}
		sdl3.SetRenderDrawColor(
			r.ptr,
			dbg.cfg.color.r,
			dbg.cfg.color.g,
			dbg.cfg.color.b,
			dbg.cfg.color.a,
		)
		sdl3.RenderDebugText(r.ptr, cast(f32)pos.x, cast(f32)pos.y, strings.clone_to_cstring(text))

		// Used to render fmt strings. Potentially useful
		// sdl3.RenderDebugTextFormat()

		switch dbg.cfg.axis {
		case .horizontal:
			pos.x += dbg.cfg.step_size
		case .vertical:
			pos.y += dbg.cfg.step_size
		}
	}
}

