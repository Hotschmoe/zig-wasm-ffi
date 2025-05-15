# WebGPU Implementation in wasm-particles Project

This document outlines how WebGPU is initialized and utilized in the `wasm-particles` project, focusing on the interaction between Zig (Wasm) and JavaScript. The goal is to understand the existing FFI (Foreign Function Interface) and how it can be structured into a reusable Zig WebGPU binding library.

## Project File Structure

The relevant files for WebGPU integration are:

*   **Zig (src):**
    *   [`archive/wasm-particles/src/main.zig`](../../archive/wasm-particles/src/main.zig): Main entry point for the Wasm module, initializes other Zig modules.
    *   [`archive/wasm-particles/src/webgpu_core.zig`](../../archive/wasm-particles/src/webgpu_core.zig): Defines core WebGPU data structures, handles, and enums used in Zig.
    *   [`archive/wasm-particles/src/webgpu_js_api.zig`](../../archive/wasm-particles/src/webgpu_js_api.zig): Declares `extern` functions that Zig calls, which are implemented in JavaScript. These form the FFI.
    *   [`archive/wasm-particles/src/gpu_context.zig`](../../archive/wasm-particles/src/gpu_context.zig): Manages the GPU state, including adapter, device, canvas context, and other global GPU resources.
    *   [`archive/wasm-particles/src/webgpu_callbacks.zig`](../../archive/wasm-particles/src/webgpu_callbacks.zig): Contains functions called by JavaScript in response to asynchronous WebGPU operations (e.g., adapter/device request completion).
    *   [`archive/wasm-particles/src/renderer.zig`](../../archive/wasm-particles/src/renderer.zig): Handles the rendering logic, creating pipelines, bind groups, and issuing draw calls.
    *   [`archive/wasm-particles/src/simulation.zig`](../../archive/wasm-particles/src/simulation.zig): Manages the particle simulation logic, including compute shaders.
    *   Shaders:
        *   [`archive/wasm-particles/src/shaders/particle_render.wgsl`](../../archive/wasm-particles/src/shaders/particle_render.wgsl)
        *   [`archive/wasm-particles/src/shaders/particle_compute.wgsl`](../../archive/wasm-particles/src/shaders/particle_compute.wgsl)
        *   [`archive/wasm-particles/src/shaders/particle_binning.wgsl`](../../archive/wasm-particles/src/shaders/particle_binning.wgsl)
        *   [`archive/wasm-particles/src/shaders/particle_prefix_sum.wgsl`](../../archive/wasm-particles/src/shaders/particle_prefix_sum.wgsl)
        *   [`archive/wasm-particles/src/shaders/particle_sort.wgsl`](../../archive/wasm-particles/src/shaders/particle_sort.wgsl)

