# WebGPU Binding FFI - Missing Features for Finalization

This document lists features and API parts of the WebGPU specification that are currently missing or incomplete in the `webgpu.zig` (Zig FFI) and `webgpu.js` (JavaScript glue) bindings. This list is based on a review against the WebGPU specification dated May 2025 (Candidate Recommendation Draft) and the existing codebase.

## 1. Core GPU Setup & Management

### 1.1. GPUCanvasContext & Associated Operations (Spec §21)
- **Description:** Enables WebGPU to render to an HTML canvas. This involves getting a `GPUCanvasContext` from a canvas element, configuring it with a `GPUDevice` and desired texture format/usage, and obtaining `GPUTexture`s from it to use as render attachments.
- **`webgpu.zig` Status:**
    - Missing: `GPUCanvasContext` opaque handle or struct.
    - Missing: `GPUCanvasConfiguration` struct.
    - Missing: Enums like `GPUCanvasAlphaMode`, `GPUCanvasToneMappingMode`, `PredefinedColorSpace` (for canvas).
    - Missing: FFI function declarations for `navigator.gpu.getPreferredCanvasFormat()`, `GPUCanvasContext.configure()`, `GPUCanvasContext.unconfigure()`, `GPUCanvasContext.getCurrentTexture()`.
- **`webgpu.js` Status:**
    - Missing: Implementation for `env_gpu_get_preferred_canvas_format_js`.
    - Missing: Implementations for canvas context FFIs (e.g., `env_canvas_context_configure_js`, `env_canvas_context_get_current_texture_js`).
    - The `initWebGPUJs` function does not currently handle canvas integration.

### 1.2. Device Lost Handling (Spec §22.1, §4.4)
- **Description:** Provides `GPUDevice.lost`, a promise that resolves when the `GPUDevice` becomes unavailable (e.g., due to hardware issues or explicit destruction), allowing applications to handle such scenarios gracefully.
- **`webgpu.zig` Status:**
    - Missing: FFI declaration to get the `device.lost` promise or set up a callback.
    - Missing: `GPUDeviceLostInfo` struct (for reason and message).
    - Missing: Zig wrapper to expose this promise/callback.
- **`webgpu.js` Status:**
    - Missing: No logic to handle or expose the `device.lost` promise to Zig. A robust mechanism (callback or promise management) is needed.

### 1.3. Adapter/Device Capabilities Exposure (Spec §3.6, §4.3, §4.4)
- **Description:** Allows querying supported features (`GPUAdapter.features`, `GPUDevice.features`), limits (`GPUAdapter.limits`, `GPUDevice.limits`), adapter metadata (`GPUAdapter.info`), and WGSL language features (`navigator.gpu.wgslLanguageFeatures`).
- **`webgpu.zig` Status:**
    - Partial: `Adapter` and `Device` handles exist.
    - Missing: Structs for `GPUSupportedLimits`, `GPUSupportedFeatures` (beyond basic checks), `GPUAdapterInfo`, `WGSLLanguageFeatures`.
    - Missing: FFI declarations to request this detailed information.
- **`webgpu.js` Status:**
    - `GPUAdapter.features` and `GPUAdapter.limits` are accessible in JS but not systematically passed to or used by Zig for validation or information.
    - Missing: FFI implementations for `GPUAdapterInfo` and `WGSLLanguageFeatures`.

### 1.4. Error Handling - Scopes (Spec §22.3)
- **Description:** `GPUDevice.pushErrorScope()` and `GPUDevice.popErrorScope()` allow capturing specific types of errors (`GPUValidationError`, `GPUOutOfMemoryError`, `GPUInternalError`) within a defined block of operations.
- **`webgpu.zig` Status:**
    - `GPUError` (generic) and its subtypes are defined.
    - Missing: FFI declarations for `pushErrorScope` and `popErrorScope`.
    - `GPUErrorFilter` enum is needed.
- **`webgpu.js` Status:**
    - Missing: Implementations for `env_device_push_error_scope_js` and `env_device_pop_error_scope_js`. Current error handling is via a single `globalWebGPU.error` string.

### 1.5. Shader Module Compilation Info (Spec §9.1.2)
- **Description:** `GPUShaderModule.getCompilationInfo()` returns a promise with detailed compilation messages (errors, warnings).
- **`webgpu.zig` Status:**
    - Missing: `GPUCompilationInfo` and `GPUCompilationMessage` structs.
    - Missing: FFI declaration for `getCompilationInfo` (async).
- **`webgpu.js` Status:**
    - Missing: Implementation for `env_shader_module_get_compilation_info_js`.

## 2. Buffer Operations

### 2.1. Buffer Mapping (Spec §5.2)
- **Description:** `GPUBuffer.mapAsync()` maps a GPU buffer's memory to be CPU-accessible. `getMappedRange()` provides an `ArrayBuffer` for reading/writing, and `unmap()` releases the mapping. Essential for CPU-GPU data transfer.
- **`webgpu.zig` Status:**
    - `BufferDescriptor` has `mappedAtCreation`.
    - Missing: `GPUMapModeFlags` enum.
    - Missing: FFI declarations for `mapAsync()`, `getMappedRange()`, `unmap()`.
    - Missing: Zig wrapper functions for these operations.
