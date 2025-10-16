package game

Color :: struct {
	r: u8,
	g: u8,
	b: u8,
	a: u8,
}

color_new :: proc(r: u8, g: u8, b: u8, a: u8) -> Color {
	return Color{r = r, g = g, b = b, a = a}
}

ColorF :: struct {
	r: f32,
	g: f32,
	b: f32,
	a: f32,
}

colorf_new :: proc(r: f32, g: f32, b: f32, a: f32) -> ColorF {
	return ColorF{r = r, g = g, b = b, a = a}
}

colorf_new_safe :: proc(r: f32, g: f32, b: f32, a: f32) -> ColorF {
	return ColorF {
		r = clamp(r, 0.0, 1.0),
		g = clamp(g, 0.0, 1.0),
		b = clamp(b, 0.0, 1.0),
		a = clamp(a, 0.0, 1.0),
	}
}
