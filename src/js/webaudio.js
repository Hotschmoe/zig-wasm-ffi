// zig-wasm-ffi/js/webaudio.js

let wasmInstance = null; // Stores the Wasm instance for calling exported Zig functions.

// --- Internal JavaScript State ---
let nextAudioContextId = 1; // Counter for generating unique AudioContext IDs.
const activeAudioContexts = {}; // Stores active AudioContext objects, keyed by ID.

let nextJsDecodedBufferId = 1; // Counter for JS-side decoded buffer IDs.
const jsDecodedBuffers = {}; // Stores successfully decoded AudioBuffer objects, keyed by ID.
                               // This is for potential future use, e.g., playing the sound by this ID.

const active_tagged_sources = {}; // Stores currently playing tagged AudioBufferSourceNodes, keyed by sound_instance_tag.

// --- Setup Function (Called by user's JavaScript) ---

/**
 * Initializes the WebAudio JavaScript glue code with the Wasm instance.
 * This must be called after the Wasm module is instantiated and before any WebAudio
 * functionality that relies on callbacks to Zig is used.
 * @param {object} instance The instantiated Wasm module instance, containing `instance.exports`.
 */
export function setupWebAudio(instance) {
    if (!instance || !instance.exports) {
        console.error("[webaudio.js] Wasm instance or exports not provided to setupWebAudio. Callbacks to Zig will fail.");
        wasmInstance = null;
        return;
    }
    wasmInstance = instance;
    console.log("[webaudio.js] WebAudio system initialized with Wasm instance.");
}

// --- Functions Exported to Zig (via `env` object in Wasm imports) ---

/**
 * Called by Zig to create a new Web Audio API AudioContext.
 * @returns {number} A non-zero ID for the created AudioContext on success, or 0 on failure.
 */
export function env_createAudioContext() {
    try {
        const newCtx = new AudioContext();
        if (!newCtx) {
            console.error("[webaudio.js] Failed to create AudioContext (returned null or undefined).");
            return 0; // 0 indicates failure to Zig.
        }
        const id = nextAudioContextId++;
        activeAudioContexts[id] = newCtx;
        console.log(`[webaudio.js] AudioContext created with ID: ${id}`);
        return id;
    } catch (e) {
        console.error("[webaudio.js] Error creating AudioContext:", e);
        return 0; // 0 indicates failure.
    }
}

/**
 * Called by Zig to request decoding of audio data.
 * This function is asynchronous. It initiates the decoding and returns immediately.
 * Callbacks (`zig_internal_on_audio_buffer_decoded` or `zig_internal_on_decode_error`)
 * will be made into Wasm upon completion or failure.
 * @param {number} context_id The ID of the AudioContext to use for decoding.
 * @param {number} data_ptr Pointer to the audio data in Wasm memory.
 * @param {number} data_len Length of the audio data.
 * @param {number} user_request_id A user-defined ID from Zig to correlate async responses.
 */
export async function env_decodeAudioData(context_id, data_ptr, data_len, user_request_id) {
    if (!wasmInstance || !wasmInstance.exports) {
        console.error("[webaudio.js] Wasm instance not available for decodeAudioData callbacks. Ensure setupWebAudio was called.");
        // Cannot call back to Zig without wasmInstance.exports.
        return;
    }

    const ctx = activeAudioContexts[context_id];
    if (!ctx) {
        console.error(`[webaudio.js] env_decodeAudioData: AudioContext with ID ${context_id} not found.`);
        if (wasmInstance.exports.zig_internal_on_decode_error) {
            wasmInstance.exports.zig_internal_on_decode_error(user_request_id);
        }
        return;
    }

    if (!wasmInstance.exports.memory || !(wasmInstance.exports.memory.buffer instanceof ArrayBuffer)) {
        console.error("[webaudio.js] Wasm memory not available or not an ArrayBuffer.");
        if (wasmInstance.exports.zig_internal_on_decode_error) {
            wasmInstance.exports.zig_internal_on_decode_error(user_request_id);
        }
        return;
    }

    try {
        // Copy audio data from Wasm memory to avoid issues if Wasm memory resizes or the view becomes detached.
        const wasmMemoryU8Array = new Uint8Array(wasmInstance.exports.memory.buffer, data_ptr, data_len);
        const audioDataCopy = wasmMemoryU8Array.slice().buffer; // .slice() creates a copy, .buffer gets its ArrayBuffer.

        ctx.decodeAudioData(
            audioDataCopy,
            (decodedBuffer) => { // Success callback for browser's decodeAudioData
                if (wasmInstance.exports.zig_internal_on_audio_buffer_decoded) {
                    const js_decoded_buffer_id = nextJsDecodedBufferId++;
                    jsDecodedBuffers[js_decoded_buffer_id] = decodedBuffer;

                    const duration_ms = Math.round(decodedBuffer.duration * 1000);
                    const sample_rate_hz = Math.round(decodedBuffer.sampleRate);

                    wasmInstance.exports.zig_internal_on_audio_buffer_decoded(
                        user_request_id,
                        js_decoded_buffer_id,
                        duration_ms,
                        decodedBuffer.length, // length is in samples
                        decodedBuffer.numberOfChannels,
                        sample_rate_hz
                    );
                } else {
                    console.warn("[webaudio.js] Wasm export 'zig_internal_on_audio_buffer_decoded' not found. Decode succeeded but could not inform Zig.");
                }
            },
            (error) => { // Error callback for browser's decodeAudioData
                // DOMException is often passed here.
                console.error("[webaudio.js] Error decoding audio data in AudioContext:", error);
                if (wasmInstance.exports.zig_internal_on_decode_error) {
                    // Consider passing a specific error code based on 'error' type/message if needed.
                    wasmInstance.exports.zig_internal_on_decode_error(user_request_id);
                } else {
                    console.warn("[webaudio.js] Wasm export 'zig_internal_on_decode_error' not found. Decode failed and could not inform Zig.");
                }
            }
        );
    } catch (e) {
        console.error("[webaudio.js] Exception during env_decodeAudioData preparation or call to ctx.decodeAudioData:", e);
        if (wasmInstance.exports.zig_internal_on_decode_error) {
            wasmInstance.exports.zig_internal_on_decode_error(user_request_id);
        }
    }
}

