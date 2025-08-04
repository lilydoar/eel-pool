# WebGPU Programming Guide: Modern GPU Architecture for Real-Time Applications

WebGPU represents the convergence of modern GPU architectures into a unified programming model that spans native platforms (Vulkan, Metal, DirectX 12) and web environments. Built on explicit state management and command-based submission patterns, WebGPU exposes the full performance potential of contemporary graphics hardware while maintaining cross-platform compatibility.

This guide assumes familiarity with graphics programming concepts, linear algebra, and modern C/C++ patterns. We progress from fundamental WebGPU architecture through production-ready rendering systems, culminating in advanced GPU compute applications and specialized rendering techniques used in high-performance real-time applications.

## Understanding WebGPU Architecture

WebGPU follows a layered architecture where each component has specific responsibilities:

- **Instance**: The top-level context that enumerates available graphics adapters
- **Adapter**: Represents a specific GPU and driver combination
- **Device**: Your application's connection to the GPU for issuing commands
- **Surface**: The render target (typically a window or canvas)
- **Queue**: The command submission interface where all GPU work is scheduled

WebGPU's **asynchronous initialization pattern** reflects modern GPU driver architecture where hardware enumeration, capability detection, and context creation involve significant latency. This design ensures consistent behavior across native drivers (which could block) and web environments (which mandate async operations), while enabling applications to remain responsive during potentially expensive initialization phases.

## Section 1: Setup

### The Async Initialization Chain

WebGPU requires a specific initialization sequence where each step depends on the previous one completing. Here's the complete setup process:

```c
#include <webgpu/webgpu.h>
#include <SDL3/SDL.h>
#include <stdio.h>
#include <stdbool.h>

// Global state structure
typedef struct {
    SDL_Window* window;

    WGPUInstance instance;
    WGPUSurface surface;
    WGPUAdapter adapter;
    WGPUDevice device;
    WGPUSurfaceConfiguration config;
    WGPUQueue queue;
    WGPUShaderModule shader_module;
    WGPUPipelineLayout pipeline_layout;
    WGPURenderPipeline render_pipeline;

    bool webgpu_ready;
    bool should_quit;
} AppState;

AppState g_state = {0};

// Callback for when adapter is found
void on_adapter_received(WGPURequestAdapterStatus status, WGPUAdapter adapter,
                        const char* message, void* userdata) {
    if (status != WGPURequestAdapterStatus_Success || !adapter) {
        printf("Failed to get adapter: %s\n", message);
        exit(1);
    }

    g_state.adapter = adapter;

    // Request device from the adapter
    WGPUDeviceDescriptor device_desc = {0};
    wgpuAdapterRequestDevice(adapter, &device_desc, on_device_received, NULL);
}

// Callback for when device is ready
void on_device_received(WGPURequestDeviceStatus status, WGPUDevice device,
                       const char* message, void* userdata) {
    if (status != WGPURequestDeviceStatus_Success || !device) {
        printf("Failed to get device: %s\n", message);
        exit(1);
    }

    g_state.device = device;
    g_state.queue = wgpuDeviceGetQueue(device);

    // Configure the surface
    int width, height;
    SDL_GetWindowSizeInPixels(g_state.window, &width, &height);

    g_state.config = (WGPUSurfaceConfiguration){
        .device = device,
        .usage = WGPUTextureUsage_RenderAttachment,
        .format = WGPUTextureFormat_BGRA8Unorm,
        .width = width,
        .height = height,
        .presentMode = WGPUPresentMode_Fifo,
        .alphaMode = WGPUCompositeAlphaMode_Opaque
    };
    wgpuSurfaceConfigure(g_state.surface, &g_state.config);

    // Create shader module
    const char* shader_source =
        "@vertex\n"
        "fn vs_main(@builtin(vertex_index) in_vertex_index: u32) -> @builtin(position) vec4<f32> {\n"
        "    let x = f32(i32(in_vertex_index) - 1);\n"
        "    let y = f32(i32(in_vertex_index & 1u) * 2 - 1);\n"
        "    return vec4<f32>(x, y, 0.0, 1.0);\n"
        "}\n"
        "\n"
        "@fragment\n"
        "fn fs_main() -> @location(0) vec4<f32> {\n"
        "    return vec4<f32>(1.0, 0.0, 0.0, 1.0);\n"
        "}";

    WGPUShaderSourceWGSL wgsl_desc = {
        .chain = {.sType = WGPUSType_ShaderSourceWGSL},
        .code = shader_source
    };

    WGPUShaderModuleDescriptor shader_desc = {
        .nextInChain = (WGPUChainedStruct*)&wgsl_desc
    };
    g_state.shader_module = wgpuDeviceCreateShaderModule(device, &shader_desc);

    // Create pipeline layout
    WGPUPipelineLayoutDescriptor layout_desc = {0};
    g_state.pipeline_layout = wgpuDeviceCreatePipelineLayout(device, &layout_desc);

    // Create render pipeline
    WGPUColorTargetState color_target = {
        .format = WGPUTextureFormat_BGRA8Unorm,
        .writeMask = WGPUColorWriteMask_All
    };

    WGPUFragmentState fragment_state = {
        .module = g_state.shader_module,
        .entryPoint = "fs_main",
        .targetCount = 1,
        .targets = &color_target
    };

    WGPURenderPipelineDescriptor pipeline_desc = {
        .layout = g_state.pipeline_layout,
        .vertex = {
            .module = g_state.shader_module,
            .entryPoint = "vs_main"
        },
        .fragment = &fragment_state,
        .primitive = {
            .topology = WGPUPrimitiveTopology_TriangleList
        },
        .multisample = {
            .count = 1,
            .mask = 0xFFFFFFFF
        }
    };
    g_state.render_pipeline = wgpuDeviceCreateRenderPipeline(device, &pipeline_desc);

    // Signal that WebGPU is ready
    g_state.webgpu_ready = true;
}

bool initialize_webgpu() {
    // Create WebGPU instance
    WGPUInstanceDescriptor instance_desc = {0};
    g_state.instance = wgpuCreateInstance(&instance_desc);
    if (!g_state.instance) {
        printf("Failed to create WebGPU instance\n");
        return false;
    }

    // Create surface from SDL window
    g_state.surface = SDL_GetWGPUSurface(g_state.instance, g_state.window);
    if (!g_state.surface) {
        printf("Failed to create WebGPU surface\n");
        return false;
    }

    // Request adapter (async)
    WGPURequestAdapterOptions adapter_options = {
        .compatibleSurface = g_state.surface
    };
    wgpuInstanceRequestAdapter(g_state.instance, &adapter_options,
                              on_adapter_received, NULL);

    return true;
}

bool initialize_sdl() {
    if (!SDL_Init(SDL_INIT_VIDEO)) {
        printf("SDL init failed: %s\n", SDL_GetError());
        return false;
    }

    g_state.window = SDL_CreateWindow("WebGPU Triangle",
                                     1280, 720,
                                     SDL_WINDOW_RESIZABLE);
    if (!g_state.window) {
        printf("Window creation failed: %s\n", SDL_GetError());
        return false;
    }

    return true;
}
```

