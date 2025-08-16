package game

import "core:fmt"
import "core:log"
import "core:strings"

import "vendor:wgpu"
import "vendor:wgpu/sdl3glue"

WGPU :: struct {
	initialized:    bool,
	instance:       wgpu.Instance,
	surface:        wgpu.Surface,
	config:         wgpu.SurfaceConfiguration,
	adapter:        wgpu.Adapter,
	device:         wgpu.Device,
	queue:          wgpu.Queue,
	sprite_batcher: SpriteBatcher,
}

get_surface :: proc(instance: wgpu.Instance) -> wgpu.Surface {
	return sdl3glue.GetSurface(instance, app.sdl.window)
}

wgpu_panic :: proc(ok: bool, msg: string = "") {
	if !ok do log.panic("WebGPU panic: {}", msg)
}

wgpu_init :: proc() {
	log.info("Initializing WebGPU...")

	assert(!app.wgpu.initialized)
	defer app.wgpu.initialized = true

	app.wgpu.instance = wgpu.CreateInstance(nil)
	wgpu_panic(app.wgpu.instance != nil, "failed to create WGPU instance")

	app.wgpu.surface = get_surface(app.wgpu.instance)
	wgpu_panic(app.wgpu.surface != nil, "failed to create WGPU surface")

	wgpu.InstanceRequestAdapter(
		app.wgpu.instance,
		&{compatibleSurface = app.wgpu.surface},
		{callback = on_adapter},
	)

	on_adapter :: proc "c" (
		status: wgpu.RequestAdapterStatus,
		adapter: wgpu.Adapter,
		message: string,
		userdata1, userdata2: rawptr,
	) {
		context = app.ctx

		wgpu_panic(status == .Success, "request adapter failure")
		wgpu_panic(adapter != nil, "request adapter returned nil")

		app.wgpu.adapter = adapter
		wgpu.AdapterRequestDevice(adapter, nil, {callback = on_device})
	}

	on_device :: proc "c" (
		status: wgpu.RequestDeviceStatus,
		device: wgpu.Device,
		message: string,
		userdata1, userdata2: rawptr,
	) {
		context = app.ctx

		wgpu_panic(status == .Success, "request device failure")
		wgpu_panic(device != nil, "request device returned nil")


		capabilities, ok := wgpu.SurfaceGetCapabilities(app.wgpu.surface, app.wgpu.adapter)
		wgpu_panic(ok == .Success, "get surface capabilities failed")

		app.wgpu.device = device
		app.wgpu.config = wgpu.SurfaceConfiguration {
			device      = app.wgpu.device,
			format      = .BGRA8Unorm,
			usage       = {.RenderAttachment},
			alphaMode   = .Auto,
			presentMode = .Fifo,
		}

		w, h := sdl_get_window_size()
		wgpu_resize(cast(u32)(w), cast(u32)(h))

		app.wgpu.queue = wgpu.DeviceGetQueue(app.wgpu.device)
		wgpu_panic(app.wgpu.queue != nil, "get device queue returned nil")
	}

	sprite_batcher_init()
}

wgpu_deinit :: proc() {
	log.info("Deinitializing WebGPU...")

	assert(app.wgpu.initialized)
	defer app.wgpu.initialized = false

	sprite_batcher_deinit()

	wgpu.QueueRelease(app.wgpu.queue)
	wgpu.DeviceRelease(app.wgpu.device)
	wgpu.AdapterRelease(app.wgpu.adapter)
	wgpu.SurfaceRelease(app.wgpu.surface)
	wgpu.InstanceRelease(app.wgpu.instance)
}

wgpu_resize :: proc(width, height: u32) {
	log.debugf("WGPU surface resizing to: [{}, {}]", width, height)

	app.wgpu.config.width = width
	app.wgpu.config.height = height
	wgpu.SurfaceConfigure(app.wgpu.surface, &app.wgpu.config)
}

wgpu_frame :: proc "c" () {
	context = app.ctx

	assert(app.wgpu.initialized)

	// log.debug("Starting WGPU frame...")

	surface_texture := wgpu.SurfaceGetCurrentTexture(app.wgpu.surface)
	switch surface_texture.status {
	case .SuccessOptimal, .SuccessSuboptimal:
	case .Timeout, .Outdated, .Lost:
		log.warnf("get_current_texture status=%v, resizing surface", surface_texture.status)
		if surface_texture.texture != nil {wgpu.TextureRelease(surface_texture.texture)}
		w, h := sdl_get_window_size()
		if w > 0 && h > 0 {wgpu_resize(cast(u32)(w), cast(u32)(h))}
		return
	case .OutOfMemory, .DeviceLost, .Error:
		// Fatal error
		fmt.panicf("get_current_texture status=%v", surface_texture.status)
	}
	defer wgpu.TextureRelease(surface_texture.texture)

	frame := wgpu.TextureCreateView(surface_texture.texture, nil)
	defer wgpu.TextureViewRelease(frame)

	command_encoder := wgpu.DeviceCreateCommandEncoder(app.wgpu.device, nil)
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

	wgpu.QueueSubmit(app.wgpu.queue, {command_buffer})
	wgpu.SurfacePresent(app.wgpu.surface)
}

