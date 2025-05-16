const webutils = @import("webutils.zig");

// Opaque handles for WebGPU objects (represented as u32 IDs from JavaScript)
// pub const PromiseId = u32; // REMOVED as primary async mechanism changes
pub const Adapter = u32;
pub const Device = u32;
pub const Queue = u32;
pub const Buffer = u32;
pub const ShaderModule = u32;
pub const Texture = u32;
pub const TextureView = u32;
pub const Sampler = u32;
pub const BindGroupLayout = u32;
pub const BindGroup = u32;
pub const PipelineLayout = u32;
pub const ComputePipeline = u32;
pub const RenderPipeline = u32;
pub const CommandEncoder = u32;
pub const CommandBuffer = u32;
pub const RenderPassEncoder = u32;
pub const ComputePassEncoder = u32;
pub const QuerySet = u32;
// TODO: Add more handles: Texture, TextureView, Sampler, BindGroupLayout, PipelineLayout, RenderPipeline, ComputePipeline, BindGroup, CommandEncoder, CommandBuffer, RenderPassEncoder, ComputePassEncoder, QuerySet

// Enum for promise status - REMOVED as pollPromise is removed
// pub const PromiseStatus = enum(i32) {
//     pending = 0,
//     fulfilled = 1,
//     rejected = -1,
// };

// Enum for handle types for releasing
pub const HandleType = enum(u32) {
    // promise = 1, // REMOVED
    adapter = 2,
    device = 3,
    queue = 4,
    buffer = 5,
    shader_module = 6,
    texture = 7,
    texture_view = 8,
    sampler = 9,
    bind_group_layout = 10,
    bind_group = 11,
    pipeline_layout = 12,
    compute_pipeline = 13,
    render_pipeline = 14,
    command_encoder = 15,
    command_buffer = 16,
    render_pass_encoder = 17,
    compute_pass_encoder = 18,
    query_set = 19,
    // TODO: Add other WebGPU object types here as they are introduced
};

// --- Descriptors ---

pub const BufferDescriptor = extern struct {
    label: ?[*:0]const u8,
    size: u64, // Corresponds to GPUSize64
    usage: u32, // Corresponds to GPUBufferUsageFlags (bitflags)
    mappedAtCreation: bool,

    // Helper to create a descriptor. `usage` should be a bitmask of GPUBufferUsageFlags.
    pub fn new(size_in_bytes: u64, usage_flags: u32) BufferDescriptor {
        return BufferDescriptor{
            .label = null,
            .size = size_in_bytes,
            .usage = usage_flags,
            .mappedAtCreation = false,
        };
    }

    pub fn newLabeled(label_text: ?[*:0]const u8, size_in_bytes: u64, usage_flags: u32) BufferDescriptor {
        return BufferDescriptor{
            .label = label_text,
            .size = size_in_bytes,
            .usage = usage_flags,
            .mappedAtCreation = false,
        };
    }
};

// GPUBufferUsageFlags - values should match WebGPU spec's GPUBufferUsage
// These are just examples; a full set would be needed.
pub const GPUBufferUsage = struct {
    pub const MAP_READ = 0x0001;
    pub const MAP_WRITE = 0x0002;
    pub const COPY_SRC = 0x0004;
    pub const COPY_DST = 0x0008;
    pub const INDEX = 0x0010;
    pub const VERTEX = 0x0020;
    pub const UNIFORM = 0x0040;
    pub const STORAGE = 0x0080;
    pub const INDIRECT = 0x0100;
    pub const QUERY_RESOLVE = 0x0200;
};

pub const ShaderModuleWGSLDescriptor = extern struct {
    // For now, directly pass code. Later might add entryPoints or other features.
    // Based on GPUShaderModuleDescriptor, which typically only has `code` and `label`.
    // `sourceMap` and `hints` are more advanced.
    code_ptr: [*c]const u8,
    code_len: usize,
};