/**
 * Called by Zig to play a previously decoded audio buffer.
 * @param {number} context_id The ID of the AudioContext to use.
 * @param {number} js_decoded_buffer_id The ID of the decoded AudioBuffer (stored in jsDecodedBuffers).
 */
export function env_playDecodedAudio(context_id, js_decoded_buffer_id) {
    const ctx = activeAudioContexts[context_id];
    if (!ctx) {
        console.error(`[webaudio.js] env_playDecodedAudio: AudioContext with ID ${context_id} not found.`);
        return;
    }

    const bufferToPlay = jsDecodedBuffers[js_decoded_buffer_id];
    if (!bufferToPlay) {
        console.error(`[webaudio.js] env_playDecodedAudio: Decoded AudioBuffer with JS ID ${js_decoded_buffer_id} not found.`);
        return;
    }

    try {
        const source = ctx.createBufferSource();
        source.buffer = bufferToPlay;
        source.connect(ctx.destination);
        source.start(0); // Play immediately
        console.log(`[webaudio.js] Playing decoded buffer with JS ID ${js_decoded_buffer_id} on AudioContext ID ${context_id}.`);
    } catch (e) {
        console.error(`[webaudio.js] Error playing decoded audio (JS ID ${js_decoded_buffer_id}):`, e);
    }
}

/**
 * Called by Zig to play a decoded audio buffer in a loop, identified by a tag.
 * If another sound with the same tag is already playing, it's stopped first.
 * @param {number} context_id The ID of the AudioContext to use.
 * @param {number} js_buffer_id The ID of the decoded AudioBuffer.
 * @param {number} sound_instance_tag A tag from Zig to identify this sound instance.
 */
export function env_playLoopingTaggedSound(context_id, js_buffer_id, sound_instance_tag) {
    const ctx = activeAudioContexts[context_id];
    if (!ctx) {
        console.error(`[webaudio.js] env_playLoopingTaggedSound: AudioContext ID ${context_id} not found.`);
        return;
    }
    const bufferToPlay = jsDecodedBuffers[js_buffer_id];
    if (!bufferToPlay) {
        console.error(`[webaudio.js] env_playLoopingTaggedSound: Decoded AudioBuffer JS ID ${js_buffer_id} not found.`);
        return;
    }

    // Stop and remove any existing source with the same tag
    if (active_tagged_sources[sound_instance_tag]) {
        try {
            active_tagged_sources[sound_instance_tag].stop();
            console.log(`[webaudio.js] Stopped existing tagged sound (tag: ${sound_instance_tag}) before playing new one.`);
        } catch (e) { /* Ignore errors if already stopped or in an invalid state */ }
        delete active_tagged_sources[sound_instance_tag];
    }

    try {
        const source = ctx.createBufferSource();
        source.buffer = bufferToPlay;
        source.loop = true;
        source.connect(ctx.destination);
        source.start(0);
        active_tagged_sources[sound_instance_tag] = source;
        console.log(`[webaudio.js] Started looping tagged sound (tag: ${sound_instance_tag}, buffer JS ID: ${js_buffer_id}) on AudioContext ID ${context_id}.`);
    } catch (e) {
        console.error(`[webaudio.js] Error playing looping tagged sound (tag: ${sound_instance_tag}):`, e);
    }
}

/**
 * Called by Zig to stop a tagged, playing sound instance.
 * @param {number} context_id The ID of the AudioContext (currently unused but good for consistency).
 * @param {number} sound_instance_tag The tag of the sound instance to stop.
 */
export function env_stopTaggedSound(context_id, sound_instance_tag) {
    // context_id is not currently used but is part of the function signature for consistency.
    const sourceToStop = active_tagged_sources[sound_instance_tag];
    if (sourceToStop) {
        try {
            sourceToStop.stop();
            console.log(`[webaudio.js] Stopped tagged sound (tag: ${sound_instance_tag}).`);
        } catch (e) {
            console.error(`[webaudio.js] Error stopping tagged sound (tag: ${sound_instance_tag}):`, e);
        }
        delete active_tagged_sources[sound_instance_tag];
    } else {
        console.warn(`[webaudio.js] env_stopTaggedSound: No active sound found for tag ${sound_instance_tag} to stop.`);
    }
}
