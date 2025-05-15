// zig-wasm-ffi/src/webutils.zig

extern "env" fn env_js_log_message_with_length(message_ptr: [*c]const u8, message_len: usize) void;

pub fn log(message: []const u8) void {
    env_js_log_message_with_length(message.ptr, message.len);
}
