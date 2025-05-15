const std = @import("std");
const testing = std.testing;
const webaudio = @import("webaudio.zig");

// --- Mock JavaScript FFI Implementations & Control Variables ---

// Mock for env_createAudioContext
var mock_create_audio_context_should_succeed: bool = true;
var mock_created_audio_context_id: webaudio.AudioContextHandle = 1;
var mock_env_createAudioContext_call_count: u32 = 0;

pub fn env_createAudioContext() u32 {
    mock_env_createAudioContext_call_count += 1;
    if (mock_create_audio_context_should_succeed) {
        return mock_created_audio_context_id;
    } else {
        return 0; // 0 indicates failure
    }
}

// Mock for env_decodeAudioData
const MockDecodeParams = struct {
    context_id: u32,
    audio_data_ptr: [*]const u8,
    audio_data_len: usize,
    user_request_id: u32,
};
var mock_env_decodeAudioData_call_count: u32 = 0;
var mock_env_decodeAudioData_last_params: ?MockDecodeParams = null;
var mock_decode_audio_data_should_succeed_js_side: bool = true;
var mock_decode_audio_data_js_buffer_id: u32 = 100;
var mock_decode_audio_data_js_duration_ms: u32 = 3000;
var mock_decode_audio_data_js_length_samples: u32 = 44100 * 3;
var mock_decode_audio_data_js_num_channels: u32 = 2;
var mock_decode_audio_data_js_sample_rate_hz: u32 = 44100;

var mock_decodeAudioData_is_noop: bool = false;

pub fn env_decodeAudioData(
    context_id: u32,
    audio_data_ptr: [*]const u8,
    audio_data_len: usize,
    user_request_id: u32,
) void {
    mock_env_decodeAudioData_call_count += 1;
    mock_env_decodeAudioData_last_params = .{
        .context_id = context_id,
        .audio_data_ptr = audio_data_ptr,
        .audio_data_len = audio_data_len,
        .user_request_id = user_request_id,
    };

    if (mock_decodeAudioData_is_noop) {
        return;
    }

    if (mock_decode_audio_data_should_succeed_js_side) {
        webaudio.zig_internal_on_audio_buffer_decoded(
            user_request_id,
            mock_decode_audio_data_js_buffer_id,
            mock_decode_audio_data_js_duration_ms,
            mock_decode_audio_data_js_length_samples,
            mock_decode_audio_data_js_num_channels,
            mock_decode_audio_data_js_sample_rate_hz,
        );
    } else {
        webaudio.zig_internal_on_decode_error(user_request_id);
    }
}

// For the "duplicate pending request" test
var duplicate_test_first_call_done: bool = false;

// Helper to reset mock states before each test
fn reset_mock_states() void {
    mock_create_audio_context_should_succeed = true;
    mock_created_audio_context_id = 1;
    mock_env_createAudioContext_call_count = 0;

    mock_env_decodeAudioData_call_count = 0;
    mock_env_decodeAudioData_last_params = null;
    mock_decode_audio_data_should_succeed_js_side = true;
    mock_decode_audio_data_js_buffer_id = 100;
    mock_decode_audio_data_js_duration_ms = 3000;
    mock_decode_audio_data_js_length_samples = 44100 * 3;
    mock_decode_audio_data_js_num_channels = 2;
    mock_decode_audio_data_js_sample_rate_hz = 44100;
    mock_decodeAudioData_is_noop = false;

    duplicate_test_first_call_done = false; // Reset for the specific test

    webaudio.testing_reset_internal_webaudio_state_for_tests();
}

// --- Tests ---

test "initialize module state" {
    reset_mock_states();
    webaudio.init_webaudio_module_state();
    try testing.expect(webaudio.getAudioContextState() == .NotCreatedYet);
    try testing.expect(webaudio.g_decode_requests[0].status == .Free);
    try testing.expect(webaudio.g_decode_requests[0].user_request_id == 0);
}

