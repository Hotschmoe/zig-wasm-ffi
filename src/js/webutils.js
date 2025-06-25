const webUtils = {
    memory: null,
};

export function initWebUtilsJs(wasmMemory) {
    webUtils.memory = wasmMemory;
    console.log("[webutils.js] WebUtils initialized with Wasm memory.");
}

export function env_js_log_message_with_length(messagePtr, messageLen) {
    if (!webUtils.memory) {
        console.error("WASM memory not available to webutils.js for logging.");
        console.log(`[WASM LOG (mem err)] ptr: ${messagePtr}, len: ${messageLen}`);
        return;
    }
    try {
        const memoryBuffer = webUtils.memory.buffer;
        const messageBuffer = new Uint8Array(memoryBuffer, messagePtr, messageLen);
        const message = new TextDecoder('utf-8').decode(messageBuffer);
        console.log(message);
    } catch (e) {
        console.error("Error decoding WASM string for logging:", e);
        console.log(`[WASM LOG (decode err)] ptr: ${messagePtr}, len: ${messageLen}`);
    }
}