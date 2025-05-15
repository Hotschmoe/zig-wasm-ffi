# WebGPU FFI Implementation and Particle Simulator Demo Plan

## 1. Introduction

This document outlines the plan to:
1.  Develop robust WebGPU FFI bindings for `zig-wasm-ffi` (`src/webgpu.zig` and `js/webgpu.js`).
2.  Refactor the existing WebGPU particle simulator (`particle_sim.html`) into a demo project within the `zig-wasm-ffi` repository (`demos/particle_simulator/`). This demo will utilize the new WebGPU FFI bindings.

The goal is to create a clear separation between the reusable WebGPU FFI layer and the application-specific logic of the demo, while replicating the functionality of the original particle simulator as closely as possible.

## 2. Analysis of `particle_sim.html`

The `particle_sim.html` file contains a complete 2D particle life simulation using WebGPU. Key components to analyze and refactor:

*   **WebGPU Initialization**: `navigator.gpu.requestAdapter()`, `adapter.requestDevice()`.
*   **Resource Management**:
    *   Buffers: `device.createBuffer()` for particles, species data, forces, uniforms (simulation options, camera), and intermediate compute shader data (bin offsets).
    *   Textures: `device.createTexture()` for HDR rendering and blue noise.
    *   Samplers: (If any, though not prominent in this example).
*   **Shader Handling**:
    *   WGSL shaders embedded as JavaScript template literals (e.g., `particleDescription`, `speciesDescription`, `binFillSizeShader`, `particleComputeForcesShader`, `particleAdvanceShader`, `particleRenderShader`, `composeShader`).
    *   Shader modules: `device.createShaderModule()`.
*   **Pipeline Creation**:
    *   Bind Group Layouts: `device.createBindGroupLayout()`.
    *   Pipeline Layouts: `device.createPipelineLayout()`.
    *   Compute Pipelines: `device.createComputePipeline()` for various simulation stages (binning, prefix sum, sorting, force computation, particle advancement).
    *   Render Pipelines: `device.createRenderPipeline()` for particle rendering (glow, circle, point) and final composition.
*   **Command Encoding & Execution**:
    *   `device.createCommandEncoder()`.
    *   Compute Passes: `encoder.beginComputePass()`, `pass.setPipeline()`, `pass.setBindGroup()`, `pass.dispatchWorkgroups()`, `pass.end()`.
    *   Render Passes: `encoder.beginRenderPass()`, `pass.setPipeline()`, `pass.setBindGroup()`, `pass.draw()`, `pass.end()`.
    *   Queue Submission: `device.queue.submit()`.
*   **Data Flow**:
    *   JavaScript structs/arrays for particle data, species attributes, force interactions, simulation parameters.
    *   Updating GPU buffers: `device.queue.writeBuffer()`.
*   **JavaScript Logic**: Simulation setup, UI interaction (camera controls, parameter adjustments), the main animation loop (`redraw()`).
*   **Asynchronous Operations**: Primarily around adapter/device requests and buffer mapping (e.g., for timestamp queries).

## 3. FFI Design (`src/webgpu.zig` and `js/webgpu.js`)

The FFI layer will provide low-level access to WebGPU capabilities.

### 3.1. `js/webgpu.js` (JavaScript Glue)

This file will contain JavaScript functions that directly call browser WebGPU APIs. These functions will be exported for Zig to call.

**Key Responsibilities:**

*   Expose WebGPU object creation and manipulation functions.
*   Handle asynchronous WebGPU calls (e.g., `requestAdapter`, `requestDevice`) and provide a way for Zig to get the results (e.g., by returning Promises that Zig can await via an interop mechanism, or by using unique IDs for requests and allowing Zig to poll for completion/results).
*   Convert data types between Zig (numbers, pointers to memory) and JavaScript (numbers, ArrayBuffers, WebGPU objects).
*   Manage a mapping of opaque Zig handles (integers) to actual JavaScript WebGPU objects.
It's crucial that this `js/webgpu.js` file remains a *thin shim* focused solely on direct WebGPU API interactions. Higher-level JavaScript logic for demo initialization, WASM loading, and the main event loop will reside in `demos/particle_simulator/web/main.js`.

