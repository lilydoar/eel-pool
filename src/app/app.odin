package app

import "base:runtime"
import "core:fmt"
import "core:log"
import os "core:os/os2"
import "core:time"
import sdl "vendor:sdl3"
import "vendor:wgpu"
import "vendor:wgpu/sdl3glue"

log_opts: log.Options : {
	.Level,
	.Time,
	// .Short_File_Path,
	// .Long_File_Path,
	.Procedure,
	.Line,
	.Terminal_Color,
	// .Thread_Id,
}

AppState :: struct {
	// SDL
	window:        ^sdl.Window,
	window_size:   [2]i32,

	// WGPU
	wgpu_is_ready: bool,
	instance:      wgpu.Instance,
	surface:       wgpu.Surface,
	adapter:       wgpu.Adapter,
	device:        wgpu.Device,
	config:        wgpu.SurfaceConfiguration,
	queue:         wgpu.Queue,

	// Application
	ctx:           runtime.Context,
	threads:       AppThreads,
}

state: AppState

app_init :: proc() {
	cli_parse()

	state.ctx = context
	log.info("Starting app initialization...")

	sdl_init()
	wgpu_init()
	sprite_batcher_init()

	app_threads_init()
	app_threads_start()

	state.threads.app_data.clock = thread_clock_init(APP_DESIRED_FRAME_TIME)

	app_init_wait()
}

app_init_wait :: proc() {
	// TODO: If a thread fails during it initialization it will return and never be initialized.
	// It should also mark itself as failed so we can check for that within this loop.

	initialization_wait: time.Stopwatch
	time.stopwatch_start(&initialization_wait)
	for !(cast(^GameThreadData)state.threads.threads[ThreadID.GAME].data).initialized ||
	    !(cast(^GameThreadData)state.threads.threads[ThreadID.RENDER].data).initialized ||
	    !(cast(^GameThreadData)state.threads.threads[ThreadID.AUDIO].data).initialized {
		if (time.stopwatch_duration(initialization_wait) > time.Second * 5) {
			log.warn("Timeout waiting for initialization.")
			os.exit(1)
		}
		time.sleep(time.Millisecond * 10)
	}
	time.stopwatch_stop(&initialization_wait)

	wait_ms := cast(u64)(time.stopwatch_duration(initialization_wait) / time.Millisecond)
	log.debugf("initialization wait time: {} ms", wait_ms)

	state.threads.app_data.initialized = true
}

app_deinit :: proc() {
	log.info("Deinitializing app...")
	app_threads_stop()
	sprite_batcher_deinit()
	wgpu_deinit()
	sdl_deinit()
}

sdl_init :: proc() {
	log.info("Initializing SDL...")
	ok := sdl.Init({.AUDIO, .VIDEO});sdl_assert(ok)

	title: cstring = "Window Title"
	window_width: i32 = 1280
	window_height: i32 = 780

	// read the profile config and load application flags based on dev/release
	// release: full_screen, no window decorations, etc.
	// development: windowed, with decorations, resizable, etc.
	// viewport: run as the viewport in an editor
	// Define environments that truly need different behavior

	flags: sdl.WindowFlags = {.RESIZABLE}

	window := sdl.CreateWindow(title, window_width, window_height, flags);sdl_assert(window != nil)
	state.window = window

	ok = sdl.GetWindowSize(state.window, &window_width, &window_height);sdl_assert(ok)
	state.window_size = [2]i32{window_width, window_height}
}

sdl_deinit :: proc() {
	log.info("Deinitializing SDL...")
	if state.window != nil {
		sdl.DestroyWindow(state.window)
		state.window = nil
	}
	state.window_size = [2]i32{-1, -1}

	sdl.Quit()
}

sdl_assert :: proc(ok: bool) {if !ok do log.panicf("SDL error: {}", sdl.GetError())}

sdl_get_framebuffer_size :: proc() -> (width, height: u32) {
	w, h: i32
	sdl.GetWindowSizeInPixels(state.window, &w, &h)
	return u32(w), u32(h)
}

sdl_get_surface :: proc(instance: wgpu.Instance) -> wgpu.Surface {
	return sdl3glue.GetSurface(instance, state.window)
}

sdl_resize :: proc() -> (w, h: u32) {
	width, height := sdl_get_framebuffer_size()
	if width == 0 || height == 0 {
		log.warn("Invalid framebuffer size, skipping resize.")
		return 0, 0
	}

	log.debugf("SDL window resizing to: [{}, {}]", width, height)
	state.window_size = [2]i32{cast(i32)(width), cast(i32)(height)}

	return cast(u32)(width), cast(u32)(height)
}