### Key Setup Concepts

**Asynchronous Initialization**: The callback-driven initialization pattern mirrors how modern GPU drivers actually work internally. Driver-level operations like device enumeration, capability queries, and context creation involve kernel transitions and hardware communication that can introduce significant latency (10-100ms). The async pattern prevents thread blocking while maintaining deterministic initialization ordering.

**Explicit Resource Lifetime**: WebGPU exposes the underlying resource management of modern graphics APIs. Unlike legacy OpenGL's reference counting, WebGPU requires explicit release calls that correspond directly to GPU memory allocation/deallocation. This deterministic lifetime management enables precise control over GPU memory pressure and prevents resource leaks that plague many graphics applications.

**Surface Configuration**: The surface abstraction bridges platform-specific presentation (Win32/Cocoa/X11/Wayland) with GPU-agnostic rendering operations. Configuration parameters like `presentMode` directly control hardware presentation timing (V-sync behavior), while format selection affects memory bandwidth and color precision.

## Section 2: Run

### Frame Rendering Workflow

Once WebGPU is initialized, the rendering loop follows a consistent pattern:

```c
void handle_resize() {
    int width, height;
    SDL_GetWindowSizeInPixels(g_state.window, &width, &height);

    if (width == 0 || height == 0) return;

    g_state.config.width = width;
    g_state.config.height = height;
    wgpuSurfaceConfigure(g_state.surface, &g_state.config);
}

void render_frame() {
    if (!g_state.webgpu_ready) return;

    // Get the current surface texture
    WGPUSurfaceTexture surface_texture;
    wgpuSurfaceGetCurrentTexture(g_state.surface, &surface_texture);

    switch (surface_texture.status) {
        case WGPUSurfaceGetCurrentTextureStatus_Success:
            break;
        case WGPUSurfaceGetCurrentTextureStatus_Timeout:
        case WGPUSurfaceGetCurrentTextureStatus_Outdated:
        case WGPUSurfaceGetCurrentTextureStatus_Lost:
            // Skip frame and reconfigure surface
            if (surface_texture.texture) {
                wgpuTextureRelease(surface_texture.texture);
            }
            handle_resize();
            return;
        case WGPUSurfaceGetCurrentTextureStatus_OutOfMemory:
        case WGPUSurfaceGetCurrentTextureStatus_DeviceLost:
            printf("Fatal surface error\n");
            exit(1);
    }

    // Create texture view for rendering
    WGPUTextureView frame_view = wgpuTextureCreateView(surface_texture.texture, NULL);

    // Create command encoder
    WGPUCommandEncoderDescriptor encoder_desc = {0};
    WGPUCommandEncoder command_encoder = wgpuDeviceCreateCommandEncoder(g_state.device, &encoder_desc);

    // Begin render pass
    WGPURenderPassColorAttachment color_attachment = {
        .view = frame_view,
        .loadOp = WGPULoadOp_Clear,
        .storeOp = WGPUStoreOp_Store,
        .clearValue = {0.0, 0.2, 0.4, 1.0}  // Dark blue background
    };

    WGPURenderPassDescriptor render_pass_desc = {
        .colorAttachmentCount = 1,
        .colorAttachments = &color_attachment
    };

    WGPURenderPassEncoder render_pass = wgpuCommandEncoderBeginRenderPass(command_encoder, &render_pass_desc);

    // Set pipeline and draw
    wgpuRenderPassEncoderSetPipeline(render_pass, g_state.render_pipeline);
    wgpuRenderPassEncoderDraw(render_pass, 3, 1, 0, 0);  // 3 vertices, 1 instance

    // End render pass
    wgpuRenderPassEncoderEnd(render_pass);

    // Finish command buffer
    WGPUCommandBufferDescriptor cmd_buffer_desc = {0};
    WGPUCommandBuffer command_buffer = wgpuCommandEncoderFinish(command_encoder, &cmd_buffer_desc);

    // Submit to queue
    wgpuQueueSubmit(g_state.queue, 1, &command_buffer);

    // Present the frame
    wgpuSurfacePresent(g_state.surface);

    // Cleanup
    wgpuCommandBufferRelease(command_buffer);
    wgpuRenderPassEncoderRelease(render_pass);
    wgpuCommandEncoderRelease(command_encoder);
    wgpuTextureViewRelease(frame_view);
    wgpuTextureRelease(surface_texture.texture);
}

void handle_events() {
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        switch (event.type) {
            case SDL_EVENT_QUIT:
                g_state.should_quit = true;
                break;
            case SDL_EVENT_WINDOW_RESIZED:
            case SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED:
                handle_resize();
                break;
        }
    }
}

int main() {
    if (!initialize_sdl()) return 1;
    if (!initialize_webgpu()) return 1;

    // Main loop
    while (!g_state.should_quit) {
        handle_events();
        render_frame();

        // Simple frame rate limiting
        SDL_Delay(16);  // ~60 FPS
    }

    // Cleanup
    cleanup();
    return 0;
}
```

