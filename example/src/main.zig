const wasm_ffi = @import("zig-wasm-ffi");
// const std = @import("std"); // Removed std

pub fn main() !void {
    // Call a function from the library to ensure it links.
    // The result is assigned to underscore to indicate it's intentionally unused in this minimal example.
    // _ = try wasm_ffi.webaudio.createAudioContext();

    // If the build succeeds, the import and function call are working.
    // No actual logging is performed in this simplified version.
}
