const webinput = @import("zig-wasm-ffi").webinput;

// FFI import for JavaScript's console.log
extern "env" fn js_log_string(message_ptr: [*c]const u8, message_len: u32) void;

// Helper function to log strings from Zig (application-level)
fn log_app_info(message: []const u8) void {
    const prefix = "[AppInputHandler] ";
    var buffer: [128]u8 = undefined; // Ensure buffer is large enough for prefix + message
    var current_len: usize = 0;

    // Copy prefix
    for (prefix) |char_code| {
        if (current_len >= buffer.len - 1) { // Space around - for linter
            break;
        }
        buffer[current_len] = char_code;
        current_len += 1;
    }
    // Copy message
    for (message) |char_code| {
        if (current_len >= buffer.len - 1) { // Space around - for linter
            break;
        }
        buffer[current_len] = char_code;
        current_len += 1;
    }
    js_log_string(&buffer, @intCast(current_len));
}

// --- Configuration & State (Application-Specific) ---
const KEY_SPACE: u32 = 32; // JavaScript event.keyCode for Spacebar
const KEY_A: u32 = 65;
const KEY_ENTER: u32 = 13;
const KEY_SHIFT_LEFT: u32 = 16; // Note: keyCode for Shift is often just 16 for both left/right

const MOUSE_LEFT_BUTTON: u32 = 0; // JavaScript event.button for Left Mouse Button
const MOUSE_MIDDLE_BUTTON: u32 = 1;
const MOUSE_RIGHT_BUTTON: u32 = 2;

var g_last_mouse_x: f32 = -1.0; // Use a sentinel value for first update
var g_last_mouse_y: f32 = -1.0;
var g_first_update_cycle: bool = true;

// Cached input states for the current frame
var g_was_left_mouse_just_pressed_this_frame: bool = false;
var g_was_right_mouse_just_pressed_this_frame: bool = false;
var g_was_space_just_pressed_this_frame: bool = false;

// --- Public API for Input Handler (Application Layer) ---
pub fn update() void {
    webinput.begin_input_frame_state_update();

    // Cache "just pressed" states for this frame
    g_was_left_mouse_just_pressed_this_frame = webinput.was_mouse_button_just_pressed(MOUSE_LEFT_BUTTON);
    g_was_right_mouse_just_pressed_this_frame = webinput.was_mouse_button_just_pressed(MOUSE_RIGHT_BUTTON);
    g_was_space_just_pressed_this_frame = webinput.was_key_just_pressed(KEY_SPACE);

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
    if (g_was_left_mouse_just_pressed_this_frame) { // Use cached state for logging
        log_app_info("Left mouse button just pressed!");
    }
    if (webinput.was_mouse_button_just_pressed(MOUSE_MIDDLE_BUTTON)) {
        log_app_info("Middle mouse button just pressed!");
    }
    if (webinput.was_mouse_button_just_pressed(MOUSE_RIGHT_BUTTON)) {
        log_app_info("Right mouse button just pressed!");
    }

    // Demonstrate checking multiple specific keys
    if (g_was_space_just_pressed_this_frame) { // Use cached state for logging
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

    webinput.end_input_frame_state_update();
}

// --- Getters for Application Use ---
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

pub fn was_space_just_pressed() bool {
    return g_was_space_just_pressed_this_frame; // Return cached state
}

pub fn was_left_mouse_button_just_pressed() bool {
    return g_was_left_mouse_just_pressed_this_frame; // Return cached state
}

pub fn was_right_mouse_button_just_pressed() bool {
    return g_was_right_mouse_just_pressed_this_frame; // Return cached state for right mouse
}