- **`webgpu.js` Status:**
    - Missing: Implementations for `env_buffer_map_async_js`, `env_buffer_get_mapped_range_js`, `env_buffer_unmap_js`. This involves promise handling and `ArrayBuffer` management.

## 3. Texture Operations & Management

### 3.1. GPUExternalTexture (Spec §6.4)
- **Description:** Wraps external image sources (like HTMLVideoElement or VideoFrame) for efficient sampling in shaders.
- **`webgpu.zig` Status:**
    - `BGLResourceType.external_texture` enum member exists.
    - Missing: `GPUExternalTexture` handle, `GPUExternalTextureDescriptor` struct.
    - Missing: FFI for `GPUDevice.importExternalTexture()`.
- **`webgpu.js` Status:**
    - `externalTexture` case in `readBindGroupLayoutDescriptorFromMemory` is a placeholder.
    - Missing: `env_device_import_external_texture_js` implementation.
    - The binding for external textures in `env_wgpu_device_create_bind_group_js` needs to handle this resource type.

### 3.2. GPUQueue Texture Copy Operations (Spec §19.2)
- **Description:** Methods on `GPUQueue` for writing data directly to textures from CPU or copying from external image sources.
- **`webgpu.zig` Status:**
    - Missing: FFI declarations for `GPUQueue.writeTexture()`, `GPUQueue.copyExternalImageToTexture()`.
    - Structs like `GPUTexelCopyTextureInfo`, `GPUCopyExternalImageSourceInfo`, `GPUCopyExternalImageDestInfo` are needed.
- **`webgpu.js` Status:**
    - Missing: Implementations for `env_queue_write_texture_js`, `env_queue_copy_external_image_to_texture_js`.

### 3.3. GPUCommandEncoder Texture Copy Operations (Spec §13.5)
- **Description:** Command encoder methods for copying data between buffers and textures, or textures and textures.
- **`webgpu.zig` Status:**
    - `env_wgpu_command_encoder_copy_buffer_to_buffer_js` exists.
    - Missing: FFI declarations for `copyBufferToTexture()`, `copyTextureToBuffer()`, `copyTextureToTexture()`.
- **`webgpu.js` Status:**
    - Missing: Implementations for `env_command_encoder_copy_buffer_to_texture_js`, etc.

### 3.4. Texture Format Completeness (Spec §6.3, §26.1)
- **Description:** The WebGPU spec defines numerous texture formats. The current bindings implement a subset. "Finalizing" implies a more complete coverage.
- **`webgpu.zig` Status:**
    - `TextureFormat` enum is partial (acknowledged in README). Many formats (especially compressed ones requiring features) are missing.
- **`webgpu.js` Status:**
    - `ZIG_TEXTURE_FORMAT_TO_JS` map is correspondingly partial.
    - Validation and capabilities checks for all formats (filterable, renderable, storage, multisample, resolve, dimension support) would be needed for comprehensive support.

## 4. Pipeline Creation & Management

### 4.1. Asynchronous Pipeline Creation (Spec §10.2.1, §10.3.1)
- **Description:** `createComputePipelineAsync()` and `createRenderPipelineAsync()` are preferred for non-blocking pipeline compilation. They return Promises.
- **`webgpu.zig` Status:**
    - Current FFI calls for pipeline creation are synchronous in appearance (`env_wgpu_device_create_compute_pipeline_js`).
    - Missing: FFI declarations for async versions (needs promise/callback handling).
    - Missing: `GPUPipelineError` struct for error reporting from async creation.
- **`webgpu.js` Status:**
    - JS implementations (`env_wgpu_device_create_compute_pipeline_js`, etc.) use the synchronous WebGPU `create*Pipeline` methods.
    - Missing: Handling for `create*PipelineAsync` and `GPUPipelineError`.

### 4.2. Completeness of Pipeline Stage Descriptors
- **Description:** Ensuring all fields within pipeline stage descriptors (e.g., `GPUDepthStencilState`) are correctly represented and usable.
- **`webgpu.zig` Status:**
    - `RenderPassDepthStencilAttachment` (used by `RenderPassDescriptor`) is noted as simplified. The full `GPUDepthStencilState` (Spec §10.3.6) used in `RenderPipelineDescriptor` needs to be fully implemented (e.g., `depthLoadOp`, `depthStoreOp`, `stencilLoadOp`, `stencilStoreOp`, etc.).
    - Other state structs (`GPUVertexState`, `GPUPrimitiveState`, `GPUMultisampleState`, `GPUFragmentState`, `GPUColorTargetState`) should be cross-referenced with the spec for any missing fields or incorrect assumptions about defaults/optionals.
- **`webgpu.js` Status:**
    - JS code reading these descriptors from Wasm memory needs to be updated if Zig structs change. Correct handling of optional members and default values is critical.

## 5. Command Encoding & Execution

