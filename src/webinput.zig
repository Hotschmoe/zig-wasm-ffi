// zig-wasm-ffi/src/webinput.zig
// const std = @import("std");

// Opaque type for JavaScript objects
// pub const Gamepad = opaque {};

// FFI declarations for JavaScript glue
// const js = @import("webinput.js"); // REMOVED - JS functions will be provided as WASM imports
pub extern "env" fn js_addKeyListener(event: [*:0]const u8, callback: *const fn (*anyopaque, bool, u32) callconv(.C) void, context_ptr: *anyopaque) void;
// pub extern "env" fn js_getGamepads() ?*[*]?*Gamepad;
// pub extern "env" fn js_getGamepadButton(gamepad: *Gamepad, index: u32) bool;
// pub extern "env" fn js_getGamepadAxis(gamepad: *Gamepad, index: u32) f64;

// const MAX_GAMEPADS = 4; // Maximum number of gamepads expected from the JS API

// Binding functions
pub fn addKeyListener(event: [:0]const u8, comptime Callback: type, callback_context: *Callback) void {
    js_addKeyListener(event.ptr, Callback.callback, callback_context);
}

// Example callback struct for key events
pub const KeyCallback = struct {
    pressed: bool = false,
    key_code: u32 = 0,
    pub fn callback(ctx: *anyopaque, pressed: bool, key_code: u32) callconv(.C) void {
        const self: *KeyCallback = @ptrCast(@alignCast(ctx));
        self.pressed = pressed;
        self.key_code = key_code;
    }
};

// --- Configuration ---
const MAX_KEY_CODES: usize = 256;
const MAX_MOUSE_BUTTONS: usize = 5; // Common buttons: Left, Middle, Right, Back, Forward

// --- Mouse State ---
const MouseState = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    buttons_down: [MAX_MOUSE_BUTTONS]bool = [_]bool{false} ** MAX_MOUSE_BUTTONS,
    prev_buttons_down: [MAX_MOUSE_BUTTONS]bool = [_]bool{false} ** MAX_MOUSE_BUTTONS,
    wheel_delta_x: f32 = 0.0,
    wheel_delta_y: f32 = 0.0,
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
    g_mouse_state.x = x; // Update position on click too
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

/// Call this at the beginning of each frame/update loop.
/// It updates previous input states for "just pressed/released" logic
/// and resets per-frame accumulators like mouse wheel delta.
pub fn update_input_frame_start() void {
    g_mouse_state.prev_buttons_down = g_mouse_state.buttons_down;
    g_mouse_state.wheel_delta_x = 0.0;
    g_mouse_state.wheel_delta_y = 0.0;

    g_keyboard_state.prev_keys_down = g_keyboard_state.keys_down;
}

// Mouse Getters
pub const MousePosition = struct { x: f32, y: f32 };
pub fn get_mouse_position() MousePosition {
    return .{ .x = g_mouse_state.x, .y = g_mouse_state.y };
}

pub fn is_mouse_button_down(button_code: u32) bool {
    if (button_code < MAX_MOUSE_BUTTONS) {
        return g_mouse_state.buttons_down[button_code];
    }
    return false;
}

pub fn was_mouse_button_just_pressed(button_code: u32) bool {
    if (button_code < MAX_MOUSE_BUTTONS) {
        return g_mouse_state.buttons_down[button_code] and !g_mouse_state.prev_buttons_down[button_code];
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

// Original FFI for addKeyListener and related structs are removed as per previous refactoring.
// Gamepad related code (constants, FFI, public functions, GamepadData struct) is removed for now.
// For future gamepad integration, the FFI functions would be declared here similar to:
// pub extern "env" fn platform_poll_gamepads() void;
// pub extern "env" fn platform_get_gamepad_count() u32;
// etc.
// And public Zig functions would wrap these calls.
