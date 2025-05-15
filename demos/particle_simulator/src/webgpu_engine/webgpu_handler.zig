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

// --- Callbacks Implemented by the Application (this handler) ---

pub export fn zig_receive_adapter(adapter_handle: webgpu.Adapter, status: u32) void {
    if (status == 0) { // 0 for success
        log("[WebGPUHandler-CB] Adapter received successfully.");
        g_adapter = adapter_handle;
        g_initialization_status = .adapter_success;

        // Automatically request device after adapter is acquired
        if (g_adapter != 0) {
            log("[WebGPUHandler-CB] Requesting device...");
            webgpu.adapterRequestDevice(g_adapter);
        } else {
            log("[WebGPUHandler-CB] Adapter handle is 0, cannot request device.");
            g_initialization_status = .adapter_failed; // Or a more specific error
            // Signal failure to the main application logic if possible
        }
    } else { // Error
        log("[WebGPUHandler-CB] Failed to receive adapter.");
        webgpu.getAndLogWebGPUError("[WebGPUHandler-CB] Adapter Request Error: ");
        g_initialization_status = .adapter_failed;
        // Signal failure to the main application logic
    }
}

pub export fn zig_receive_device(device_handle: webgpu.Device, status: u32) void {
    if (status == 0) { // 0 for success
        log("[WebGPUHandler-CB] Device received successfully.");
        g_device = device_handle;
        g_initialization_status = .device_success;

        // Automatically get queue after device is acquired
        if (g_device != 0) {
            log("[WebGPUHandler-CB] Getting queue...");
            const queue_maybe = webgpu.deviceGetQueue(g_device);
            if (queue_maybe) |q_handle| {
                g_queue = q_handle;
                log("[WebGPUHandler-CB] Queue acquired successfully.");
                log("[WebGPUHandler] WebGPU Initialized Fully via Callbacks.");
                const info_array = formatAdapterInfo();
                logSlice(info_array[0..ADAPTER_INFO_STATIC_MSG.len]);
                g_initialization_status = .complete;
            } else {
                log("[WebGPUHandler-CB] Failed to get queue.");
                // getAndLogWebGPUError is called by deviceGetQueue itself on failure
                g_initialization_status = .queue_failed;
                g_initialization_status = .failed; // Overall failure
            }
        } else {
            log("[WebGPUHandler-CB] Device handle is 0, cannot get queue.");
            g_initialization_status = .device_failed; // Or a more specific error
            g_initialization_status = .failed; // Overall failure
        }
    } else { // Error
        log("[WebGPUHandler-CB] Failed to receive device.");
        webgpu.getAndLogWebGPUError("[WebGPUHandler-CB] Device Request Error: ");
        g_initialization_status = .device_failed;
        g_initialization_status = .failed; // Overall failure
    }
}

// Helper comptime string for formatAdapterInfo
const ADAPTER_INFO_STATIC_MSG = "WebGPU Initialized: Adapter, Device, Queue acquired.";

fn logSlice(slice: []const u8) void {
    webgpu.log(slice);
}

pub fn init() !void {
    log("[WebGPUHandler] Initializing WebGPU (async via callbacks)...", .{});
    g_initialization_status = .pending;
    // Request adapter; the rest of the initialization flows through callbacks
    webgpu.requestAdapter();

    // Since initialization is now asynchronous and driven by callbacks,
    // this init() function cannot immediately return success/failure of the full WebGPU setup.
    // The application will need to check g_initialization_status or have a separate mechanism
    // to know when WebGPU is ready if it needs to wait before proceeding with GPU operations.
    // For now, init() completes its task of *starting* the initialization.
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

pub fn deinit() void {
    log("[WebGPUHandler] Deinitializing WebGPU...", .{});
    // Check if handles are valid before trying to release, as they might not have been acquired
    if (g_queue != 0) {
        webgpu.releaseHandle(.queue, g_queue);
        g_queue = 0;
    }
    if (g_device != 0) {
        webgpu.releaseHandle(.device, g_device);
        g_device = 0;
    }
    if (g_adapter != 0) {
        webgpu.releaseHandle(.adapter, g_adapter);
        g_adapter = 0;
    }
    g_initialization_status = .pending; // Reset status
    log("[WebGPUHandler] WebGPU handles released.", .{});
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

fn formatAdapterInfo() [ADAPTER_INFO_STATIC_MSG.len + 1]u8 { // +1 for null terminator
    var buffer: [ADAPTER_INFO_STATIC_MSG.len + 1]u8 = undefined;
    @memcpy(buffer[0..ADAPTER_INFO_STATIC_MSG.len], ADAPTER_INFO_STATIC_MSG);
    buffer[ADAPTER_INFO_STATIC_MSG.len] = 0; // Null terminate
    return buffer;
}
