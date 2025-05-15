# WebGPU FFI Development and Particle Simulator Refactor Plan

This document outlines the plan to develop the `zig-wasm-ffi` WebGPU bindings, refactor the particle simulator to use these bindings, and lay the groundwork for a reusable WebGPU rendering engine. This plan considers the existing `particle_sim.html`, `docs/old_proj_webgpu_imp.md`, current `src/webgpu.zig` and `src/js/webgpu.js`, and the goals outlined in `README.MD` and `ROADMAP.MD`.

## Phase 1: Solidify Core WebGPU FFI Library (`zig-wasm-ffi.webgpu`)

**Goal:** Create a comprehensive, low-level Zig FFI for WebGPU, enabling a wide range of WebGPU operations from Zig. This phase focuses on `src/webgpu.zig` and `src/js/webgpu.js`.

**Guiding Principles:**
*   **Async Operations:** Utilize a **JS-to-Zig callback mechanism** for all asynchronous WebGPU operations. Zig FFI functions will initiate the operation, and exported Zig functions (implemented by the application) will receive the results (handles or errors) asynchronously. This approach is chosen to minimize JS/WASM boundary crossings for performance. Existing async functions using polling (e.g., for adapter/device requests) will be refactored to this callback pattern.
*   Refer to `docs/old_proj_webgpu_imp.md` for a comprehensive list of WebGPU APIs to bind, adapting its FFI structure to the chosen callback model.
*   Ensure `js/webgpu.js` remains a thin JavaScript shim directly interacting with browser WebGPU APIs, managing handles and invoking Zig callbacks.
*   `webgpu.zig` will provide Zig types, extern declarations for JS functions, and declarations for the exported Zig callback functions. Wrapper functions in `webgpu.zig` will initiate the JS calls.

**Steps:**

1.  **Expand Handle Definitions (`src/webgpu.zig`):**
    *   Define all necessary `u32` opaque handles for WebGPU objects (e.g., `Adapter`, `Device`, `Queue`, `Buffer`, `Texture`, `TextureView`, `Sampler`, `ShaderModule`, `BindGroupLayout`, `PipelineLayout`, `RenderPipeline`, `ComputePipeline`, `BindGroup`, `CommandEncoder`, `CommandBuffer`, `RenderPassEncoder`, `ComputePassEncoder`, `QuerySet`).
    *   Ensure `HandleType` enum includes all these for `releaseHandle`.

2.  **Define Descriptor Structs (`src/webgpu.zig`):**
    *   Create `extern struct` or `struct` definitions for all WebGPU descriptor objects (e.g., `BufferDescriptor`, `TextureDescriptor`, `ShaderModuleDescriptor`, `BindGroupLayoutDescriptor`, `PipelineLayoutDescriptor`, `RenderPipelineDescriptor`, `ComputePipelineDescriptor`, `BindGroupDescriptor`, `ColorTargetState`, `RenderPassDescriptor`, etc.).
    *   These structs should align with the WebGPU specification and the data structures used in `particle_sim.html`. They will be passed by pointer to JS.