sdl_poll_events :: proc() -> (quit: bool) {
	ev: sdl.Event
	for sdl.PollEvent(&ev) {
		#partial switch ev.type {
		case .QUIT:
			quit = true
		case .WINDOW_RESIZED, .WINDOW_PIXEL_SIZE_CHANGED:
			pixel_w, pixel_h := sdl_resize()
			wgpu_resize(pixel_w, pixel_h)
		}
	}
	return
}

wgpu_init :: proc() {
	log.info("Initializing WebGPU...")

	state.instance = wgpu.CreateInstance(nil)
	if state.instance == nil {
		panic("WebGPU is not supported")
	}
	state.surface = sdl_get_surface(state.instance)

	wgpu.InstanceRequestAdapter(
		state.instance,
		&{compatibleSurface = state.surface},
		{callback = on_adapter},
	)

	on_adapter :: proc "c" (
		status: wgpu.RequestAdapterStatus,
		adapter: wgpu.Adapter,
		message: string,
		userdata1, userdata2: rawptr,
	) {
		context = state.ctx
		if status != .Success || adapter == nil {
			fmt.panicf("request adapter failure: [%v] %s", status, message)
		}
		state.adapter = adapter
		wgpu.AdapterRequestDevice(adapter, nil, {callback = on_device})
	}

	on_device :: proc "c" (
		status: wgpu.RequestDeviceStatus,
		device: wgpu.Device,
		message: string,
		userdata1, userdata2: rawptr,
	) {
		context = state.ctx
		if status != .Success || device == nil {
			fmt.panicf("request device failure: [%v] %s", status, message)
		}
		state.device = device

		width, height := sdl_get_framebuffer_size()

		state.config = wgpu.SurfaceConfiguration {
			device      = state.device,
			usage       = {.RenderAttachment},
			format      = .BGRA8Unorm,
			width       = width,
			height      = height,
			presentMode = .Fifo,
			alphaMode   = .Opaque,
		}
		wgpu.SurfaceConfigure(state.surface, &state.config)

		state.queue = wgpu.DeviceGetQueue(state.device)

		state.wgpu_is_ready = true
	}
}

wgpu_is_ready :: proc() -> bool {return state.wgpu_is_ready}

wgpu_deinit :: proc() {
	log.info("Deinitializing WebGPU...")
	wgpu.QueueRelease(state.queue)
	wgpu.DeviceRelease(state.device)
	wgpu.AdapterRelease(state.adapter)
	wgpu.SurfaceRelease(state.surface)
	wgpu.InstanceRelease(state.instance)
}

wgpu_frame :: proc "c" () {
	context = state.ctx

	// log.debug("Starting WGPU frame...")

	surface_texture := wgpu.SurfaceGetCurrentTexture(state.surface)
	switch surface_texture.status {
	case .SuccessOptimal, .SuccessSuboptimal:
	case .Timeout, .Outdated, .Lost:
		log.warnf("get_current_texture status=%v, resizing surface", surface_texture.status)
		if surface_texture.texture != nil {
			wgpu.TextureRelease(surface_texture.texture)
		}
		wgpu_resize(sdl_get_framebuffer_size())
		return
	case .OutOfMemory, .DeviceLost, .Error:
		// Fatal error
		fmt.panicf("get_current_texture status=%v", surface_texture.status)
	}
	defer wgpu.TextureRelease(surface_texture.texture)

	frame := wgpu.TextureCreateView(surface_texture.texture, nil)
	defer wgpu.TextureViewRelease(frame)

	command_encoder := wgpu.DeviceCreateCommandEncoder(state.device, nil)
	defer wgpu.CommandEncoderRelease(command_encoder)

	// log.debug("Starting render pass...")

	render_pass := wgpu.CommandEncoderBeginRenderPass(
		command_encoder,
		&{
			colorAttachmentCount = 1,
			colorAttachments = &wgpu.RenderPassColorAttachment {
				view = frame,
				loadOp = .Clear,
				storeOp = .Store,
				depthSlice = wgpu.DEPTH_SLICE_UNDEFINED,
				clearValue = {0.0, 0.2, 0.4, 1.0},
			},
		},
	)

	identity_matrix := [16]f32{1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1}
	sprite_batcher_frame(render_pass, identity_matrix)

	wgpu.RenderPassEncoderEnd(render_pass)
	wgpu.RenderPassEncoderRelease(render_pass)
	// log.debug("Ended render pass...")

	command_buffer := wgpu.CommandEncoderFinish(command_encoder, nil)
	defer wgpu.CommandBufferRelease(command_buffer)

	wgpu.QueueSubmit(state.queue, {command_buffer})
	wgpu.SurfacePresent(state.surface)
}

wgpu_resize :: proc(width, height: u32) {
	state.config.width = width
	state.config.height = height
	log.debugf("WebGPU surface resizing to: [{}, {}]", width, height)
	wgpu.SurfaceConfigure(state.surface, &state.config)
}

