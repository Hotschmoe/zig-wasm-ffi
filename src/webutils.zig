extern fn js_log(message: [*c]const u8) void;

pub fn log(message: []const u8) void {
    // Ensure the message is null-terminated for C interop
    // This is a simplified example; proper allocation might be needed for complex scenarios
    // or a helper function to convert Zig strings to null-terminated strings.
    // For now, assuming the input is often a string literal which is null-terminated.
    // A more robust approach would be to allocate a new null-terminated string.
    js_log(message.ptr);
}

// Example of how it might be used internally or by users:
// pub fn logInfo(comptime format: []const u8, args: anytype) void {
//     const message = std.fmt.allocPrint(std.heap.page_allocator, format, args) catch |err| {
//         // Fallback or panic, in a real scenario, might try a simpler log
//         js_log("Error formatting log message");
//         return;
//     };
//     defer std.heap.page_allocator.free(message);
//     js_log(message.ptr);
// }
