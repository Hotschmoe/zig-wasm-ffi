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
        .name = "hill-climber",
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(wasm_target),
        .optimize = optimize,
    });

    // Important WASM-specific settings
    exe.rdynamic = true;
    exe.entry = .disabled;

    // Install in the output directory
    b.installArtifact(exe);

    // Create dist directory if it doesn't exist
    const make_dist = b.addSystemCommand(if (builtin.os.tag == .windows)
        &[_][]const u8{ "cmd", "/c", "if", "not", "exist", "dist", "mkdir", "dist" }
    else
        &[_][]const u8{ "mkdir", "-p", "dist" });
    make_dist.step.dependOn(b.getInstallStep());

    // Create a step to copy the WASM file to the root dist directory
    const copy_wasm = b.addInstallFile(exe.getEmittedBin(), "../dist/flapper.wasm");
    copy_wasm.step.dependOn(b.getInstallStep());
    copy_wasm.step.dependOn(&make_dist.step);

    // Create a step to copy all files from the web directory to the root dist directory
    const copy_web = b.addInstallDirectory(.{
        .source_dir = b.path("web"),
        .install_dir = .{ .custom = "../dist" },
        .install_subdir = "",
    });
    copy_web.step.dependOn(&make_dist.step);

    // Add a run step to start Python HTTP server
    const cmd_args = if (builtin.os.tag == .windows)
        &[_][]const u8{ "cmd", "/c", "cd", "dist", "&&", "py", "-m", "http.server" }
    else
        &[_][]const u8{ "cd", "dist", "&&", "py", "-m", "http.server" };

    const run_cmd = b.addSystemCommand(cmd_args);
    run_cmd.step.dependOn(&copy_wasm.step);
    run_cmd.step.dependOn(&copy_web.step);

    const run_step = b.step("run", "Build, deploy, and start Python HTTP server");
    run_step.dependOn(&run_cmd.step);

    // Add a deploy step that only copies the files without starting the server
    const deploy_step = b.step("deploy", "Build and copy files to dist directory");
    deploy_step.dependOn(&copy_wasm.step);
    deploy_step.dependOn(&copy_web.step);
}
