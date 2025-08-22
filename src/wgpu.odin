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
	default:     struct {
		texture_format: wgpu.TextureFormat,
		depth_format:   wgpu.TextureFormat,
		sampler:        wgpu.Sampler,
		render_pass:    wgpu.RenderPassDescriptor,
	},
}

// This is used to expose wgpu actions to the rest of the application.
// Functions that accept an active render pass can perform draw/gpu operations.
// Another option is embedding this type in other structs as well.
WGPU_RenderPass :: struct {
	surface:         wgpu.SurfaceTexture,
	surface_view:    wgpu.TextureView,
	command_encoder: wgpu.CommandEncoder,
	render_encoder:  wgpu.RenderPassEncoder,
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

	w.default.texture_format = .BGRA8Unorm

	w.default.depth_format = .Depth24Plus

	w.default.sampler = wgpu.DeviceCreateSampler(
		w.device,
		&wgpu.SamplerDescriptor {
			label = "default",
			addressModeU = .Repeat,
			addressModeV = .Repeat,
			addressModeW = .Repeat,
			magFilter = .Linear,
			minFilter = .Linear,
			mipmapFilter = .Nearest,
			maxAnisotropy = 1,
		},
	)

	w.default.render_pass = wgpu.RenderPassDescriptor {
		label                = "default",
		colorAttachmentCount = 1,
		colorAttachments     = &wgpu.RenderPassColorAttachment {
			view = nil,
			depthSlice = wgpu.DEPTH_SLICE_UNDEFINED,
			loadOp = .Clear,
			storeOp = .Store,
			clearValue = wgpu.Color{0.0, 0.0, 0.0, 1.0},
		},
	}
}

wgpu_deinit :: proc(w: ^WGPU) {
	log.info("Deinitializing WebGPU...")
	defer log.info("Deinitialized WebGPU")

	assert(w.initialized)

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

wgpu_frame_begin :: proc(w: ^WGPU, r: ^Render, window_size: Vec2i) {
	assert(w.initialized)
	renderpass_begin(w, r, &r.render_pass, window_size)
}

wgpu_frame_end :: proc(w: ^WGPU, r: ^Render) {
	assert(w.initialized)
	renderpass_end(w, r, &r.render_pass)
}

wgpu_panic :: proc(ok: bool, msg: string = "") {
	if ok {return}
	log.panic("WebGPU panic: {}", msg)
}

