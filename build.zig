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

    // Demo: auto-discover, build, and serve (zig build run)
    const allocator = b.allocator;
    var demo_names: std.ArrayList([]const u8) = .empty;

    if (b.build_root.handle.openDir("demos", .{ .iterate = true })) |mut_dir| {
        var dir = mut_dir;
        var iter = dir.iterate();
        while (iter.next() catch null) |entry| {
            if (entry.kind != .directory) continue;
            dir.access(b.fmt("{s}/build.zig", .{entry.name}), .{}) catch continue;
            demo_names.append(allocator, allocator.dupe(u8, entry.name) catch @panic("OOM")) catch @panic("OOM");
        }
    } else |_| {}

    const demos = demo_names.items;

    // Join step: all copies must finish before index install + serve
    const copies_done = b.step("_copies", "internal: all demo copies finished");

    for (demos) |name| {
        const build_cmd = b.addSystemCommand(&.{
            "sh", "-c", b.fmt("cd demos/{s} && zig build deploy", .{name}),
        });

        const copy_cmd = b.addSystemCommand(&.{
            "sh", "-c", b.fmt("mkdir -p dist/{s} && cp -r demos/{s}/dist/. dist/{s}/", .{ name, name, name }),
        });
        copy_cmd.step.dependOn(&build_cmd.step);

        copies_done.dependOn(&copy_cmd.step);
    }

    // Generate index.html linking to each demo
    var index_buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&index_buf);
    const w = fbs.writer();
    w.writeAll(
        \\<!DOCTYPE html>
        \\<html><head><meta charset="utf-8">
        \\<title>zig-wasm-ffi demos</title>
        \\<style>
        \\  body { background: #1a1a2e; color: #e0e0e0; font-family: monospace;
        \\         display: flex; flex-direction: column; align-items: center; padding: 2rem; }
        \\  a { color: #7fdbca; text-decoration: none; font-size: 1.2rem; margin: 0.5rem 0; }
        \\  a:hover { text-decoration: underline; }
        \\  h1 { color: #c792ea; }
        \\</style></head><body>
        \\<h1>zig-wasm-ffi demos</h1>
        \\
    ) catch @panic("index buf overflow");

    for (demos) |name| {
        w.print("<a href=\"/{s}/\">{s}</a>\n", .{ name, name }) catch @panic("index buf overflow");
    }

    w.writeAll("</body></html>\n") catch @panic("index buf overflow");

    const wf = b.addWriteFiles();
    wf.step.dependOn(copies_done);
    const index_lazy = wf.add("index.html", fbs.getWritten());

    const install_index = b.addInstallFileWithDir(index_lazy, .{ .custom = "../dist" }, "index.html");
    install_index.step.dependOn(&wf.step);

    const serve = b.addSystemCommand(&.{ "python3", "-m", "http.server", "-d", "dist" });
    serve.step.dependOn(&install_index.step);

    b.step("run", "Build all demos and start local server").dependOn(&serve.step);
}
