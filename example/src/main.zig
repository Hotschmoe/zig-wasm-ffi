const wasm_ffi = @import("zig-wasm-ffi");
// const std = @import("std"); // Removed std

pub fn main() void {
    // Call a function from the library to ensure it links.
    const context = wasm_ffi.webaudio.createAudioContext();
    // For now, we're not doing anything with the context or handling if it's null.
    _ = context;
}
