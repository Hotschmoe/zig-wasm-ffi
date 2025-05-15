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