test "createAudioContext success" {
    reset_mock_states();
    mock_create_audio_context_should_succeed = true;
    mock_created_audio_context_id = 123;

    const handle = webaudio.createAudioContext();
    try testing.expect(handle.? == 123);
    try testing.expect(webaudio.getAudioContextState() == .Ready);
    try testing.expect(mock_env_createAudioContext_call_count == 1);

    const handle2 = webaudio.createAudioContext();
    try testing.expect(handle2.? == 123);
    try testing.expect(mock_env_createAudioContext_call_count == 1);
}

test "createAudioContext failure" {
    reset_mock_states();
    mock_create_audio_context_should_succeed = false;

    const handle = webaudio.createAudioContext();
    try testing.expect(handle == null);
    try testing.expect(webaudio.getAudioContextState() == .Error);
    try testing.expect(mock_env_createAudioContext_call_count == 1);

    const handle2 = webaudio.createAudioContext();
    try testing.expect(handle2 == null);
    try testing.expect(mock_env_createAudioContext_call_count == 1);
}

test "getAudioContextState transitions" {
    reset_mock_states();
    try testing.expect(webaudio.getAudioContextState() == .NotCreatedYet);

    mock_create_audio_context_should_succeed = true;
    _ = webaudio.createAudioContext();
    try testing.expect(webaudio.getAudioContextState() == .Ready);

    reset_mock_states();
    try testing.expect(webaudio.getAudioContextState() == .NotCreatedYet);
    mock_create_audio_context_should_succeed = false;
    _ = webaudio.createAudioContext();
    try testing.expect(webaudio.getAudioContextState() == .Error);
}

test "requestDecodeAudioData success" {
    reset_mock_states();
    const ctx_handle = webaudio.createAudioContext().?;

    const sample_data_array = [_]u8{ 0, 1, 2, 3 };
    const sample_data_slice = sample_data_array[0..];
    const user_req_id: u32 = 10;

    mock_decode_audio_data_should_succeed_js_side = true;
    const requested = webaudio.requestDecodeAudioData(ctx_handle, sample_data_slice, user_req_id);
    try testing.expect(requested);
    try testing.expect(mock_env_decodeAudioData_call_count == 1);
    try testing.expect(mock_env_decodeAudioData_last_params.?.context_id == ctx_handle);
    try testing.expect(mock_env_decodeAudioData_last_params.?.audio_data_ptr == sample_data_slice.ptr);
    try testing.expect(mock_env_decodeAudioData_last_params.?.audio_data_len == sample_data_slice.len);
    try testing.expect(mock_env_decodeAudioData_last_params.?.user_request_id == user_req_id);

    const status = webaudio.getDecodeRequestStatus(user_req_id);
    try testing.expect(status.? == .Success);

    const info = webaudio.getDecodedAudioBufferInfo(user_req_id);
    try testing.expect(info != null);
    try testing.expect(info.?.js_buffer_id == mock_decode_audio_data_js_buffer_id);
    try testing.expect(info.?.duration_ms == mock_decode_audio_data_js_duration_ms);
}

test "requestDecodeAudioData js failure" {
    reset_mock_states();
    const ctx_handle = webaudio.createAudioContext().?;
    const sample_data_array = [_]u8{ 4, 5, 6 };
    const sample_data_slice = sample_data_array[0..];
    const user_req_id: u32 = 11;

    mock_decode_audio_data_should_succeed_js_side = false;
    const requested = webaudio.requestDecodeAudioData(ctx_handle, sample_data_slice, user_req_id);
    try testing.expect(requested);
    try testing.expect(mock_env_decodeAudioData_call_count == 1);
    try testing.expect(mock_env_decodeAudioData_last_params.?.user_request_id == user_req_id);

    const status = webaudio.getDecodeRequestStatus(user_req_id);
    try testing.expect(status.? == .Error);

    const info = webaudio.getDecodedAudioBufferInfo(user_req_id);
    try testing.expect(info == null);
}

