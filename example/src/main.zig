const input_handler = @import("input_handler.zig");

// FFI import for JavaScript's console.log
// This can remain here if main.zig also needs to log directly,
// or it could be removed if all logging is delegated.
extern "env" fn js_log_string(message_ptr: [*c]const u8, message_len: u32) void;

// Helper function to log strings from Zig
fn log_info(message: []const u8) void {
    js_log_string(message.ptr, @intCast(message.len));
}

// This is the main entry point called by the Wasm runtime/JS after instantiation.
// It replaces the previous `pub fn main() void` for JS interaction.
pub export fn _start() void {
    log_info("[Main] _start() called. Initializing application.");
    // If input_handler had an init function, it would be called here:
    // input_handler.init();
}

// This function is called repeatedly from JavaScript (e.g., via requestAnimationFrame)
pub export fn update_frame() void {
    // 1. Update the input handler (which internally calls webinput.update_input_frame_start())
    input_handler.update();

    // 2. Application logic using the input handler's state
    if (input_handler.was_mouse_button_just_pressed(0)) { // Left mouse button
        const mouse_pos = input_handler.get_current_mouse_position();
        // Log that a click happened and we read the mouse position.
        // Actual coordinates would need f32-to-string or FFI for js_log_f32_pair.
        log_info("[Main] Left click detected via input_handler. Mouse position captured.");
        // To use mouse_pos.x, mouse_pos.y, you'd pass them to an FFI logger or format them.
        // For now, this access is enough to satisfy the linter that mouse_pos is used.
        _ = mouse_pos; // Explicitly acknowledge use if direct logging isn't done here.
    }

    if (input_handler.was_space_just_pressed()) {
        log_info("[Main] Spacebar was just pressed (detected via input_handler)!");
    }

    // Example of checking continuous key down state from input_handler
    // if (input_handler.is_key_down(input_handler.KEY_SPACE)) { // Assuming KEY_SPACE is exposed or use literal 32
    //     log_info("[Main] Spacebar is being held (polled from input_handler).");
    // }
}

// The original pub fn main() is no longer the primary JS entry point.
// It could be removed or repurposed for Zig-only initialization if Wasm
// execution starts via _start and doesn't implicitly call a "main" symbol.
// For clarity with _start being the JS entry, we can remove the old main.
