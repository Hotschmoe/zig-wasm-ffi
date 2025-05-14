// zig-wasm-ffi/build.zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.addModule("zig-wasm-ffi", .{
        .root_source_file = b.path("src/lib.zig"),
    });

    // Optional: Add tests for the library
    const test_step = b.addTest(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
    const run_tests = b.addRunArtifact(test_step);
    b.step("test", "Run library tests").dependOn(&run_tests.step);
}