pub const ShaderModuleDescriptor = extern struct {
    label: ?[*:0]const u8,
    // For now, only WGSL is directly supported in WebGPU by browsers.
    // If other shader types were supported via FFI, a tagged union or similar might be here.
    wgsl_code: ShaderModuleWGSLDescriptor,

    // DEPRECATED: newFromWGSL and newFromWGSLabeled. Use direct struct initialization.
    // pub fn newFromWGSL(wgsl_source: []const u8) ShaderModuleDescriptor {
    //     return ShaderModuleDescriptor{
    //         .label = null,
    //         .wgsl_code = ShaderModuleWGSLDescriptor{
    //             .code_ptr = wgsl_source.ptr,
    //             .code_len = wgsl_source.len,
    //         },
    //     };
    // }
    //
    // pub fn newFromWGSLabeled(label_text: ?[*:0]const u8, wgsl_source: []const u8) ShaderModuleDescriptor {
    //     return ShaderModuleDescriptor{
    //         .label = label_text,
    //         .wgsl_code = ShaderModuleWGSLDescriptor{
    //             .code_ptr = wgsl_source.ptr,
    //             .code_len = wgsl_source.len,
    //         },
    //     };
    // }
};

// Texture Related Enums and Structs (matching WebGPU spec)

/// Corresponds to GPUTextureDimension
pub const TextureDimension = enum(u32) {
    @"1d" = 0,
    @"2d" = 1,
    @"3d" = 2,
    // Removed fromStr and toJsStringId to avoid std dependency here
};

/// Corresponds to GPUTextureFormat
/// This is a partial list. Many more formats exist.
pub const TextureFormat = enum(u32) {
    // 8-bit formats
    r8unorm = 0,
    r8snorm = 1,
    r8uint = 2,
    r8sint = 3,
    // 16-bit formats
    r16uint = 4,
    r16sint = 5,
    r16float = 6,
    rg8unorm = 7,
    rg8snorm = 8,
    rg8uint = 9,
    rg8sint = 10,
    // 32-bit formats
    r32uint = 11,
    r32sint = 12,
    r32float = 13,
    rg16uint = 14,
    rg16sint = 15,
    rg16float = 16,
    rgba8unorm = 17,
    rgba8unorm_srgb = 18,
    rgba8snorm = 19,
    rgba8uint = 20,
    rgba8sint = 21,
    bgra8unorm = 22,
    bgra8unorm_srgb = 23,
    // More formats...
    rgb9e5ufloat = 24,
    rgb10a2unorm = 25,
    rg11b10ufloat = 26,
    // 64-bit formats
    rg32uint = 27,
    rg32sint = 28,
    rg32float = 29,
    rgba16uint = 30,
    rgba16sint = 31,
    rgba16float = 32,
    // 128-bit formats
    rgba32uint = 33,
    rgba32sint = 34,
    rgba32float = 35,
    // Depth/stencil formats
    stencil8 = 36,
    depth16unorm = 37,
    depth24plus = 38,
    depth24plus_stencil8 = 39,
    depth32float = 40,
    depth32float_stencil8 = 41, // If feature "depth32float-stencil8" is enabled

    // BC compressed formats (feature: "texture-compression-bc")
    // ASTC compressed formats (feature: "texture-compression-astc")
    // ETC2 compressed formats (feature: "texture-compression-etc2")

    // Removed toJsStringId
};

pub const Extent3D = extern struct { // Corresponds to GPUExtent3DDict
    width: u32, // GPUIntegerCoordinate
    height: u32 = 1, // GPUIntegerCoordinate
    depth_or_array_layers: u32 = 1, // GPUIntegerCoordinate
};

pub const TextureDescriptor = extern struct {
    label: ?[*:0]const u8,
    size: Extent3D,
    mip_level_count: u32 = 1, // GPUIntegerCoordinate
    sample_count: u32 = 1, // GPUIntegerCoordinate
    dimension: TextureDimension = .@"2d", // GPUTextureDimension, pass as u32 id
    format: TextureFormat, // GPUTextureFormat, pass as u32 id
    usage: u32, // GPUTextureUsageFlags (bitmask)
    view_formats: ?[*]const TextureFormat = null, // Optional: Pointer to array of TextureFormat enums
    view_formats_count: usize = 0,
};

pub const GPUTextureUsage = struct { // GPUTextureUsageFlags
    pub const COPY_SRC = 0x01;
    pub const COPY_DST = 0x02;
    pub const TEXTURE_BINDING = 0x04; // aka SAMPLED
    pub const STORAGE_BINDING = 0x08;
    pub const RENDER_ATTACHMENT = 0x10;
};

/// Corresponds to GPUTextureAspect
pub const TextureAspect = enum(u32) {
    all = 0,
    stencil_only = 1,
    depth_only = 2,
    // Removed toJsStringId
};

