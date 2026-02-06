const std = @import("std");
const builtin = @import("builtin");

// This is the build script for our generic WebAssembly project
pub fn build(b: *std.Build) void {
    // Standard target options for WebAssembly
    const wasm_target = std.Target.Query{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
        .abi = .none,
    };

    // Use ReleaseFast optimization by default for better WebAssembly performance
    // This helps reduce warm-up jitter by generating pre-optimized Wasm code
    const optimize = b.option(
        std.builtin.OptimizeMode,
        "optimize",
        "Optimization mode (default: ReleaseFast)",
    ) orelse .ReleaseFast;

    // Create an executable that compiles to WebAssembly
    const exe = b.addExecutable(.{
        .name = "zig-ffi-example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(wasm_target),
            .optimize = optimize,
        }),
    });

    // Add zig-webaudio-direct module
    const zig_wasm_ffi_dep = b.dependency("zig-wasm-ffi", .{
        .target = b.resolveTargetQuery(wasm_target),
        .optimize = optimize,
    });
    exe.root_module.addImport("zig-wasm-ffi", zig_wasm_ffi_dep.module("zig-wasm-ffi"));

    // Important WASM-specific settings
    exe.rdynamic = true;
    exe.entry = .disabled;
    exe.export_memory = true;

    // Install in the output directory
    b.installArtifact(exe);

    // --- Directory Setup for project-level 'dist' ---
    const clean_dist = b.addSystemCommand(if (builtin.os.tag == .windows)
        &[_][]const u8{ "cmd", "/c", "if", "exist", "dist", "rd", "/s", "/q", "dist" }
    else
        &[_][]const u8{ "rm", "-rf", "dist" });

    const make_dist = b.addSystemCommand(if (builtin.os.tag == .windows)
        &[_][]const u8{ "cmd", "/c", "if", "not", "exist", "dist", "mkdir", "dist" }
    else
        &[_][]const u8{ "mkdir", "-p", "dist" });
    make_dist.step.dependOn(&clean_dist.step);

    // --- Asset Installation to project-level 'dist' directory ---
    const copy_wasm = b.addInstallFile(exe.getEmittedBin(), "../dist/app.wasm");
    copy_wasm.step.dependOn(&make_dist.step);

    const copy_web_assets = b.addInstallDirectory(.{
        .source_dir = b.path("web"),
        .install_dir = .{ .custom = "../dist" }, // Copies contents of web/ to dist/
        .install_subdir = "",
    });
    copy_web_assets.step.dependOn(&make_dist.step);

    // --- API GLUE FILE MANAGEMENT ---
    // Define which APIs from zig-wasm-ffi are being used by this example project.
    const used_web_apis = [_][]const u8{
        "webaudio",
        "webinput",
        // "webgpu", // Uncomment if using WebGPU API from zig-wasm-ffi
    };

    // --- Run and Deploy Steps ---
    const run_cmd = b.addSystemCommand(&.{ "python3", "-m", "http.server", "-d", "dist" });
    run_cmd.step.dependOn(&copy_wasm.step);
    run_cmd.step.dependOn(&copy_web_assets.step);

    const deploy_step = b.step("deploy", "Build and copy files to dist directory");
    deploy_step.dependOn(&copy_wasm.step);
    deploy_step.dependOn(&copy_web_assets.step);

    // Copy JS glue files from zig-wasm-ffi dependency into dist/
    for (used_web_apis) |api_name| {
        const source_path = zig_wasm_ffi_dep.path(b.fmt("src/js/{s}.js", .{api_name}));
        const install_step = b.addInstallFile(source_path, b.fmt("../dist/{s}.js", .{api_name}));
        install_step.step.dependOn(&make_dist.step);
        run_cmd.step.dependOn(&install_step.step);
        deploy_step.dependOn(&install_step.step);
    }

    const run_step = b.step("run", "Build, deploy, and start Python HTTP server");
    run_step.dependOn(&run_cmd.step);
}
