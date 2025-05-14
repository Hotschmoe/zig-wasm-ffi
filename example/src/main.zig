const wasm_ffi = @import("zig-wasm-ffi");
// const std = @import("std"); // Removed std

// FFI declaration for a JavaScript logging function
extern fn console_log_str(message_ptr: [*]const u8, message_len: usize) void;

// Zig wrapper for the FFI logging function
fn log(comptime format: []const u8, args: anytype) void {
    // Note: This is a simplified logger. For production, you'd want a more robust
    // way to format strings without std.fmt, or pass raw strings/data to JS.
    // For this example, we'll just log the format string if there are no args,
    // or a placeholder if there are. A proper solution might involve a custom
    // formatter or sending structured data to JS.
    if (args == .{}) {
        console_log_str(format.ptr, format.len);
    } else {
        // This is a placeholder. A real implementation would require a custom
        // formatter or a different logging strategy for arguments without std.fmt.
        const message = "Log with args (formatting requires std or custom impl)";
        console_log_str(message.ptr, message.len);
    }
}

pub fn main() !void {
    const ctx = try wasm_ffi.webaudio.createAudioContext();
    // const gamepads = try wasm_ffi.webinput.getGamepads(std.heap.page_allocator); // Remains commented
    // Use ctx and gamepads
    log("AudioContext: {any}\\n", .{ctx}); // Replaced std.debug.print
    // log("Gamepads: {any}\\n", .{gamepads}); // Remains commented
}
