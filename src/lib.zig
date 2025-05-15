// zig-wasm-ffi/src/lib.zig
pub const webaudio = @import("webaudio.zig");
pub const webinput = @import("webinput.zig");

// If you have other modules, you can export them here as well:
// pub const webaudio = @import("webaudio.zig");
// pub const webgpu = @import("webgpu.zig");

// This block ensures that tests defined in webinput.test.zig are included
// when 'zig build test' is executed.
test {
    // The path is relative to this file (lib.zig).
    _ = @import("webinput.test.zig");

    // If other modules also have their own .test.zig files:
    // _ = @import("webaudio.test.zig");
}
