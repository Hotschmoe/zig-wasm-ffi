const webgpu = @import("zig-wasm-ffi").webgpu;
const std = @import("std"); // Included for @memcpy, will evaluate if truly needed for no_std later

// Global state for WebGPU handles for this demo module
var g_adapter: webgpu.Adapter = 0;
var g_device: webgpu.Device = 0;
var g_queue: webgpu.Queue = 0;
var g_initialization_status: InitializationStatus = .pending;

const InitializationStatus = enum {
    pending,
    adapter_success,
    adapter_failed,
    device_success,
    device_failed,
    queue_success, // If queue retrieval also becomes async or for completion state
    queue_failed,
    complete,
    failed,
};

fn log(message: []const u8) void {
    webgpu.log(message);
}

// --- Exported Zig functions for JavaScript to call back into ---

pub export fn zig_receive_adapter(adapter_handle: webgpu.Adapter, status: u32) void {
    log("[WebGPUHandler] zig_receive_adapter called.");
    if (status == 1 and adapter_handle != 0) { // 1 for success
        g_adapter = adapter_handle;
        g_initialization_status = .adapter_success;
        log("[WebGPUHandler] Adapter received successfully. Requesting device...");
        webgpu.adapterRequestDevice(g_adapter);
    } else {
        g_initialization_status = .adapter_failed;
        webgpu.getAndLogWebGPUError("[WebGPUHandler] Failed to get adapter. ");
        log("[WebGPUHandler] Adapter request failed. Further initialization halted.");
    }
}

pub export fn zig_receive_device(device_handle: webgpu.Device, status: u32) void {
    log("[WebGPUHandler] zig_receive_device called.");
    if (status == 1 and device_handle != 0) { // 1 for success
        g_device = device_handle;
        g_initialization_status = .device_success;
        log("[WebGPUHandler] Device received successfully. Getting queue...");

        // Attempt to get the queue synchronously as part of the device success callback
        // const queue_maybe = webgpu.deviceGetQueue(g_device);
        // log("[WebGPUHandler] deviceGetQueue call attempted.");

        // Correctly handle the error union returned by deviceGetQueue
        if (webgpu.deviceGetQueue(g_device)) |q_handle| {
            g_queue = q_handle;
            g_initialization_status = .queue_success; // Or .complete if this is the last step
            log("[WebGPUHandler] Queue obtained successfully. Initialization complete.");
            g_initialization_status = .complete; // Mark as fully complete
        } else |err| {
            g_initialization_status = .queue_failed;
            webgpu.getAndLogWebGPUError("[WebGPUHandler] Failed to get queue. Error: " ++ @errorName(err) ++ ". ");
            log("[WebGPUHandler] Failed to get queue. Initialization failed.");
            g_initialization_status = .failed; // Mark as failed overall
        }
    } else {
        g_initialization_status = .device_failed;
        webgpu.getAndLogWebGPUError("[WebGPUHandler] Failed to get device. ");
        log("[WebGPUHandler] Device request failed. Further initialization halted.");
        g_initialization_status = .failed;
    }
}

// --- Public API for main.zig or other application logic ---

pub fn init() !void {
    log("[WebGPUHandler] Initializing WebGPU (async via callbacks)...");
    g_initialization_status = .pending;
    webgpu.requestAdapter(); // This will eventually call zig_receive_adapter
    // The actual success/failure is now determined by callbacks and status checks.
}

pub fn isInitialized() bool {
    return g_initialization_status == .complete;
}

pub fn hasFailed() bool {
    return g_initialization_status == .failed or
        g_initialization_status == .adapter_failed or
        g_initialization_status == .device_failed or
        g_initialization_status == .queue_failed;
}

pub fn getAdapter() webgpu.Adapter {
    return g_adapter;
}

pub fn getDevice() webgpu.Device {
    return g_device;
}

pub fn getQueue() webgpu.Queue {
    return g_queue;
}

pub fn deinit() void {
    log("[WebGPUHandler] Deinitializing WebGPU...");
    if (g_queue != 0) {
        webgpu.releaseHandle(.queue, g_queue);
        g_queue = 0;
        log("[WebGPUHandler] Queue released.");
    }
    if (g_device != 0) {
        webgpu.releaseHandle(.device, g_device);
        g_device = 0;
        log("[WebGPUHandler] Device released.");
    }
    if (g_adapter != 0) {
        webgpu.releaseHandle(.adapter, g_adapter);
        g_adapter = 0;
        log("[WebGPUHandler] Adapter released.");
    }
    g_initialization_status = .pending; // Reset status
    log("[WebGPUHandler] WebGPU deinitialized.");
}
