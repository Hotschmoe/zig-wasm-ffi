const std = @import("std");
const builtin = @import("builtin");

// This is the build script for our generic WebAssembly project
pub fn build(b: *std.Build) !void {
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
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(wasm_target),
        .optimize = optimize,
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

    var all_copy_js_glue_steps = std.ArrayList(*std.Build.Step).init(b.allocator);
    defer all_copy_js_glue_steps.deinit();

    for (used_web_apis) |api_name| {
        const js_source_filename_in_dep = b.fmt("src/js/{s}.js", .{api_name});
        const source_lazy_path = zig_wasm_ffi_dep.path(js_source_filename_in_dep);

        const dest_sub_path = b.fmt("../dist/{s}.js", .{api_name});
        const install_js_glue_step = b.addInstallFile(source_lazy_path, dest_sub_path);
        install_js_glue_step.step.dependOn(&make_dist.step);
        try all_copy_js_glue_steps.append(&install_js_glue_step.step);
    }

    // --- STRETCH GOAL COMMENT for dynamic main.js ---
    // TODO: Dynamically generate `main.js` in the `dist` directory.
    // This generated `main.js` would:
    // 1. Import only the JavaScript modules for the APIs listed in `used_web_apis`
    //    (e.g., `import { someFunction } from './webaudio.js';`).
    // 2. Construct the `importsObject.env` with only the functions from these imported modules.
    // 3. Instantiate `app.wasm` with this tailored `importsObject`.
    // This would replace a static `web/main.js`.
    // See README.md for an example of how this might be implemented with `b.addWriteFiles()`.

    // --- Run and Deploy Steps ---
    const cmd_args = if (builtin.os.tag == .windows)
        &[_][]const u8{ "cmd", "/c", "cd", "dist", "&&", "python", "-m", "http.server" }
    else
        &[_][]const u8{ "cd", "dist", "&&", "python", "-m", "http.server" };

    const run_cmd = b.addSystemCommand(cmd_args);
    run_cmd.step.dependOn(&copy_wasm.step);
    run_cmd.step.dependOn(&copy_web_assets.step); // For index.html, static main.js, etc.
    for (all_copy_js_glue_steps.items) |js_copy_step| {
        run_cmd.step.dependOn(js_copy_step);
    }

    const run_step = b.step("run", "Build, deploy, and start Python HTTP server");
    run_step.dependOn(&run_cmd.step);

    const deploy_step = b.step("deploy", "Build and copy files to dist directory");
    deploy_step.dependOn(&copy_wasm.step);
    deploy_step.dependOn(&copy_web_assets.step);
    for (all_copy_js_glue_steps.items) |js_copy_step| {
        deploy_step.dependOn(js_copy_step);
    }
}
