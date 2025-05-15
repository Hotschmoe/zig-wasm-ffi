// Opaque handles for WebGPU objects (represented as u32 IDs from JavaScript)
pub const PromiseId = u32;
pub const Adapter = u32;
pub const Device = u32;
pub const Queue = u32;

// Enum for promise status
pub const PromiseStatus = enum(i32) {
    pending = 0,
    fulfilled = 1,
    rejected = -1,
};

// Enum for handle types for releasing
pub const HandleType = enum(u32) {
    promise = 1,
    adapter = 2,
    device = 3,
    queue = 4,
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

extern "env" fn env_wgpu_request_adapter_async_js() PromiseId;
extern "env" fn env_wgpu_adapter_request_device_async_js(adapter_handle: Adapter) PromiseId;
extern "env" fn env_wgpu_poll_promise_js(promise_id: PromiseId) i32;
extern "env" fn env_wgpu_get_adapter_from_promise_js(promise_id: PromiseId) Adapter;
extern "env" fn env_wgpu_get_device_from_promise_js(promise_id: PromiseId) Device;
extern "env" fn env_wgpu_device_get_queue_js(device_handle: Device) Queue;

extern "env" fn env_wgpu_get_last_error_msg_ptr_js() [*c]const u8;
extern "env" fn env_wgpu_get_last_error_msg_len_js() usize;
extern "env" fn env_wgpu_copy_last_error_msg_js(buffer_ptr: [*c]u8, buffer_len: usize) void;
extern "env" fn env_wgpu_release_handle_js(type_id: u32, handle: u32) void;
extern "env" fn js_log_string(message_ptr: [*c]const u8, message_len: usize) void;

// --- Public API for Zig Application ---

pub fn log(message: []const u8) void {
    js_log_string(message.ptr, message.len);
}

fn simple_min(a: u32, b: u32) u32 {
    return if (a < b) a else b;
}

// Logs an error message retrieved from JS FFI into a stack buffer.
fn logJsError(comptime prefix: []const u8) void {
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

// Helper to poll a promise and handle errors
fn pollPromise(promise_id: PromiseId, comptime success_msg: []const u8, comptime failure_msg: []const u8) !bool {
    var retries: u32 = 0;
    const max_retries: u32 = 20;
    const spin_iterations: u32 = 50000; // Short spin, NOT FOR PRODUCTION

    while (retries < max_retries) : (retries += 1) {
        const status_val = env_wgpu_poll_promise_js(promise_id);
        const status = @as(PromiseStatus, @enumFromInt(status_val));

        switch (status) {
            .pending => {
                if (retries == max_retries - 1) {
                    log("Promise still pending after max retries.");
                }
                var i: u32 = 0;
                while (i < spin_iterations) : (i += 1) {
                    // Spin wait - replace with proper async yielding.
                }
                continue;
            },
            .fulfilled => {
                log(success_msg);
                return true;
            },
            .rejected => {
                logJsError(failure_msg);
                return false;
            },
        }
    }
    log("Promise polling timed out.");
    return false; // Timed out
}

fn genericErrorHandlerPromise(comptime context_msg: []const u8) void {
    logJsError(context_msg);
}

pub fn requestAdapter() !Adapter {
    log("Requesting WebGPU Adapter...");
    const promise_id = env_wgpu_request_adapter_async_js();
    if (promise_id == 0) {
        genericErrorHandlerPromise("E01: Failed to start adapter request (JS promise_id is 0). ");
        return error.AdapterRequestFailed;
    }

    const promise_ok = pollPromise(promise_id, "Adapter promise fulfilled.", "E02: Adapter promise rejected. ") catch |err| {
        log("E03: Error during adapter promise polling.");
        releaseHandle(HandleType.promise, promise_id);
        return err;
    };

    if (!promise_ok) {
        releaseHandle(HandleType.promise, promise_id);
        return error.AdapterRequestFailed;
    }

    const adapter_handle = env_wgpu_get_adapter_from_promise_js(promise_id);
    releaseHandle(HandleType.promise, promise_id);

    if (adapter_handle == 0) {
        genericErrorHandlerPromise("E04: Failed to get adapter handle from promise. ");
        return error.AdapterRequestFailed;
    }
    log("Adapter acquired.");
    return adapter_handle;
}

pub fn adapterRequestDevice(adapter: Adapter) !Device {
    log("Requesting WebGPU Device...");
    const promise_id = env_wgpu_adapter_request_device_async_js(adapter);
    if (promise_id == 0) {
        genericErrorHandlerPromise("E05: Failed to start device request (JS promise_id is 0). ");
        return error.DeviceRequestFailed;
    }

    const promise_ok = pollPromise(promise_id, "Device promise fulfilled.", "E06: Device promise rejected. ") catch |err| {
        log("E07: Error during device promise polling.");
        releaseHandle(HandleType.promise, promise_id);
        return err;
    };

    if (!promise_ok) {
        releaseHandle(HandleType.promise, promise_id);
        return error.DeviceRequestFailed;
    }

    const device_handle = env_wgpu_get_device_from_promise_js(promise_id);
    releaseHandle(HandleType.promise, promise_id);

    if (device_handle == 0) {
        genericErrorHandlerPromise("E08: Failed to get device handle from promise. ");
        return error.DeviceRequestFailed;
    }
    log("Device acquired.");
    return device_handle;
}

pub fn deviceGetQueue(device: Device) !Queue {
    log("Getting WebGPU Queue...");
    const queue_handle = env_wgpu_device_get_queue_js(device);
    if (queue_handle == 0) {
        genericErrorHandlerPromise("E09: Failed to get queue (JS queue_handle is 0). ");
        return error.QueueRetrievalFailed;
    }
    log("Queue acquired.");
    return queue_handle;
}

pub fn releaseHandle(handle_type: HandleType, handle: u32) void {
    if (handle == 0) return;
    env_wgpu_release_handle_js(@intFromEnum(handle_type), handle);
}
