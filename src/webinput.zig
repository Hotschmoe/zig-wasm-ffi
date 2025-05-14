// zig-wasm-ffi/src/webinput.zig
// const std = @import("std");

// Opaque type for JavaScript objects
// pub const Gamepad = opaque {};

// FFI declarations for JavaScript glue
// const js = @import("webinput.js"); // REMOVED - JS functions will be provided as WASM imports
// pub extern "env" fn js_addKeyListener(event: [*:0]const u8, callback: *const fn (*anyopaque, bool, u32) callconv(.C) void, context_ptr: *anyopaque) void;
// pub extern "env" fn js_getGamepads() ?*[*]?*Gamepad;
// pub extern "env" fn js_getGamepadButton(gamepad: *Gamepad, index: u32) bool;
// pub extern "env" fn js_getGamepadAxis(gamepad: *Gamepad, index: u32) f64;

// const MAX_GAMEPADS = 4; // Maximum number of gamepads expected from the JS API

// Binding functions
// pub fn addKeyListener(event: [:0]const u8, comptime Callback: type, callback_context: *Callback) void {
//     js_addKeyListener(event.ptr, Callback.callback, callback_context);
// }

// Example callback struct for key events
// pub const KeyCallback = struct {
//     pressed: bool = false,
//     key_code: u32 = 0,
//     pub fn callback(ctx: *anyopaque, pressed: bool, key_code: u32) callconv(.C) void {
//         const self: *KeyCallback = @ptrCast(@alignCast(ctx));
//         self.pressed = pressed;
//         self.key_code = key_code;
//     }
// };

// TEMPORARY DIAGNOSTIC LOGS ADDED - REMOVE AFTER DEBUGGING

// FFI import for JavaScript's console.log (TEMPORARY for debugging)
// extern "env" fn js_log_string(message_ptr: [*c]const u8, message_len: u32) void;

// Helper function to log strings from Zig (TEMPORARY for debugging)
// fn log_lib_debug(message: []const u8) void {
//     const prefix = "[WebInputLib ZIG DBG] ";
//     var buffer: [128]u8 = undefined;
//     var i: usize = 0;
//     while (i < prefix.len and i < buffer.len) : (i += 1) {
//         buffer[i] = prefix[i];
//     }
//     var j: usize = 0;
//     while (j < message.len and (i + j) < buffer.len - 1) : (j += 1) {
//         buffer[i + j] = message[j];
//     }
//     const final_len = i + j;
//     js_log_string(&buffer, @intCast(final_len));
// }

// --- Configuration ---
const MAX_KEY_CODES: usize = 256;
const MAX_MOUSE_BUTTONS: usize = 5; // 0:Left, 1:Middle, 2:Right, 3:Back, 4:Forward

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

// Original FFI for addKeyListener and related structs are removed as per previous refactoring.
// Gamepad related code (constants, FFI, public functions, GamepadData struct) is removed for now.
// For future gamepad integration, the FFI functions would be declared here similar to:
// pub extern "env" fn platform_poll_gamepads() void;
// pub extern "env" fn platform_get_gamepad_count() u32;
// etc.
// And public Zig functions would wrap these calls.