### Understanding the Render Loop

**Surface Texture Acquisition**: The surface texture acquisition process directly exposes the underlying swap chain mechanics. Status codes like `Timeout` and `Outdated` reflect real hardware conditions - display disconnection, window resize, or compositor state changes. Robust applications must handle these conditions gracefully rather than assuming successful acquisition.

**Command Buffer Architecture**: WebGPU's command recording follows modern GPU architecture where work is batched into command buffers before submission. This enables driver-level optimizations like command reordering, state consolidation, and parallel command buffer construction. The render pass abstraction maps directly to modern GPU tile-based rendering optimizations.

**Per-Frame Resource Management**: The explicit cleanup pattern reflects WebGPU's deterministic resource model. Unlike garbage-collected APIs, WebGPU requires immediate cleanup of transient resources to prevent GPU memory exhaustion during high-frequency operations. This pattern is essential for maintaining consistent frame times in production applications.

## Next Steps: Sprite Batching

### GPU Utilization Analysis

Modern GPUs are massively parallel processors optimized for throughput, not latency. Traditional immediate-mode sprite rendering creates a pathological workload: thousands of draw calls with minimal work per call. Each draw call incurs driver overhead, GPU state validation, and potential pipeline stalls. This pattern severely underutilizes GPU compute units and memory bandwidth.

### Batching Strategy

Effective sprite batching transforms a high-frequency, low-work submission pattern into a low-frequency, high-work pattern that matches GPU architecture:

1. **Texture Atlas Consolidation**: Eliminates texture binding overhead and enables texture cache coherency
2. **Storage Buffer Architecture**: Leverages GPU's high-bandwidth memory access patterns for sprite parameters  
3. **Procedural Geometry Generation**: Eliminates vertex buffer overhead by generating quad geometry algorithmically
4. **Single Draw Call Submission**: Maximizes GPU utilization by submitting work in GPU-optimal batch sizes

Here's a comprehensive sprite batcher implementation:

```c
#define MAX_SPRITES 8192

typedef struct {
    float position[3];    // x, y, z
    float rotation;       // rotation in radians
    float scale[2];       // width, height scale
    float tex_coords[4];  // u0, v0, u1, v1 (texture atlas coordinates)
    float color[4];       // r, g, b, a
} SpriteData;

typedef struct {
    WGPUBuffer sprite_buffer;
    WGPUBuffer index_buffer;
    WGPUBindGroup bind_group;
    WGPUBindGroupLayout bind_group_layout;

    SpriteData sprites[MAX_SPRITES];
    int sprite_count;

    WGPUTexture atlas_texture;
    WGPUSampler atlas_sampler;
} SpriteBatcher;

SpriteBatcher g_batcher = {0};

bool initialize_sprite_batcher() {
    // Create sprite data buffer
    WGPUBufferDescriptor buffer_desc = {
        .usage = WGPUBufferUsage_Storage | WGPUBufferUsage_CopyDst,
        .size = sizeof(SpriteData) * MAX_SPRITES
    };
    g_batcher.sprite_buffer = wgpuDeviceCreateBuffer(g_state.device, &buffer_desc);

    // Create index buffer for quad indices
    uint32_t indices[MAX_SPRITES * 6];  // 6 indices per sprite (2 triangles)
    for (int i = 0; i < MAX_SPRITES; i++) {
        int base_vertex = i * 4;
        int base_index = i * 6;

        // First triangle: 0, 1, 2
        indices[base_index + 0] = base_vertex + 0;
        indices[base_index + 1] = base_vertex + 1;
        indices[base_index + 2] = base_vertex + 2;

        // Second triangle: 2, 3, 0
        indices[base_index + 3] = base_vertex + 2;
        indices[base_index + 4] = base_vertex + 3;
        indices[base_index + 5] = base_vertex + 0;
    }

    WGPUBufferDescriptor index_buffer_desc = {
        .usage = WGPUBufferUsage_Index | WGPUBufferUsage_CopyDst,
        .size = sizeof(indices)
    };
    g_batcher.index_buffer = wgpuDeviceCreateBuffer(g_state.device, &index_buffer_desc);
    wgpuQueueWriteBuffer(g_state.queue, g_batcher.index_buffer, 0, indices, sizeof(indices));

    // Create bind group layout
    WGPUBindGroupLayoutEntry layout_entries[] = {
        {
            .binding = 0,
            .visibility = WGPUShaderStage_Vertex,
            .buffer = {
                .type = WGPUBufferBindingType_ReadOnlyStorage,
                .hasDynamicOffset = false
            }
        },
        {
            .binding = 1,
            .visibility = WGPUShaderStage_Fragment,
            .texture = {
                .sampleType = WGPUTextureSampleType_Float,
                .viewDimension = WGPUTextureViewDimension_2D
            }
        },
        {
            .binding = 2,
            .visibility = WGPUShaderStage_Fragment,
            .sampler = {
                .type = WGPUSamplerBindingType_Filtering
            }
        }
    };

    WGPUBindGroupLayoutDescriptor layout_desc = {
        .entryCount = 3,
        .entries = layout_entries
    };
    g_batcher.bind_group_layout = wgpuDeviceCreateBindGroupLayout(g_state.device, &layout_desc);

    return true;
}

const char* sprite_shader_source =
    "struct SpriteData {\n"
    "    position: vec3<f32>,\n"
    "    rotation: f32,\n"
    "    scale: vec2<f32>,\n"
    "    tex_coords: vec4<f32>,\n"
    "    color: vec4<f32>,\n"
    "}\n"
    "\n"
    "@group(0) @binding(0) var<storage, read> sprites: array<SpriteData>;\n"
    "@group(0) @binding(1) var atlas_texture: texture_2d<f32>;\n"
    "@group(0) @binding(2) var atlas_sampler: sampler;\n"
    "\n"
    "struct VertexOutput {\n"
    "    @builtin(position) position: vec4<f32>,\n"
    "    @location(0) tex_coord: vec2<f32>,\n"
    "    @location(1) color: vec4<f32>,\n"
    "}\n"
    "\n"
    "@vertex\n"
    "fn vs_main(@builtin(vertex_index) vertex_id: u32) -> VertexOutput {\n"
    "    let sprite_id = vertex_id / 4u;\n"
    "    let corner_id = vertex_id % 4u;\n"
    "    \n"
    "    let sprite = sprites[sprite_id];\n"
    "    \n"
    "    // Generate quad corners: (0,0), (1,0), (1,1), (0,1)\n"
    "    var corner = vec2<f32>(f32(corner_id & 1u), f32(corner_id >> 1u));\n"
    "    \n"
    "    // Center around origin, then scale\n"
    "    corner = (corner - 0.5) * sprite.scale;\n"
    "    \n"
    "    // Apply rotation\n"
    "    let cos_r = cos(sprite.rotation);\n"
    "    let sin_r = sin(sprite.rotation);\n"
    "    let rotated = vec2<f32>(\n"
    "        corner.x * cos_r - corner.y * sin_r,\n"
    "        corner.x * sin_r + corner.y * cos_r\n"
    "    );\n"
    "    \n"
    "    // Translate to world position\n"
    "    let world_pos = sprite.position.xy + rotated;\n"
    "    \n"
    "    // Convert to NDC (assumes orthographic projection)\n"
    "    let ndc = vec2<f32>(world_pos.x / 640.0, -world_pos.y / 360.0);\n"
    "    \n"
    "    // Interpolate texture coordinates\n"
    "    let tex_coord = mix(\n"
    "        sprite.tex_coords.xy,\n"
    "        sprite.tex_coords.zw,\n"
    "        corner + 0.5\n"
    "    );\n"
    "    \n"
    "    var out: VertexOutput;\n"
    "    out.position = vec4<f32>(ndc, sprite.position.z, 1.0);\n"
    "    out.tex_coord = tex_coord;\n"
    "    out.color = sprite.color;\n"
    "    return out;\n"
    "}\n"
    "\n"
    "@fragment\n"
    "fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {\n"
    "    let tex_color = textureSample(atlas_texture, atlas_sampler, in.tex_coord);\n"
    "    return tex_color * in.color;\n"
    "}";

void add_sprite(float x, float y, float z, float rotation,
               float width, float height,
               float u0, float v0, float u1, float v1,
               float r, float g, float b, float a) {
    if (g_batcher.sprite_count >= MAX_SPRITES) return;

    SpriteData* sprite = &g_batcher.sprites[g_batcher.sprite_count++];
    sprite->position[0] = x;
    sprite->position[1] = y;
    sprite->position[2] = z;
    sprite->rotation = rotation;
    sprite->scale[0] = width;
    sprite->scale[1] = height;
    sprite->tex_coords[0] = u0;
    sprite->tex_coords[1] = v0;
    sprite->tex_coords[2] = u1;
    sprite->tex_coords[3] = v1;
    sprite->color[0] = r;
    sprite->color[1] = g;
    sprite->color[2] = b;
    sprite->color[3] = a;
}

void render_sprites() {
    if (g_batcher.sprite_count == 0) return;

    // Upload sprite data to GPU
    wgpuQueueWriteBuffer(g_state.queue, g_batcher.sprite_buffer, 0,
                        g_batcher.sprites, sizeof(SpriteData) * g_batcher.sprite_count);

    // ... (render pass setup as before) ...

    // Set sprite pipeline and bindings
    wgpuRenderPassEncoderSetPipeline(render_pass, sprite_render_pipeline);
    wgpuRenderPassEncoderSetBindGroup(render_pass, 0, g_batcher.bind_group, 0, NULL);
    wgpuRenderPassEncoderSetIndexBuffer(render_pass, g_batcher.index_buffer,
                                       WGPUIndexFormat_Uint32, 0, WGPU_WHOLE_SIZE);

    // Draw all sprites in a single call
    wgpuRenderPassEncoderDrawIndexed(render_pass,
                                    g_batcher.sprite_count * 6,  // 6 indices per sprite
                                    1, 0, 0, 0);

    // Reset for next frame
    g_batcher.sprite_count = 0;
}
```

