// zig-wasm-ffi/src/webinput.zig
const std = @import("std");

// Opaque type for JavaScript objects
pub const Gamepad = opaque {};

// FFI declarations for JavaScript glue
const js = @import("webinput.js");
extern fn js_addKeyListener(event: [*:0]const u8, callback: *const fn (*anyopaque, bool, u32) callconv(.C) void, context_ptr: *anyopaque) void;
extern fn js_getGamepads() ?[*]*Gamepad;
extern fn js_getGamepadButton(gamepad: *Gamepad, index: u32) bool;
extern fn js_getGamepadAxis(gamepad: *Gamepad, index: u32) f64;

// Binding functions
pub fn addKeyListener(event: [:0]const u8, comptime Callback: type, callback_context: *Callback) void {
    js_addKeyListener(event.ptr, Callback.callback, callback_context);
}

pub fn getGamepads(allocator: std.mem.Allocator) ![]*Gamepad {
    const ptr = js_getGamepads() orelse return error.GamepadAccessFailed;
    // Assume up to 4 gamepads for simplicity; adjust as needed
    var len: usize = 0;
    while (len < 4 and ptr[len] != null) : (len += 1) {}
    const result = try allocator.alloc(*Gamepad, len);
    std.mem.copy(*Gamepad, result, ptr[0..len]);
    return result;
}

pub fn getGamepadButton(gamepad: *Gamepad, index: u32) bool {
    return js_getGamepadButton(gamepad, index);
}

pub fn getGamepadAxis(gamepad: *Gamepad, index: u32) f64 {
    return js_getGamepadAxis(gamepad, index);
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