**Example exported functions (conceptual):**

```javascript
// Initialization
export async function wgpu_request_adapter_async(options_ptr, options_len); // Returns a promise/ID
export function wgpu_get_adapter_result(request_id); // Poll for adapter or get result
export async function wgpu_adapter_request_device_async(adapter_handle, descriptor_ptr, descriptor_len); // Returns a promise/ID
export function wgpu_get_device_result(request_id); // Poll for device or get result
export function wgpu_device_get_queue(device_handle);

// Resource Creation
export function wgpu_device_create_buffer(device_handle, descriptor_ptr, descriptor_len); // Returns buffer_handle
export function wgpu_device_create_texture(device_handle, descriptor_ptr, descriptor_len); // Returns texture_handle
export function wgpu_device_create_shader_module(device_handle, descriptor_ptr, descriptor_len); // Returns shader_module_handle
export function wgpu_device_create_bind_group_layout(device_handle, descriptor_ptr, descriptor_len); // Returns bgl_handle
export function wgpu_device_create_pipeline_layout(device_handle, descriptor_ptr, descriptor_len); // Returns pipeline_layout_handle
export function wgpu_device_create_render_pipeline(device_handle, descriptor_ptr, descriptor_len); // Returns render_pipeline_handle
export function wgpu_device_create_compute_pipeline(device_handle, descriptor_ptr, descriptor_len); // Returns compute_pipeline_handle
export function wgpu_device_create_bind_group(device_handle, descriptor_ptr, descriptor_len); // Returns bind_group_handle
export function wgpu_texture_create_view(texture_handle, descriptor_ptr, descriptor_len); // Returns texture_view_handle

// Commands
export function wgpu_device_create_command_encoder(device_handle, descriptor_ptr, descriptor_len); // Returns command_encoder_handle
export function wgpu_command_encoder_begin_render_pass(encoder_handle, descriptor_ptr, descriptor_len); // Returns render_pass_encoder_handle
export function wgpu_command_encoder_begin_compute_pass(encoder_handle, descriptor_ptr, descriptor_len); // Returns compute_pass_encoder_handle
export function wgpu_command_encoder_finish(encoder_handle, descriptor_ptr, descriptor_len); // Returns command_buffer_handle

// Pass Encoder Operations
export function wgpu_render_pass_encoder_set_pipeline(pass_handle, pipeline_handle);
export function wgpu_render_pass_encoder_set_bind_group(pass_handle, index, bind_group_handle, offsets_ptr, offsets_len);
export function wgpu_render_pass_encoder_set_vertex_buffer(pass_handle, slot, buffer_handle, offset, size);
export function wgpu_render_pass_encoder_set_index_buffer(pass_handle, buffer_handle, index_format, offset, size);
export function wgpu_render_pass_encoder_draw(pass_handle, vertex_count, instance_count, first_vertex, first_instance);
export function wgpu_render_pass_encoder_draw_indexed(pass_handle, index_count, instance_count, first_index, base_vertex, first_instance);
export function wgpu_render_pass_encoder_end(pass_handle);
// ... similar for compute_pass_encoder

// Queue Operations
export function wgpu_queue_write_buffer(queue_handle, buffer_handle, buffer_offset, data_ptr, data_size);
export function wgpu_queue_submit(queue_handle, command_buffers_ptr, command_buffers_len);

// Utility
export function wgpu_release_handle(handle); // To release JS-side objects
```

### 3.2. `src/webgpu.zig` (Zig Bindings)

This file will define Zig `extern` functions pointing to the JavaScript functions in `js/webgpu.js`. It will also provide Zig structs for WebGPU objects and descriptors.

**Key Responsibilities:**

