// zig-wasm-ffi/src/webinput.zig

// --- Configuration ---
pub const MAX_KEY_CODES: usize = 256;
pub const MAX_MOUSE_BUTTONS: usize = 5; // 0:Left, 1:Middle, 2:Right, 3:Back, 4:Forward

// --- Mouse State ---
const MouseState = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    buttons_down: [MAX_MOUSE_BUTTONS]bool = [_]bool{false} ** MAX_MOUSE_BUTTONS,
    prev_buttons_down: [MAX_MOUSE_BUTTONS]bool = [_]bool{false} ** MAX_MOUSE_BUTTONS,
    wheel_delta_x: f32 = 0.0, // Accumulated delta for the current frame
    wheel_delta_y: f32 = 0.0, // Accumulated delta for the current frame
};
var g_mouse_state: MouseState = .{};

// --- Keyboard State ---
const KeyboardState = struct {
    keys_down: [MAX_KEY_CODES]bool = [_]bool{false} ** MAX_KEY_CODES,
    prev_keys_down: [MAX_KEY_CODES]bool = [_]bool{false} ** MAX_KEY_CODES,
};
var g_keyboard_state: KeyboardState = .{};

// --- Exported Zig functions for JavaScript to call (Input Callbacks) ---

/// Called by JavaScript when the mouse moves.
/// Coordinates are relative to the canvas.
pub export fn zig_internal_on_mouse_move(x: f32, y: f32) void {
    g_mouse_state.x = x;
    g_mouse_state.y = y;
}

/// Called by JavaScript on mouse button press or release.
/// Coordinates are relative to the canvas.
pub export fn zig_internal_on_mouse_button(button_code: u32, is_down: bool, x: f32, y: f32) void {
    g_mouse_state.x = x;
    g_mouse_state.y = y;
    if (button_code < MAX_MOUSE_BUTTONS) {
        g_mouse_state.buttons_down[button_code] = is_down;
    }
}

/// Called by JavaScript on mouse wheel scroll.
/// Deltas are normalized pixel values.
pub export fn zig_internal_on_mouse_wheel(delta_x: f32, delta_y: f32) void {
    g_mouse_state.wheel_delta_x += delta_x;
    g_mouse_state.wheel_delta_y += delta_y;
}

/// Called by JavaScript on key press or release.
pub export fn zig_internal_on_key_event(key_code: u32, is_down: bool) void {
    if (key_code < MAX_KEY_CODES) {
        g_keyboard_state.keys_down[key_code] = is_down;
    }
}

// --- Public API for Zig Application ---

/// Call this at the BEGINNING of your application's per-frame input processing sequence.
/// It resets per-frame accumulators (e.g., mouse wheel delta).
/// The crucial update of previous button/key states is now done in `end_input_frame_state_update`.
pub fn begin_input_frame_state_update() void {
    g_mouse_state.wheel_delta_x = 0.0;
    g_mouse_state.wheel_delta_y = 0.0;
}

/// Call this at the END of your application's per-frame input processing sequence,
/// after all input checks (like was_mouse_button_just_pressed) for the current frame are done.
/// This snapshots the current button/key states to be used as the "previous" states in the next frame.
pub fn end_input_frame_state_update() void {
    g_mouse_state.prev_buttons_down = g_mouse_state.buttons_down;
    g_keyboard_state.prev_keys_down = g_keyboard_state.keys_down;
}

// Mouse Getters

/// Represents the mouse position (x, y coordinates).
pub const MousePosition = struct { x: f32, y: f32 };

/// Gets the current mouse cursor position relative to the canvas.
pub fn get_mouse_position() MousePosition {
    return .{ .x = g_mouse_state.x, .y = g_mouse_state.y };
}

/// Checks if a specific mouse button is currently held down.
/// button_code: 0=Left, 1=Middle, 2=Right, 3=Back, 4=Forward.
pub fn is_mouse_button_down(button_code: u32) bool {
    if (button_code < MAX_MOUSE_BUTTONS) {
        return g_mouse_state.buttons_down[button_code];
    }
    return false;
}

/// Checks if a specific mouse button was just pressed in this frame.
pub fn was_mouse_button_just_pressed(button_code: u32) bool {
    if (button_code < MAX_MOUSE_BUTTONS) {
        const current_state = g_mouse_state.buttons_down[button_code];
        const prev_state = g_mouse_state.prev_buttons_down[button_code];
        return current_state and !prev_state;
    }
    return false;
}

/// Checks if a specific mouse button was just released in this frame.
pub fn was_mouse_button_just_released(button_code: u32) bool {
    if (button_code < MAX_MOUSE_BUTTONS) {
        return !g_mouse_state.buttons_down[button_code] and g_mouse_state.prev_buttons_down[button_code];
    }
    return false;
}

/// Represents the mouse wheel scroll delta for the current frame.
pub const MouseWheelDelta = struct { dx: f32, dy: f32 };

/// Gets the mouse wheel scroll delta accumulated during the current frame.
/// This value is reset at the start of each frame by `update_input_frame_start()`.
pub fn get_mouse_wheel_delta() MouseWheelDelta {
    return .{ .dx = g_mouse_state.wheel_delta_x, .dy = g_mouse_state.wheel_delta_y };
}

// Keyboard Getters

/// Checks if a specific key is currently held down.
/// key_code corresponds to JavaScript `event.keyCode`.
pub fn is_key_down(key_code: u32) bool {
    if (key_code < MAX_KEY_CODES) {
        return g_keyboard_state.keys_down[key_code];
    }
    return false;
}

/// Checks if a specific key was just pressed in this frame.
pub fn was_key_just_pressed(key_code: u32) bool {
    if (key_code < MAX_KEY_CODES) {
        return g_keyboard_state.keys_down[key_code] and !g_keyboard_state.prev_keys_down[key_code];
    }
    return false;
}

/// Checks if a specific key was just released in this frame.
pub fn was_key_just_released(key_code: u32) bool {
    if (key_code < MAX_KEY_CODES) {
        return !g_keyboard_state.keys_down[key_code] and g_keyboard_state.prev_keys_down[key_code];
    }
    return false;
}

// --- Test Utilities ---
// This function is intended for use in test environments to reset the global state.
pub fn testing_reset_internal_state_for_tests() void {
    // Reset mouse state
    g_mouse_state.x = 0.0;
    g_mouse_state.y = 0.0;
    g_mouse_state.wheel_delta_x = 0.0;
    g_mouse_state.wheel_delta_y = 0.0;
    var i_mouse: usize = 0;
    while (i_mouse < MAX_MOUSE_BUTTONS) : (i_mouse += 1) {
        g_mouse_state.buttons_down[i_mouse] = false;
        g_mouse_state.prev_buttons_down[i_mouse] = false;
    }

    // Reset keyboard state
    var i_key: usize = 0;
    while (i_key < MAX_KEY_CODES) : (i_key += 1) {
        g_keyboard_state.keys_down[i_key] = false;
        g_keyboard_state.prev_keys_down[i_key] = false;
    }
}
