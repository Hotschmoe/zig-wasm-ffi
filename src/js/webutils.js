export function env_js_log_message_with_length(messagePtr, messageLen) {
    if (!window.wasmInstance || !window.wasmInstance.exports.memory) {
        console.error("WASM instance or memory not found on window.wasmInstance for logging.");
        // Fallback log attempt with raw values
        let fallbackMessage = `[WASM LOG (mem err)] ptr: ${messagePtr}, len: ${messageLen}`;
        try {
            // If we can read a little bit without assuming too much, it might give a hint
            // This is risky and might fail if messagePtr is invalid.
            const tempBuf = new Uint8Array(window.wasmInstance.exports.memory.buffer, messagePtr, Math.min(messageLen, 50));
            fallbackMessage += `, partial data: "${new TextDecoder('utf-8', { fatal: false }).decode(tempBuf)}"`;
        } catch (e) { /* ignore error during fallback enhance */ }
        console.log(fallbackMessage);
        return;
    }
    try {
        const memoryBuffer = window.wasmInstance.exports.memory.buffer;
        const messageBuffer = new Uint8Array(memoryBuffer, messagePtr, messageLen);
        const message = new TextDecoder('utf-8').decode(messageBuffer);
        console.log(message);
    } catch (e) {
        console.error("Error decoding WASM string for logging:", e);
        console.log(`[WASM LOG (decode err)] ptr: ${messagePtr}, len: ${messageLen}`);
    }
}

// do we need this below?

// FFI import for JavaScript's console.log
// extern "env" fn js_log_string(message_ptr: [*c]const u8, message_len: u32) void;

// Helper function to log strings from Zig (application-level)
// fn log_app_info(message: []const u8) void {
//     const prefix = "[AppInputHandler] ";
//     var buffer: [128]u8 = undefined; // Ensure buffer is large enough for prefix + message
//     var current_len: usize = 0;
//
//     // Copy prefix
//     for (prefix) |char_code| {
//         if (current_len >= buffer.len - 1) { // Space around - for linter
//             break;
//         }
//         buffer[current_len] = char_code;
//         current_len += 1;
//     }
//     // Copy message
//     for (message) |char_code| {
//         if (current_len >= buffer.len - 1) { // Space around - for linter
//             break;
//         }
//         buffer[current_len] = char_code;
//         current_len += 1;
//     }
//     js_log_string(&buffer, @intCast(current_len));
// }