pub const TextureViewDescriptor = extern struct {
    label: ?[*:0]const u8,
    format: ?TextureFormat = null,
    dimension: ?TextureDimension = null, // NOTE: This should ideally be TextureViewDimension if it differs
    aspect: TextureAspect = .all,
    base_mip_level: u32 = 0,
    mip_level_count: ?u32 = null,
    base_array_layer: u32 = 0,
    array_layer_count: ?u32 = null,
};

// Bind Group Layout Related Enums and Structs

pub const ShaderStage = extern struct { // Corresponds to GPUShaderStageFlags (bitflags)
    pub const NONE: u32 = 0;
    pub const VERTEX: u32 = 1;
    pub const FRAGMENT: u32 = 2;
    pub const COMPUTE: u32 = 4;
};

pub const BufferBindingType = enum(u32) { // Corresponds to GPUBufferBindingType
    uniform = 0,
    storage = 1,
    read_only_storage = 2,
    // JS strings: "uniform", "storage", "read-only-storage"
};

pub const BufferBindingLayout = extern struct { // Corresponds to GPUBufferBindingLayout
    type: BufferBindingType, // = .uniform,
    has_dynamic_offset: bool, // = false,
    min_binding_size: u64, // = 0, // GPUSize64
};

// Re-using TextureDimension for view_dimension for now. WebGPU spec has GPUTextureViewDimension
// which includes "1d", "2d", "2d-array", "cube", "cube-array", "3d".
// Our TextureDimension only has 1d, 2d, 3d. This might need a separate enum if advanced views are used.
pub const TextureBindingLayout = extern struct { // Corresponds to GPUTextureBindingLayout
    sample_type: TextureSampleType, // = .float,
    view_dimension: TextureDimension, // = .@"2d", // This should be TextureViewDimension type
    multisampled: bool, // = false,
};

// More specific enums needed for StorageTextureBindingLayout if used (e.g. StorageTextureAccess)
// pub const StorageTextureAccess = enum(u32) { write_only = 0, read_only = 1, read_write = 2 };
// pub const StorageTextureBindingLayout = extern struct { ... }

pub const BGLResourceType = enum(u32) {
    buffer = 0,
    texture = 1,
    sampler = 2, // Placeholder for future use
    storage_texture = 3, // Placeholder for future use
    external_texture = 4, // Placeholder for future use
};

pub const BindGroupLayoutEntry = extern struct { // Corresponds to GPUBindGroupLayoutEntry
    binding: u32, // GPUIndex32
    visibility: u32, // GPUShaderStageFlags (bitmask of ShaderStage constants)
    resource_type: BGLResourceType,
    layout: ResourceLayout,

    pub const ResourceLayout = extern union {
        buffer: BufferBindingLayout,
        texture: TextureBindingLayout,
        // sampler: SamplerBindingLayout, // TODO for later
        // storage_texture: StorageTextureBindingLayout, // TODO for later
        // external_texture: ExternalTextureBindingLayout, // TODO for later
    };

    // Convenience constructors for Zig-side usage
    pub fn newBuffer(binding_idx: u32, visibility_flags: u32, layout_details: BufferBindingLayout) BindGroupLayoutEntry {
        return .{
            .binding = binding_idx,
            .visibility = visibility_flags,
            .resource_type = .buffer,
            .layout = .{ .buffer = layout_details },
        };
    }

    pub fn newTexture(binding_idx: u32, visibility_flags: u32, layout_details: TextureBindingLayout) BindGroupLayoutEntry {
        return .{
            .binding = binding_idx,
            .visibility = visibility_flags,
            .resource_type = .texture,
            .layout = .{ .texture = layout_details },
        };
    }
    // TODO: Add constructors for sampler, storage_texture etc. when implemented
};

pub const BindGroupLayoutDescriptor = extern struct {
    label: ?[*:0]const u8 = null,
    entries: [*]const BindGroupLayoutEntry,
    entries_len: usize,
};

// --- FFI Imports (JavaScript functions Zig will call) ---
// These functions are expected to be provided in the JavaScript 'env' object during Wasm instantiation.

// Async Init (Zig -> JS -> Zig callback)
pub extern "env" fn env_wgpu_request_adapter_js() void;
pub extern "env" fn env_wgpu_adapter_request_device_js(adapter_handle: Adapter) void;

