// Opaque handles for WebGPU objects (represented as u32 IDs from JavaScript)
// pub const PromiseId = u32; // REMOVED as primary async mechanism changes
pub const Adapter = u32;
pub const Device = u32;
pub const Queue = u32;
pub const Buffer = u32;
pub const ShaderModule = u32;
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

    pub fn newFromWGSL(wgsl_source: []const u8) ShaderModuleDescriptor {
        return ShaderModuleDescriptor{
            .label = null,
            .wgsl_code = ShaderModuleWGSLDescriptor{
                .code_ptr = wgsl_source.ptr,
                .code_len = wgsl_source.len,
            },
        };
    }

    pub fn newFromWGSLabeled(label_text: ?[*:0]const u8, wgsl_source: []const u8) ShaderModuleDescriptor {
        return ShaderModuleDescriptor{
            .label = label_text,
            .wgsl_code = ShaderModuleWGSLDescriptor{
                .code_ptr = wgsl_source.ptr,
                .code_len = wgsl_source.len,
            },
        };
    }
};

// --- FFI Imports (JavaScript functions Zig will call) ---
// These functions are expected to be provided in the JavaScript 'env' object during Wasm instantiation.
// extern "env" fn env_wgpu_request_adapter_async_js() callconv(.Js) PromiseId;
// extern "env" fn env_wgpu_adapter_request_device_async_js(adapter_handle: Adapter) callconv(.Js) PromiseId;
// extern "env" fn env_wgpu_poll_promise_js(promise_id: PromiseId) callconv(.Js) PromiseStatus;
// extern "env" fn env_wgpu_get_adapter_from_promise_js(promise_id: PromiseId) callconv(.Js) Adapter;
// extern "env" fn env_wgpu_get_device_from_promise_js(promise_id: PromiseId) callconv(.Js) Device;
// extern "env" fn env_wgpu_device_get_queue_js(device_handle: Device) callconv(.Js) Queue;

// Error handling related FFI calls - assumed to be called from JS into Zig initially, but now part of 'env'
// extern "env" fn env_wgpu_get_last_error_msg_ptr_js() callconv(.Js) [*c]const u8;
// extern "env" fn env_wgpu_get_last_error_msg_len_js() callconv(.Js) usize;
// extern "env" fn env_wgpu_copy_last_error_msg_js(buffer_ptr: [*c]u8, buffer_len: usize) callconv(.Js) void;
// extern "env" fn env_wgpu_release_handle_js(type_id: u32, handle: u32) callconv(.Js) void;
// extern "env" fn js_log_string(message_ptr: [*c]const u8, message_len: usize) callconv(.Js) void;

extern "env" fn env_wgpu_request_adapter_js() void;
extern "env" fn env_wgpu_adapter_request_device_js(adapter_handle: Adapter) void;
// extern "env" fn env_wgpu_poll_promise_js(promise_id: PromiseId) i32; // REMOVED
// extern "env" fn env_wgpu_get_adapter_from_promise_js(promise_id: PromiseId) Adapter; // REMOVED
// extern "env" fn env_wgpu_get_device_from_promise_js(promise_id: PromiseId) Device; // REMOVED
extern "env" fn env_wgpu_device_get_queue_js(device_handle: Device) Queue;

// New FFI imports for buffer and shader module
extern "env" fn env_wgpu_device_create_buffer_js(device_handle: Device, descriptor_ptr: *const BufferDescriptor) Buffer;
extern "env" fn env_wgpu_device_create_shader_module_js(device_handle: Device, descriptor_ptr: *const ShaderModuleDescriptor) ShaderModule;

extern "env" fn env_wgpu_get_last_error_msg_ptr_js() [*c]const u8;
extern "env" fn env_wgpu_get_last_error_msg_len_js() usize;
extern "env" fn env_wgpu_copy_last_error_msg_js(buffer_ptr: [*c]u8, buffer_len: usize) void;
extern "env" fn env_wgpu_release_handle_js(type_id: u32, handle: u32) void;
extern "env" fn js_log_string(message_ptr: [*c]const u8, message_len: usize) void;

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

// --- Public API for Zig Application ---

pub fn log(message: []const u8) void {
    js_log_string(message.ptr, message.len);
}

fn simple_min(a: u32, b: u32) u32 {
    return if (a < b) a else b;
}

