// zig-wasm-ffi/build.zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize_mode = b.standardOptimizeOption(.{});

    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    // Module exposed to consumers of this package
    const mod = b.addModule("zig-wasm-ffi", .{
        .root_source_file = b.path("src/lib.zig"),
    });

    // WASM library build (zig build wasm)
    const wasm_lib = b.addExecutable(.{
        .name = "zig_wasm_ffi",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lib.zig"),
            .target = wasm_target,
            .optimize = optimize_mode,
        }),
    });
    wasm_lib.entry = .disabled;
    b.installArtifact(wasm_lib);

    const build_wasm_step = b.step("wasm", "Build the WASM freestanding library");
    build_wasm_step.dependOn(&wasm_lib.step);

    // Tests (native target)
    _ = mod; // mod is for consumers; tests use their own module
    const test_mod = b.addModule("zig-wasm-ffi-test", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = optimize_mode,
    });
    const test_step = b.addTest(.{
        .root_module = test_mod,
    });
    const run_tests = b.addRunArtifact(test_step);
    b.step("test", "Run library tests").dependOn(&run_tests.step);

    // Demo: build and serve (zig build run)
    const build_demo = b.addSystemCommand(&.{ "sh", "-c", "cd demos/input_n_audio && zig build deploy" });

    const serve_demo = b.addSystemCommand(&.{ "python3", "-m", "http.server", "-d", "demos/input_n_audio/dist" });
    serve_demo.step.dependOn(&build_demo.step);

    b.step("run", "Build demos and start local server").dependOn(&serve_demo.step);
}
