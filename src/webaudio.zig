// zig-wasm-ffi/src/webaudio.zig
// const std = @import("std"); // Removed std

// Opaque types for JavaScript objects
pub const AudioContext = opaque {};
pub const AudioBuffer = opaque {};
pub const AudioBufferSourceNode = opaque {};

// FFI declarations for JavaScript glue
// const js = @import("webaudio.js"); // REMOVED - JS functions will be provided as WASM imports
pub extern "env" fn js_createAudioContext() ?*AudioContext;
pub extern "env" fn js_decodeAudioData(context: *AudioContext, data: [*]const u8, len: usize, callback: *const fn (*anyopaque, ?*AudioBuffer) callconv(.C) void, context_ptr: *anyopaque) void;
pub extern "env" fn js_createBufferSource(context: *AudioContext) ?*AudioBufferSourceNode;
pub extern "env" fn js_setBuffer(source: *AudioBufferSourceNode, buffer: *AudioBuffer) void;
pub extern "env" fn js_startSource(source: *AudioBufferSourceNode) void;

// Binding functions
pub fn createAudioContext() ?*AudioContext {
    return js_createAudioContext();
}

pub fn decodeAudioData(context: *AudioContext, data: []const u8, comptime Callback: type, callback_context: *Callback) void {
    js_decodeAudioData(context, data.ptr, data.len, Callback.callback, callback_context);
}

pub fn createBufferSource(context: *AudioContext) !*AudioBufferSourceNode {
    return js_createBufferSource(context) orelse return error.BufferSourceCreationFailed;
}

pub fn setBuffer(source: *AudioBufferSourceNode, buffer: *AudioBuffer) void {
    js_setBuffer(source, buffer);
}

pub fn startSource(source: *AudioBufferSourceNode) void {
    js_startSource(source);
}

// Example callback struct for decodeAudioData
pub const DecodeCallback = struct {
    buffer: ?*AudioBuffer = null,
    pub fn callback(ctx: *anyopaque, buffer: ?*AudioBuffer) callconv(.C) void {
        const self: *DecodeCallback = @ptrCast(@alignCast(ctx));
        self.buffer = buffer;
    }
};