### Sprite Batching Key Benefits

**Performance**: By combining thousands of sprites into a single draw call, you eliminate the overhead of state changes and leverage GPU parallelism. The example can easily render 8,192 sprites at 60+ FPS.

**Flexibility**: Each sprite can have individual position, rotation, scale, texture coordinates, and color, while still being rendered efficiently.

**Memory Efficiency**: Using storage buffers allows direct GPU access to sprite data without vertex buffer overhead.

### Integration Patterns

The sprite batcher integrates into your main loop like this:

```c
void game_update() {
    // Clear previous frame's sprites
    // (sprite_count is reset in render_sprites())

    // Add sprites for current frame
    for (int i = 0; i < enemy_count; i++) {
        add_sprite(enemies[i].x, enemies[i].y, 0.0, enemies[i].rotation,
                  32, 32,  // 32x32 pixel sprite
                  enemies[i].atlas_u0, enemies[i].atlas_v0,
                  enemies[i].atlas_u1, enemies[i].atlas_v1,
                  1.0, 1.0, 1.0, 1.0);  // white tint
    }

    // Add player sprite
    add_sprite(player.x, player.y, 0.1, player.rotation,
              48, 48,  // Larger player sprite
              player.atlas_u0, player.atlas_v0,
              player.atlas_u1, player.atlas_v1,
              1.0, 1.0, 1.0, 1.0);
}

void render_frame() {
    // ... (surface texture setup as before) ...

    // Render all sprites
    render_sprites();

    // ... (present and cleanup as before) ...
}
```

## Advanced Topics

### Indirect Rendering and GPU-Driven Pipelines

Modern GPUs excel at data-parallel workloads where the GPU itself drives rendering decisions. Indirect rendering eliminates CPU bottlenecks by storing draw commands in GPU buffers, enabling compute shaders to generate rendering work dynamically.

