// zig-wasm-ffi/src/lib.zig
pub const webaudio = @import("webaudio.zig");
pub const webinput = @import("webinput.zig");
pub const webgpu = @import("webgpu.zig");
pub const webutils = @import("webutils.zig");

// This block ensures that tests defined in webinput.test.zig are included
// when 'zig build test' is executed.
test {
    // The path is relative to this file (lib.zig).
    _ = @import("webinput.test.zig");
    // _ = @import("webaudio.test.zig");
}
