// zig-wasm-ffi/js/webaudio.js
export function createAudioContext() {
    return new AudioContext();
}

export function decodeAudioData(context, data_ptr, len, callback, context_ptr) {
    const data = new Uint8Array(wasm_memory.buffer, data_ptr, len);
    context.decodeAudioData(data.buffer).then(buffer => callback(context_ptr, buffer));
}

export function createBufferSource(context) {
    return context.createBufferSource();
}

export function setBuffer(source, buffer) {
    source.buffer = buffer;
}

export function startSource(source) {
    source.start();
}