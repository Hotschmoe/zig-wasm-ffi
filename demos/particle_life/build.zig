const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const wasm_target = std.Target.Query{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
        .abi = .none,
    };

    const optimize = b.option(
        std.builtin.OptimizeMode,
        "optimize",
        "Optimization mode (default: ReleaseFast)",
    ) orelse .ReleaseFast;

    const exe = b.addExecutable(.{
        .name = "particle-life",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(wasm_target),
            .optimize = optimize,
        }),
    });

    const zig_wasm_ffi_dep = b.dependency("zig-wasm-ffi", .{
        .target = b.resolveTargetQuery(wasm_target),
        .optimize = optimize,
    });
    exe.root_module.addImport("zig-wasm-ffi", zig_wasm_ffi_dep.module("zig-wasm-ffi"));

    exe.rdynamic = true;
    exe.entry = .disabled;
    exe.export_memory = true;

    // Memory configuration for particle simulation
    exe.initial_memory = 64 * 1024 * 1024; // 64MB initial
    exe.max_memory = 512 * 1024 * 1024; // 512MB max
    exe.stack_size = 32 * 1024 * 1024; // 32MB stack

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
        .install_dir = .{ .custom = "../dist" },
        .install_subdir = "",
    });
    copy_web_assets.step.dependOn(&make_dist.step);

    // --- API GLUE FILE MANAGEMENT ---
    const used_web_apis = [_][]const u8{
        "webgpu",
        "webinput",
    };

    // --- Run and Deploy Steps ---
    const run_cmd = b.addSystemCommand(&.{ "python3", "-m", "http.server", "-d", "dist" });
    run_cmd.step.dependOn(&copy_wasm.step);
    run_cmd.step.dependOn(&copy_web_assets.step);

    const deploy_step = b.step("deploy", "Build and copy files to dist directory");
    deploy_step.dependOn(&copy_wasm.step);
    deploy_step.dependOn(&copy_web_assets.step);

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
