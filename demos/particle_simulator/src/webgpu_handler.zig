const webgpu = @import("zig-wasm-ffi").webgpu;

// Global state for WebGPU handles for this demo module
var g_adapter: webgpu.Adapter = 0;
var g_device: webgpu.Device = 0;
var g_queue: webgpu.Queue = 0;

// Helper comptime string for formatAdapterInfo
const ADAPTER_INFO_STATIC_MSG = "WebGPU Initialized: Adapter, Device, Queue acquired.";

fn log(comptime message: []const u8, comptime args: anytype) void {
    // Assuming webgpu.log is available from the FFI layer
    // webgpu.log(std.fmt.comptimePrint(message, args)); // This would require std
    // For no_std, we can use a simpler logging approach if webgpu.log can take slices directly
    // Or implement a simple formatter here if needed. For now, direct log calls.
    _ = args;
    webgpu.log(message); // Simplified for now
}

fn logSlice(slice: []const u8) void {
    webgpu.log(slice);
}

pub fn init() !void {
    log("[WebGPUHandler] Initializing WebGPU...", .{});

    g_adapter = webgpu.requestAdapter() catch |err| {
        log("[WebGPUHandler] Failed to request adapter.", .{});
        return err;
    };
    if (g_adapter == 0) {
        log("[WebGPUHandler] Adapter handle is 0 after request.", .{});
        return error.InvalidAdapter;
    }
    // log("[WebGPUHandler] Adapter ID: {d}", .{g_adapter});

    g_device = webgpu.adapterRequestDevice(g_adapter) catch |err| {
        log("[WebGPUHandler] Failed to request device.", .{});
        return err;
    };
    if (g_device == 0) {
        log("[WebGPUHandler] Device handle is 0 after request.", .{});
        return error.InvalidDevice;
    }
    // log("[WebGPUHandler] Device ID: {d}", .{g_device});

    g_queue = webgpu.deviceGetQueue(g_device) catch |err| {
        log("[WebGPUHandler] Failed to get queue.", .{});
        return err;
    };
    if (g_queue == 0) {
        log("[WebGPUHandler] Queue handle is 0 after request.", .{});
        return error.InvalidQueue;
    }
    // log("[WebGPUHandler] Queue ID: {d}", .{g_queue});

    log("[WebGPUHandler] WebGPU Initialized Successfully.", .{});
    const info_array = formatAdapterInfo();
    logSlice(info_array[0..ADAPTER_INFO_STATIC_MSG.len]);
}

pub fn deinit() void {
    log("[WebGPUHandler] Deinitializing WebGPU...", .{});
    webgpu.releaseHandle(webgpu.HandleType.queue, g_queue);
    webgpu.releaseHandle(webgpu.HandleType.device, g_device);
    webgpu.releaseHandle(webgpu.HandleType.adapter, g_adapter);
    g_queue = 0;
    g_device = 0;
    g_adapter = 0;
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

// Example of a helper function to format info without std.fmt.
// This is very basic and uses a fixed buffer.
fn formatAdapterInfo() [100]u8 {
    var buffer: [100]u8 = undefined;

    // Ensure the message fits, leaving space for a null terminator if desired for other uses.
    comptime if (ADAPTER_INFO_STATIC_MSG.len >= buffer.len) { // >= to leave space for null terminator if we add one
        @compileError("Adapter info message too long for buffer");
    };

    @memcpy(buffer[0..ADAPTER_INFO_STATIC_MSG.len], ADAPTER_INFO_STATIC_MSG);

    // Optional: Null terminate the string in the buffer.
    // This is good practice if the buffer might be read by C-style functions.
    // logSlice takes a well-defined slice, so null termination isn't strictly necessary for it.
    buffer[ADAPTER_INFO_STATIC_MSG.len] = 0;

    // Optional: Fill the rest of the buffer, e.g., with spaces, if a full "initialized" buffer is desired.
    // var i = ADAPTER_INFO_STATIC_MSG.len + 1;
    // while (i < buffer.len) : (i += 1) {
    //     buffer[i] = ' '; // or 0
    // }

    return buffer;
}

// To make this truly no_std, the `formatAdapterInfo` and `log` functions
// would need to avoid `std.io.fixedBufferStream` and `std.fmt` respectively for arguments.
// `webgpu.log` itself is an FFI call and is fine.
// For now, the `log` function is simplified and `formatAdapterInfo` is a placeholder.
