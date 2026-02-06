// zig-wasm-ffi/src/webaudio.zig
const builtin = @import("builtin");

// --- Configuration ---
pub const MAX_DECODE_REQUESTS: usize = 16;

// --- Types ---
pub const AudioContextState = enum { Uninitialized, Ready, Error, NotCreatedYet };

/// 0 is invalid.
pub const AudioContextHandle = u32;

pub const DecodeStatus = enum { Free, Pending, Success, Error };

pub const AudioBufferInfo = struct {
    js_buffer_id: u32,
    duration_ms: u32,
    length_samples: u32,
    num_channels: u32,
    sample_rate_hz: u32,
};

pub const DecodeRequestEntry = struct {
    user_request_id: u32 = 0,
    status: DecodeStatus = .Free,
    buffer_info: ?AudioBufferInfo = null,
};

// --- FFI Binding Layer ---
// WASM builds: direct extern "env" calls (unreferenced in test builds, DCE'd by compiler).
// Test builds: calls through overridable function pointers.

extern "env" fn env_createAudioContext() u32;
extern "env" fn env_decodeAudioData(u32, [*]const u8, usize, u32) void;
extern "env" fn env_playDecodedAudio(u32, u32) void;
extern "env" fn env_playLoopingTaggedSound(u32, u32, u32) void;
extern "env" fn env_stopTaggedSound(u32, u32) void;

fn noopCreate() u32 { return 0; }
fn noopDecode(_: u32, _: [*]const u8, _: usize, _: u32) void {}
fn noop2(_: u32, _: u32) void {}
fn noop3(_: u32, _: u32, _: u32) void {}

pub var mock_createAudioContext: *const fn () u32 = &noopCreate;
pub var mock_decodeAudioData: *const fn (u32, [*]const u8, usize, u32) void = &noopDecode;
pub var mock_playDecodedAudio: *const fn (u32, u32) void = &noop2;
pub var mock_playLoopingTaggedSound: *const fn (u32, u32, u32) void = &noop3;
pub var mock_stopTaggedSound: *const fn (u32, u32) void = &noop2;

inline fn ffiCreateAudioContext() u32 {
    if (comptime builtin.is_test) return mock_createAudioContext();
    return env_createAudioContext();
}
inline fn ffiDecodeAudioData(ctx: u32, ptr: [*]const u8, len: usize, id: u32) void {
    if (comptime builtin.is_test) return mock_decodeAudioData(ctx, ptr, len, id);
    return env_decodeAudioData(ctx, ptr, len, id);
}
inline fn ffiPlayDecodedAudio(ctx: u32, buf: u32) void {
    if (comptime builtin.is_test) return mock_playDecodedAudio(ctx, buf);
    return env_playDecodedAudio(ctx, buf);
}
inline fn ffiPlayLoopingTaggedSound(ctx: u32, buf: u32, tag: u32) void {
    if (comptime builtin.is_test) return mock_playLoopingTaggedSound(ctx, buf, tag);
    return env_playLoopingTaggedSound(ctx, buf, tag);
}
inline fn ffiStopTaggedSound(ctx: u32, tag: u32) void {
    if (comptime builtin.is_test) return mock_stopTaggedSound(ctx, tag);
    return env_stopTaggedSound(ctx, tag);
}

// --- State ---

var g_audio_context_handle: AudioContextHandle = 0;
var g_current_audio_context_state: AudioContextState = .Uninitialized;
pub var g_decode_requests: [MAX_DECODE_REQUESTS]DecodeRequestEntry = undefined;

// --- Internal Helpers ---

fn findRequest(user_request_id: u32) ?usize {
    for (0..MAX_DECODE_REQUESTS) |i| {
        if (g_decode_requests[i].user_request_id == user_request_id and g_decode_requests[i].status != .Free) {
            return i;
        }
    }
    return null;
}

fn findPendingRequest(user_request_id: u32) ?usize {
    for (0..MAX_DECODE_REQUESTS) |i| {
        if (g_decode_requests[i].user_request_id == user_request_id and g_decode_requests[i].status == .Pending) {
            return i;
        }
    }
    return null;
}

fn isContextValid(ctx_handle: AudioContextHandle) bool {
    return g_current_audio_context_state == .Ready and ctx_handle == g_audio_context_handle and ctx_handle != 0;
}

// --- Exported Zig functions (called by JavaScript for async callbacks) ---