// Synchronous Resource Creation & Operations (Zig -> JS)
pub extern "env" fn env_wgpu_device_get_queue_js(device_handle: Device) callconv(.C) Queue;
pub extern "env" fn env_wgpu_device_create_buffer_js(device_handle: Device, descriptor_ptr: [*]const BufferDescriptor) callconv(.C) Buffer;
pub extern "env" fn env_wgpu_queue_write_buffer_js(queue_handle: Queue, buffer_handle: Buffer, buffer_offset: u64, data_ptr: [*]const u8, data_size: usize) callconv(.C) void;
pub extern "env" fn env_wgpu_device_create_shader_module_js(device_handle: Device, descriptor_ptr: [*]const ShaderModuleDescriptor) callconv(.C) ShaderModule;
pub extern "env" fn env_wgpu_device_create_texture_js(device_handle: Device, descriptor_ptr: [*]const TextureDescriptor) callconv(.C) Texture;
pub extern "env" fn env_wgpu_texture_create_view_js(texture_handle: Texture, descriptor_ptr: ?[*]const TextureViewDescriptor) callconv(.C) TextureView;
pub extern "env" fn env_wgpu_device_create_bind_group_layout_js(device_handle: Device, descriptor_ptr: [*]const BindGroupLayoutDescriptor) callconv(.C) BindGroupLayout;
pub extern "env" fn env_wgpu_device_create_bind_group_js(device_handle: Device, descriptor_ptr: [*]const BindGroupDescriptor) callconv(.C) BindGroup;

// Error Handling & Release
pub extern "env" fn env_wgpu_get_last_error_msg_ptr_js() u32;
pub extern "env" fn env_wgpu_get_last_error_msg_len_js() usize;
pub extern "env" fn env_wgpu_copy_last_error_msg_js(buffer_ptr: [*c]u8, buffer_len: usize) void;
pub extern "env" fn env_wgpu_release_handle_js(handle_type: HandleType, handle_id: u32) void;
// pub extern "env" fn js_log_string(message_ptr: [*c]const u8, message_len: usize) void; // Now in webutils directly

// --- Zig functions exported to be called by JavaScript ---
// These functions will be implemented by the application using this FFI library (e.g., in webgpu_handler.zig)
// They are declared here so the FFI user knows what signatures to provide.
// It is the responsibility of the consuming application to define these exported functions.
// We declare them here as extern to indicate they are *expected* exports for the JS side to call.
// This is a bit of a convention; Zig doesn't require declaring expected exports this way,
// but it helps document the FFI contract.
// Actual `pub export fn` definitions will be in the application code.
// For the purpose of this library, we can comment them out or make them illustrative.
// pub export fn zig_receive_adapter(adapter_handle: Adapter, status: u32) void;
// pub export fn zig_receive_device(device_handle: Device, status: u32) void;

fn simple_min(a: u32, b: u32) u32 {
    return if (a < b) a else b;
}

// Logs an error message retrieved from JS FFI into a stack buffer.
// Renamed to avoid conflict if application also has a getLastErrorMsg
pub fn getAndLogWebGPUError(prefix: []const u8) void {
    if (env_wgpu_get_last_error_msg_ptr_js() == 0) { // Check if JS has an error message prepared
        if (prefix.len > 0) {
            webutils.log(prefix);
        }
        return;
    }
    const len = env_wgpu_get_last_error_msg_len_js();
    if (len == 0) {
        if (prefix.len > 0) webutils.log(prefix);
        return;
    }

    var error_buf: [256]u8 = undefined;
    const copy_len = simple_min(len, error_buf.len - 1);

    env_wgpu_copy_last_error_msg_js(&error_buf, copy_len);

    var log_buf: [512]u8 = undefined; // Combined buffer for prefix and error message
    var current_len: usize = 0;

    if (prefix.len > 0) {
        if (prefix.len < log_buf.len - current_len) {
            @memcpy(log_buf[current_len..][0..prefix.len], prefix[0..prefix.len]);
            current_len += prefix.len;
        } else {
            webutils.log(prefix); // Prefix too long for combined buffer, log separately
            webutils.log(error_buf[0..copy_len]);
            return;
        }
    }
    // Add a separator if prefix was added and error message is not empty
    if (prefix.len > 0 and copy_len > 0) {
        if (current_len < log_buf.len - 1) {
            log_buf[current_len] = ' ';
            current_len += 1;
        }
    }

    if (copy_len > 0) {
        if (copy_len < log_buf.len - current_len) {
            @memcpy(log_buf[current_len..][0..copy_len], error_buf[0..copy_len]);
            current_len += copy_len;
        } else {
            // Error message too long for remaining space, log separately if prefix was already copied
            if (prefix.len == 0) { // If prefix wasn't an issue, then just log error_buf directly
                webutils.log(error_buf[0..copy_len]);
            } else { // Prefix was copied, log error part that didn't fit
                webutils.log(log_buf[0..current_len]); // Log what fit (prefix + space)
                webutils.log(error_buf[0..copy_len]); // Log the error message
            }
            return;
        }
    }

    webutils.log(log_buf[0..current_len]);
}

