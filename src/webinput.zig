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

// pub fn getGamepads(allocator: std.mem.Allocator) ![]?*Gamepad {
//     const gamepads_c_array_ptr = js_getGamepads() orelse return error.GamepadAccessFailed;
//
//     // Convert the C-style array pointer to a Zig slice of known max length
//     const all_slots_slice: []?*Gamepad = gamepads_c_array_ptr[0..MAX_GAMEPADS];
//
//     var active_len: usize = 0;
//     // Loop through the slice to find the number of contiguously active (non-null) gamepads
//     while (active_len < MAX_GAMEPADS and all_slots_slice[active_len] != null) : (active_len += 1) {}
//
//     // Allocate memory for the active gamepads
//     const result_slice = try allocator.alloc(?*Gamepad, active_len);
//
//     // Copy the active gamepads into the new slice
//     std.mem.copy(?*Gamepad, result_slice, all_slots_slice[0..active_len]);
//
//     return result_slice;
// }
//
// pub fn getGamepadButton(gamepad: *Gamepad, index: u32) bool {
//     return js_getGamepadButton(gamepad, index);
// }
//
// pub fn getGamepadAxis(gamepad: *Gamepad, index: u32) f64 {
//     return js_getGamepadAxis(gamepad, index);
// }

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
