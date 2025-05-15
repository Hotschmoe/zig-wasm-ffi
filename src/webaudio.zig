// zig-wasm-ffi/src/webaudio.zig

// --- Configuration ---
pub const MAX_DECODE_REQUESTS: usize = 16; // Maximum number of concurrent audio decode requests

// --- Named Enums and Types ---
pub const AudioContextState = enum {
    Uninitialized,
    Ready,
    Error,
    NotCreatedYet, // Added for getAudioContextState return
};

// --- FFI Imports (JavaScript functions Zig will call) ---
// These functions are expected to be provided in the JavaScript 'env' object during Wasm instantiation.
extern "env" fn env_createAudioContext() u32; // Returns a non-zero ID for the AudioContext on success, 0 on failure.
extern "env" fn env_decodeAudioData(
    context_id: u32, // The ID of the AudioContext to use for decoding.
    audio_data_ptr: [*]const u8, // Pointer to the audio data in Wasm memory. CHANGED to [*] for slice data
    audio_data_len: usize, // Length of the audio data.
    user_request_id: u32, // A user-defined ID to correlate this request with its async response.
) void;

// New FFI import for playing a decoded audio buffer
extern "env" fn env_playDecodedAudio(audio_context_id: u32, js_decoded_buffer_id: u32) void;

// FFI imports for tagged, looping sound playback control
extern "env" fn env_playLoopingTaggedSound(audio_context_id: u32, js_buffer_id: u32, sound_instance_tag: u32) void;
extern "env" fn env_stopTaggedSound(audio_context_id: u32, sound_instance_tag: u32) void;

// --- State Management ---

/// Opaque handle representing an AudioContext instance managed by JavaScript.
/// A value of 0 is considered invalid.
pub const AudioContextHandle = u32;

var g_audio_context_handle: AudioContextHandle = 0;
var g_current_audio_context_state: AudioContextState = .Uninitialized; // Use named enum

/// Status of an audio data decoding request.
pub const DecodeStatus = enum {
    Free, // Slot is available
    Pending,
    Success,
    Error,
};

/// Information about a successfully decoded audio buffer.
pub const AudioBufferInfo = struct {
    js_buffer_id: u32, // ID assigned by JavaScript to the decoded AudioBuffer object (for future use, e.g., playing).
    duration_ms: u32, // Duration of the audio in milliseconds.
    length_samples: u32, // Total number of samples in the buffer.
    num_channels: u32, // Number of audio channels.
    sample_rate_hz: u32, // Sample rate in Hertz.
};

// Public for testing purposes, consider a testing-specific API if this feels too exposed.
pub const DecodeRequestEntry = struct {
    user_request_id: u32 = 0, // ID provided by the Zig application user.
    status: DecodeStatus = .Free,
    buffer_info: ?AudioBufferInfo = null,
    // error_code: u32 = 0, // Could be added for more detailed error reporting
};

// Public for testing purposes
pub var g_decode_requests: [MAX_DECODE_REQUESTS]DecodeRequestEntry = undefined;

// --- Exported Zig functions for JavaScript to call (Async Callbacks) ---

/// Called by JavaScript when an AudioBuffer has been successfully decoded.
/// Parameters:
/// - user_request_id: The ID originally provided by the Zig application for this decode request.
/// - js_buffer_id: An ID assigned by JavaScript for the newly decoded AudioBuffer object.
/// - duration_ms: Duration of the audio in milliseconds.
/// - length_samples: Total number of samples.
/// - num_channels: Number of audio channels.
/// - sample_rate_hz: Sample rate in Hertz.
pub export fn zig_internal_on_audio_buffer_decoded(
    user_request_id: u32,
    js_buffer_id: u32,
    duration_ms: u32,
    length_samples: u32,
    num_channels: u32,
    sample_rate_hz: u32,
) void {
    var i: usize = 0;
    while (i < MAX_DECODE_REQUESTS) : (i += 1) {
        if (g_decode_requests[i].user_request_id == user_request_id and g_decode_requests[i].status == .Pending) {
            g_decode_requests[i].status = .Success;
            g_decode_requests[i].buffer_info = AudioBufferInfo{
                .js_buffer_id = js_buffer_id,
                .duration_ms = duration_ms,
                .length_samples = length_samples,
                .num_channels = num_channels,
                .sample_rate_hz = sample_rate_hz,
            };
            return;
        }
    }
}