```c
typedef struct {
    uint32_t vertex_count;
    uint32_t instance_count;
    uint32_t first_vertex;
    uint32_t first_instance;
} IndirectDrawCommand;

typedef struct {
    WGPUBuffer command_buffer;    // Contains IndirectDrawCommand array
    WGPUBuffer counter_buffer;    // GPU-writable draw count
    WGPUComputePipeline cull_pipeline;
    WGPURenderPipeline draw_pipeline;
} IndirectRenderer;

// Compute shader for GPU-based frustum culling
const char* culling_compute_shader =
    "@group(0) @binding(0) var<storage, read> object_data: array<ObjectData>;\n"
    "@group(0) @binding(1) var<storage, read_write> commands: array<IndirectDrawCommand>;\n"
    "@group(0) @binding(2) var<storage, read_write> counter: atomic<u32>;\n"
    "\n"
    "@compute @workgroup_size(64)\n"
    "fn cull_objects(@builtin(global_invocation_id) id: vec3<u32>) {\n"
    "    if (id.x >= arrayLength(&object_data)) { return; }\n"
    "    \n"
    "    let obj = object_data[id.x];\n"
    "    if (is_visible(obj.bounds, camera.frustum)) {\n"
    "        let cmd_index = atomicAdd(&counter, 1u);\n"
    "        commands[cmd_index] = IndirectDrawCommand(\n"
    "            obj.vertex_count, 1u, obj.first_vertex, id.x\n"
    "        );\n"
    "    }\n"
    "}";

void dispatch_culling_and_render() {
    // Reset counter buffer
    uint32_t zero = 0;
    wgpuQueueWriteBuffer(queue, indirect.counter_buffer, 0, &zero, sizeof(zero));
    
    // Compute pass: GPU-driven culling
    WGPUComputePassEncoder compute_pass = wgpuCommandEncoderBeginComputePass(encoder, NULL);
    wgpuComputePassEncoderSetPipeline(compute_pass, indirect.cull_pipeline);
    wgpuComputePassEncoderSetBindGroup(compute_pass, 0, cull_bind_group, 0, NULL);
    wgpuComputePassEncoderDispatchWorkgroups(compute_pass, 
        (object_count + 63) / 64, 1, 1);
    wgpuComputePassEncoderEnd(compute_pass);
    
    // Render pass: Draw visible objects indirectly
    WGPURenderPassEncoder render_pass = wgpuCommandEncoderBeginRenderPass(encoder, &render_desc);
    wgpuRenderPassEncoderSetPipeline(render_pass, indirect.draw_pipeline);
    wgpuRenderPassEncoderSetBindGroup(render_pass, 0, draw_bind_group, 0, NULL);
    wgpuRenderPassEncoderDrawIndirect(render_pass, indirect.command_buffer, 0);
    wgpuRenderPassEncoderEnd(render_pass);
}
```

This pattern enables GPU-driven LOD selection, occlusion culling, and dynamic batching without CPU involvement, scaling to hundreds of thousands of objects.

### Compute-Based Particle Systems

WebGPU's compute capabilities enable sophisticated particle systems that leverage GPU parallelism for physics simulation, collision detection, and complex behaviors.

```c
typedef struct {
    float position[3];
    float velocity[3];
    float life_time;
    float max_life;
    uint32_t type_id;
    float padding[3];  // Align to 16 bytes
} Particle;

const char* particle_update_shader =
    "struct Particle {\n"
    "    position: vec3<f32>,\n"
    "    velocity: vec3<f32>,\n"
    "    life_time: f32,\n"
    "    max_life: f32,\n"
    "    type_id: u32,\n"
    "    padding: vec3<f32>,\n"
    "}\n"
    "\n"
    "@group(0) @binding(0) var<storage, read_write> particles: array<Particle>;\n"
    "@group(0) @binding(1) var<uniform> sim_params: SimParams;\n"
    "@group(0) @binding(2) var<storage, read> force_fields: array<ForceField>;\n"
    "\n"
    "@compute @workgroup_size(256)\n"
    "fn update_particles(@builtin(global_invocation_id) id: vec3<u32>) {\n"
    "    if (id.x >= arrayLength(&particles)) { return; }\n"
    "    \n"
    "    var particle = &particles[id.x];\n"
    "    \n"
    "    // Physics integration\n"
    "    var force = vec3<f32>(0.0, -9.81, 0.0) * sim_params.gravity_scale;\n"
    "    \n"
    "    // Apply force fields\n"
    "    for (var i = 0u; i < arrayLength(&force_fields); i++) {\n"
    "        let field = force_fields[i];\n"
    "        let dir = particle.position - field.position;\n"
    "        let dist_sq = dot(dir, dir);\n"
    "        if (dist_sq < field.radius * field.radius) {\n"
    "            force += normalize(dir) * field.strength / max(dist_sq, 0.01);\n"
    "        }\n"
    "    }\n"
    "    \n"
    "    // Verlet integration\n"
    "    particle.velocity += force * sim_params.delta_time;\n"
    "    particle.position += particle.velocity * sim_params.delta_time;\n"
    "    \n"
    "    // Update lifetime\n"
    "    particle.life_time -= sim_params.delta_time;\n"
    "    if (particle.life_time <= 0.0) {\n"
    "        // Reset particle for recycling\n"
    "        particle.position = emit_position(id.x);\n"
    "        particle.velocity = emit_velocity(id.x);\n"
    "        particle.life_time = particle.max_life;\n"
    "    }\n"
    "}";
```

This approach scales to millions of particles with complex interactions while maintaining real-time performance.

### Mesh Shaders and Geometry Amplification

