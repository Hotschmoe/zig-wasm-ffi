const webinput = @import("zig-wasm-ffi").webinput;

// FFI import for JavaScript's console.log
extern "env" fn js_log_string(message_ptr: [*c]const u8, message_len: u32) void;

// Helper function to log strings from Zig (application-level)
fn log_app_info(message: []const u8) void {
    // Simple prefix for now, avoiding std.fmt for freestanding
    const prefix = "[AppInputHandler] ";
    // This is a rudimentary way to concatenate. For more complex needs,
    // a custom freestanding-compatible formatter or passing multiple strings to JS would be better.
    var buffer: [128]u8 = undefined; // Ensure buffer is large enough
    var i: usize = 0;
    while (i < prefix.len and i < buffer.len) : (i += 1) {
        buffer[i] = prefix[i];
    }
    var j: usize = 0;
    while (j < message.len and (i + j) < buffer.len - 1) : (j += 1) { // -1 for null terminator if needed by C strings, though js_log_string takes len
        buffer[i + j] = message[j];
    }
    const final_len = i + j;
    js_log_string(&buffer, @intCast(final_len));
}

// --- Configuration & State (Application-Specific) ---
const KEY_SPACE: u32 = 32; // JavaScript event.keyCode for Spacebar
const MOUSE_LEFT_BUTTON: u32 = 0; // JavaScript event.button for Left Mouse Button
// Add other key/mouse constants your application specifically cares about.

// Optional: Track application-specific derived states if needed, e.g., mouse delta
var g_last_mouse_x: f32 = -1.0; // Use a sentinel value for first update
var g_last_mouse_y: f32 = -1.0;
var g_first_update_cycle: bool = true;

// --- Public API for Input Handler (Application Layer) ---

/// Call this once per frame, typically at the beginning of the main application update.
/// It updates the underlying webinput state and can perform handler-specific logic.
pub fn update() void {
    // 1. Update the core input state from the webinput library module
    webinput.update_input_frame_start();

    // 2. Handler-specific logic (e.g., logging, derived states for the application)
    const current_mouse_pos = webinput.get_mouse_position();
    if (g_first_update_cycle) {
        g_last_mouse_x = current_mouse_pos.x;
        g_last_mouse_y = current_mouse_pos.y;
        g_first_update_cycle = false;
        // log_app_info("Initial mouse position captured."); // Optional log
    } else {
        // Example: Log if mouse moved significantly (optional)
        if (current_mouse_pos.x != g_last_mouse_x or current_mouse_pos.y != g_last_mouse_y) {
            // log_app_info("Mouse moved."); // This can be very verbose, use with caution
            g_last_mouse_x = current_mouse_pos.x;
            g_last_mouse_y = current_mouse_pos.y;
        }
    }

    if (was_mouse_button_just_pressed(MOUSE_LEFT_BUTTON)) { // Using self-defined constant
        log_app_info("Left mouse button just pressed!");
    }

    const wheel = webinput.get_mouse_wheel_delta();
    if (wheel.dx != 0.0 or wheel.dy != 0.0) {
        // log_app_info("Mouse wheel scrolled."); // Can be verbose
    }

    if (was_space_just_pressed()) { // Using self-defined helper
        log_app_info("Spacebar just pressed!");
    }
}

/// Optional: if the input handler itself needed specific one-time setup.
// pub fn init() void {
//    log_app_info("Initialized.");
// }

// --- Getters for Application Use ---
// These functions provide an API for the main application,
// forwarding calls to the webinput module or providing app-specific helpers.

pub fn get_current_mouse_position() webinput.MousePosition {
    return webinput.get_mouse_position();
}

pub fn is_mouse_button_down(button_code: u32) bool {
    return webinput.is_mouse_button_down(button_code);
}

pub fn was_mouse_button_just_pressed(button_code: u32) bool {
    return webinput.was_mouse_button_just_pressed(button_code);
}

pub fn was_mouse_button_just_released(button_code: u32) bool {
    return webinput.was_mouse_button_just_released(button_code);
}

pub fn get_current_mouse_wheel_delta() webinput.MouseWheelDelta {
    return webinput.get_mouse_wheel_delta();
}

pub fn is_key_down(key_code: u32) bool {
    return webinput.is_key_down(key_code);
}

pub fn was_key_just_pressed(key_code: u32) bool {
    return webinput.was_key_just_pressed(key_code);
}

pub fn was_key_just_released(key_code: u32) bool {
    return webinput.was_key_just_released(key_code);
}

// Example of an application-specific helper
pub fn was_space_just_pressed() bool {
    return webinput.was_key_just_pressed(KEY_SPACE);
}

// Example of another application-specific helper for the left mouse button
pub fn was_left_mouse_button_just_pressed() bool {
    return webinput.was_mouse_button_just_pressed(MOUSE_LEFT_BUTTON);
}
