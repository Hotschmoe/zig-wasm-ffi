// zig-wasm-ffi/build.zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    // Define the module; useful if other Zig code in this build or other packages import "zig-wasm-ffi"
    _ = b.addModule("zig-wasm-ffi", .{
        .root_source_file = b.path("src/lib.zig"),
    });

    // --- BEGINNING OF ADDED WASM LIBRARY BUILD ---
    // Define the target for wasm32-freestanding
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    // Get the optimization mode from command line options (e.g., -Doptimize=ReleaseSmall)
    const optimize_mode = b.standardOptimizeOption(.{});

    // Add an executable artifact for the WASM library
    // We use addExecutable because it's the standard way to produce a .wasm file,
    // especially when it needs to export functions for a JS environment.
    const wasm_lib = b.addExecutable(.{
        .name = "zig_wasm_ffi", // Output will be zig_wasm_ffi.wasm
        .root_source_file = b.path("src/lib.zig"), // The main source file for the library
        .target = wasm_target,
        .optimize = optimize_mode,
    });

    // Disable the entry point, making it a library (like -fno-entry)
    wasm_lib.entry = .disabled;

    // Install the .wasm file to zig-out/bin/ (or zig-out/lib/ for libraries)
    b.installArtifact(wasm_lib);

    // Add a build step to create the WASM library, e.g., `zig build wasm`
    const build_wasm_step = b.step("wasm", "Build the WASM freestanding library");
    build_wasm_step.dependOn(&wasm_lib.step);
    // --- END OF ADDED WASM LIBRARY BUILD ---

    // Optional: Add tests for the library
    const test_step = b.addTest(.{
        .root_source_file = b.path("src/lib.zig"),
        // Tests usually run on a native target for ease of execution and debugging
        .target = b.standardTargetOptions(.{}),
        .optimize = optimize_mode, // Reuse the optimize_mode defined earlier
    });
    const run_tests = b.addRunArtifact(test_step);
    b.step("test", "Run library tests").dependOn(&run_tests.step);
}