*   Define opaque struct types for WebGPU handles (e.g., `pub const Device = opaque {};`, or integer IDs).
*   Define Zig structs for descriptors (`GpuBufferDescriptor`, `GpuTextureDescriptor`, etc.) that are compatible with what the JS glue functions expect (e.g., pointers to packed structs).
*   Provide wrapper functions that call the `extern` JS functions, handling data marshalling (e.g., converting Zig slices to `ptr+len` for JS).
*   Manage asynchronous operations: This will involve calling the `_async` JS functions and then using a mechanism (TBD, could be Zig's `async/await` if WASM target supports it well with JS promises, or a polling mechanism) to get the results.
*   Abstract common patterns, such as creating a buffer with initial data.

**Example Zig structs and `extern` functions (conceptual):**

```zig
pub const Adapter = extern struct { id: u32 }; // Opaque handle
pub const Device = extern struct { id: u32 };
pub const Queue = extern struct { id: u32 };
pub const Buffer = extern struct { id: u32 };
// ... other opaque handles

pub const BufferDescriptor = extern struct {
    label: ?[*:0]const u8,
    size: u64,
    usage: u32, // Flags
    mappedAtCreation: bool,
};

// Extern JS function declarations
extern "c" fn wgpu_request_adapter_async(options_ptr: ?*const anyopaque, options_len: usize) callconv(.Js) void; // Returns a request ID or promise
// ... other extern functions

// Zig wrapper functions
pub fn requestAdapter(allocator: std.mem.Allocator, options: ?AdapterOptions) !Adapter {
    // ... call wgpu_request_adapter_async
    // ... await/poll for result using the returned request_id/promise
    // ... return Adapter handle
}

pub fn createBuffer(device: Device, descriptor: BufferDescriptor) !Buffer {
    // ... call wgpu_device_create_buffer
    // ... return Buffer handle
}

pub fn queueWriteBuffer(queue: Queue, buffer: Buffer, buffer_offset: u64, data: []const u8) void {
    wgpu_queue_write_buffer(queue.id, buffer.id, buffer_offset, data.ptr, data.len);
}

// ... many more
```

## 4. Demo Project Design (`demos/particle_simulator/`)

The demo will showcase the use of the `zig-wasm-ffi` WebGPU bindings.

### 4.1. `demos/particle_simulator/src/simulator.zig`

*   **Responsibilities**:
    *   Core simulation logic: particle data structures (arrays of structs), managing particle state (position, velocity, species).
    *   Physics updates: Implementing the particle interaction rules. If these are done on the CPU, this module does the calculations. If on GPU (as in the original), this module prepares data for compute shaders (e.g., uniform buffers).
    *   Managing simulation parameters (particle count, species count, forces, friction, etc.).
    *   Interaction with `renderer.zig` to trigger rendering and compute shader execution.
    *   Potentially handling high-level state (paused, running).
*   **Data Structures**:
    *   `Particle` struct (x, y, vx, vy, species_id).
    *   `Species` struct (color, force_parameters).
    *   `Force` struct (strength, radius, etc.).
    *   Array or ArrayList of particles.

### 4.2. `demos/particle_simulator/src/renderer.zig` (New File)

*   **Responsibilities**:
    *   All direct WebGPU interactions via the `webgpu.zig` FFI layer.
    *   **Initialization**:
        *   `requestAdapter()`, `adapter.requestDevice()`, `device.getQueue()`.
    *   **Resource Creation & Management**:
        *   Create GPU buffers for particles, species, forces, simulation options (uniforms), binning data, etc.
        *   Manage `particleBuffer` and `particleTempBuffer` (ping-ponging for compute stages).
        *   Create textures for HDR rendering target and blue noise.
        *   Upload initial particle data, species data, force data.
    *   **Shader Handling**:
        *   Store WGSL shader code (likely as `comptime` strings initially).
        *   `device.createShaderModule()` for each shader.
    *   **Pipeline Setup**:
        *   `device.createBindGroupLayout()` for various bind group configurations.
        *   `device.createPipelineLayout()`.
        *   `device.createComputePipeline()` for:
            *   `binClearSizePipeline`, `binFillSizePipeline`
            *   `binPrefixSumPipeline`
            *   `particleSortClearSizePipeline`, `particleSortPipeline`
            *   `particleComputeForcesPipeline`
            *   `particleAdvancePipeline`
        *   `device.createRenderPipeline()` for:
            *   `particleRenderGlowPipeline`, `particleRenderPipeline`, `particleRenderPointPipeline` (for particle rendering)
            *   `composePipeline` (for final screen presentation)
    *   **Main Loop (`renderFrame` function called by `simulator.zig` or a main loop):**
        *   Update uniform buffers (simulation options, camera).
        *   Create command encoder.
        *   **Compute Passes**: Encode commands for each compute stage, similar to the `redraw()` function in `particle_sim.html`.
            *   Set pipelines, bind groups, dispatch workgroups.
        *   **Render Pass (HDR)**: Encode commands to render particles to the HDR texture.
        *   **Render Pass (Compose)**: Encode commands to render the HDR texture to the screen (with tonemapping).
        *   `commandEncoder.finish()`, `queue.submit()`.
*   **Data Structures**:
    *   Hold `webgpu.zig` opaque handles for all GPU resources.
    *   Camera struct (center, extent, pixelsPerUnit).
    *   SimulationOptions struct.

### 4.3. Shaders (`demos/particle_simulator/shaders/` or embedded in `renderer.zig`)

*   The WGSL shaders (`particleDescription`, `speciesDescription`, `forceDescription`, `simulationOptionsDescription`, `binFillSizeShader`, `binPrefixSumShader`, `particleSortShader`, `particleComputeForcesShader`, `particleAdvanceShader`, `particleRenderShader`, `composeShader`) will be extracted from `particle_sim.html`.
*   Initially, they can be embedded as `comptime` multi-line strings in `renderer.zig`.
*   Later, a build step or runtime loading mechanism could fetch them from separate `.wgsl` files in a `shaders/` subdirectory.

### 4.4. `demos/particle_simulator/web/main.js` (Utilized and potentially adapted)

*   The existing `demos/particle_simulator/web/main.js` will be utilized and adapted. Its responsibilities will include:
    *   Loading the `app.wasm` (the compiled Zig demo).
    *   Instantiating the WASM module, providing the necessary imports. This includes functions from the minimal `js/webgpu.js` shim and any other required FFI glue (e.g., `webinput.js`).
    *   Calling an exported Zig `main` or `init` function to start the simulation.
    *   Handling canvas setup (retrieving the canvas element) and resizing, potentially notifying Zig.
    *   Implementing the main browser animation loop (`requestAnimationFrame`) which calls an exported `update_frame` or `render_frame` function in the Zig application.
    *   Forwarding UI events from `index.html` (if any complex UI is added beyond the original particle simulator's scope and handled in JS) to exported Zig functions. For the particle simulator, the UI interactions were largely embedded in the original HTML's JS, which will be ported to Zig or handled by minimal adaptations in this `main.js`.

### 4.5. `demos/particle_simulator/web/index.html` (Utilized)

*   The existing `demos/particle_simulator/web/index.html` will be utilized. It's already a lightweight HTML file.
    *   It will continue to provide the basic HTML structure with a `<canvas id="zigCanvas"></canvas>` element.
    *   It will continue to include `<script type="module" src="main.js"></script>`.
    *   The goal is to keep this HTML file as minimal as it currently is. The UI controls from the original `particle_sim.html` (sliders, buttons) will be recreated within the Zig application or, if necessary, as simple HTML elements whose events are wired up in `main.js` to call Zig functions.
    *   CSS can be linked or remain inline if simple, as is currently the case.

## 5. Step-by-Step Implementation Plan

1.  **Setup FFI Basics**:
    *   Create `js/webgpu.js` and `src/webgpu.zig`.
    *   Implement `requestAdapter`, `requestDevice`, and `getQueue` in both files. Focus on getting a `GPUDevice` and `GPUQueue` handle into Zig.
    *   Set up a minimal `build.zig` for the demo to compile a WASM that calls these initial FFI functions and logs success/failure.
2.  **Buffer Operations**:
    *   Implement FFI functions for `createBuffer` and `queueWriteBuffer`.
    *   In `renderer.zig`, use these to create a simple buffer and write data to it.
3.  **Shader Module & Basic Compute Pipeline**:
    *   Implement FFI for `createShaderModule`.
    *   Port a very simple compute shader (e.g., one that reads from one buffer and writes to another).
    *   Implement FFI for `createBindGroupLayout`, `createPipelineLayout`, `createComputePipeline`.
    *   In `renderer.zig`, create these resources.
4.  **Basic Compute Pass**:
    *   Implement FFI for `createCommandEncoder`, `beginComputePass`, `setPipeline`, `setBindGroup`, `dispatchWorkgroups`, `endPass`, `finishEncoder`, `submitQueue`.
    *   In `renderer.zig`, run the simple compute shader. Add FFI for reading back buffer data (for verification).
5.  **Port Particle Simulation Compute Shaders**:
    *   Systematically port each compute shader stage from `particle_sim.html` (`binFillSize`, `prefixSum`, `sort`, `computeForces`, `advance`).
    *   Implement the necessary buffer creations (`particleBuffer`, `particleTempBuffer`, `binOffsetBuffer`, `forcesBuffer`, `simulationOptionsBuffer`) in `renderer.zig`.
    *   Set up the corresponding compute pipelines and bind groups in `renderer.zig`.
    *   Implement the compute pass sequence in `renderer.zig`.
6.  **Basic Render Pipeline**:
    *   Implement FFI for `createRenderPipeline`.
    *   Port the simplest particle rendering shader and the compose shader.
    *   Implement FFI for `textureCreateView`, `beginRenderPass` (with color attachments), `draw`, `endPass`.
    *   In `renderer.zig`, set up render pipelines for rendering particles to an HDR texture and then composing to the canvas.
    *   Configure the canvas context in `particle_sim.js` via `context.configure()`.
7.  **Integrate `simulator.zig`**:
    *   Develop `simulator.zig` to manage particle state and simulation parameters.
    *   `renderer.zig` will fetch data from `simulator.zig` to update GPU buffers.
8.  **HTML/JS Frontend Refinement**:
    *   Modify `particle_sim.html` and `particle_sim.js` to load the WASM.
    *   Connect UI controls in `particle_sim.html` (via `particle_sim.js`) to exported Zig functions in `simulator.zig` or `renderer.zig` to update parameters.
9.  **Advanced Features & Refinements**:
    *   Timestamp queries (if supported by adapter).
    *   Handle canvas resizing properly.
    *   Ensure proper error handling through the FFI layer.
    *   Optimize data transfers and GPU usage.
    *   Implement all UI functionalities (pause, center view, randomize, save/load (client-side), etc.).

## 6. Considerations

*   **Asynchronous Operations**: JS `async/await` for adapter/device requests. The `js/webgpu.js` will manage promises. Zig's interaction with these promises needs careful design. Possibilities:
    *   Zig calls an async JS function that stores the promise and returns an ID. Zig polls another JS function with this ID to check promise status/result.
    *   If Zig's WASM `async/await` can interoperate with JS promises directly, this would be cleaner. (Needs investigation for `wasm32-freestanding`).
*   **Error Handling**: How errors from WebGPU (e.g., validation errors, device loss) are propagated from JS to Zig. JS could return error codes/messages, or Zig could query for errors.
*   **Memory Management**:
    *   Zig: The demo project will manage its own memory for particle data, etc.
    *   JS: `js/webgpu.js` will need a mechanism to release GPU objects when their corresponding Zig handles are no longer needed (e.g., `wgpu_release_handle(handle_id)`).
*   **Data Marshalling**: Efficiently passing structs and arrays between Zig and JS. For sending data to JS, Zig can pass `ptr+len`. For JS returning complex data, it might write to WASM memory allocated by Zig.
*   **String Handling**: Passing shader code and labels (null-terminated strings from Zig).
*   **Build System**: `build.zig` will need to compile `simulator.zig` and `renderer.zig` along with `webgpu.zig` (as a dependency) into `app.wasm`. It also needs to ensure `js/webgpu.js` and the modified `particle_sim.js` are available to the HTML.

This plan provides a structured approach to developing the WebGPU FFI and refactoring the particle simulator. Each step will involve iterative development and testing.