/// Called by JavaScript when an error occurs during audio data decoding.
pub export fn zig_internal_on_decode_error(user_request_id: u32) void {
    var i: usize = 0;
    while (i < MAX_DECODE_REQUESTS) : (i += 1) {
        if (g_decode_requests[i].user_request_id == user_request_id and g_decode_requests[i].status == .Pending) {
            g_decode_requests[i].status = .Error;
            g_decode_requests[i].buffer_info = null;
            return;
        }
    }
}

// --- Public API for Zig Application ---

/// Initializes or resets the WebAudio module's internal state.
/// Call this once at the beginning if you need a clean state, especially for testing.
pub fn init_webaudio_module_state() void {
    g_audio_context_handle = 0;
    g_current_audio_context_state = .Uninitialized;
    var i: usize = 0;
    while (i < MAX_DECODE_REQUESTS) : (i += 1) {
        g_decode_requests[i] = .{}; // Resets to default values (.status = .Free, .user_request_id = 0)
    }
}

/// Attempts to create (or retrieve if already created) an AudioContext.
/// This function is synchronous as `new AudioContext()` in JavaScript is synchronous.
/// Returns: An `AudioContextHandle` (a non-zero u32 ID) on success, or `null` on failure.
pub fn createAudioContext() ?AudioContextHandle {
    if (g_current_audio_context_state == .Ready and g_audio_context_handle != 0) {
        return g_audio_context_handle;
    }
    if (g_current_audio_context_state == .Error) {
        return null;
    }

    const ctx_id = env_createAudioContext();
    if (ctx_id == 0) {
        g_current_audio_context_state = .Error;
        g_audio_context_handle = 0;
        return null;
    }

    g_audio_context_handle = ctx_id;
    g_current_audio_context_state = .Ready;
    return g_audio_context_handle;
}

/// Returns the current state of the global AudioContext.
pub fn getAudioContextState() AudioContextState {
    if (g_audio_context_handle == 0 and g_current_audio_context_state == .Uninitialized) return .NotCreatedYet;
    return g_current_audio_context_state;
}

/// Requests decoding of the provided audio data using the specified AudioContext.
/// This operation is asynchronous. JavaScript will call `zig_internal_on_audio_buffer_decoded`
/// or `zig_internal_on_decode_error` upon completion.
/// Parameters:
/// - ctx_handle: The handle of the AudioContext to use, obtained from `createAudioContext()`.
/// - audio_data: A slice containing the raw audio file data (e.g., MP3, WAV).
/// - user_request_id: A unique u32 ID provided by the caller to track this specific decode request.
///                    This ID will be returned in the corresponding `zig_internal_` callback.
/// Returns: `true` if the decode request was successfully submitted, `false` otherwise (e.g.,
///          invalid context, no free request slots, or user_request_id already pending).
pub fn requestDecodeAudioData(
    ctx_handle: AudioContextHandle,
    audio_data: []const u8, // Zig slice
    user_request_id: u32,
) bool {
    if (g_current_audio_context_state != .Ready or ctx_handle != g_audio_context_handle or ctx_handle == 0) {
        return false;
    }
    if (user_request_id == 0) return false;

    var target_slot_idx: ?usize = null;
    var first_free_idx: ?usize = null;
    var i: usize = 0;

    while (i < MAX_DECODE_REQUESTS) : (i += 1) {
        if (g_decode_requests[i].user_request_id == user_request_id) {
            if (g_decode_requests[i].status == .Pending) return false;
            target_slot_idx = i;
            break;
        }
        if (g_decode_requests[i].status == .Free and first_free_idx == null) {
            first_free_idx = i;
        }
    }

    if (target_slot_idx == null) {
        if (first_free_idx) |idx| {
            target_slot_idx = idx;
        } else {
            return false;
        }
    }

    const final_slot_idx = target_slot_idx orelse return false;

    g_decode_requests[final_slot_idx] = .{
        .user_request_id = user_request_id,
        .status = .Pending,
        .buffer_info = null,
    };

    // Pass audio_data.ptr (which is *const u8) and length.
    // The FFI declaration for env_decodeAudioData now expects [*]const u8.
    // Zig should handle the implicit cast from *const u8 to [*]const u8 for FFI if length is provided.
    // However, to be explicit and correct with the change to [*]const u8 in FFI:
    // we should pass a pointer that is already a many-pointer if the FFI expects it.
    // Given audio_data is []const u8, audio_data.ptr is *const u8.
    // The change to extern fn env_decodeAudioData(..., audio_data_ptr: [*]const u8, ...) was made.
    // This means the JS side receives a view based on this pointer and length.
    env_decodeAudioData(ctx_handle, audio_data.ptr, audio_data.len, user_request_id);
    return true;
}