3.  **Implement JS FFI Functions (`src/js/webgpu.js`):**
    *   Systematically implement JavaScript functions for each WebGPU operation listed in `docs/old_proj_webgpu_imp.md` (under "List of JS WebGPU Functions...").
    *   **Initialization:** Adapter, Device, Queue (largely existing, verify completeness).
    *   **Resource Creation:** `createBuffer`, `createTexture`, `textureCreateView`, `createSampler` (if needed), `createShaderModule`.
    *   **Pipeline Creation:** `createBindGroupLayout`, `createPipelineLayout`, `createRenderPipelineAsync`, `createComputePipelineAsync`. These async operations should return `promise_id`.
    *   **Bind Group Creation:** `createBindGroup`.
    *   **Command Encoding:** `createCommandEncoder`, `beginRenderPass`, `beginComputePass`, methods for render/compute pass encoders (`setPipeline`, `setBindGroup`, `setVertexBuffer`, `setIndexBuffer`, `draw`, `drawIndexed`, `dispatchWorkgroups`, `end`).
    *   **Command Buffer:** `commandEncoderFinish` (should probably be `commandEncoderFinishAsync` or handle commands that might take time, though spec says it's sync).
    *   **Queue Operations:** `queueSubmit`, `queueWriteBuffer`, `queueWriteTexture`.
    *   **Handle Management:** Robustly use `store<Object>`, `getObject`, and ensure `releaseHandle` cleans up JS-side objects.
    *   **Error Handling:** Consistently use `globalWebGPU.error` and the `get_last_error_msg` mechanism.

4.  **Implement Zig Externs and Wrappers (`src/webgpu.zig`):**
    *   For each JS function, declare the corresponding `extern "env" fn` in `src/webgpu.zig`.
    *   Write thin Zig wrapper functions that:
        *   Accept Zig-idiomatic parameters (e.g., slices, Zig structs).
        *   Marshal data (e.g., convert Zig strings to `[*c]const u8`, pass struct pointers).
        *   Call the `extern` JS functions to initiate the WebGPU operation.
    *   Declare `pub export fn` signatures for the Zig callbacks that JS will invoke (e.g., `zig_receive_adapter(handle: Adapter, status: u32) void`). The implementation of these callbacks will reside in the application using the FFI.
    *   Propagate errors using `!` and error sets where appropriate for synchronous parts of FFI calls, or rely on status codes in callbacks for asynchronous operations.

5.  **Testing (Basic):**
    *   Create minimal tests (or a small standalone example) that initialize WebGPU, create a buffer, and write to it to verify the core FFI is working.

## Phase 2: Develop Particle Simulator Demo

**Goal:** Replicate the functionality of `demos/particle_simulator/particle_sim.html` as a Zig application using the `zig-wasm-ffi.webgpu` library.

**Steps:**

1.  **Project Setup (largely as per `docs/webgpu_init_plan.md`):**
    *   **Directory Structure:**
        *   `demos/particle_simulator/src/main.zig` (main application logic)
        *   `demos/particle_simulator/src/simulation.zig` (particle state, physics logic if on CPU)
        *   `demos/particle_simulator/src/webgpu_engine/webgpu_handler.zig` (uses FFI for init, stores handles)
        *   `demos/particle_simulator/src/webgpu_engine/renderer.zig` (all WebGPU calls via FFI for rendering and compute)
        *   `demos/particle_simulator/shaders/` (WGSL files)
        *   `demos/particle_simulator/web/index.html`
        *   `demos/particle_simulator/web/main.js` (WASM loader, main loop, UI event forwarding)
    *   Update `build.zig` for the demo to link `zig-wasm-ffi` and include `js/webgpu.js`.

2.  **Implement `webgpu_handler.zig`:**
    *   Use the FFI's `requestAdapter`, `adapterRequestDevice`, `deviceGetQueue`.
    *   Store and provide access to the `Adapter`, `Device`, `Queue` handles. (Current version is a good start).

3.  **Port Shaders:**
    *   Extract all WGSL shaders from `particle_sim.html` into individual `.wgsl` files in `demos/particle_simulator/shaders/`.
    *   Embed these shaders into `renderer.zig` using `comptime` string literals or `@embedFile`.

4.  **Implement `renderer.zig`:**
    *   **Initialization:** Get device/queue from `webgpu_handler`.
    *   **Resource Management:** Create all necessary GPU resources (buffers for particles, species, forces, uniforms, binning; textures for HDR, blue noise) using the FFI. Refer to `particle_sim.html` for resource specifications. Manage ping-pong buffers.
    *   **Shader Modules:** Create `ShaderModule`s for all shaders using the FFI.
    *   **Pipeline Creation:** Recreate all compute and render pipelines from `particle_sim.html` using the FFI. This involves creating layouts, and then the pipelines themselves. This is a significant part.
    *   **Bind Groups:** Create all necessary `BindGroup`s using the FFI.
    *   **Render Loop (`renderFrame` function):**
        *   Update uniform buffers (camera, simulation options) via `queueWriteBuffer`.
        *   Create `CommandEncoder`.
        *   Encode all compute passes (binning, prefix sum, sort, forces, advance) as in `particle_sim.html`.
        *   Encode render pass for particles to HDR texture.
        *   Encode render pass for composing HDR to screen.
        *   `commandEncoderFinish` and `queueSubmit`.

5.  **Implement `simulation.zig` and `main.zig`:**
    *   `simulation.zig`: Manage particle data (structs, arrays), simulation parameters.
    *   `main.zig`: Initialize `webgpu_handler` and `renderer`. Implement the main application loop which:
        *   Updates simulation state (calling `simulation.zig`).
        *   Calls `renderer.renderFrame()`.
        *   Exports functions for JS to call (e.g., `init`, `update_frame`).

6.  **Update HTML/JS Frontend (`demos/particle_simulator/web/`):**
    *   `index.html`: Minimal HTML structure with a canvas.
    *   `main.js`:
        *   Load and instantiate `app.wasm`, providing `env` with `js/webgpu.js` functions and `wasmMemory`.
        *   Call exported Zig `init` function.
        *   Set up `requestAnimationFrame` to call exported Zig `update_frame`.
        *   Handle UI controls (sliders, buttons from `particle_sim.html`) by calling exported Zig functions to update parameters.
        *   Handle canvas setup and resizing.

## Phase 3: Refactor into Reusable WebGPU Engine Components

**Goal:** Abstract common WebGPU patterns and functionalities from the particle simulator's `webgpu_engine` into a more generic, reusable foundation for other freestanding Zig WASM projects. The engine components will reside in `demos/particle_simulator/src/webgpu_engine/` for now, but designed for broader applicability.

**Steps:**

1.  **Identify Core Engine Services:**
    *   From `webgpu_handler.zig`: Device/adapter/queue management.
    *   From `renderer.zig`:
        *   Abstracted resource creation (buffers, textures with common configurations).
        *   Shader management (loading, module creation).
        *   Pipeline creation helpers (perhaps taking simplified descriptors).
        *   Render pass and compute pass execution helpers.
        *   Command buffer management and submission.

2.  **Design Engine API:**
    *   Define a higher-level API that simplifies common WebGPU tasks.
    *   The engine should encapsulate some of the direct FFI complexity.
    *   Consider structures for managing resources created by the engine.

3.  **Refactor `renderer.zig` and `webgpu_handler.zig`:**
    *   Separate generic logic from particle-simulator-specific logic.
    *   The generic parts become the "engine" components.
    *   The particle simulator's `renderer.zig` would then use this engine API.

4.  **Iterate and Expand:**
    *   Initially, the engine might be a thin layer. Over time, it can grow more sophisticated features as needed by new projects (e.g., material systems, scene graphs, if aiming for a full 3D engine, but start simpler for 2D/compute focused tasks).

## Prerequisites & Questions Before Starting Deep Implementation:

1.  **Async Pattern Confirmation:**
    *   ~~The current FFI (`src/webgpu.zig`, `src/js/webgpu.js`) uses a promise ID/polling mechanism for async operations (e.g., `env_wgpu_request_adapter_async_js` -> `env_wgpu_poll_promise_js`).~~
    *   ~~`docs/old_proj_webgpu_imp.md` often implies a callback system (e.g., `zig_receive_adapter_handle`).~~
    *   **Decision:** The **JS-to-Zig callback mechanism** is the standard going forward for all asynchronous WebGPU operations. Zig FFI functions will initiate the operation, and exported Zig functions (implemented by the application) will receive results/errors. The FFI function list from `docs/old_proj_webgpu_imp.md` will be adapted to this model. Existing FFI functions for adapter/device request will be refactored to this pattern.

2.  **File Structure & Creation:**
    *   Are you okay with me proceeding based on the directory structure outlined for the demo (e.g., `demos/particle_simulator/src/main.zig`, `shaders/` dir)? I will not create files unless the plan explicitly says to for a step.
    *   Is `src/js/webgpu.js` the canonical JS glue file for the `zig-wasm-ffi.webgpu` module? (Assumed yes).

3.  **Zig Descriptor Structs:**
    *   The detailed structure of Zig structs for WebGPU descriptors needs to be defined in `src/webgpu.zig`. These will be based on the WebGPU spec and the needs demonstrated by `particle_sim.html`.
    *   **Action:** This will be a key part of FFI implementation in Phase 1.

4.  **Scope of Initial FFI Coverage:**
    *   Given the particle simulator's needs, prioritize FFI functions related to:
        *   Initialization (Adapter, Device, Queue)
        *   Buffer creation and writing (`createBuffer`, `queueWriteBuffer`)
        *   Shader module creation (`createShaderModule`)
        *   Pipeline creation (Compute & Render, including layouts: `createBindGroupLayout`, `createPipelineLayout`, `createComputePipelineAsync`, `createRenderPipelineAsync`)
        *   Bind Group creation (`createBindGroup`)
        *   Command encoding for compute and render passes (`createCommandEncoder`, `beginComputePass`, `beginRenderPass`, `setPipeline`, `setBindGroup`, `dispatchWorkgroups`, `draw`, `end` for passes)
        *   Command submission (`finish`, `submit`)
        *   Texture creation and views (`createTexture`, `textureCreateView`)
    *   **Specific Features:**
        *   **Timestamp Queries:** `particle_sim.html` uses them, and `docs/webgpu_init_plan.md` mentions them. The FFI will support creating `GPUQuerySet` and resolving queries if the adapter supports the feature. This includes JS functions for `createQuerySet`, `commandEncoderBegin/EndPipelineStatisticsQuery`, `commandEncoderResolveQuerySet`, and corresponding Zig externs/wrappers. These will be part of the FFI from Phase 1 and utilized in the `renderer.zig` in Phase 2.
        *   **Texture Formats:** The particle simulator uses `rgba16float` for HDR. The FFI for texture creation will be designed to accept various formats (passed as enums or strings from Zig to JS) to ensure flexibility.
    *   ~~Action Needed: Please confirm if timestamp queries and flexible texture format specification are high-priority for the initial FFI implementation.~~ **Decision:** These are confirmed as high-priority for the FFI.

This plan should provide a clear path forward. I'm ready for your feedback on the prerequisites and questions before we dive deeper into implementing these phases.

## PROGRESS (As of last update)

This section tracks the completion status of the items outlined above.

**Phase 1: Solidify Core WebGPU FFI Library (`zig-wasm-ffi.webgpu`)**

*   **Guiding Principles:**
    *   Async Operations (JS-to-Zig callback): **DONE**
*   **Steps:**
    1.  **Expand Handle Definitions (`src/webgpu.zig`):** Mostly **DONE** (sufficient for current needs).
    2.  **Define Descriptor Structs (`src/webgpu.zig`):** Largely **DONE** for `BufferDescriptor`, `ShaderModuleDescriptor`, `TextureDescriptor`, `TextureViewDescriptor`, `BindGroupLayoutDescriptor`, `BindGroupDescriptor`. Others will be added as needed.
    3.  **Implement JS FFI Functions (`src/js/webgpu.js`):**
        *   Initialization (Adapter, Device, Queue): **DONE**
        *   Resource Creation (`createBuffer`, `createTexture`, `textureCreateView`, `createShaderModule`): **DONE**
        *   Pipeline Creation (`createBindGroupLayout`): **DONE**. `createPipelineLayout`, `createRenderPipelineAsync`, `createComputePipelineAsync`: *In Progress (Pipeline Layouts next, then pipelines)*.
        *   Bind Group Creation (`createBindGroup`): **DONE**
        *   Command Encoding: *PENDING*
        *   Command Buffer: *PENDING*
        *   Queue Operations (`queueWriteBuffer`): **DONE**. `queueSubmit`, `queueWriteTexture`: *PENDING*.
        *   Handle Management (`releaseHandle`): **DONE**
        *   Error Handling (`getAndLogWebGPUError`): **DONE**
    4.  **Implement Zig Externs and Wrappers (`src/webgpu.zig`):** Mostly **DONE** for the completed JS functions. Callback declarations **DONE**.
    5.  **Testing (Basic):** Implicitly **DONE** through successful demo bring-up of initialization and resource creation.

**Phase 2: Develop Particle Simulator Demo**

*   **Steps:**
    1.  **Project Setup:**
        *   Directory Structure (for `demos/particle_simulator`): **DONE**
        *   `build.zig` updates: Assumed **DONE** by user for compilation.
    2.  **Implement `webgpu_handler.zig`:** **DONE**
    3.  **Port Shaders:** **DONE** (all WGSL files created, embedded in `renderer.zig`).
    4.  **Implement `renderer.zig`:**
        *   Initialization (get device/queue): **DONE**
        *   Resource Management (Buffers, Textures): **DONE**
        *   Shader Modules: **DONE**
        *   Bind Group Layouts: **DONE**
        *   Bind Groups: **DONE**
        *   Pipeline Creation: *In Progress (Pipelines next)*
        *   Render Loop (`renderFrame` function): *PENDING*
    5.  **Implement `simulation.zig` and `main.zig`:**
        *   `simulation.zig`: *PENDING*
        *   `main.zig`: Basic WebGPU init via `webgpu_handler` and `update_frame` loop exists. `renderer` instantiation and use *PENDING*.
    6.  **Update HTML/JS Frontend (`demos/particle_simulator/web/`):**
        *   `index.html`: Exists.
        *   `main.js`: Wasm loading, basic `init`/`update_frame` calls: **DONE**. UI controls and detailed simulation interaction: *PENDING*.

**Phase 3: Refactor into Reusable WebGPU Engine Components**
*   *PENDING* (To be addressed after the particle simulator demo is functional).