*   **JavaScript (web/js):**
    *   [`archive/wasm-particles/web/js/main.js`](../../archive/wasm-particles/web/js/main.js): Initializes the Wasm module, sets up the import object (linking Zig's `extern` functions to JS implementations), and manages the render loop.
    *   [`archive/wasm-particles/web/js/config.js`](../../archive/wasm-particles/web/js/config.js): Holds shared configuration, including the Wasm instance and a mechanism (`gpuObjects`, `addObject`, `getObject`) for storing and retrieving JavaScript WebGPU objects using handles (integer IDs) passed to/from Zig.
    *   [`archive/wasm-particles/web/js/webgpu_setup.js`](../../archive/wasm-particles/web/js/webgpu_setup.js): Implements JS functions for initial WebGPU setup (adapter, device, canvas, shaders, initial buffers).
    *   [`archive/wasm-particles/web/js/webgpu_pipelines_and_bindings.js`](../../archive/wasm-particles/web/js/webgpu_pipelines_and_bindings.js): Implements JS functions for creating WebGPU pipelines (render and compute) and bind groups.
    *   [`archive/wasm-particles/web/js/webgpu_commands_and_passes.js`](../../archive/wasm-particles/web/js/webgpu_commands_and_passes.js): Implements JS functions for command encoding, render/compute passes, and command submission.

## Initialization Process

The WebGPU initialization process starts from Zig's `_start` function and involves asynchronous calls across the Wasm-JS boundary.

1.  **Wasm Initiation (`_start` in `main.zig`):**
    *   The Zig Wasm module's entry point `_start` (defined in [`archive/wasm-particles/src/main.zig`](../../archive/wasm-particles/src/main.zig)) is called by JavaScript after Wasm instantiation (see [`archive/wasm-particles/web/js/main.js`](../../archive/wasm-particles/web/js/main.js)).
    *   `_start` calls `js_api.js_initiate_adapter_request()`. This is an `extern` function declared in [`archive/wasm-particles/src/webgpu_js_api.zig`](../../archive/wasm-particles/src/webgpu_js_api.zig).

2.  **JavaScript Handling Adapter Request (`js_initiate_adapter_request` in `webgpu_setup.js`):**
    *   The corresponding JavaScript function `js_initiate_adapter_request` in [`archive/wasm-particles/web/js/webgpu_setup.js`](../../archive/wasm-particles/web/js/webgpu_setup.js) is invoked.
    *   It uses `navigator.gpu.requestAdapter()` to asynchronously request a `GPUAdapter`.
    *   **Callback to Zig:** Once the promise resolves (or rejects):
        *   If successful, the adapter object is stored in the `gpuObjects` array (from [`archive/wasm-particles/web/js/config.js`](../../archive/wasm-particles/web/js/config.js)), and its handle (index) is passed back to Zig by calling `wasmInstance.exports.zig_receive_adapter_handle(handle)`.
        *   If unsuccessful, `0` (representing an invalid handle) is passed back.
    *   The target Zig function `zig_receive_adapter_handle` is located in [`archive/wasm-particles/src/webgpu_callbacks.zig`](../../archive/wasm-particles/src/webgpu_callbacks.zig).

3.  **Zig Receives Adapter Handle (`zig_receive_adapter_handle` in `webgpu_callbacks.zig`):**
    *   This function in [`archive/wasm-particles/src/webgpu_callbacks.zig`](../../archive/wasm-particles/src/webgpu_callbacks.zig) receives the adapter handle (or `0` on error).
    *   It stores the handle in the `GpuContext` (managed by [`archive/wasm-particles/src/gpu_context.zig`](../../archive/wasm-particles/src/gpu_context.zig)).
    *   If successful, it then initiates the device request by calling `js_api.js_initiate_device_request(adapter_handle)`.

4.  **JavaScript Handling Device Request (`js_initiate_device_request` in `webgpu_setup.js`):**
    *   The JS function `js_initiate_device_request` in [`archive/wasm-particles/web/js/webgpu_setup.js`](../../archive/wasm-particles/web/js/webgpu_setup.js) retrieves the `GPUAdapter` object using the provided `adapterHandle`.
    *   It calls `adapter.requestDevice()` to asynchronously request a `GPUDevice`.
    *   **Callback to Zig:** Similar to the adapter request, once the promise resolves:
        *   The device object is stored, and its handle is passed to `wasmInstance.exports.zig_receive_device_handle(handle)`.
        *   `0` is passed on error.
    *   The target Zig function `zig_receive_device_handle` is in [`archive/wasm-particles/src/webgpu_callbacks.zig`](../../archive/wasm-particles/src/webgpu_callbacks.zig).

5.  **Zig Receives Device Handle (`zig_receive_device_handle` in `webgpu_callbacks.zig`):**
    *   This function in [`archive/wasm-particles/src/webgpu_callbacks.zig`](../../archive/wasm-particles/src/webgpu_callbacks.zig) receives the device handle.
    *   It stores the handle in `GpuContext`.
    *   If successful, it proceeds to:
        *   Get the preferred canvas format: `js_api.js_get_preferred_canvas_format()`.
        *   The callback for this is `zig_receive_preferred_canvas_format`.

6.  **Canvas Configuration:**
    *   `zig_receive_preferred_canvas_format` (in [`archive/wasm-particles/src/webgpu_callbacks.zig`](../../archive/wasm-particles/src/webgpu_callbacks.zig)) receives a format ID (mapped from a string like `"bgra8unorm"` in JS).
    *   It then calls `js_api.js_configure_canvas(...)` with the device handle, canvas ID (hardcoded to `"zigCanvas"` in JS), format ID, and an alpha mode.
    *   The JS function `js_configure_canvas` (in [`archive/wasm-particles/web/js/webgpu_setup.js`](../../archive/wasm-particles/web/js/webgpu_setup.js)) gets the canvas element, gets its WebGPU context, and configures it.
    *   **Callback to Zig:** The handle for the `GPUCanvasContext` is passed to `wasmInstance.exports.zig_receive_canvas_context_handle(contextHandle)`.
    *   `zig_receive_canvas_context_handle` (in [`archive/wasm-particles/src/webgpu_callbacks.zig`](../../archive/wasm-particles/src/webgpu_callbacks.zig)) stores the context handle. At this point, the basic WebGPU setup is complete, and the application can proceed to create resources and render.

## WebGPU Object Management (Handles)

A crucial aspect of the Wasm-JS interop is managing WebGPU objects (like `GPUAdapter`, `GPUDevice`, `GPUBuffer`, `GPUShaderModule`, etc.), which cannot be directly passed to or stored in Wasm.

*   **JavaScript Storage (`config.js`):**
    *   The file [`archive/wasm-particles/web/js/config.js`](../../archive/wasm-particles/web/js/config.js) defines a global array `gpuObjects = [null]`.
    *   The `addObject(obj)` function pushes a new JS WebGPU object into this array and returns its index. This index is its "handle".
    *   The `getObject(handle)` function retrieves the JS object given its handle.
    *   `0` is typically used as an invalid/null handle.

*   **Zig Handles (`webgpu_core.zig`):**
    *   [`archive/wasm-particles/src/webgpu_core.zig`](../../archive/wasm-particles/src/webgpu_core.zig) defines various `Gpu*Handle` types (e.g., `GpuDeviceHandle`, `GpuBufferHandle`) as `u32`.
    *   Zig code stores and passes these `u32` handles. When a WebGPU operation needs to be performed on a specific object, Zig passes the relevant handle to a JS FFI function. The JS function then uses this handle to retrieve the actual WebGPU object from the `gpuObjects` array.

## Data Transfer

### Zig to JavaScript (e.g., Shader Code, Buffer Data)

*   **Writing to GPU Buffers (`js_write_gpu_buffer`):**
    *   Zig calls `js_write_gpu_buffer(bufferHandle, destinationOffsetBytes, dataPtr, dataLenBytes)`.
        *   `bufferHandle`: Handle to the target `GPUBuffer`.
        *   `dataPtr`: A pointer to the data in Wasm's linear memory.
        *   `dataLenBytes`: Length of the data.
    *   In [`archive/wasm-particles/web/js/webgpu_setup.js`](../../archive/wasm-particles/web/js/webgpu_setup.js), `js_write_gpu_buffer` does the following:
        1.  Retrieves the `GPUBuffer` object using `bufferHandle`.
        2.  Retrieves the `GPUDevice` object (currently hardcoded to handle `2`, assuming it's the main device).
        3.  Accesses Wasm's memory: `const wasmMemoryBuffer = wasmInstance.exports.memory.buffer;`
        4.  Creates a `Uint8Array` view into the Wasm memory: `const dataToWrite = new Uint8Array(wasmMemoryBuffer, dataPtr, dataLenBytes);`
        5.  **Crucially, it copies the data**: `const dataCopy = dataToWrite.slice();` This is important because the Wasm memory might change, and WebGPU operations are often asynchronous.
        6.  Calls `mainDevice.queue.writeBuffer(buffer, destinationOffsetBytes, dataCopy);` to write the copied data to the GPU buffer.

*   **Creating Shader Modules (`js_create_shader_module`):**
    *   Zig calls `js_create_shader_module(deviceHandle, purposeId, codePtr, codeLen)`.
        *   `codePtr`: Pointer to the WGSL shader code string in Wasm memory.
        *   `codeLen`: Length of the string.
    *   In [`archive/wasm-particles/web/js/webgpu_setup.js`](../../archive/wasm-particles/web/js/webgpu_setup.js), `js_create_shader_module`:
        1.  Retrieves the `GPUDevice`.
        2.  Creates a `Uint8Array` view into Wasm memory for the shader code.
        3.  Decodes it to a JS string: `const wgslCode = new TextDecoder().decode(wgslBytes);`
        4.  Creates the shader module: `device.createShaderModule({ code: wgslCode });`
        5.  Stores the `GPUShaderModule` and passes its handle back to Zig via `zig_receive_shader_module_handle`.

### JavaScript to Zig (e.g., Handles, Callbacks)

*   As seen in the initialization, JS primarily sends back `u32` handles to Zig, representing created WebGPU objects.
*   These are passed as arguments to exported Wasm functions (defined in [`archive/wasm-particles/src/webgpu_callbacks.zig`](../../archive/wasm-particles/src/webgpu_callbacks.zig)).

## Rendering and Compute Operations

The general flow for rendering or dispatching compute shaders is:

1.  **Resource Creation (Zig-driven, JS-executed):**
    *   **Buffers:** Zig calls `js_create_gpu_buffer` (in [`archive/wasm-particles/src/webgpu_js_api.zig`](../../archive/wasm-particles/src/webgpu_js_api.zig)), implemented in [`archive/wasm-particles/web/js/webgpu_setup.js`](../../archive/wasm-particles/web/js/webgpu_setup.js). JS creates `GPUBuffer`s, stores them, and returns handles to Zig via `zig_receive_gpu_buffer_handle`.
    *   **Shader Modules:** As described above, `js_create_shader_module` is used.
    *   **Pipelines (Render & Compute):**
        *   Zig calls `js_create_render_pipeline` or `js_create_compute_pipeline` (in [`archive/wasm-particles/src/webgpu_js_api.zig`](../../archive/wasm-particles/src/webgpu_js_api.zig)).
        *   These are implemented in [`archive/wasm-particles/web/js/webgpu_pipelines_and_bindings.js`](../../archive/wasm-particles/web/js/webgpu_pipelines_and_bindings.js).
        *   JS side:
            *   Retrieves `GPUDevice` and `GPUShaderModule` using handles.
            *   Defines `GPUBindGroupLayout`s (often hardcoded or determined by `purposeId` or shader structure).
            *   Creates `GPUPipelineLayout`.
            *   Constructs the pipeline descriptor (vertex, fragment, compute stages, entry points, buffer layouts, primitive topology, blend states for render pipelines). Entry point names are strings, mapped from `ShaderEntryPointId` enums from Zig.
            *   Calls `device.createRenderPipeline()` or `device.createComputePipeline()`.
            *   Stores the pipeline object and returns its handle to Zig via `zig_receive_render_pipeline_handle` or `zig_receive_compute_pipeline_handle`.
    *   **Bind Groups:**
        *   Zig calls `js_create_bind_group` (in [`archive/wasm-particles/src/webgpu_js_api.zig`](../../archive/wasm-particles/src/webgpu_js_api.zig)).
        *   Implemented in [`archive/wasm-particles/web/js/webgpu_pipelines_and_bindings.js`](../../archive/wasm-particles/web/js/webgpu_pipelines_and_bindings.js).
        *   Zig passes a pointer (`bindingsPtr`) to an array of `BindGroupEntryForJs` structs (defined in [`archive/wasm-particles/src/webgpu_core.zig`](../../archive/wasm-particles/src/webgpu_core.zig)). This struct contains `binding` number and `buffer_handle`.
        *   JS side:
            *   Retrieves `GPUDevice` and the relevant `GPUPipeline` (render or compute) using handles.
            *   Reads the array of `BindGroupEntryForJs` from Wasm memory. For each entry:
                *   Gets the `GPUBuffer` using `buffer_handle`.
                *   Constructs the `GPUBindGroupEntry` descriptor.
            *   Gets the `GPUBindGroupLayout` from the pipeline using `pipeline.getBindGroupLayout(groupIndex)`.
            *   Calls `device.createBindGroup()`.
            *   Stores the bind group and returns its handle to Zig via `zig_receive_bind_group_handle`.

2.  **Command Encoding (Zig-driven, JS-executed):**
    *   This process happens typically per frame, orchestrated by `zig_render_frame` in `renderer.zig` or simulation steps.
    *   All functions below are `extern` in [`archive/wasm-particles/src/webgpu_js_api.zig`](../../archive/wasm-particles/src/webgpu_js_api.zig) and implemented in [`archive/wasm-particles/web/js/webgpu_commands_and_passes.js`](../../archive/wasm-particles/web/js/webgpu_commands_and_passes.js).
    *   Zig calls `js_create_command_encoder`. JS creates `GPUCommandEncoder`, stores it, and returns handle via `zig_receive_command_encoder_handle`.
    *   **For Rendering:**
        *   `js_get_current_texture_view(canvasContextHandle)`: JS gets the current texture view from the `GPUCanvasContext` and returns its handle.
        *   `js_begin_render_pass(encoderHandle, textureViewHandle, r, g, b, a)`: JS begins a render pass with the specified clear color. Returns `GPURenderPassEncoder` handle.
        *   `js_set_pipeline(renderPassEncoderHandle, pipelineHandle)`: Sets the `GPURenderPipeline`.
        *   `js_set_bind_group(renderPassEncoderHandle, groupIndex, bindGroupHandle)`: Sets `GPUBindGroup`(s).
        *   `js_draw(renderPassEncoderHandle, vertexCount, instanceCount, firstVertex, firstInstance)`: Issues a draw call.
        *   `js_end_render_pass(renderPassEncoderHandle)`: Ends the render pass.
    *   **For Compute:**
        *   `js_begin_compute_pass(commandEncoderHandle)`: JS begins a compute pass. Returns `GPUComputePassEncoder` handle.
        *   `js_set_pipeline_compute(computePassEncoderHandle, pipelineHandle)`: Sets the `GPUComputePipeline`.
        *   `js_set_bind_group_compute(computePassEncoderHandle, groupIndex, bindGroupHandle, ...)`: Sets `GPUBindGroup`(s) for compute.
        *   `js_dispatch_workgroups(computePassEncoderHandle, x, y, z)`: Dispatches compute work.
        *   `js_end_compute_pass(computePassEncoderHandle)`: Ends the compute pass.
    *   `js_copy_buffer_to_buffer(...)` can be used within a command encoder to copy data between GPU buffers.
    *   `js_finish_command_encoder(commandEncoderHandle)`: JS finalizes the command recording, creating a `GPUCommandBuffer`. Returns its handle.
    *   `js_submit_commands(deviceHandle, commandBufferHandle)`: JS submits the command buffer to the device queue for execution.

## Reading Data Back from GPU (Not Explicitly Detailed but Implied)

While the provided code focuses on sending data to the GPU and rendering/compute, reading data back (e.g., for debugging, advanced simulations) would typically involve:

1.  A `GPUBuffer` created with `usage` flags including `GPUBufferUsage.COPY_DST` and `GPUBufferUsage.MAP_READ`.
2.  A command to copy data from the source GPU buffer (e.g., a storage buffer used in a compute shader) to this "staging" buffer using `encoder.copyBufferToBuffer()`. This would be an FFI call like `js_copy_buffer_to_buffer`.
3.  After submitting the command buffer and ensuring its completion (potentially via `device.queue.onSubmittedWorkDone()` or by waiting a few frames), the staging buffer can be mapped for reading.
    *   JS FFI function like `js_map_buffer_for_reading(bufferHandle, offset, size)`. This would call `buffer.mapAsync(GPUMapMode.READ, offset, size)`.
    *   A callback to Zig (`zig_receive_mapped_buffer_data_or_signal`) once the promise resolves.
4.  Inside the callback, or after being signaled, Zig would call another FFI function, say `js_get_mapped_buffer_range(bufferHandle, offset, size)`, which in JS would call `buffer.getMappedRange(offset, size)`.
5.  This `ArrayBuffer` from `getMappedRange` needs to be copied into Wasm memory. This could be done by:
    *   JS creating a `Uint8Array` view of the `ArrayBuffer`.
    *   Zig allocating space in its memory and passing a pointer and length to a JS FFI function like `js_read_mapped_data_into_wasm(srcArrayBufferView, wasmDestPtr, length)`.
    *   JS then copies the data into the Wasm heap using `new Uint8Array(wasmInstance.exports.memory.buffer, wasmDestPtr, length).set(srcArrayBufferView)`.
6.  Finally, JS would call `buffer.unmap()`. An FFI function `js_unmap_buffer(bufferHandle)` would be needed.

This readback mechanism is more complex due to asynchronicity and memory ownership.

## Proposed Separation for a Zig WebGPU Library

To create a reusable Zig WebGPU binding library and a separate renderer:

**1. Zig WebGPU FFI Library (`webgpu_ffi.zig` or similar):**

*   **Purpose:** Provide low-level, direct, and mostly stateless bindings to the JavaScript WebGPU functions.
*   **Contents:**
    *   All `Gpu*Handle` type definitions from [`archive/wasm-particles/src/webgpu_core.zig`](../../archive/wasm-particles/src/webgpu_core.zig).
    *   All `enum` definitions (like `GpuCanvasFormatId`, `BufferPurposeId`, `GpuBufferUsage`, `ShaderEntryPointId`, `PrimitiveTopologyId`, `BlendModeId`, etc.) from [`archive/wasm-particles/src/webgpu_core.zig`](../../archive/wasm-particles/src/webgpu_core.zig). These enums help make the API type-safe and expressive on the Zig side, even if they are translated to simple `u32` or strings on the JS side.
    *   All `extern fn` declarations currently in [`archive/wasm-particles/src/webgpu_js_api.zig`](../../archive/wasm-particles/src/webgpu_js_api.zig). These are the raw calls to JavaScript.
    *   Structs for data exchange if they are fundamental to the FFI calls (e.g., `BindGroupEntryForJs`).
*   **Responsibilities:**
    *   Define the contract with JavaScript.
    *   Pass data (pointers, lengths, handles, primitive values) to JS.
    *   Declare the callback functions that JS will invoke.
*   **No State:** This library itself should not hold GPU state (like the current device handle or canvas format). It just defines *how* to talk to JS.

**2. Zig WebGPU Abstraction Layer (Optional but Recommended, e.g., `webgpu.zig`):**

*   **Purpose:** Provide a more idiomatic and safer Zig API on top of the raw FFI.
*   **Contents:**
    *   Wrapper functions around the `extern fn`s. These wrappers can:
        *   Handle basic error checking (e.g., if a returned handle is `InvalidGpuHandle`).
        *   Convert Zig strings to `[*c]const u8` and `usize` for FFI calls.
        *   Potentially manage some lightweight state or provide convenience functions if carefully designed (though heavy state management belongs in the application/renderer).
        *   Encapsulate patterns like `request_adapter -> receive_adapter_callback`. This could be done using Zig's `async/await` if targeting environments where event loops can be integrated, or by providing functions that take callback functions as parameters.
*   **Example:**
    ```zig
    // In webgpu.zig
    const ffi = @import("webgpu_ffi.zig");
    const std = @import("std");

    pub fn requestAdapter() !void { // Or returns a future
        ffi.js_initiate_adapter_request();
        // Application will need to implement the callback
    }

    pub fn createBuffer(device: ffi.GpuDeviceHandle, desc: BufferDescriptor) !void { // or returns handle via callback
        // BufferDescriptor would be a Zig struct
        // Convert desc to parameters for ffi.js_create_gpu_buffer
        ffi.js_create_gpu_buffer(device, @intFromEnum(desc.purpose), desc.size, desc.usage.toInt());
    }
    ```

**3. JavaScript FFI Implementation (largely existing JS files):**

*   [`archive/wasm-particles/web/js/config.js`](../../archive/wasm-particles/web/js/config.js): Essential for handle management.
*   [`archive/wasm-particles/web/js/webgpu_setup.js`](../../archive/wasm-particles/web/js/webgpu_setup.js), [`archive/wasm-particles/web/js/webgpu_pipelines_and_bindings.js`](../../archive/wasm-particles/web/js/webgpu_pipelines_and_bindings.js), [`archive/wasm-particles/web/js/webgpu_commands_and_passes.js`](../../archive/wasm-particles/web/js/webgpu_commands_and_passes.js): These files contain the actual WebGPU calls. They would be part of the "JS side" of the library.
*   **Key for Reusability:**
    *   Ensure these JS functions are generic and rely only on the parameters passed from Zig (handles, data pointers, enums/IDs).
    *   Avoid hardcoding application-specific logic (e.g., specific shader entry points or bind group layouts if they can be fully specified from Zig). The current implementation sometimes uses `purposeId` to switch internal JS logic, which is a reasonable approach for an FFI.

**4. Zig Application/Renderer (e.g., `my_renderer.zig`):**

*   **Purpose:** Use the `webgpu_ffi.zig` (or the `webgpu.zig` abstraction) to implement rendering logic.
*   **Contents:**
    *   The `GpuContext` currently in [`archive/wasm-particles/src/gpu_context.zig`](../../archive/wasm-particles/src/gpu_context.zig) would live here or be managed by the application. It stores the adapter, device, canvas context handles, etc.
    *   The callback functions currently in [`archive/wasm-particles/src/webgpu_callbacks.zig`](../../archive/wasm-particles/src/webgpu_callbacks.zig) would be implemented by the application, as they handle application-specific responses to GPU events. The FFI library would declare them, and the application would define them.
    *   Logic for creating specific buffers, shaders, pipelines, and bind groups for the application's needs.
    *   The render loop logic, command encoding, and submission.
    *   All WGSL shaders would remain part of the application/renderer.

## List of JS WebGPU Functions and Binding to Zig

Below is a list of the key JavaScript functions exported to Zig, how they work, and considerations for their bindings. These are found across `webgpu_setup.js`, `webgpu_pipelines_and_bindings.js`, and `webgpu_commands_and_passes.js`.

The Zig `extern fn` declarations are in [`archive/wasm-particles/src/webgpu_js_api.zig`](../../archive/wasm-particles/src/webgpu_js_api.zig).
The Zig callback implementations (called *by* JS) are in [`archive/wasm-particles/src/webgpu_callbacks.zig`](../../archive/wasm-particles/src/webgpu_callbacks.zig).

---

**Handles:** All `*Handle` types in Zig are `u32`. In JS, these are indices into the `gpuObjects` array in `config.js`. `0` is an invalid handle.

---

### Setup and Initialization

1.  **`js_initiate_adapter_request()`**
    *   **JS:** Calls `navigator.gpu.requestAdapter()`. On success, stores `GPUAdapter`, calls `wasmInstance.exports.zig_receive_adapter_handle(handle)`. On failure, calls with `0`.
    *   **Zig `extern`:** `pub extern fn js_initiate_adapter_request() void;`
    *   **Zig Callback:** `pub fn zig_receive_adapter_handle(adapter_handle: GpuAdapterHandle) void`

2.  **`js_initiate_device_request(adapterHandle)`**
    *   **JS:** Gets `GPUAdapter` via `adapterHandle`. Calls `adapter.requestDevice()`. On success, stores `GPUDevice`, calls `wasmInstance.exports.zig_receive_device_handle(handle)`. On failure, calls with `0`. Also sets up `device.lost` promise.
    *   **Zig `extern`:** `pub extern fn js_initiate_device_request(adapter_handle: GpuAdapterHandle) void;`
    *   **Zig Callback:** `pub fn zig_receive_device_handle(device_handle: GpuDeviceHandle) void`

3.  **`js_get_preferred_canvas_format()`**
    *   **JS:** Calls `navigator.gpu.getPreferredCanvasFormat()`. Maps known format strings ("bgra8unorm", "rgba8unorm") to integer IDs. Calls `wasmInstance.exports.zig_receive_preferred_canvas_format(formatId)`.
    *   **Zig `extern`:** `pub extern fn js_get_preferred_canvas_format() void;`
    *   **Zig Callback:** `pub fn zig_receive_preferred_canvas_format(format_id: GpuCanvasFormatId) void` (Zig receives an enum value)

4.  **`js_configure_canvas(deviceHandle, canvasIdStringPtr, canvasIdStringLen, formatId, alphaModeId)`**
    *   **JS:** Gets `GPUDevice` via `deviceHandle`. Gets canvas element (currently hardcoded ID "zigCanvas", `canvasIdStringPtr` ignored). Gets `GPUCanvasContext`. Configures it using `formatId` (mapped back to string) and `alphaModeId` (mapped to string e.g. "opaque", "premultiplied"). Stores context, calls `wasmInstance.exports.zig_receive_canvas_context_handle(contextHandle)`.
    *   **Zig `extern`:** `pub extern fn js_configure_canvas(device_handle: GpuDeviceHandle, canvas_id_ptr: [*c]const u8, canvas_id_len: usize, format_id: GpuCanvasFormatId, alpha_mode: GpuCanvasAlphaMode) void;`
        *   *Note:* `canvas_id_ptr` and `len` could be used in JS to dynamically find the canvas.
    *   **Zig Callback:** `pub fn zig_receive_canvas_context_handle(context_handle: GpuCanvasContextHandle) void`

---

### Buffer Operations

5.  **`js_create_gpu_buffer(deviceHandle, bufferPurposeId, sizeInBytes, usageFlags)`**
    *   **JS:** Gets `GPUDevice`. Calls `device.createBuffer({ size: sizeInBytes, usage: usageFlags })`. `usageFlags` is a `u32` bitmask directly corresponding to WebGPU `GPUBufferUsage` flags. `bufferPurposeId` is for Zig's internal tracking/debugging, not directly used by `createBuffer` but passed back with the handle. Stores `GPUBuffer`, calls `wasmInstance.exports.zig_receive_gpu_buffer_handle(bufferPurposeId, handle)`.
    *   **Zig `extern`:** `pub extern fn js_create_gpu_buffer(device_handle: GpuDeviceHandle, buffer_purpose_id: u32, size_in_bytes: u32, usage_flags: GpuBufferUsageFlags) void;`
    *   **Zig Callback:** `pub fn zig_receive_gpu_buffer_handle(buffer_purpose_id: u32, buffer_handle: GpuBufferHandle) void`

6.  **`js_write_gpu_buffer(bufferHandle, destinationOffsetBytes, dataPtr, dataLenBytes)`**
    *   **JS:** Gets `GPUBuffer` (target) and `GPUDevice` (currently hardcoded handle `2` for its queue). Reads data from Wasm memory (`wasmInstance.exports.memory.buffer` at `dataPtr` for `dataLenBytes`) into a new `Uint8Array`, then `.slice()` it to make a copy. Calls `device.queue.writeBuffer(buffer, destinationOffsetBytes, copiedData)`. No callback to Zig.
    *   **Zig `extern`:** `pub extern fn js_write_gpu_buffer(buffer_handle: GpuBufferHandle, destination_offset_bytes: u32, data_ptr: [*c]const u8, data_len_bytes: u32) void;`

---

### Shader Operations

7.  **`js_create_shader_module(deviceHandle, purposeId, codePtr, codeLen)`**
    *   **JS:** Gets `GPUDevice`. Reads WGSL code from Wasm memory (`codePtr`, `codeLen`) using `TextDecoder`. Calls `device.createShaderModule({ code: wgslCode })`. `purposeId` is for Zig's tracking. Stores `GPUShaderModule`, calls `wasmInstance.exports.zig_receive_shader_module_handle(purposeId, handle)`.
    *   **Zig `extern`:** `pub extern fn js_create_shader_module(device_handle: GpuDeviceHandle, purpose_id: u32, code_ptr: [*c]const u8, code_len: u32) void;`
    *   **Zig Callback:** `pub fn zig_receive_shader_module_handle(purpose_id: u32, shader_module_handle: GpuShaderModuleHandle) void`

---

### Pipeline Operations

8.  **`js_create_render_pipeline(deviceHandle, purposeId, shaderModuleHandle, vertexEntryPointId, fragmentEntryPointId, topologyId, blendModeId)`**
    *   **JS:** Gets `GPUDevice`, `GPUShaderModule`.
        *   `purposeId`: Used to select pre-defined bind group layouts in JS (e.g., camera, particle data for this project). A more general FFI might pass layout descriptions from Zig.
        *   `vertexEntryPointId`, `fragmentEntryPointId`: Mapped to WGSL entry point strings (e.g., "vs_main", "fs_main") via `getShaderEntryPointString` utility.
        *   `topologyId`: Mapped to `GPUPrimitiveTopology` string (e.g., "triangle-list").
        *   `blendModeId`: Mapped to `GPUBlendState` object or `undefined` for opaque.
        *   Canvas format is retrieved from `gpuObjects.canvasFormat` (set during canvas configuration).
        *   Creates `GPUPipelineLayout` (based on `purposeId`), then `device.createRenderPipeline()`.
        *   Stores `GPURenderPipeline`, calls `wasmInstance.exports.zig_receive_render_pipeline_handle(purposeId, handle)`.
    *   **Zig `extern`:** `pub extern fn js_create_render_pipeline(device_handle: GpuDeviceHandle, purpose_id: u32, shader_module_handle: GpuShaderModuleHandle, vertex_entry_point_id: u32, fragment_entry_point_id: u32, topology_id: u32, blend_mode_id: u32) void;`
    *   **Zig Callback:** `pub fn zig_receive_render_pipeline_handle(pipeline_purpose_id: u32, pipeline_handle: GpuRenderPipelineHandle) void`

9.  **`js_create_compute_pipeline(deviceHandle, purposeId, shaderModuleHandle, entryPointId)`**
    *   **JS:** Gets `GPUDevice`, `GPUShaderModule`.
        *   `purposeId`: Used to select pre-defined bind group layouts in JS for specific compute shaders (e.g., particle update, binning, prefix sum).
        *   `entryPointId`: Mapped to WGSL entry point string.
        *   Creates `GPUPipelineLayout` (based on `purposeId`), then `device.createComputePipeline()`.
        *   Stores `GPUComputePipeline`, calls `wasmInstance.exports.zig_receive_compute_pipeline_handle(purposeId, handle)`.
    *   **Zig `extern`:** `pub extern fn js_create_compute_pipeline(device_handle: u32, pipeline_purpose_id: u32, shader_module_handle: u32, entry_point_id: u32) void;`
    *   **Zig Callback:** `pub fn zig_receive_compute_pipeline_handle(pipeline_purpose_id: u32, pipeline_handle: GpuComputePipelineHandle) void`

---

### Bind Group Operations

10. **`js_create_bind_group(deviceHandle, purposeId, pipelineHandle, groupIndex, bindingsPtr, bindingsLen)`**
    *   **JS:** Gets `GPUDevice`, `GPUPipeline` (render or compute, type doesn't matter for `getBindGroupLayout`).
        *   `purposeId`: For Zig's tracking/debugging.
        *   Reads an array of `BindGroupEntryForJs` structs from Wasm memory (`bindingsPtr`, `bindingsLen`). Each struct provides `binding` (number) and `buffer_handle`.
        *   For each entry, gets `GPUBuffer` via `buffer_handle`.
        *   Gets `GPUBindGroupLayout` from `pipeline.getBindGroupLayout(groupIndex)`.
        *   Calls `device.createBindGroup({ layout: bindGroupLayout, entries: [...] })`.
        *   Stores `GPUBindGroup`, calls `wasmInstance.exports.zig_receive_bind_group_handle(purposeId, handle)`.
    *   **Zig `extern`:** `pub extern fn js_create_bind_group(device_handle: GpuDeviceHandle, purpose_id: u32, pipeline_handle: GpuRenderPipelineHandle, group_index: u32, bindings_ptr: [*c]const core.BindGroupEntryForJs, bindings_len: u32) void;`
        *   *Note:* `pipeline_handle` is typed as `GpuRenderPipelineHandle` but JS can use it for compute pipelines too if `getBindGroupLayout` is the only method used. A `GpuPipelineLayoutHandle` might be more generic if layouts are created separately.
    *   **Zig Callback:** `pub fn zig_receive_bind_group_handle(bg_purpose_id: u32, bg_handle: GpuBindGroupHandle) void`

---

### Command Encoding & Submission

11. **`js_create_command_encoder(deviceHandle)`**
    *   **JS:** Gets `GPUDevice`. Calls `device.createCommandEncoder()`. Stores `GPUCommandEncoder`, calls `wasmInstance.exports.zig_receive_command_encoder_handle(handle)`.
    *   **Zig `extern`:** `pub extern fn js_create_command_encoder(device_handle: GpuDeviceHandle) void;`
    *   **Zig Callback:** `pub fn zig_receive_command_encoder_handle(encoder_handle: GpuCommandEncoderHandle) void`

12. **`js_get_current_texture_view(canvasContextHandle)`**
    *   **JS:** Gets `GPUCanvasContext`. Calls `context.getCurrentTexture().createView()`. Stores `GPUTextureView`, calls `wasmInstance.exports.zig_receive_current_texture_view_handle(handle)`.
    *   **Zig `extern`:** `pub extern fn js_get_current_texture_view(canvas_context_handle: GpuCanvasContextHandle) void;`
    *   **Zig Callback:** `pub fn zig_receive_current_texture_view_handle(view_handle: GpuTextureViewHandle) void`

13. **`js_begin_render_pass(commandEncoderHandle, textureViewHandle, r, g, b, a)`**
    *   **JS:** Gets `GPUCommandEncoder`, `GPUTextureView`. Calls `encoder.beginRenderPass({ colorAttachments: [{ view, clearValue, loadOp:'clear', storeOp:'store' }] })`. Stores `GPURenderPassEncoder`, calls `wasmInstance.exports.zig_receive_render_pass_encoder_handle(handle)`.
    *   **Zig `extern`:** `pub extern fn js_begin_render_pass(command_encoder_handle: GpuCommandEncoderHandle, texture_view_handle: GpuTextureViewHandle, r: f32, g: f32, b: f32, a: f32) void;`
    *   **Zig Callback:** `pub fn zig_receive_render_pass_encoder_handle(rpe_handle: GpuRenderPassEncoderHandle) void`

14. **`js_set_pipeline(renderPassEncoderHandle, pipelineHandle)`**
    *   **JS:** Gets `GPURenderPassEncoder`, `GPURenderPipeline`. Calls `passEncoder.setPipeline(pipeline)`.
    *   **Zig `extern`:** `pub extern fn js_set_pipeline(render_pass_encoder_handle: GpuRenderPassEncoderHandle, pipeline_handle: GpuRenderPipelineHandle) void;`

15. **`js_set_bind_group(renderPassEncoderHandle, groupIndex, bindGroupHandle)`**
    *   **JS:** Gets `GPURenderPassEncoder`, `GPUBindGroup`. Calls `passEncoder.setBindGroup(groupIndex, bindGroup)`.
    *   **Zig `extern`:** `pub extern fn js_set_bind_group(render_pass_encoder_handle: GpuRenderPassEncoderHandle, group_index: u32, bind_group_handle: GpuBindGroupHandle) void;`

16. **`js_draw(renderPassEncoderHandle, vertexCount, instanceCount, firstVertex, firstInstance)`**
    *   **JS:** Gets `GPURenderPassEncoder`. Calls `passEncoder.draw(vertexCount, instanceCount, firstVertex, firstInstance)`.
    *   **Zig `extern`:** `pub extern fn js_draw(render_pass_encoder_handle: GpuRenderPassEncoderHandle, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void;`

17. **`js_end_render_pass(renderPassEncoderHandle)`**
    *   **JS:** Gets `GPURenderPassEncoder`. Calls `passEncoder.end()`.
    *   **Zig `extern`:** `pub extern fn js_end_render_pass(render_pass_encoder_handle: GpuRenderPassEncoderHandle) void;`

18. **`js_begin_compute_pass(commandEncoderHandle)`**
    *   **JS:** Gets `GPUCommandEncoder`. Calls `encoder.beginComputePass()`. Stores `GPUComputePassEncoder`. **Directly returns handle to Zig.**
    *   **Zig `extern`:** `pub extern fn js_begin_compute_pass(command_encoder_handle: GpuCommandEncoderHandle) GpuComputePassEncoderHandle;`
        *   *Note:* This is synchronous unlike others that use callbacks. If `addObject` could fail (e.g. out of memory for JS array), this pattern is risky. For simple handle generation, it's okay.

19. **`js_set_pipeline_compute(computePassEncoderHandle, pipelineHandle)`**
    *   **JS:** Gets `GPUComputePassEncoder`, `GPUComputePipeline`. Calls `passEncoder.setPipeline(pipeline)`.
    *   **Zig `extern`:** `pub extern fn js_set_pipeline_compute(compute_pass_encoder_handle: GpuComputePassEncoderHandle, pipeline_handle: GpuComputePipelineHandle) void;`

20. **`js_set_bind_group_compute(computePassEncoderHandle, groupIndex, bindGroupHandle, dynamicOffsetsPtr, dynamicOffsetsLen)`**
    *   **JS:** Gets `GPUComputePassEncoder`, `GPUBindGroup`. If `dynamicOffsetsPtr` is valid and `len > 0`, it should read these (currently logs "not fully implemented"). Calls `passEncoder.setBindGroup(groupIndex, bindGroup, dynamicOffsetsArrayIfProvided)`.
    *   **Zig `extern`:** `pub extern fn js_set_bind_group_compute(compute_pass_encoder_handle: GpuComputePassEncoderHandle, group_index: u32, bind_group_handle: GpuBindGroupHandle, dynamic_offsets_ptr: [*c]const u32, dynamic_offsets_len: u32) void;`

21. **`js_dispatch_workgroups(computePassEncoderHandle, x, y, z)`**
    *   **JS:** Gets `GPUComputePassEncoder`. Calls `passEncoder.dispatchWorkgroups(x, y, z)`.
    *   **Zig `extern`:** `pub extern fn js_dispatch_workgroups(compute_pass_encoder_handle: GpuComputePassEncoderHandle, x: u32, y: u32, z: u32) void;`

22. **`js_end_compute_pass(computePassEncoderHandle)`**
    *   **JS:** Gets `GPUComputePassEncoder`. Calls `passEncoder.end()`.
    *   **Zig `extern`:** `pub extern fn js_end_compute_pass(compute_pass_encoder_handle: GpuComputePassEncoderHandle) void;`

23. **`js_copy_buffer_to_buffer(commandEncoderHandle, sourceBufferHandle, sourceOffset, destinationBufferHandle, destinationOffset, copySize)`**
    *   **JS:** Gets `GPUCommandEncoder`, source `GPUBuffer`, destination `GPUBuffer`. Calls `encoder.copyBufferToBuffer(sourceBuffer, sourceOffset, destinationBuffer, destinationOffset, copySize)`. Offsets and size are `u64` from Zig, passed as `Number` to JS.
    *   **Zig `extern`:** `pub extern fn js_copy_buffer_to_buffer(command_encoder_handle: GpuCommandEncoderHandle, source_buffer_handle: GpuBufferHandle, source_offset: u64, destination_buffer_handle: GpuBufferHandle, destination_offset: u64, copy_size: u64) void;`

24. **`js_finish_command_encoder(commandEncoderHandle)`**
    *   **JS:** Gets `GPUCommandEncoder`. Calls `encoder.finish()`. Stores `GPUCommandBuffer`, calls `wasmInstance.exports.zig_receive_command_buffer_handle(handle)`.
    *   **Zig `extern`:** `pub extern fn js_finish_command_encoder(command_encoder_handle: GpuCommandEncoderHandle) void;`
    *   **Zig Callback:** `pub fn zig_receive_command_buffer_handle(buffer_handle: GpuCommandBufferHandle) void`

25. **`js_submit_commands(deviceHandle, commandBufferHandle)`**
    *   **JS:** Gets `GPUDevice`, `GPUCommandBuffer`. Calls `device.queue.submit([commandBuffer])`.
    *   **Zig `extern`:** `pub extern fn js_submit_commands(device_handle: GpuDeviceHandle, command_buffer_handle: GpuCommandBufferHandle) void;`

---

This list covers the primary WebGPU interactions. The separation proposal aims to make these FFI calls the "thin layer" of a dedicated Zig WebGPU library, allowing a separate Zig application/renderer to use them without being tightly coupled to the specific JS implementation details beyond this defined FFI contract.
The JavaScript side of the FFI would consist of these functions, organized into modules as they are now, and the `config.js` for handle management.
The Zig library would define the `extern fn`s, the `Gpu*Handle` types, enums, and necessary data structures for FFI calls (like `BindGroupEntryForJs`).
The Zig application would then use this library, implement the `zig_receive_*` callbacks, and manage its own `GpuContext` and rendering/compute logic.

</rewritten_file>
