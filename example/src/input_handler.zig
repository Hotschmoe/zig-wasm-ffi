const webinput = @import("zig-wasm-ffi").webinput;
const std = @import("std");

// FFI import for JavaScript's console.log
extern "env" fn js_log_string(message_ptr: [*c]const u8, message_len: u32) void;

// Helper function to log strings from Zig (application-level)
fn log_app_info(message: []const u8) void {
    const prefix = "[AppInputHandler] ";
    var buffer: [128]u8 = undefined; // Ensure buffer is large enough for prefix + message
    var current_len: usize = 0;

    // Copy prefix
    for (prefix) |char_code| {
        if (current_len >= buffer.len - 1) { // Corrected spacing
            break;
        }
        buffer[current_len] = char_code;
        current_len += 1;
    }
    // Copy message
    for (message) |char_code| {
        if (current_len >= buffer.len - 1) { // Corrected spacing
            break;
        }
        buffer[current_len] = char_code;
        current_len += 1;
    }
    js_log_string(&buffer, @intCast(current_len));
}

// More specific log for button codes if needed, or just use names
fn log_mouse_button_event(button_code: u32, action: []const u8) void {
    const prefix = "[AppInputHandler] ";
    var message_buf: [64]u8 = undefined; // Buffer for the specific message part
    var message_len: usize = 0;

    switch (button_code) {
        MOUSE_LEFT_BUTTON => message_len = (try std.fmt.bufPrint(&message_buf, "Left mouse button {}", .{action}) catch 0).len,
        MOUSE_MIDDLE_BUTTON => message_len = (try std.fmt.bufPrint(&message_buf, "Middle mouse button {}", .{action}) catch 0).len,
        MOUSE_RIGHT_BUTTON => message_len = (try std.fmt.bufPrint(&message_buf, "Right mouse button {}", .{action}) catch 0).len,
        else => message_len = (try std.fmt.bufPrint(&message_buf, "Mouse button {} {}", .{ button_code, action }) catch 0).len,
    }
    if (message_len == 0) return; // Formatting failed or not needed

    var final_log_buf: [128]u8 = undefined;
    var current_final_len: usize = 0;
    // Copy prefix
    for (prefix) |char_code| {
        if (current_final_len >= final_log_buf.len - 1) break;
        final_log_buf[current_final_len] = char_code;
        current_final_len += 1;
    }
    // Copy formatted message
    for (message_buf[0..message_len]) |char_code| {
        if (current_final_len >= final_log_buf.len - 1) break;
        final_log_buf[current_final_len] = char_code;
        current_final_len += 1;
    }
    js_log_string(&final_log_buf, @intCast(current_final_len));
}

// --- Configuration & State (Application-Specific) ---
const KEY_SPACE: u32 = 32; // JavaScript event.keyCode for Spacebar
const KEY_A: u32 = 65;
const KEY_ENTER: u32 = 13;
const KEY_SHIFT_LEFT: u32 = 16; // Note: keyCode for Shift is often just 16 for both left/right
// Add other key/mouse constants your application specifically cares about.

const MOUSE_LEFT_BUTTON: u32 = 0; // JavaScript event.button for Left Mouse Button
const MOUSE_MIDDLE_BUTTON: u32 = 1;
const MOUSE_RIGHT_BUTTON: u32 = 2;

// Optional: Track application-specific derived states if needed, e.g., mouse delta
var g_last_mouse_x: f32 = -1.0; // Use a sentinel value for first update
var g_last_mouse_y: f32 = -1.0;
var g_first_update_cycle: bool = true;

// --- Public API for Input Handler (Application Layer) ---

/// Call this once per frame, typically at the beginning of the main application update.
/// It updates the underlying webinput state and can perform handler-specific logic.
pub fn update() void {
    // 1. Begin frame state update (resets accumulators in webinput)
    webinput.begin_input_frame_state_update();

    // 2. Handler-specific logic (e.g., logging, derived states for the application)
    const current_mouse_pos = webinput.get_mouse_position();
    if (g_first_update_cycle) {
        g_last_mouse_x = current_mouse_pos.x;
        g_last_mouse_y = current_mouse_pos.y;
        g_first_update_cycle = false;
    } else {
        if (current_mouse_pos.x != g_last_mouse_x or current_mouse_pos.y != g_last_mouse_y) {
            g_last_mouse_x = current_mouse_pos.x;
            g_last_mouse_y = current_mouse_pos.y;
        }
    }

    // Demonstrate checking multiple mouse buttons
    if (webinput.was_mouse_button_just_pressed(MOUSE_LEFT_BUTTON)) {
        log_app_info("Left mouse button just pressed!");
    }
    if (webinput.was_mouse_button_just_pressed(MOUSE_MIDDLE_BUTTON)) {
        log_app_info("Middle mouse button just pressed!");
    }
    if (webinput.was_mouse_button_just_pressed(MOUSE_RIGHT_BUTTON)) {
        log_app_info("Right mouse button just pressed!");
    }
    // For mouse buttons 3 and 4, you might not have them, but could add checks:
    // if (webinput.was_mouse_button_just_pressed(3)) { log_app_info("Mouse button 3 (Back) just pressed!"); }
    // if (webinput.was_mouse_button_just_pressed(4)) { log_app_info("Mouse button 4 (Forward) just pressed!"); }

    // Demonstrate checking multiple specific keys
    if (webinput.was_key_just_pressed(KEY_SPACE)) {
        log_app_info("Spacebar just pressed!");
    }
    if (webinput.was_key_just_pressed(KEY_A)) {
        log_app_info("'A' key just pressed!");
    }
    if (webinput.was_key_just_pressed(KEY_ENTER)) {
        log_app_info("Enter key just pressed!");
    }
    if (webinput.was_key_just_pressed(KEY_SHIFT_LEFT)) {
        log_app_info("Shift key just pressed!");
    }

    const wheel = webinput.get_mouse_wheel_delta();
    if (wheel.dx != 0.0 or wheel.dy != 0.0) {
        // log_app_info("Mouse wheel scrolled."); // Can be verbose
    }

    // 3. End frame state update (snapshots current input state to previous state in webinput)
    webinput.end_input_frame_state_update();
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
