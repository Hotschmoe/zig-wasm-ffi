const input_handler = @import("input_handler.zig");
const webgpu_handler = @import("webgpu_handler.zig");
// const audio_handler = @import("audio_handler.zig"); // Removed

// FFI import for JavaScript's console.log
// This can remain here if main.zig also needs to log directly,
// or it could be removed if all logging is delegated.
extern "env" fn js_log_string(message_ptr: [*c]const u8, message_len: u32) void;

// Helper function to log strings from Zig, prefixed for this main application module
fn log_main_app_info(message: []const u8) void {
    const prefix = "[MainApp] ";
    var buffer: [128]u8 = undefined; // Assuming messages + prefix won't exceed 128 bytes
    var i: usize = 0;
    while (i < prefix.len and i < buffer.len) : (i += 1) {
        buffer[i] = prefix[i];
    }
    var j: usize = 0;
    while (j < message.len and (i + j) < buffer.len - 1) : (j += 1) { // -1 for null terminator if needed by C
        buffer[i + j] = message[j];
    }
    const final_len = i + j;
    js_log_string(&buffer, @intCast(final_len));
}

// New function to log frame updates
fn log_frame_update(count: u32, dt_ms: f32) void {
    _ = count; // Acknowledge use to prevent unused variable error
    _ = dt_ms; // Acknowledge use
    log_main_app_info("Frame update processed.");
}

var frame_count: u32 = 0;

// This is the main entry point called by the Wasm runtime/JS after instantiation.
// It replaces the previous `pub fn main() void` for JS interaction.
pub export fn _start() void {
    log("Zig _start called. Initializing WebGPU FFI...");

    var adapter: webgpu.Adapter = 0;
    var device: webgpu.Device = 0;
    var queue: webgpu.Queue = 0;

    // Defer release of handles
    defer {
        webgpu.releaseHandle(webgpu.HandleType.queue, queue);
        webgpu.releaseHandle(webgpu.HandleType.device, device);
        webgpu.releaseHandle(webgpu.HandleType.adapter, adapter);
        log("WebGPU handles released (if acquired).");
        if (gpa.deinit() == .leak) {
            log("Memory leak detected in GeneralPurposeAllocator!");
        }
    }

    adapter = webgpu.requestAdapter(allocator) catch |err| {
        log(std.fmt.comptimePrint("Failed to request adapter: {}", .{err}));
        return;
    };
    if (adapter == 0) {
        log("Adapter handle is 0 after successful request function call. This shouldn't happen if no error was returned.");
        return;
    }

    device = webgpu.adapterRequestDevice(allocator, adapter) catch |err| {
        log(std.fmt.comptimePrint("Failed to request device: {}", .{err}));
        return;
    };
    if (device == 0) {
        log("Device handle is 0 after successful request function call.");
        return;
    }

    queue = webgpu.deviceGetQueue(allocator, device) catch |err| {
        log(std.fmt.comptimePrint("Failed to get queue: {}", .{err}));
        return;
    };
    if (queue == 0) {
        log("Queue handle is 0 after successful get function call.");
        return;
    }

    log("Successfully acquired WebGPU Adapter, Device, and Queue!");
    log(std.fmt.comptimePrint("Adapter ID: {d}, Device ID: {d}, Queue ID: {d}", .{ adapter, device, queue }));

    // TODO: Add more WebGPU operations here using the handles
}

// This function is called repeatedly from JavaScript (e.g., via requestAnimationFrame)
export fn update_frame(delta_time_ms: f32) void {
    frame_count += 1;
    log_frame_update(frame_count, delta_time_ms);

    input_handler.update();
    // audio_handler.process_audio_events(); // Removed

    if (input_handler.was_left_mouse_button_just_pressed()) {
        // js_log_string("Left mouse button just pressed!", 31); // Removed
        // audio_handler.trigger_explosion_sound(); // Removed
        // For a base input demo, we can simply log via input_handler's internal logging
        // or add a generic log_main_app_info here if specific main app action is taken.
        log_main_app_info("Left mouse button was pressed (detected in main.zig).");
    }

    // Check for right mouse button press
    if (input_handler.was_right_mouse_button_just_pressed()) {
        // audio_handler.trigger_toggle_background_music(); // Removed
        log_main_app_info("Right mouse button was pressed (detected in main.zig).");
    }

    // Check for spacebar press (using the specific helper from input_handler)
    if (input_handler.was_space_just_pressed()) {
        log_main_app_info("Spacebar was just pressed!");
    }

    // Example: Continuous check for a key being held down (e.g., 'C' key - keyCode 67)
    // if (input_handler.is_key_down(67)) { // 67 is 'C'
    //     log_main_app_info("'C' key is being held down.");
    // }
}

// The original pub fn main() is no longer the primary JS entry point.
// It could be removed or repurposed for Zig-only initialization if Wasm
// execution starts via _start and doesn't implicitly call a "main" symbol.
// For clarity with _start being the JS entry, we can remove the old main.
