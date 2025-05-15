const input_handler = @import("input_handler.zig");
const audio_handler = @import("audio_handler.zig");

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
    log_main_app_info("_start() called. Application initialized.");
    // input_handler.init_input_system(); // Removed: No specific init in input_handler.zig
    // Core FFI state init is handled by audio_handler or could be called directly if needed.
    audio_handler.init_audio_system();
}

// This function is called repeatedly from JavaScript (e.g., via requestAnimationFrame)
export fn update_frame(delta_time_ms: f32) void {
    frame_count += 1;
    log_frame_update(frame_count, delta_time_ms);

    input_handler.update(); // Corrected: Was input_handler.process_events()
    audio_handler.process_audio_events();

    if (input_handler.was_left_mouse_button_just_pressed()) {
        js_log_string("Left mouse button just pressed!", 31);
        audio_handler.trigger_explosion_sound();
    }

    // Check for right mouse button press to toggle background music
    if (input_handler.was_right_mouse_button_just_pressed()) {
        log_main_app_info("Right mouse button just pressed! Toggling background music...");
        audio_handler.trigger_toggle_background_music();
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
