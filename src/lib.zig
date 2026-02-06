// zig-wasm-ffi/src/lib.zig
pub const webaudio = @import("webaudio.zig");
pub const webgpu = @import("webgpu.zig");
pub const webinput = @import("webinput.zig");

test {
    _ = @import("webinput.test.zig");
    // webaudio tests require extern "env" FFI mocks; run directly: zig test src/webaudio.test.zig -fPIC
    // _ = @import("webaudio.test.zig");
}
