const input_handler = @import("input_handler.zig");
const webgpu_handler = @import("webgpu_handler.zig");
// const audio_handler = @import("audio_handler.zig"); // Removed

// FFI import for JavaScript's console.log
// This is now delegated to webgpu.log from the FFI layer,
// which is wrapped by webgpu_handler.log or directly by webgpu_handler if needed.
// So, we don't need a direct extern "env" fn js_log_string here anymore if all logging goes via webgpu.log.
// extern "env" fn js_log_string(message_ptr: [*c]const u8, message_len: u32) void;

// The webgpu.log (from ffi) is expected to be used by webgpu_handler.
// If main.zig needs to log directly, it can use webgpu_handler.log or webgpu.log directly.
fn log(message: []const u8) void {
    // This direct log assumes webgpu.log is exposed correctly and globally available via the module.
    // It might be cleaner for main.zig to also use a log function from webgpu_handler if it adds context,
    // or directly use `webgpu.log` if the `webgpu_handler` is only for WebGPU state.
    // For now, let's assume webgpu_handler might expose its own log or we use webgpu.log from the FFI.
    // Let's use the webgpu ffi log directly for simplicity in main, or define a main_log.
    // For consistency and since webgpu_handler might not be fully initialized when _start begins logging,
    // it might be best to call the lowest level log if no allocator context is needed.
    // const webgpu = @import("../../../../src/webgpu.zig"); // Assuming direct path for now or it's part of webgpu_handler's export
    // webgpu.log(message); // This creates a circular dependency if webgpu_handler also imports it this way.
    // Let's assume for now that _start can log via webgpu_handler if it's initialized or a global log is setup.
    // For the initial _start message, we might need a raw FFI call if webgpu_handler is not ready.
    // This is tricky. Let's assume `webgpu_handler.log` is safe to call OR we make `webgpu.log` easily accessible.
    // For now, deferring complex logging setup. The webgpu.log in webgpu.zig itself is fine.
    // We will rely on webgpu_handler to have initialized its logging or use its log function.
    // webgpu_handler.log(message, .{}); // If webgpu_handler.log takes comptime args
    // The simplest is if webgpu.log is globally available. Let's assume that.
    const webgpu_ffi = @import("zig-wasm-ffi").webgpu; // Adjust if webgpu_handler re-exports it or use module.
    webgpu_ffi.log(message);
}

// New function to log frame updates without std.fmt
fn log_frame_update_info(count: u32, dt_ms: f32) void {
    _ = count;
    _ = dt_ms;
    log("Frame update processed by main.zig.");
    // More complex formatting without std.fmt would require manual int/float to string conversion.
}

var frame_count: u32 = 0;

pub export fn _start() void {
    log("Zig _start called from main.zig.");

    // Initialize WebGPU through the handler
    webgpu_handler.init() catch {
        // Log error using the direct log function as webgpu_handler.init might have failed before its log is fully usable.
        // Or, webgpu_handler.init itself should log detailed errors using webgpu.log from the FFI layer.
        log("WebGPU Handler initialization failed in main.zig.");
        // Further error details should have been logged by webgpu_handler.init or webgpu.zig FFI calls.
        // The error is already logged by the handler, we just need to stop execution here.
        return; // Exit _start if init fails
    };

    log("WebGPU Handler initialized successfully by main.zig.");
    // Access WGPU objects via webgpu_handler getters if needed
    // const adapter = webgpu_handler.getAdapter();
    // const device = webgpu_handler.getDevice();
    // const queue = webgpu_handler.getQueue();
    // log(std.fmt.comptimePrint("Main.zig sees Adapter: {d}, Device: {d}, Queue: {d}", .{adapter, device, queue}));
    // The above log needs a no_std string formatter.
    // For now, webgpu_handler.init() logs its own success and details.

    // TODO: Add more application-specific setup here that uses the WebGPU device/queue
}

// This function is called repeatedly from JavaScript (e.g., via requestAnimationFrame)
export fn update_frame(delta_time_ms: f32) void {
    frame_count += 1;
    log_frame_update_info(frame_count, delta_time_ms);

    input_handler.update();

    if (input_handler.was_left_mouse_button_just_pressed()) {
        log("Left mouse button was pressed (detected in main.zig).");
    }

    if (input_handler.was_right_mouse_button_just_pressed()) {
        log("Right mouse button was pressed (detected in main.zig).");
    }

    if (input_handler.was_space_just_pressed()) {
        log("Spacebar was just pressed (detected in main.zig)!");
    }

    // Defer deinitialization to when the Wasm module is about to be shut down if possible.
    // For a continuous running app, deinit is usually not called from update_frame.
    // If there was a specific shutdown signal from JS, then call webgpu_handler.deinit().
}

// Ensure that if the Wasm module has a way to be explicitly torn down by JS,
// an exported function could call webgpu_handler.deinit().
// For now, `_start` sets up and `update_frame` runs. Deinit in `_start` might be too early
// if `_start` is just an init and not the main loop itself.
// If JS calls _start once and then update_frame in a loop, then deinit should be handled
// by a separate exported shutdown function or managed by JS when the page unloads.
// The original defer in _start in the previous main.zig version would deinit immediately after _start finishes.
// We want WebGPU to stay alive for update_frame. So, deinit must be handled differently.

pub export fn _wasm_shutdown() void { // Example: JS could call this on page unload or explicit stop
    log("Wasm shutdown requested.");
    webgpu_handler.deinit();
    log("WebGPU handler deinitialized during Wasm shutdown.");
    // If gpa was used in main, deinit it here.
    // Note: `gpa` and `allocator` were removed from main.zig in this refactoring as webgpu.zig became no_std.
}