### 5.1. GPUCommandEncoder - Miscellaneous
- **`clearBuffer()` (Spec §13.4):**
    - **Description:** Encodes a command to fill a sub-region of a GPUBuffer with zeros.
    - **`webgpu.zig` Status:** Missing FFI declaration and Zig wrapper.
    - **`webgpu.js` Status:** Missing `env_command_encoder_clear_buffer_js` implementation.
- **Debug Markers (Spec §15):**
    - **Description:** `pushDebugGroup()`, `popDebugGroup()`, `insertDebugMarker()` for labeling command sequences for debugging tools.
    - **`webgpu.zig` Status:** Missing FFI declarations and Zig wrappers.
    - **`webgpu.js` Status:** Missing implementations for these FFIs.

### 5.2. Render Bundles (Spec §18)
- **Description:** Allow pre-recording a sequence of render commands that can be executed multiple times within different render passes.
- **`webgpu.zig` Status:**
    - `RenderBundle` and `RenderBundleEncoder` handles are defined.
    - Missing: `GPURenderBundleEncoderDescriptor`, `GPURenderBundleDescriptor` structs.
    - Missing: FFI declarations for `GPUDevice.createRenderBundleEncoder()`, `GPURenderBundleEncoder.finish()`, and `GPURenderPassEncoder.executeBundles()`.
- **`webgpu.js` Status:**
    - Missing: Corresponding FFI implementations for render bundle operations.

## 6. Queries

### 6.1. GPUQuerySet Management (Spec §20.1)
- **Description:** `GPUQuerySet` objects store results from occlusion or timestamp queries.
- **`webgpu.zig` Status:**
    - `QuerySet` handle exists. `GPUQueryType` enum exists.
    - Missing: `GPUQuerySetDescriptor` struct.
    - Missing: FFI for `GPUDevice.createQuerySet()`.
    - Missing: FFI for `GPUQuerySet.destroy()`.
- **`webgpu.js` Status:**
    - `globalWebGPU.querySets` array exists.
    - Missing: `env_device_create_query_set_js` and `env_queryset_destroy_js` implementations.

### 6.2. Query Resolution (Spec §13.6)
- **Description:** `GPUCommandEncoder.resolveQuerySet()` copies query results from a `GPUQuerySet` to a `GPUBuffer`.
- **`webgpu.zig` Status:** Missing FFI declaration and Zig wrapper.
- **`webgpu.js` Status:** Missing `env_command_encoder_resolve_query_set_js` implementation.

### 6.3. Occlusion Queries (Spec §17.2.3, §20.3)
- **Description:** Measure whether any samples pass all per-fragment tests for a set of drawing commands.
- **`webgpu.zig` Status:**
    - `GPURenderPassDescriptor` has `occlusionQuerySet` field.
    - Missing: FFI for `GPURenderPassEncoder.beginOcclusionQuery()` and `endOcclusionQuery()`.
- **`webgpu.js` Status:**
    - Missing: Implementations for `env_render_pass_encoder_begin_occlusion_query_js` and `env_render_pass_encoder_end_occlusion_query_js`.

### 6.4. Timestamp Queries (Spec §16.1.1, §17.1.1, §20.4)
- **Description:** Allow writing GPU timestamps at various points during compute or render passes.
- **`webgpu.zig` Status:**
    - `ComputePassTimestampWrite` and `RenderPassTimestampWrites` structs exist for pass descriptors.
    - FFI for `computePassEncoderWriteTimestamp()` and `renderPassEncoderWriteTimestamp()` exists but JS side might be incomplete or not directly used by current examples.
- **`webgpu.js` Status:**
    - `env_wgpu_compute_pass_encoder_write_timestamp_js` and `env_wgpu_render_pass_encoder_write_timestamp_js` exist but their usage and completeness, especially if relying on descriptor-based timestamps, need review. Full functionality depends on `QuerySet` creation.

## 7. General Binding Improvements

### 7.1. Enum Completeness & JS Mappings
- **Description:** Many WebGPU enums are extensive (e.g., `GPUTextureFormat`, `GPUVertexFormat`, `GPUFeatureName`).
- **Status:** Both `webgpu.zig` enums and their corresponding `ZIG_..._TO_JS` string maps in `webgpu.js` are acknowledged as partial in the README. They need to be expanded for broader API compatibility.

### 7.2. Descriptor Reading in JS
- **Description:** The JavaScript code that reads Zig descriptor structs from Wasm memory (e.g., `readBindGroupLayoutDescriptorFromMemory`, pipeline descriptor parsing) is complex and relies on manual offset calculations.
- **Status:** This area is prone to errors if Zig struct layouts change or were initially misinterpreted, especially concerning optional fields, unions, and padding/alignment. A thorough review and potentially more robust/less manual methods for this data conversion are advisable. Adding more comments explaining these parts in `webgpu.js` would improve maintainability.

### 7.3. Testing
- **Description:** A comprehensive test suite (`webgpu.test.zig`) is crucial for verifying the correctness and robustness of the bindings.
- **Status:** Explicitly mentioned in `ROADMAP.MD` as a "Next Milestone" for WebGPU. This is a significant work item.
