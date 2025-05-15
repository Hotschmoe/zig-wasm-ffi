const webgpu = @import("zig-wasm-ffi").webgpu;

// Global state for WebGPU handles for this demo module
var g_adapter: webgpu.Adapter = 0;
var g_device: webgpu.Device = 0;
var g_queue: webgpu.Queue = 0;

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
    logSlice(formatAdapterInfo());
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

// Example of a helper function to format info without std.fmt.allocPrint
// This is very basic and uses a fixed buffer.
fn formatAdapterInfo() [100]u8 {
    var buffer: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    // This still uses std.io.fixedBufferStream and writer.print which are std lib.
    // To be truly no_std, manual string construction (e.g. with @memcpy and integer to string conversion)
    // would be needed here.
    // For now, this part will cause issues if `std` is not available/permissible at all.
    // Let's simplify it to just log a static string for now to avoid std dep here.
    _ = writer.print("Adapter: {d}, Device: {d}, Queue: {d}", .{ g_adapter, g_device, g_queue }) catch {
        return "Failed to format WebGPU info.";
    };
    // return fbs.getWritten(); // This returns a slice, but the func expects an array.
    // To return an array, you'd need to copy or ensure it fills and then maybe return a slice of it.
    // This is a placeholder showing the difficulty of no_std string formatting.

    // Simplified: return a comptime known string or just log internally.
    // The `log` function in this file is also simplified and doesn't use std.fmt.comptimePrint correctly
    // without std for formatting args. Let's assume the webgpu.log can handle basic strings.
    _ = g_adapter;
    _ = g_device;
    _ = g_queue; // use vars
    return "WebGPU Info (Adapter/Device/Queue IDs available internally)";
}

// To make this truly no_std, the `formatAdapterInfo` and `log` functions
// would need to avoid `std.io.fixedBufferStream` and `std.fmt` respectively for arguments.
// `webgpu.log` itself is an FFI call and is fine.
// For now, the `log` function is simplified and `formatAdapterInfo` is a placeholder.

const std = @import("std"); // For std.io.fixedBufferStream in formatAdapterInfo. REMOVE FOR TRUE NO_STD.
