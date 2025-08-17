package game

import "base:runtime"
import "core:log"
import "vendor:wgpu"
import "vendor:wgpu/sdl3glue"

WGPU :: struct {
	initialized: bool,
	instance:    wgpu.Instance,
	surface:     wgpu.Surface,
	surface_cfg: wgpu.SurfaceConfiguration,
	adapter:     wgpu.Adapter,
	device:      wgpu.Device,
	queue:       wgpu.Queue,

	// // Runtime state
	// is_frame_hot: bool,
}

// This is used to expose wgpu actions to the rest of the application.
// Functions that accept an active render pass can perform draw/gpu operations.
WGPU_RenderPass_Active :: struct {
	surface:        wgpu.SurfaceTexture,
	texture_view:   wgpu.TextureView,
	cmd_encoder:    wgpu.CommandEncoder,
	render_encoder: wgpu.RenderPassEncoder,
}

wgpu_render_pass_desc_default := wgpu.RenderPassDescriptor {
	colorAttachmentCount = 1,
	colorAttachments     = &wgpu.RenderPassColorAttachment {
		view       = nil,
		depthSlice = wgpu.DEPTH_SLICE_UNDEFINED,
		//
		loadOp     = .Clear,
		storeOp    = .Store,
		clearValue = wgpu.Color{0.0, 0.0, 0.0, 0.0},
	},
}

wgpu_init :: proc(w: ^WGPU, s: ^SDL) {
	log.info("Initializing WebGPU...")
	defer log.info("WebGPU initialized")

	assert(!w.initialized)
	defer w.initialized = true

	w.instance = wgpu.CreateInstance(nil)
	wgpu_panic(w.instance != nil, "create instance")

	w.surface = sdl3glue.GetSurface(w.instance, s.window.ptr)
	wgpu_panic(w.surface != nil, "create surface")

	callback_data := WGPU_InitCallbackData {
		ctx = context,
		w   = w,
		s   = s,
	}

	wgpu.InstanceRequestAdapter(
		w.instance,
		&{compatibleSurface = w.surface},
		// The callback chain defined below is called here.
		{callback = on_adapter, userdata1 = rawptr(&callback_data)},
	)

	// This is used to pass knowledge of our app data into the scope of the wgpu setup callbacks.
	// Not designed to be used outside of the wgpu setup functions.
	WGPU_InitCallbackData :: struct {
		ctx: runtime.Context,
		w:   ^WGPU,
		s:   ^SDL,
	}

	on_adapter :: proc "c" (
		status: wgpu.RequestAdapterStatus,
		adapter: wgpu.Adapter,
		message: string,
		userdata1, userdata2: rawptr,
	) {
		data: ^WGPU_InitCallbackData = cast(^WGPU_InitCallbackData)userdata1

		context = data.ctx

		wgpu_panic(status == .Success, "request adapter status")
		wgpu_panic(adapter != nil, "request adapter")

		data.w.adapter = adapter

		wgpu.AdapterRequestDevice(adapter, nil, {callback = on_device, userdata1 = userdata1})
	}

	on_device :: proc "c" (
		status: wgpu.RequestDeviceStatus,
		device: wgpu.Device,
		message: string,
		userdata1, userdata2: rawptr,
	) {
		data: ^WGPU_InitCallbackData = cast(^WGPU_InitCallbackData)userdata1

		context = data.ctx

		wgpu_panic(status == .Success, "request device status")
		wgpu_panic(device != nil, "request device")

		capabilities, ok := wgpu.SurfaceGetCapabilities(data.w.surface, data.w.adapter)
		wgpu_panic(ok == .Success, "surface get capabilities")

		data.w.device = device
		data.w.surface_cfg = wgpu.SurfaceConfiguration {
			device      = data.w.device,
			format      = capabilities.formats[0],
			usage       = {.RenderAttachment},
			alphaMode   = capabilities.alphaModes[0],
			presentMode = .Fifo,
		}

		wgpu_resize(data.w, sdl_get_window_size(data.s))

		data.w.queue = wgpu.DeviceGetQueue(data.w.device)
		wgpu_panic(data.w.queue != nil, "device get queue")
	}
}

wgpu_deinit :: proc(w: ^WGPU) {
	log.info("Deinitializing WebGPU...")

	assert(w.initialized)
	defer w.initialized = false

	wgpu.QueueRelease(w.queue)
	wgpu.DeviceRelease(w.device)
	wgpu.AdapterRelease(w.adapter)
	wgpu.SurfaceRelease(w.surface)
	wgpu.InstanceRelease(w.instance)
}

wgpu_resize :: proc(w: ^WGPU, size: Vec2i) {
	if size.x <= 0 || size.y <= 0 {return}

	log.debugf("WebGPU: resizing surface to ({}x{})", size.x, size.y)

	w.surface_cfg.width = cast(u32)size.x
	w.surface_cfg.height = cast(u32)size.y

	wgpu.SurfaceConfigure(w.surface, &w.surface_cfg)
}

wgpu_frame_begin :: proc(w: ^WGPU, window_size: Vec2i) -> WGPU_RenderPass_Active {
	assert(w.initialized)

	when #config(FRAME_DEBUG, false) {
		log.debug("beginning frame...")
	}

	surface := wgpu.SurfaceGetCurrentTexture(w.surface)

	#partial switch surface.status {
	case .Timeout, .Outdated, .Lost:
		log.warnf("WebGPU: surface texture status: {}", surface.status)
		wgpu_resize(w, window_size)
		return WGPU_RenderPass_Active{}
	case .OutOfMemory, .DeviceLost, .Error:
		log.error("WebGPU: surface texture status: {}", surface.status)
		return WGPU_RenderPass_Active{}
	}

	view := wgpu.TextureCreateView(surface.texture, nil)
	cmd_encoder := wgpu.DeviceCreateCommandEncoder(w.device, nil)

	render_pass_desc := wgpu_render_pass_desc_default
	render_pass_desc.colorAttachments[0].view = view

	render_encoder := wgpu.CommandEncoderBeginRenderPass(cmd_encoder, &render_pass_desc)

	when ODIN_DEBUG {
		wgpu.RenderPassEncoderInsertDebugMarker(render_encoder, "begin frame")
	}

	return WGPU_RenderPass_Active {
		surface = surface,
		texture_view = view,
		cmd_encoder = cmd_encoder,
		render_encoder = render_encoder,
	}
}

wgpu_frame_end :: proc(w: ^WGPU, r: WGPU_RenderPass_Active) {
	assert(w.initialized)

	when FRAME_DEBUG {
		log.debug("ending frame...")
	}

	when ODIN_DEBUG {
		wgpu.RenderPassEncoderInsertDebugMarker(r.render_encoder, "end frame")
	}

	wgpu.RenderPassEncoderEnd(r.render_encoder)
	wgpu.RenderPassEncoderRelease(r.render_encoder)

	cmd_buf := wgpu.CommandEncoderFinish(r.cmd_encoder, nil)
	wgpu.QueueSubmit(w.queue, {cmd_buf})
	wgpu.CommandEncoderRelease(r.cmd_encoder)

	wgpu.SurfacePresent(w.surface)

	wgpu.TextureViewRelease(r.texture_view)
	wgpu.TextureRelease(r.surface.texture)
}

wgpu_panic :: proc(ok: bool, msg: string = "") {
	if ok {return}
	log.panic("WebGPU panic: {}", msg)
}

