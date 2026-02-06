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

pub export fn zig_internal_on_mouse_move(x: f32, y: f32) void {
    g_mouse_state.x = x;
    g_mouse_state.y = y;
}

pub export fn zig_internal_on_mouse_button(button_code: u32, is_down: bool, x: f32, y: f32) void {
    g_mouse_state.x = x;
    g_mouse_state.y = y;
    if (button_code < MAX_MOUSE_BUTTONS) {
        g_mouse_state.buttons_down[button_code] = is_down;
    }
}

pub export fn zig_internal_on_mouse_wheel(delta_x: f32, delta_y: f32) void {
    g_mouse_state.wheel_delta_x += delta_x;
    g_mouse_state.wheel_delta_y += delta_y;
}

pub export fn zig_internal_on_key_event(key_code: u32, is_down: bool) void {
    if (key_code < MAX_KEY_CODES) {
        g_keyboard_state.keys_down[key_code] = is_down;
    }
}

// --- Public API for Zig Application ---

/// Resets per-frame accumulators. Call at the beginning of each frame.
pub fn begin_input_frame_state_update() void {
    g_mouse_state.wheel_delta_x = 0.0;
    g_mouse_state.wheel_delta_y = 0.0;
}

/// Snapshots current state as "previous" for next-frame edge detection. Call at the end of each frame.
pub fn end_input_frame_state_update() void {
    g_mouse_state.prev_buttons_down = g_mouse_state.buttons_down;
    g_keyboard_state.prev_keys_down = g_keyboard_state.keys_down;
}

// Mouse Getters

pub const MousePosition = struct { x: f32, y: f32 };

pub fn get_mouse_position() MousePosition {
    return .{ .x = g_mouse_state.x, .y = g_mouse_state.y };
}

/// button_code: 0=Left, 1=Middle, 2=Right, 3=Back, 4=Forward
pub fn is_mouse_button_down(button_code: u32) bool {
    if (button_code < MAX_MOUSE_BUTTONS) {
        return g_mouse_state.buttons_down[button_code];
    }
    return false;
}

pub fn was_mouse_button_just_pressed(button_code: u32) bool {
    if (button_code < MAX_MOUSE_BUTTONS) {
        const current_state = g_mouse_state.buttons_down[button_code];
        const prev_state = g_mouse_state.prev_buttons_down[button_code];
        return current_state and !prev_state;
    }
    return false;
}

pub fn was_mouse_button_just_released(button_code: u32) bool {
    if (button_code < MAX_MOUSE_BUTTONS) {
        return !g_mouse_state.buttons_down[button_code] and g_mouse_state.prev_buttons_down[button_code];
    }
    return false;
}

pub const MouseWheelDelta = struct { dx: f32, dy: f32 };

pub fn get_mouse_wheel_delta() MouseWheelDelta {
    return .{ .dx = g_mouse_state.wheel_delta_x, .dy = g_mouse_state.wheel_delta_y };
}

// Keyboard Getters

/// key_code corresponds to JavaScript event.keyCode
pub fn is_key_down(key_code: u32) bool {
    if (key_code < MAX_KEY_CODES) {
        return g_keyboard_state.keys_down[key_code];
    }
    return false;
}

pub fn was_key_just_pressed(key_code: u32) bool {
    if (key_code < MAX_KEY_CODES) {
        return g_keyboard_state.keys_down[key_code] and !g_keyboard_state.prev_keys_down[key_code];
    }
    return false;
}

pub fn was_key_just_released(key_code: u32) bool {
    if (key_code < MAX_KEY_CODES) {
        return !g_keyboard_state.keys_down[key_code] and g_keyboard_state.prev_keys_down[key_code];
    }
    return false;
}

// --- Test Utilities ---

pub fn testing_reset_internal_state_for_tests() void {
    g_mouse_state = .{};
    g_keyboard_state = .{};
}
