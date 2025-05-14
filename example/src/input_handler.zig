const webinput = @import("zig-wasm-ffi").webinput;

// FFI import for JavaScript's console.log (duplicated for now for self-containment)
// In a larger app, you might centralize FFI declarations or pass a logger.
extern "env" fn js_log_string(message_ptr: [*c]const u8, message_len: u32) void;

// Helper function to log strings from Zig
fn log_info(message: []const u8) void {
    js_log_string(message.ptr, @intCast(message.len));
}

// --- Configuration & State ---
const KEY_SPACE: u32 = 32;
// Add other key codes your input handler might specifically track or provide helpers for.

var g_last_mouse_x: f32 = -1.0;
var g_last_mouse_y: f32 = -1.0;

// --- Public API for Input Handler ---

/// Call this once per frame, typically at the beginning.
/// It updates the underlying webinput state and can perform handler-specific logic.
pub fn update() void {
    // 1. Update the core input state from the webinput module
    webinput.update_input_frame_start();

    // 2. Handler-specific logic (e.g., logging, derived states)
    const mouse_pos = webinput.get_mouse_position();
    if (mouse_pos.x != g_last_mouse_x or mouse_pos.y != g_last_mouse_y) {
        log_info("[InputHandler] Mouse moved.");
        g_last_mouse_x = mouse_pos.x;
        g_last_mouse_y = mouse_pos.y;
        // In a real app, you might set a flag here: g_mouse_moved_this_frame = true;
    }

    if (webinput.was_mouse_button_just_pressed(0)) { // Left mouse button
        log_info("[InputHandler] Left mouse button just pressed!");
    }

    const wheel = webinput.get_mouse_wheel_delta();
    if (wheel.dx != 0.0 or wheel.dy != 0.0) {
        log_info("[InputHandler] Mouse wheel scrolled.");
    }

    if (webinput.was_key_just_pressed(KEY_SPACE)) {
        log_info("[InputHandler] Spacebar just pressed!");
    }
}

/// No explicit init needed for this simple version, but could be added.
// pub fn init() void {
//    log_info("[InputHandler] Initialized.");
// }

// --- Getters for Application Use ---
// These functions provide a cleaner API for the main application
// and can encapsulate more complex logic if needed later.

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

// Example of a more specific getter
pub fn was_space_just_pressed() bool {
    return webinput.was_key_just_pressed(KEY_SPACE);
}