Mesh shaders represent the next evolution in GPU geometry processing, replacing the traditional vertex/geometry shader pipeline with a more flexible compute-like model for primitive generation.

```c
// Mesh shader for procedural grass generation
const char* grass_mesh_shader =
    "struct GrassInstance {\n"
    "    position: vec3<f32>,\n"
    "    height: f32,\n"
    "    wind_phase: f32,\n"
    "    density: f32,\n"
    "}\n"
    "\n"
    "@group(0) @binding(0) var<storage, read> instances: array<GrassInstance>;\n"
    "@group(0) @binding(1) var<uniform> camera: CameraUniforms;\n"
    "\n"
    "struct VertexOutput {\n"
    "    @builtin(position) position: vec4<f32>,\n"
    "    @location(0) uv: vec2<f32>,\n"
    "    @location(1) wind_offset: f32,\n"
    "}\n"
    "\n"
    "@mesh @workgroup_size(32)\n"
    "fn grass_mesh(\n"
    "    @builtin(workgroup_id) wg_id: vec3<u32>,\n"
    "    @builtin(local_invocation_id) local_id: vec3<u32>\n"
    ") -> @location(0) array<VertexOutput, 192> {\n"  // 32 instances * 6 vertices each
    "    let instance_id = wg_id.x * 32u + local_id.x;\n"
    "    if (instance_id >= arrayLength(&instances)) { return; }\n"
    "    \n"
    "    let grass = instances[instance_id];\n"
    "    \n"
    "    // LOD calculation based on distance\n"
    "    let distance = length(grass.position - camera.position);\n"
    "    let lod_factor = saturate(1.0 - distance / camera.lod_distance);\n"
    "    \n"
    "    if (lod_factor < 0.1) {\n"
    "        SetMeshOutputsEXT(0u, 0u);  // Cull distant grass\n"
    "        return;\n"
    "    }\n"
    "    \n"
    "    // Generate grass blade geometry\n"
    "    let blade_width = 0.02 * grass.density;\n"
    "    let blade_height = grass.height * lod_factor;\n"
    "    \n"
    "    // Wind animation\n"
    "    let wind_strength = sin(camera.time * 2.0 + grass.wind_phase) * 0.3;\n"
    "    let wind_offset = vec3<f32>(wind_strength, 0.0, wind_strength * 0.5);\n"
    "    \n"
    "    // Emit 6 vertices (2 triangles) per grass blade\n"
    "    let base_vertex = local_id.x * 6u;\n"
    "    \n"
    "    // Bottom vertices\n"
    "    vertices[base_vertex + 0] = generate_vertex(grass.position, vec2<f32>(-blade_width, 0.0), vec2<f32>(0.0, 0.0), 0.0);\n"
    "    vertices[base_vertex + 1] = generate_vertex(grass.position, vec2<f32>(blade_width, 0.0), vec2<f32>(1.0, 0.0), 0.0);\n"
    "    \n"
    "    // Top vertices (with wind)\n"
    "    let top_pos = grass.position + vec3<f32>(0.0, blade_height, 0.0) + wind_offset;\n"
    "    vertices[base_vertex + 2] = generate_vertex(top_pos, vec2<f32>(-blade_width * 0.1, 0.0), vec2<f32>(0.0, 1.0), wind_strength);\n"
    "    vertices[base_vertex + 3] = generate_vertex(top_pos, vec2<f32>(blade_width * 0.1, 0.0), vec2<f32>(1.0, 1.0), wind_strength);\n"
    "    \n"
    "    // Generate primitive indices\n"
    "    let base_primitive = local_id.x * 2u;\n"
    "    primitives[base_primitive + 0] = vec3<u32>(base_vertex + 0, base_vertex + 1, base_vertex + 2);\n"
    "    primitives[base_primitive + 1] = vec3<u32>(base_vertex + 1, base_vertex + 3, base_vertex + 2);\n"
    "    \n"
    "    SetMeshOutputsEXT(32u * 6u, 32u * 2u);  // 192 vertices, 64 primitives\n"
    "}";
```

Mesh shaders enable procedural geometry generation, adaptive tessellation, and geometry amplification directly on the GPU, eliminating CPU geometry preprocessing bottlenecks.

### Multi-Pass Rendering and G-Buffer Management

Production rendering engines utilize multi-pass techniques for complex lighting, post-processing, and effects. WebGPU's explicit resource management enables efficient G-buffer architectures.

