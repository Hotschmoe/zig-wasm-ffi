const input_handler = @import("input_handler.zig");

// FFI import for JavaScript's console.log
// This can remain here if main.zig also needs to log directly,
// or it could be removed if all logging is delegated.
extern "env" fn js_log_string(message_ptr: [*c]const u8, message_len: u32) void;

// Helper function to log strings from Zig (application-level)
fn log_main_app_info(message: []const u8) void {
    // Simple prefix for now, avoiding std.fmt for freestanding
    const prefix = "[MainApp] ";
    var buffer: [128]u8 = undefined;
    var i: usize = 0;
    while (i < prefix.len and i < buffer.len) : (i += 1) {
        buffer[i] = prefix[i];
    }
    var j: usize = 0;
    while (j < message.len and (i + j) < buffer.len - 1) : (j += 1) {
        buffer[i + j] = message[j];
    }
    const final_len = i + j;
    js_log_string(&buffer, @intCast(final_len));
}

// This is the main entry point called by the Wasm runtime/JS after instantiation.
// It replaces the previous `pub fn main() void` for JS interaction.
pub export fn _start() void {
    log_main_app_info("_start() called. Application initialized.");
    // If input_handler had an explicit init function, it could be called here:
    // input_handler.init();
}

// This function is called repeatedly from JavaScript (e.g., via requestAnimationFrame)
pub export fn update_frame() void {
    // 1. Update the input handler (which internally calls webinput.update_input_frame_start())
    input_handler.update();

    // 2. Application logic using the input handler's state

    // Check for left mouse button click (using the specific helper from input_handler)
    if (input_handler.was_left_mouse_button_just_pressed()) {
        const mouse_pos = input_handler.get_current_mouse_position();
        // For logging mouse_pos.x and .y, we would need a f32 to string conversion
        // or an FFI function to log f32 pairs. For now, just log the event.
        log_main_app_info("Left mouse button clicked!");
        // Acknowledge use of mouse_pos to prevent unused variable warnings if not logging coordinates.
        _ = mouse_pos;
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