test "requestDecodeAudioData no AudioContext" {
    reset_mock_states();
    webaudio.init_webaudio_module_state();
    mock_create_audio_context_should_succeed = false;
    _ = webaudio.createAudioContext(); // This sets internal state to Error
    try testing.expect(webaudio.getAudioContextState() == .Error);

    const sample_data_array = [_]u8{0};
    const sample_data_slice = sample_data_array[0..];
    const user_req_id: u32 = 12;

    const requested = webaudio.requestDecodeAudioData(0, sample_data_slice, user_req_id);
    try testing.expect(!requested);
    try testing.expect(mock_env_decodeAudioData_call_count == 0);

    const requested_with_stale_handle = webaudio.requestDecodeAudioData(123, sample_data_slice, user_req_id + 1);
    try testing.expect(!requested_with_stale_handle);
    try testing.expect(mock_env_decodeAudioData_call_count == 0);
}

test "requestDecodeAudioData invalid user_request_id (0)" {
    reset_mock_states();
    const ctx_handle = webaudio.createAudioContext().?;
    const sample_data_array = [_]u8{0};
    const sample_data_slice = sample_data_array[0..];
    const user_req_id: u32 = 0;
    const requested = webaudio.requestDecodeAudioData(ctx_handle, sample_data_slice, user_req_id);
    try testing.expect(!requested);
    try testing.expect(mock_env_decodeAudioData_call_count == 0);
}

test "requestDecodeAudioData too many requests" {
    reset_mock_states();
    const ctx_handle = webaudio.createAudioContext().?;
    const sample_data_array = [_]u8{0};
    const sample_data_slice = sample_data_array[0..];

    var i: u32 = 0;
    while (i < webaudio.MAX_DECODE_REQUESTS) : (i += 1) {
        mock_decode_audio_data_should_succeed_js_side = true;
        const success = webaudio.requestDecodeAudioData(ctx_handle, sample_data_slice, i + 1);
        try testing.expect(success);
        try testing.expect(webaudio.getDecodeRequestStatus(i + 1).? == .Success);
    }

    try testing.expect(mock_env_decodeAudioData_call_count == webaudio.MAX_DECODE_REQUESTS);

    const extra_req_id = webaudio.MAX_DECODE_REQUESTS + 1;
    const requested_extra = webaudio.requestDecodeAudioData(ctx_handle, sample_data_slice, extra_req_id);
    try testing.expect(!requested_extra);
    try testing.expect(mock_env_decodeAudioData_call_count == webaudio.MAX_DECODE_REQUESTS);
}

test "requestDecodeAudioData duplicate pending request" {
    reset_mock_states();
    const ctx_handle = webaudio.createAudioContext().?;
    const sample_data_array = [_]u8{0};
    const sample_data_slice = sample_data_array[0..];
    const user_req_id: u32 = 20;

    mock_decodeAudioData_is_noop = true; // Configure mock to not call back, leaving request pending

    const requested1 = webaudio.requestDecodeAudioData(ctx_handle, sample_data_slice, user_req_id);
    try testing.expect(requested1);
    try testing.expect(mock_env_decodeAudioData_call_count == 1);
    try testing.expect(webaudio.getDecodeRequestStatus(user_req_id).? == .Pending);

    const requested2 = webaudio.requestDecodeAudioData(ctx_handle, sample_data_slice, user_req_id);
    try testing.expect(!requested2);
    try testing.expect(mock_env_decodeAudioData_call_count == 1); // Not called again as it failed early
}

test "getDecodeRequestStatus and getDecodedAudioBufferInfo for non-existent request" {
    reset_mock_states();
    _ = webaudio.createAudioContext();

    const non_existent_req_id: u32 = 999;
    const status = webaudio.getDecodeRequestStatus(non_existent_req_id);
    try testing.expect(status == null);

    const info = webaudio.getDecodedAudioBufferInfo(non_existent_req_id);
    try testing.expect(info == null);
}