```c
typedef struct {
    WGPUTexture depth_buffer;
    WGPUTexture albedo_buffer;      // RGB: albedo, A: metallic
    WGPUTexture normal_buffer;      // RGB: world normal, A: roughness
    WGPUTexture motion_buffer;      // RG: motion vectors, BA: unused
    WGPUTexture lighting_buffer;    // HDR lighting accumulation
} GBuffer;

const char* deferred_lighting_shader =
    "@group(0) @binding(0) var gbuffer_albedo: texture_2d<f32>;\n"
    "@group(0) @binding(1) var gbuffer_normal: texture_2d<f32>;\n"
    "@group(0) @binding(2) var gbuffer_depth: texture_depth_2d<f32>;\n"
    "@group(0) @binding(3) var<uniform> lights: LightData;\n"
    "\n"
    "@fragment\n"
    "fn deferred_lighting(@builtin(position) screen_pos: vec4<f32>) -> @location(0) vec4<f32> {\n"
    "    let coords = vec2<i32>(screen_pos.xy);\n"
    "    \n"
    "    // Sample G-buffer\n"
    "    let albedo_metallic = textureLoad(gbuffer_albedo, coords, 0);\n"
    "    let normal_roughness = textureLoad(gbuffer_normal, coords, 0);\n"
    "    let depth = textureLoad(gbuffer_depth, coords, 0);\n"
    "    \n"
    "    // Reconstruct world position\n"
    "    let world_pos = reconstruct_world_pos(screen_pos.xy, depth, camera.inv_view_proj);\n"
    "    \n"
    "    // PBR lighting calculation\n"
    "    let albedo = albedo_metallic.rgb;\n"
    "    let metallic = albedo_metallic.a;\n"
    "    let normal = normalize(normal_roughness.rgb * 2.0 - 1.0);\n"
    "    let roughness = normal_roughness.a;\n"
    "    \n"
    "    var final_color = vec3<f32>(0.0);\n"
    "    \n"
    "    // Evaluate all lights\n"
    "    for (var i = 0u; i < lights.count; i++) {\n"
    "        let light = lights.data[i];\n"
    "        final_color += evaluate_pbr_light(world_pos, normal, albedo, metallic, roughness, light);\n"
    "    }\n"
    "    \n"
    "    return vec4<f32>(final_color, 1.0);\n"
    "}";

void render_deferred_frame() {
    // G-buffer pass: Render geometry to multiple render targets
    WGPURenderPassColorAttachment color_attachments[] = {
        {.view = gbuffer.albedo_view, .loadOp = WGPULoadOp_Clear, .storeOp = WGPUStoreOp_Store},
        {.view = gbuffer.normal_view, .loadOp = WGPULoadOp_Clear, .storeOp = WGPUStoreOp_Store},
        {.view = gbuffer.motion_view, .loadOp = WGPULoadOp_Clear, .storeOp = WGPUStoreOp_Store}
    };
    
    WGPURenderPassDepthStencilAttachment depth_attachment = {
        .view = gbuffer.depth_view,
        .depthLoadOp = WGPULoadOp_Clear,
        .depthStoreOp = WGPUStoreOp_Store,
        .depthClearValue = 1.0f
    };
    
    WGPURenderPassDescriptor gbuffer_pass = {
        .colorAttachmentCount = 3,
        .colorAttachments = color_attachments,
        .depthStencilAttachment = &depth_attachment
    };
    
    WGPURenderPassEncoder gbuffer_encoder = wgpuCommandEncoderBeginRenderPass(cmd_encoder, &gbuffer_pass);
    // ... render all geometry to G-buffer
    wgpuRenderPassEncoderEnd(gbuffer_encoder);
    
    // Lighting pass: Full-screen quad with deferred shading
    WGPURenderPassColorAttachment lighting_attachment = {
        .view = gbuffer.lighting_view,
        .loadOp = WGPULoadOp_Clear,
        .storeOp = WGPUStoreOp_Store
    };
    
    WGPURenderPassDescriptor lighting_pass = {
        .colorAttachmentCount = 1,
        .colorAttachments = &lighting_attachment
    };
    
    WGPURenderPassEncoder lighting_encoder = wgpuCommandEncoderBeginRenderPass(cmd_encoder, &lighting_pass);
    wgpuRenderPassEncoderSetPipeline(lighting_encoder, deferred_lighting_pipeline);
    wgpuRenderPassEncoderSetBindGroup(lighting_encoder, 0, gbuffer_bind_group, 0, NULL);
    wgpuRenderPassEncoderDraw(lighting_encoder, 3, 1, 0, 0);  // Full-screen triangle
    wgpuRenderPassEncoderEnd(lighting_encoder);
}
```

This architecture enables complex lighting models, screen-space effects, and temporal techniques like temporal anti-aliasing and motion blur.

## Conclusion

WebGPU exposes the full computational and rendering capabilities of modern GPU architectures through explicit, low-level control. The progression from basic triangle rendering through advanced compute-driven techniques demonstrates the API's scalability from simple graphics to sophisticated real-time applications.

Mastery of WebGPU requires understanding both the API's explicit resource model and the underlying GPU hardware characteristics it exposes. The patterns demonstrated here - from asynchronous initialization through GPU-driven rendering - form the foundation for modern real-time graphics systems capable of handling complex scenes at interactive frame rates.

The convergence of graphics and compute capabilities in modern GPUs, combined with WebGPU's unified programming model, enables new categories of real-time applications that blur the traditional boundaries between rendering and general-purpose GPU computation.