// REMOVED pollPromise function
// REMOVED genericErrorHandlerPromise function as errors are now handled in callbacks

// Initiates the request for a WebGPU Adapter.
// The result will be delivered asynchronously to the exported Zig function `zig_receive_adapter`.
pub fn requestAdapter() void {
    webutils.log("Requesting WebGPU Adapter (async via callback)...");
    env_wgpu_request_adapter_js();
}

// Initiates the request for a WebGPU Device from an Adapter.
// The result will be delivered asynchronously to the exported Zig function `zig_receive_device`.
pub fn adapterRequestDevice(adapter: Adapter) void {
    webutils.log("Requesting WebGPU Device (async via callback)...");
    if (adapter == 0) {
        // This is a synchronous error check before making the async call.
        // The application needs a way to know this immediate failure.
        // For now, we log. A robust FFI might have requestAdapter return an error for invalid params.
        webutils.log("E00: Invalid adapter handle (0) passed to adapterRequestDevice. Device request not sent.");
        // Potentially, the JS side could also check and call back with an error,
        // but an early Zig-side check is good.
        // How to signal this back to the caller in an async model without return values here?
        // The calling code must ensure valid handles, or the callback for device request will indicate an error.
        return; // Or, if the JS can handle a 0 adapter handle and call back with error, let it.
        // For now, let's assume JS will handle it or the Zig callback for device will get an error.
    }
    env_wgpu_adapter_request_device_js(adapter);
}

pub fn deviceGetQueue(device: Device) !Queue {
    webutils.log("Getting WebGPU Queue...");
    if (device == 0) {
        webutils.log("E00: Invalid device handle (0) passed to deviceGetQueue.");
        return error.QueueRetrievalFailed; // Synchronous error for invalid input
    }
    const queue_handle = env_wgpu_device_get_queue_js(device);
    if (queue_handle == 0) {
        // Assuming JS sets an error that getAndLogWebGPUError can retrieve
        getAndLogWebGPUError("E09: Failed to get queue (JS queue_handle is 0). ");
        return error.QueueRetrievalFailed;
    }
    webutils.log("Queue acquired.");
    return queue_handle;
}

pub fn deviceCreateBuffer(device_handle: Device, descriptor: *const BufferDescriptor) !Buffer {
    webutils.log("Creating WebGPU Buffer (Zig FFI wrapper)...");
    if (device_handle == 0) {
        webutils.log("E00: Invalid device handle (0) passed to deviceCreateBuffer.");
        return error.InvalidHandle;
    }
    if (descriptor == null) {
        webutils.log("E00: Invalid descriptor (null) passed to deviceCreateBuffer.");
        return error.InvalidDescriptor;
    }
    const buffer_handle = env_wgpu_device_create_buffer_js(device_handle, descriptor);
    if (buffer_handle == 0) {
        getAndLogWebGPUError("E11: Failed to create buffer (JS buffer_handle is 0). ");
        return error.OperationFailed;
    }
    webutils.logV("Buffer created with handle: {d}", .{buffer_handle});
    return buffer_handle;
}

