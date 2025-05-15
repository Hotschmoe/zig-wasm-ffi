export function js_log(messagePtr) {
    // Assuming the Zig string is UTF-8 encoded and null-terminated
    // Need to read the string from WASM memory
    const buffer = new Uint8Array(WebAssembly.Module.exports(wasmInstance.module, 'memory').buffer);
    let message = '';
    let offset = messagePtr;
    while (buffer[offset] !== 0) {
        message += String.fromCharCode(buffer[offset]);
        offset++;
    }
    console.log(message);
} 