/// Retrieves the current status of a decode request.
/// Parameters:
/// - user_request_id: The ID used when `requestDecodeAudioData` was called.
/// Returns: The `DecodeStatus` of the request, or `null` if the `user_request_id` is not found.
pub fn getDecodeRequestStatus(user_request_id: u32) ?DecodeStatus {
    var i: usize = 0;
    while (i < MAX_DECODE_REQUESTS) : (i += 1) {
        if (g_decode_requests[i].user_request_id == user_request_id and g_decode_requests[i].status != .Free) {
            return g_decode_requests[i].status;
        }
    }
    return null;
}

/// Retrieves information about a successfully decoded audio buffer.
/// Parameters:
/// - user_request_id: The ID used when `requestDecodeAudioData` was called.
/// Returns: An `AudioBufferInfo` struct if the request completed successfully,
///          `null` otherwise (e.g., request not found, pending, or resulted in an error).
pub fn getDecodedAudioBufferInfo(user_request_id: u32) ?AudioBufferInfo {
    var i: usize = 0;
    while (i < MAX_DECODE_REQUESTS) : (i += 1) {
        if (g_decode_requests[i].user_request_id == user_request_id) {
            if (g_decode_requests[i].status == .Success) {
                return g_decode_requests[i].buffer_info;
            } else {
                return null;
            }
        }
    }
    return null;
}

/// Plays a previously decoded audio buffer.
/// Parameters:
/// - ctx_handle: The handle of the AudioContext to use.
/// - js_decoded_buffer_id: The ID of the decoded buffer (obtained from AudioBufferInfo.js_buffer_id).
pub fn playDecodedAudio(ctx_handle: AudioContextHandle, js_decoded_buffer_id: u32) void {
    if (g_current_audio_context_state != .Ready or ctx_handle != g_audio_context_handle or ctx_handle == 0) {
        // Optionally log an error or handle it
        return;
    }
    if (js_decoded_buffer_id == 0) {
        // Optionally log an error (js_buffer_id 0 is invalid)
        return;
    }
    env_playDecodedAudio(ctx_handle, js_decoded_buffer_id);
}

/// Plays a previously decoded audio buffer in a loop, associated with a tag.
/// If a sound with the same tag is already playing, it is stopped and replaced.
/// Parameters:
/// - ctx_handle: The handle of the AudioContext to use.
/// - js_buffer_id: The ID of the decoded buffer.
/// - sound_instance_tag: A u32 tag to uniquely identify this sound instance for later control (e.g., stopping).
pub fn playLoopingTaggedSound(ctx_handle: AudioContextHandle, js_buffer_id: u32, sound_instance_tag: u32) void {
    if (g_current_audio_context_state != .Ready or ctx_handle != g_audio_context_handle or ctx_handle == 0) return;
    if (js_buffer_id == 0) return; // 0 is not a valid js_buffer_id from our JS glue
    if (sound_instance_tag == 0) return; // 0 might be reserved or indicate no tag
    env_playLoopingTaggedSound(ctx_handle, js_buffer_id, sound_instance_tag);
}

/// Stops a tagged sound instance if it is currently playing.
/// Parameters:
/// - ctx_handle: The handle of the AudioContext associated with the sound.
/// - sound_instance_tag: The u32 tag of the sound instance to stop.
pub fn stopTaggedSound(ctx_handle: AudioContextHandle, sound_instance_tag: u32) void {
    if (g_current_audio_context_state != .Ready or ctx_handle != g_audio_context_handle or ctx_handle == 0) return;
    if (sound_instance_tag == 0) return;
    env_stopTaggedSound(ctx_handle, sound_instance_tag);
}

/// Releases a decode request slot, marking it as free.
/// Call this when you are done with a `user_request_id` to allow its slot to be reused.
/// Parameters:
/// - user_request_id: The ID of the decode request to release.
pub fn releaseDecodeRequest(user_request_id: u32) void {
    var i: usize = 0;
    while (i < MAX_DECODE_REQUESTS) : (i += 1) {
        if (g_decode_requests[i].user_request_id == user_request_id) {
            g_decode_requests[i] = .{};
            return;
        }
    }
}

// --- Test Utilities ---
// This function is intended for use in test environments to reset the global state.
pub fn testing_reset_internal_webaudio_state_for_tests() void {
    init_webaudio_module_state();
}