pub fn queueWriteBuffer(queue_handle: Queue, buffer_handle: Buffer, buffer_offset: u64, data: []const u8) !void {
    webutils.logV(
        "Writing to WebGPU Buffer (Zig FFI wrapper). Queue: {d}, Buffer: {d}, Offset: {d}, Data Size: {d}",
        .{ queue_handle, buffer_handle, buffer_offset, data.len },
    );
    if (queue_handle == 0 or buffer_handle == 0) {
        webutils.log("E00: Invalid handle (0) for queue or buffer passed to queueWriteBuffer.");
        return error.InvalidHandle;
    }
    env_wgpu_queue_write_buffer_js(queue_handle, buffer_handle, buffer_offset, data.ptr, data.len);
    // TODO: Check for errors after write? WebGPU doesn't throw sync errors for queue ops usually.
    webutils.log("Buffer write operation submitted.");
}

pub fn deviceCreateShaderModule(device_handle: Device, descriptor: *const ShaderModuleDescriptor) !ShaderModule {
    webutils.log("Creating WebGPU Shader Module (Zig FFI wrapper)...");
    if (device_handle == 0) {
        webutils.log("E00: Invalid device handle (0) passed to deviceCreateShaderModule.");
        return error.InvalidHandle;
    }
    if (descriptor == null) {
        webutils.log("E00: Invalid descriptor (null) passed to deviceCreateShaderModule.");
        return error.InvalidDescriptor;
    }
    const sm_handle = env_wgpu_device_create_shader_module_js(device_handle, descriptor);
    if (sm_handle == 0) {
        getAndLogWebGPUError("E12: Failed to create shader module (JS sm_handle is 0). ");
        return error.OperationFailed;
    }
    webutils.logV("Shader module created with handle: {d}", .{sm_handle});
    return sm_handle;
}

pub fn releaseHandle(handle_type: HandleType, handle: u32) void {
    if (handle == 0) return;
    // Ensure type_id for releaseHandle in JS matches this HandleType enum.
    // Note: Promise handle type was 1. Adapter is 2, Device 3, Queue 4.
    // Need to ensure JS side env_wgpu_release_handle_js expects these integer values correctly.
    const type_id_for_js: u32 = switch (handle_type) {
        // .promise => 1, // Removed
        .adapter => @intFromEnum(HandleType.adapter),
        .device => @intFromEnum(HandleType.device),
        .queue => @intFromEnum(HandleType.queue),
        .buffer => @intFromEnum(HandleType.buffer),
        .shader_module => @intFromEnum(HandleType.shader_module),
        .texture => @intFromEnum(HandleType.texture),
        .texture_view => @intFromEnum(HandleType.texture_view),
        .sampler => @intFromEnum(HandleType.sampler),
        .bind_group_layout => @intFromEnum(HandleType.bind_group_layout),
        .bind_group => @intFromEnum(HandleType.bind_group),
        .pipeline_layout => @intFromEnum(HandleType.pipeline_layout),
        .compute_pipeline => @intFromEnum(HandleType.compute_pipeline),
        .render_pipeline => @intFromEnum(HandleType.render_pipeline),
        .command_encoder => @intFromEnum(HandleType.command_encoder),
        .command_buffer => @intFromEnum(HandleType.command_buffer),
        .render_pass_encoder => @intFromEnum(HandleType.render_pass_encoder),
        .compute_pass_encoder => @intFromEnum(HandleType.compute_pass_encoder),
        .query_set => @intFromEnum(HandleType.query_set),
    };
    env_wgpu_release_handle_js(@as(HandleType, @enumFromInt(type_id_for_js)), handle);
}

// Error set for functions that can return synchronous errors
// Async operations will report errors via callbacks.
pub const GeneralWebGPUError = error{
    AdapterRequestFailed, // Might be used by application in callback
    DeviceRequestFailed, // Might be used by application in callback
    QueueRetrievalFailed,
    InvalidHandle,
    OperationFailed,
};

pub fn deviceCreateTexture(device_handle: Device, descriptor: *const TextureDescriptor) !Texture {
    webutils.log("Creating WebGPU Texture (Zig FFI wrapper)...");
    if (device_handle == 0) {
        webutils.log("E00: Invalid device handle (0) passed to deviceCreateTexture.");
        return error.InvalidHandle;
    }
    if (descriptor == null) {
        webutils.log("E00: Invalid descriptor (null) passed to deviceCreateTexture.");
        return error.InvalidDescriptor;
    }
    const tex_handle = env_wgpu_device_create_texture_js(device_handle, descriptor);
    if (tex_handle == 0) {
        getAndLogWebGPUError("E13: Failed to create texture (JS tex_handle is 0). ");
        return error.OperationFailed;
    }
    webutils.logV("Texture created with handle: {d}", .{tex_handle});
    return tex_handle;
}

