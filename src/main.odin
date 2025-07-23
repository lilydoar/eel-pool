package main

import "base:runtime"
import "core:log"
import "core:math/linalg"
import sdl "vendor:sdl3"

import "core:fmt"

Vec3 :: [3]f32
Vec2 :: [2]f32
Mat4 :: matrix[4, 4]f32

Globals :: struct {
	gpu: ^sdl.GPUDevice,
	window: ^sdl.Window,
	window_size: [2]i32,
	depth_texture: ^sdl.GPUTexture,
	depth_texture_format: sdl.GPUTextureFormat,
	swapchain_texture_format: sdl.GPUTextureFormat,

	key_down: #sparse[sdl.Scancode]bool,
	mouse_move: Vec2,
	ui_input_mode: bool,

	using game: Game_State,
}

g: Globals

Game_State :: struct {
	entity_pipeline: ^sdl.GPUGraphicsPipeline,
	default_sampler: ^sdl.GPUSampler,

	camera: struct {
		position: Vec3,
		target: Vec3,
	},
}

sdl_assert :: proc(ok: bool) {
	if !ok do log.panicf("SDL Error: {}", sdl.GetError())
}

init_sdl :: proc() {
	// @static sdl_log_context: runtime.Context
	// sdl_log_context = context
	// sdl_log_context.logger.options -= {.Short_File_Path, .Line, .Procedure}
	// sdl.SetLogPriorities(.VERBOSE)
	// sdl.SetLogOutputFunction(sdl_log, &sdl_log_context)

	ok := sdl.Init({.VIDEO}); sdl_assert(ok)

	g.window = sdl.CreateWindow("Hello SDL3", 1280, 780, {}); sdl_assert(g.window != nil)

	g.gpu = sdl.CreateGPUDevice({.SPIRV, .DXIL, .MSL}, true, nil); sdl_assert(g.gpu != nil)

	ok = sdl.ClaimWindowForGPUDevice(g.gpu, g.window); sdl_assert(ok)

	ok = sdl.SetGPUSwapchainParameters(g.gpu, g.window, .SDR_LINEAR, .VSYNC); sdl_assert(ok)

	g.swapchain_texture_format = sdl.GetGPUSwapchainTextureFormat(g.gpu, g.window)

	ok = sdl.GetWindowSize(g.window, &g.window_size.x, &g.window_size.y); sdl_assert(ok)
}

game_init :: proc() {

	g.default_sampler = sdl.CreateGPUSampler(g.gpu, {
		min_filter = .LINEAR,
		mag_filter = .LINEAR,
	})
}

game_update :: proc(delta_time: f32) {

}

game_render :: proc(cmd_buf: ^sdl.GPUCommandBuffer, swapchain_tex: ^sdl.GPUTexture) {

}

main :: proc() {
	context.logger = log.create_console_logger()

	init_sdl()
	game_init()

	last_ticks := sdl.GetTicks()

	main_loop: for {
		defer free_all(context.temp_allocator)

		g.mouse_move = {}

		new_ticks := sdl.GetTicks()
		delta_time := f32(new_ticks - last_ticks) / 1000
		last_ticks = new_ticks

		ev: sdl.Event
		for sdl.PollEvent(&ev) {
			#partial switch ev.type {
				case .QUIT:
					break main_loop
				case .KEY_DOWN:
					g.key_down[ev.key.scancode] = true
				case .KEY_UP:
					g.key_down[ev.key.scancode] = false
				case .MOUSE_MOTION:
					g.mouse_move += {ev.motion.xrel, ev.motion.yrel}
			}
		}

		game_update(delta_time)

		cmd_buf := sdl.AcquireGPUCommandBuffer(g.gpu)
		swapchain_tex: ^sdl.GPUTexture
		ok := sdl.WaitAndAcquireGPUSwapchainTexture(cmd_buf, g.window, &swapchain_tex, nil, nil); sdl_assert(ok)

		if swapchain_tex != nil {
			game_render(cmd_buf, swapchain_tex)
		}

		ok = sdl.SubmitGPUCommandBuffer(cmd_buf); sdl_assert(ok)
	}
}