test "releaseDecodeRequest" {
    reset_mock_states();
    const ctx_handle = webaudio.createAudioContext().?;
    const sample_data_array = [_]u8{0};
    const sample_data_slice = sample_data_array[0..];
    const user_req_id: u32 = 30;

    mock_decode_audio_data_should_succeed_js_side = true;
    _ = webaudio.requestDecodeAudioData(ctx_handle, sample_data_slice, user_req_id);
    try testing.expect(webaudio.getDecodeRequestStatus(user_req_id).? == .Success);

    webaudio.releaseDecodeRequest(user_req_id);
    try testing.expect(webaudio.getDecodeRequestStatus(user_req_id) == null);

    const requested_again = webaudio.requestDecodeAudioData(ctx_handle, sample_data_slice, user_req_id);
    try testing.expect(requested_again);
    try testing.expect(webaudio.getDecodeRequestStatus(user_req_id).? == .Success);
}

test "zig_internal_on_audio_buffer_decoded updates correctly" {
    reset_mock_states();
    const user_req_id: u32 = 40;
    const ctx_handle = webaudio.createAudioContext().?;
    const sample_data_array = [_]u8{0};
    const sample_data_slice = sample_data_array[0..];

    mock_decodeAudioData_is_noop = true;
    _ = webaudio.requestDecodeAudioData(ctx_handle, sample_data_slice, user_req_id);
    try testing.expect(webaudio.getDecodeRequestStatus(user_req_id).? == .Pending);

    const js_buf_id: u32 = 200;
    const dur_ms: u32 = 5000;
    const len_samp: u32 = 220500;
    const chans: u32 = 1;
    const sr_hz: u32 = 44100;

    webaudio.zig_internal_on_audio_buffer_decoded(user_req_id, js_buf_id, dur_ms, len_samp, chans, sr_hz);

    const status = webaudio.getDecodeRequestStatus(user_req_id);
    try testing.expect(status.? == .Success);
    const info = webaudio.getDecodedAudioBufferInfo(user_req_id);
    try testing.expect(info != null);
    try testing.expect(info.?.js_buffer_id == js_buf_id);
    try testing.expect(info.?.duration_ms == dur_ms);
    try testing.expect(info.?.length_samples == len_samp);
    try testing.expect(info.?.num_channels == chans);
    try testing.expect(info.?.sample_rate_hz == sr_hz);
}

test "zig_internal_on_decode_error updates correctly" {
    reset_mock_states();
    const user_req_id: u32 = 41;
    const ctx_handle = webaudio.createAudioContext().?;
    const sample_data_array = [_]u8{0};
    const sample_data_slice = sample_data_array[0..];

    mock_decodeAudioData_is_noop = true;
    _ = webaudio.requestDecodeAudioData(ctx_handle, sample_data_slice, user_req_id);
    try testing.expect(webaudio.getDecodeRequestStatus(user_req_id).? == .Pending);

    webaudio.zig_internal_on_decode_error(user_req_id);

    const status = webaudio.getDecodeRequestStatus(user_req_id);
    try testing.expect(status.? == .Error);
    const info = webaudio.getDecodedAudioBufferInfo(user_req_id);
    try testing.expect(info == null);
}

test "Callback for non-existent user_request_id in zig_internal funcs" {
    reset_mock_states();
    const non_existent_req_id: u32 = 1000;
    const known_req_id: u32 = 42;
    const ctx_handle = webaudio.createAudioContext().?;
    const sample_data_array = [_]u8{0};
    const sample_data_slice = sample_data_array[0..];

    mock_decodeAudioData_is_noop = true;
    _ = webaudio.requestDecodeAudioData(ctx_handle, sample_data_slice, known_req_id);
    try testing.expect(webaudio.getDecodeRequestStatus(known_req_id).? == .Pending);

    webaudio.zig_internal_on_audio_buffer_decoded(non_existent_req_id, 1, 1, 1, 1, 1);
    try testing.expect(webaudio.getDecodeRequestStatus(known_req_id).? == .Pending);

    webaudio.zig_internal_on_decode_error(non_existent_req_id);
    try testing.expect(webaudio.getDecodeRequestStatus(known_req_id).? == .Pending);
}