pub fn textureCreateView(texture_handle: Texture, descriptor: ?*const TextureViewDescriptor) !TextureView {
    webutils.logV("Creating WebGPU Texture View for texture {d} (Zig FFI wrapper)...", .{texture_handle});
    if (texture_handle == 0) {
        webutils.log("E00: Invalid texture handle (0) passed to textureCreateView.");
        return error.InvalidHandle;
    }
    const tv_handle = env_wgpu_texture_create_view_js(texture_handle, descriptor);
    if (tv_handle == 0) {
        getAndLogWebGPUError("E14: Failed to create texture view (JS tv_handle is 0). ");
        return error.OperationFailed;
    }
    webutils.logV("Texture View created with handle: {d}", .{tv_handle});
    return tv_handle;
}

pub fn deviceCreateBindGroupLayout(device_handle: Device, descriptor: *const BindGroupLayoutDescriptor) !BindGroupLayout {
    webutils.log("Creating WebGPU BindGroupLayout (Zig FFI wrapper)...");
    if (device_handle == 0) {
        webutils.log("E00: Invalid device handle (0) passed to deviceCreateBindGroupLayout.");
        return error.InvalidHandle;
    }
    if (descriptor == null or descriptor.entries.ptr == null and descriptor.entries_len > 0) {
        webutils.log("E00: Invalid descriptor (null, or null entries with non-zero length) passed to deviceCreateBindGroupLayout.");
        return error.InvalidDescriptor;
    }
    const bgl_handle = env_wgpu_device_create_bind_group_layout_js(device_handle, descriptor);
    if (bgl_handle == 0) {
        getAndLogWebGPUError("E15: Failed to create bind group layout (JS bgl_handle is 0). ");
        return error.OperationFailed;
    }
    webutils.logV("BindGroupLayout created with handle: {d}", .{bgl_handle});
    return bgl_handle;
}

pub fn deviceCreateBindGroup(device_handle: Device, descriptor: *const BindGroupDescriptor) !BindGroup {
    webutils.log("Creating WebGPU BindGroup (Zig FFI wrapper)...");
    if (device_handle == 0) {
        webutils.log("E00: Invalid device handle (0) passed to deviceCreateBindGroup.");
        return error.InvalidHandle;
    }
    if (descriptor == null or descriptor.entries.ptr == null and descriptor.entries_len > 0) {
        webutils.log("E00: Invalid descriptor (null, or null entries with non-zero length) passed to deviceCreateBindGroup.");
        return error.InvalidDescriptor;
    }
    const bg_handle = env_wgpu_device_create_bind_group_js(device_handle, descriptor);
    if (bg_handle == 0) {
        getAndLogWebGPUError("E16: Failed to create bind group (JS bg_handle is 0). ");
        return error.OperationFailed;
    }
    webutils.logV("BindGroup created with handle: {d}", .{bg_handle});
    return bg_handle;
}

// New FFI Structs for BindGroup
pub const WHOLE_SIZE: u64 = 0xffffffffffffffff;

pub const BufferBinding = extern struct {
    buffer: Buffer,
    offset: u64 = 0,
    size: u64 = WHOLE_SIZE, // WGPU.BIND_BUFFER_WHOLE_SIZE - JS will handle 'undefined' if passed as a specific large u64 value or similar sentinel.
};

pub const SamplerBinding = extern struct { // Placeholder - Sampler FFI not yet defined
    sampler: Sampler,
};

pub const TextureBinding = extern struct {
    texture_view: TextureView,
};

pub const BindGroupEntry = extern struct {
    binding: u32,
    resource: Resource,

    pub const Resource = extern union {
        buffer: BufferBinding,
        sampler: SamplerBinding,
        texture: TextureBinding,
    };
};

pub const BindGroupDescriptor = extern struct {
    label: ?[*:0]const u8 = null,
    layout: BindGroupLayout,
    entries: [*]const BindGroupEntry,
    entries_len: usize,
};

pub const TextureSampleType = enum(u32) { // Corresponds to GPUTextureSampleType
    float = 0,
    unfilterable_float = 1,
    depth = 2,
    sint = 3,
    uint = 4,
    // JS strings: "float", "unfilterable-float", "depth", "sint", "uint"
};