pub export fn zig_internal_on_audio_buffer_decoded(
    user_request_id: u32,
    js_buffer_id: u32,
    duration_ms: u32,
    length_samples: u32,
    num_channels: u32,
    sample_rate_hz: u32,
) void {
    const i = findPendingRequest(user_request_id) orelse return;
    g_decode_requests[i].status = .Success;
    g_decode_requests[i].buffer_info = .{
        .js_buffer_id = js_buffer_id,
        .duration_ms = duration_ms,
        .length_samples = length_samples,
        .num_channels = num_channels,
        .sample_rate_hz = sample_rate_hz,
    };
}

pub export fn zig_internal_on_decode_error(user_request_id: u32) void {
    const i = findPendingRequest(user_request_id) orelse return;
    g_decode_requests[i].status = .Error;
    g_decode_requests[i].buffer_info = null;
}

// --- Public API ---

pub fn init_webaudio_module_state() void {
    g_audio_context_handle = 0;
    g_current_audio_context_state = .Uninitialized;
    @memset(&g_decode_requests, .{});
}

/// Returns existing handle if already created, or creates a new one via JS FFI.
pub fn createAudioContext() ?AudioContextHandle {
    if (g_current_audio_context_state == .Ready and g_audio_context_handle != 0) {
        return g_audio_context_handle;
    }
    if (g_current_audio_context_state == .Error) {
        return null;
    }

    const ctx_id = ffiCreateAudioContext();
    if (ctx_id == 0) {
        g_current_audio_context_state = .Error;
        g_audio_context_handle = 0;
        return null;
    }

    g_audio_context_handle = ctx_id;
    g_current_audio_context_state = .Ready;
    return g_audio_context_handle;
}

pub fn getAudioContextState() AudioContextState {
    if (g_audio_context_handle == 0 and g_current_audio_context_state == .Uninitialized) return .NotCreatedYet;
    return g_current_audio_context_state;
}

/// Async: JS calls zig_internal_on_audio_buffer_decoded or zig_internal_on_decode_error on completion.
/// user_request_id must be non-zero and unique among pending requests.
pub fn requestDecodeAudioData(ctx_handle: AudioContextHandle, audio_data: []const u8, user_request_id: u32) bool {
    if (!isContextValid(ctx_handle)) return false;
    if (user_request_id == 0) return false;

    var target_slot_idx: ?usize = null;
    var first_free_idx: ?usize = null;

    for (0..MAX_DECODE_REQUESTS) |i| {
        if (g_decode_requests[i].user_request_id == user_request_id) {
            if (g_decode_requests[i].status == .Pending) return false;
            target_slot_idx = i;
            break;
        }
        if (g_decode_requests[i].status == .Free and first_free_idx == null) {
            first_free_idx = i;
        }
    }

    const final_slot_idx = target_slot_idx orelse first_free_idx orelse return false;

    g_decode_requests[final_slot_idx] = .{
        .user_request_id = user_request_id,
        .status = .Pending,
        .buffer_info = null,
    };

    ffiDecodeAudioData(ctx_handle, audio_data.ptr, audio_data.len, user_request_id);
    return true;
}

pub fn getDecodeRequestStatus(user_request_id: u32) ?DecodeStatus {
    const i = findRequest(user_request_id) orelse return null;
    return g_decode_requests[i].status;
}

pub fn getDecodedAudioBufferInfo(user_request_id: u32) ?AudioBufferInfo {
    const i = findRequest(user_request_id) orelse return null;
    if (g_decode_requests[i].status == .Success) return g_decode_requests[i].buffer_info;
    return null;
}

pub fn playDecodedAudio(ctx_handle: AudioContextHandle, js_decoded_buffer_id: u32) void {
    if (!isContextValid(ctx_handle)) return;
    if (js_decoded_buffer_id == 0) return;
    ffiPlayDecodedAudio(ctx_handle, js_decoded_buffer_id);
}

/// Replaces any existing sound with the same tag.
pub fn playLoopingTaggedSound(ctx_handle: AudioContextHandle, js_buffer_id: u32, sound_instance_tag: u32) void {
    if (!isContextValid(ctx_handle)) return;
    if (js_buffer_id == 0 or sound_instance_tag == 0) return;
    ffiPlayLoopingTaggedSound(ctx_handle, js_buffer_id, sound_instance_tag);
}

pub fn stopTaggedSound(ctx_handle: AudioContextHandle, sound_instance_tag: u32) void {
    if (!isContextValid(ctx_handle)) return;
    if (sound_instance_tag == 0) return;
    ffiStopTaggedSound(ctx_handle, sound_instance_tag);
}

/// Frees the slot for reuse by future decode requests.
pub fn releaseDecodeRequest(user_request_id: u32) void {
    const i = findRequest(user_request_id) orelse return;
    g_decode_requests[i] = .{};
}
