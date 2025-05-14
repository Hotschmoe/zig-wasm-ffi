const wasm_ffi = @import("zig-wasm-ffi");
const std = @import("std");

pub fn main() !void {
    const ctx = try wasm_ffi.webaudio.createAudioContext();
    // const gamepads = try wasm_ffi.webinput.getGamepads(std.heap.page_allocator);
    // Use ctx and gamepads
    std.debug.print("AudioContext: {any}\n", .{ctx});
    // std.debug.print("Gamepads: {any}\n", .{gamepads});
}
