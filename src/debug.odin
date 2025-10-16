package game

import "base:runtime"
import "core:math"
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

debug_draw_text :: proc(r: ^SDL_Renderer, pos: Vec2, text: string, color: Color) {
	// TODO
}
