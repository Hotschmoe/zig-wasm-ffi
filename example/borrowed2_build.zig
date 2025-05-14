// pull dependencies, copy .js files, create main.js and index.html, build wasm, copy all to dist folder

const std = @import("std");
const builtin = @import("builtin"); // Added from borrowed_build.zig

pub fn build(b: *std.Build) void {
    // Standard target options for WebAssembly (from borrowed_build.zig)
    const wasm_target = std.Target.Query{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
        .abi = .none,
    };

    // Use ReleaseFast optimization by default, configurable (from borrowed_build.zig)
    const optimize = b.option(
        std.builtin.OptimizeMode,
        "optimize",
        "Optimization mode (default: ReleaseFast)",
    ) orelse .ReleaseFast;

    // Create an executable
    const exe = b.addExecutable(.{
        .name = "app",
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(wasm_target),
        .optimize = optimize,
    });

    // Add zig-webaudio-direct module
    const webaudio_dep = b.dependency("zig-webaudio-direct", .{
        .target = b.resolveTargetQuery(wasm_target),
        .optimize = optimize,
    });
    const webaudio_module = webaudio_dep.module("zig-webaudio-direct");
    exe.root_module.addImport("zig-webaudio-direct", webaudio_module);

    // Important WASM-specific settings (from borrowed_build.zig)
    exe.rdynamic = true;
    exe.entry = .disabled;

    b.installArtifact(exe);

    // Create dist directory (e.g., template-project/dist/) (from borrowed_build.zig)
    const make_dist = b.addSystemCommand(if (builtin.os.tag == .windows)
        &[_][]const u8{ "cmd", "/c", "if", "not", "exist", "dist", "mkdir", "dist" }
    else
        &[_][]const u8{ "mkdir", "-p", "dist" });
    // This step itself doesn't depend on others; other steps will depend on it.

    // Copy the compiled WASM from zig-out/bin/app.wasm to dist/app.wasm
    const copy_wasm = b.addInstallFile(exe.getEmittedBin(), "dist/app.wasm");
    copy_wasm.step.dependOn(b.getInstallStep()); // Ensures app.wasm is built by installArtifact
    copy_wasm.step.dependOn(&make_dist.step); // Ensures dist directory exists

    // Copy webaudio.js from dependency to dist/webaudio.js (kept from original build.zig logic)
    const webaudio_js_source = b.dependency("zig-webaudio-direct", .{}).path("js/webaudio.js");
    const install_webaudio_js = b.addInstallFile(webaudio_js_source, "dist/webaudio.js");
    install_webaudio_js.step.dependOn(&make_dist.step);

    // Copy all files from "web" directory to "dist" (replaces individual index.html & main.js copies)
    // (Adapted from borrowed_build.zig's copy_web logic)
    const copy_web_files = b.addInstallDirectory(.{
        .source_dir = b.path("web"),
        .install_dir = .{ .custom = "dist" },
        .install_subdir = "",
    });
    copy_web_files.step.dependOn(&make_dist.step);

    // STRETCH GOAL, GENERATE MAIN.JS BASED ON DEPENDENCIES (remains commented out)
    // // Generate main.js
    // const gen_step = b.addWriteFiles();
    // const main_js = gen_step.add("main.js",
    //     \\import { createAudioContext, decodeAudioData } from './webaudio.js';
    //     \\async function init() {
    //     \\    if (!navigator.gpu) {
    //     \\        console.error('WebGPU not supported');
    //     \\        return;
    //     \\    }
    //     \\    const imports = {
    //     \\        env: {
    //     \\            createAudioContext,
    //     \\            decodeAudioData
    //     \\        }
    //     \\    };
    //     \\    const { instance } = await WebAssembly.instantiateStreaming(fetch('app.wasm'), imports);
    //     \\    instance.exports.main();
    //     \\}
    //     \\init().catch(console.error);
    // );
    // // To install this generated main.js, you would use something like:
    // // const install_generated_main_js = b.addInstallFile(.{
    // // .source = main_js.getOutput(),
    // // .dest_dir = .{ .custom = "dist" },
    // // .dest_sub_path = "main.js",
    // // });
    // // install_generated_main_js.step.dependOn(&make_dist.step);
    // // Ensure it doesn't conflict with copy_web_files if web/main.js also exists.

    // // STRETCH GOAL 2
    // // Bundle all javascript files into one file with esbuild or BUN
    // // to optimize for browser loading

    // Add a run step to start Python HTTP server (from borrowed_build.zig)
    const run_cmd_args = if (builtin.os.tag == .windows)
        &[_][]const u8{ "cmd", "/c", "cd", "dist", "&&", "py", "-m", "http.server" }
    else
        // Using sh -c for robustness with && on POSIX systems
        &[_][]const u8{ "sh", "-c", "cd dist && py -m http.server" };

    const run_cmd = b.addSystemCommand(run_cmd_args);
    run_cmd.step.dependOn(&copy_wasm.step);
    run_cmd.step.dependOn(&install_webaudio_js.step);
    run_cmd.step.dependOn(&copy_web_files.step);

    const run_step = b.step("run", "Build, deploy, and start Python HTTP server");
    run_step.dependOn(&run_cmd.step);

    // Add a deploy step that only copies the files (from borrowed_build.zig)
    const deploy_step = b.step("deploy", "Build and copy files to dist directory");
    deploy_step.dependOn(&copy_wasm.step);
    deploy_step.dependOn(&install_webaudio_js.step);
    deploy_step.dependOn(&copy_web_files.step);
}
