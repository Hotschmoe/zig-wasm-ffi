const input_handler = @import("input_handler.zig");
const webgpu_handler = @import("webgpu_engine/webgpu_handler.zig");
const webgpu_ffi = @import("zig-wasm-ffi").webgpu; // FFI library
// const audio_handler = @import("audio_handler.zig"); // Removed

// FFI import for JavaScript's console.log
// This is now delegated to webgpu.log from the FFI layer,
// which is wrapped by webgpu_handler.log or directly by webgpu_handler if needed.
// So, we don't need a direct extern "env" fn js_log_string here anymore if all logging goes via webgpu.log.
// extern "env" fn js_log_string(message_ptr: [*c]const u8, message_len: u32) void;

// The webgpu.log (from ffi) is expected to be used by webgpu_handler.
// If main.zig needs to log directly, it can use webgpu_handler.log or webgpu.log directly.
fn log(message: []const u8) void {
    webgpu_ffi.log(message);
}

// New function to log frame updates without std.fmt
fn log_frame_update_info(count: u32, dt_ms: f32) void {
    _ = count;
    _ = dt_ms;
    log("Frame update processed by main.zig.");
    // For more complex formatting, would need to implement int/float to string for wasm32-freestanding
    // For now, keeping it simple.
}

var frame_count: u32 = 0;

pub export fn _start() void {
    log("Zig _start called from main.zig.");

    // Initialize WebGPU through the handler
    // The init function itself no longer returns an error directly based on the `!void` change.
    // Error state is checked via isInitialized() / hasFailed() after async callbacks.
    webgpu_handler.init() catch |err| {
        // This catch block might be for a different type of error if init can still throw some.
        // For now, assuming init() starts the process and errors are async.
        log("WebGPU Handler init() call failed synchronously. Error: " ++ @errorName(err));
        return;
    };

    log("WebGPU Handler init call made. Check console for async callback status.");

    // Debug printing for struct offsets - using webgpu_ffi.log
    log("--- WebGPU Struct Offsets (main.zig) ---");
    // Manual formatting for offsets - this is cumbersome without std.fmt
    // Consider a very basic int_to_string helper if this is needed extensively,
    // or accept that logs will be more verbose/separate.
    log("BufferDescriptor.label offset: TODO_log_offset"); // @offsetOf(webgpu_ffi.BufferDescriptor, "label")
    log("BufferDescriptor.size offset: TODO_log_offset"); // @offsetOf(webgpu_ffi.BufferDescriptor, "size")
    log("BufferDescriptor.usage offset: TODO_log_offset"); // @offsetOf(webgpu_ffi.BufferDescriptor, "usage")
    log("BufferDescriptor.mappedAtCreation offset: TODO_log_offset"); // @offsetOf(webgpu_ffi.BufferDescriptor, "mappedAtCreation")
    log(" ---- ");
    log("ShaderModuleDescriptor.label offset: TODO_log_offset"); // @offsetOf(webgpu_ffi.ShaderModuleDescriptor, "label")
    log("ShaderModuleDescriptor.wgsl_code offset: TODO_log_offset"); // @offsetOf(webgpu_ffi.ShaderModuleDescriptor, "wgsl_code")
    log(" ---- ");
    log("ShaderModuleWGSLDescriptor.code_ptr offset: TODO_log_offset"); // @offsetOf(webgpu_ffi.ShaderModuleWGSLDescriptor, "code_ptr")
    log("ShaderModuleWGSLDescriptor.code_len offset: TODO_log_offset"); // @offsetOf(webgpu_ffi.ShaderModuleWGSLDescriptor, "code_len")
    log("--- End WebGPU Struct Offsets ---");
    // For now, I've replaced the dynamic offset logging with placeholders ("TODO_log_offset")
    // because implementing a robust int-to-string without std for wasm32-freestanding
    // is a bit involved for this quick fix. The key is removing `std.debug.print`.
    // If these specific offset logs are critical, a simple int-to-string can be added later.

    // The original message assumed success or pending. We should rely on isInitialized() in update_frame.
    log("Initial setup in _start complete. WebGPU initialization is asynchronous.");
}

// This function is called repeatedly from JavaScript (e.g., via requestAnimationFrame)
export fn update_frame(delta_time_ms: f32) void {
    if (!webgpu_handler.isInitialized()) {
        if (webgpu_handler.hasFailed()) {
            // log("WebGPU initialization failed, skipping update_frame logic."); // Log once or manage state
        } else {
            // log("WebGPU not yet initialized, skipping update_frame logic."); // Log once or manage state
        }
        return;
    }
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
}

// Ensure that if the Wasm module has a way to be explicitly torn down by JS,
// an exported function could call webgpu_handler.deinit().
// For now, `_start` sets up and `update_frame` runs. Deinit in `_start` might be too early
// if `_start` is just an init and not the main loop itself.
// If JS calls _start once and then update_frame in a loop, then deinit should be handled
// by a separate exported shutdown function or managed by JS when the page unloads.
// The original defer in _start in the previous main.zig version would deinit immediately after _start finishes.
// We want WebGPU to stay alive for update_frame. So, deinit must be handled differently.

pub export fn _wasm_shutdown() void {
    log("Wasm shutdown requested.");
    webgpu_handler.deinit();
    log("WebGPU handler deinitialized during Wasm shutdown.");
    // If gpa was used in main, deinit it here.
    // Note: `gpa` and `allocator` were removed from main.zig in this refactoring as webgpu.zig became no_std.
}