// Logs an error message retrieved from JS FFI into a stack buffer.
// Renamed to avoid conflict if application also has a getLastErrorMsg
pub fn getAndLogWebGPUError(prefix: []const u8) void {
    if (env_wgpu_get_last_error_msg_ptr_js() == 0) {
        if (prefix.len > 0) log(prefix);
        return;
    }
    const len = env_wgpu_get_last_error_msg_len_js();
    if (len == 0) {
        if (prefix.len > 0) log(prefix);
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
            log(prefix); // Prefix too long for combined buffer, log separately
            log(error_buf[0..copy_len]);
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
                log(error_buf[0..copy_len]);
            } else { // Prefix was copied, log error part that didn't fit
                log(log_buf[0..current_len]); // Log what fit (prefix + space)
                log(error_buf[0..copy_len]); // Log the error message
            }
            return;
        }
    }

    log(log_buf[0..current_len]);
}

// REMOVED pollPromise function
// REMOVED genericErrorHandlerPromise function as errors are now handled in callbacks

// Initiates the request for a WebGPU Adapter.
// The result will be delivered asynchronously to the exported Zig function `zig_receive_adapter`.
pub fn requestAdapter() void {
    log("Requesting WebGPU Adapter (async via callback)...");
    env_wgpu_request_adapter_js();
}

// Initiates the request for a WebGPU Device from an Adapter.
// The result will be delivered asynchronously to the exported Zig function `zig_receive_device`.
pub fn adapterRequestDevice(adapter: Adapter) void {
    log("Requesting WebGPU Device (async via callback)...");
    if (adapter == 0) {
        // This is a synchronous error check before making the async call.
        // The application needs a way to know this immediate failure.
        // For now, we log. A robust FFI might have requestAdapter return an error for invalid params.
        log("E00: Invalid adapter handle (0) passed to adapterRequestDevice. Device request not sent.");
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
    log("Getting WebGPU Queue...");
    if (device == 0) {
        log("E00: Invalid device handle (0) passed to deviceGetQueue.");
        return error.QueueRetrievalFailed; // Synchronous error for invalid input
    }
    const queue_handle = env_wgpu_device_get_queue_js(device);
    if (queue_handle == 0) {
        // Assuming JS sets an error that getAndLogWebGPUError can retrieve
        getAndLogWebGPUError("E09: Failed to get queue (JS queue_handle is 0). ");
        return error.QueueRetrievalFailed;
    }
    log("Queue acquired.");
    return queue_handle;
}

pub fn deviceCreateBuffer(device_handle: Device, descriptor: BufferDescriptor) !Buffer {
    log("Creating WebGPU Buffer...");
    if (device_handle == 0) {
        log("E00: Invalid device handle (0) passed to deviceCreateBuffer.");
        return error.InvalidHandle;
    }
    const buffer_handle = env_wgpu_device_create_buffer_js(device_handle, &descriptor);
    if (buffer_handle == 0) {
        getAndLogWebGPUError("E10: Failed to create buffer (JS buffer_handle is 0). ");
        return error.OperationFailed;
    }
    log("Buffer created.");
    return buffer_handle;
}

pub fn deviceCreateShaderModule(device_handle: Device, descriptor: ShaderModuleDescriptor) !ShaderModule {
    log("Creating WebGPU Shader Module...");
    if (device_handle == 0) {
        log("E00: Invalid device handle (0) passed to deviceCreateShaderModule.");
        return error.InvalidHandle;
    }
    const module_handle = env_wgpu_device_create_shader_module_js(device_handle, &descriptor);
    if (module_handle == 0) {
        getAndLogWebGPUError("E11: Failed to create shader module (JS module_handle is 0). ");
        return error.OperationFailed;
    }
    log("Shader module created.");
    return module_handle;
}

pub fn releaseHandle(handle_type: HandleType, handle: u32) void {
    if (handle == 0) return;
    // Ensure type_id for releaseHandle in JS matches this HandleType enum.
    // Note: Promise handle type was 1. Adapter is 2, Device 3, Queue 4.
    // Need to ensure JS side env_wgpu_release_handle_js expects these integer values correctly.
    const type_id_for_js: u32 = switch (handle_type) {
        // .promise => 1, // Removed
        .adapter => 2,
        .device => 3,
        .queue => 4,
        .buffer => 5,
        .shader_module => 6,
    };
    env_wgpu_release_handle_js(type_id_for_js, handle);
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
