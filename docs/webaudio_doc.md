# WebAudio Module

## Goals

### Current Focus: Core Audio Operations
The `webaudio` module currently provides an interface for fundamental Web Audio API operations within a Zig WebAssembly application, specifically:
- Creating an `AudioContext`.
- Decoding audio data into an `AudioBuffer`.
- Playing decoded `AudioBuffer`s (basic one-shot playback).
- Playing and controlling tagged, looping sounds (e.g., for background music).

It relies on Zig calling FFI functions implemented in JavaScript, which then interact with the browser's Web Audio API. For asynchronous operations like decoding, JavaScript calls back into exported Zig functions.

### Future Enhancements
- **Advanced Audio Playback**: Implement more sophisticated controls for playing decoded `AudioBuffer`s (e.g., more detailed control over stop, pause, resume, gain control, panning for one-shot sounds. Looping is covered by tagged sounds).
- **Audio Graph Manipulation**: Allow creation and connection of various `AudioNode` types (e.g., `GainNode`, `PannerNode`, `OscillatorNode`, `ConvolverNode`).
- **Advanced Decoding Options**: Support for more detailed error handling or progress events during decoding.
- **Microphone Input**: Accessing and processing microphone input via `MediaStreamAudioSourceNode`.
- **Worklet Support**: Interface with `AudioWorkletNode` for custom audio processing in JavaScript.

## Using `webaudio`

### Overview
The `webaudio` module enables your Zig Wasm application to initialize an audio environment and prepare audio data for playback.
- **JavaScript Side (`js/webaudio.js`):**
    - A `setupWebAudio(wasmInstance)` function initializes the JavaScript glue, primarily storing the Wasm instance to allow callbacks to Zig.
    - Exports FFI functions (e.g., `env_createAudioContext`, `env_decodeAudioData`, `env_playDecodedAudio`, `env_playLoopingTaggedSound`, `env_stopTaggedSound`) that are imported and called by Zig.
    - `env_createAudioContext`: Creates a new `AudioContext` and returns a handle (ID) to Zig.
    - `env_decodeAudioData`: Receives a pointer to audio data in Wasm memory, decodes it using the browser's `AudioContext.decodeAudioData()`, and then calls back to Zig (`zig_internal_on_audio_buffer_decoded` or `zig_internal_on_decode_error`) with the result.
    - `env_playDecodedAudio`: Plays a specified, previously decoded audio buffer (one-shot).
    - `env_playLoopingTaggedSound`: Plays a decoded buffer in a loop, identified by a tag.
    - `env_stopTaggedSound`: Stops a playing sound identified by its tag.
- **Zig Side (`src/webaudio.zig`):**
    - Defines `extern "env"` FFI function signatures that Zig expects JavaScript to provide.
    - Manages internal state for the `AudioContextHandle` and tracks active audio decoding requests.
    - Provides internal exported functions (e.g., `zig_internal_on_audio_buffer_decoded`) called by JavaScript upon completion of async operations.
    - Offers a public API for your Zig application to:
        1. Call `init_webaudio_module_state()` (optional, mainly for testing) to reset internal states.
        2. Call `createAudioContext()` to get a handle to an `AudioContext`.
        3. Call `requestDecodeAudioData()` to initiate decoding of raw audio data.
        4. Poll for decoding status using `getDecodeRequestStatus()`.
        5. Retrieve information about decoded audio using `getDecodedAudioBufferInfo()`.
        6. Call `playDecodedAudio()` to play a successfully decoded buffer (one-shot).
        7. Call `playLoopingTaggedSound()` to play a decoded buffer in a loop with a tag.
        8. Call `stopTaggedSound()` to stop a tagged, looping sound.
        9. Release decoding request slots using `releaseDecodeRequest()`.

### Zig Setup (`src/webaudio.zig`)

**Key Zig Structures & Types:**
- `AudioContextHandle: u32`: An opaque handle representing a JavaScript `AudioContext`.
- `AudioContextState: enum { Uninitialized, Ready, Error, NotCreatedYet }`: Tracks the state of the `AudioContext`.
- `DecodeStatus: enum { Free, Pending, Success, Error }`: Status of an audio data decoding request.
- `AudioBufferInfo: struct`: Contains details of a successfully decoded buffer (JS ID, duration, length, channels, sample rate).
- `DecodeRequestEntry: struct`: Internal entry to track a decode request.
- `g_decode_requests: [MAX_DECODE_REQUESTS]DecodeRequestEntry`: Array for managing decode requests.

**FFI Imports (Zig calling JavaScript - defined in `src/webaudio.zig`):**
These are `extern "env"` functions that the Zig code calls. The JavaScript glue in `js/webaudio.js` must provide these in the import object during Wasm instantiation.
- `env_createAudioContext() u32`
- `env_decodeAudioData(context_id: u32, audio_data_ptr: [*]const u8, audio_data_len: usize, user_request_id: u32) void`
- `env_playDecodedAudio(audio_context_id: u32, js_decoded_buffer_id: u32) void`
- `env_playLoopingTaggedSound(audio_context_id: u32, js_buffer_id: u32, sound_instance_tag: u32) void`
- `env_stopTaggedSound(audio_context_id: u32, sound_instance_tag: u32) void`

**Exported Zig Functions (called by JavaScript for async callbacks):**
These functions are `pub export` in `src/webaudio.zig`.
- `zig_internal_on_audio_buffer_decoded(user_request_id: u32, js_buffer_id: u32, duration_ms: u32, length_samples: u32, num_channels: u32, sample_rate_hz: u32) void`
- `zig_internal_on_decode_error(user_request_id: u32) void`
- `getDecodeRequestStatus(user_request_id: u32) ?DecodeStatus`: Checks the status of a decode request.
- `getDecodedAudioBufferInfo(user_request_id: u32) ?AudioBufferInfo`: Gets info if decoding was successful.
- `playDecodedAudio(ctx_handle: AudioContextHandle, js_decoded_buffer_id: u32) void`: Plays a decoded audio buffer.
- `playLoopingTaggedSound(ctx_handle: AudioContextHandle, js_buffer_id: u32, sound_instance_tag: u32) void`: Plays a looping sound with a tag.
- `stopTaggedSound(ctx_handle: AudioContextHandle, sound_instance_tag: u32) void`: Stops a tagged sound.
- `releaseDecodeRequest(user_request_id: u32) void`: Frees a decode request slot.

**Public Zig API (called by your application):**
- `init_webaudio_module_state() void`: Resets the module's internal state.
- `createAudioContext() ?AudioContextHandle`: Attempts to create an `AudioContext`.
- `getAudioContextState() AudioContextState`: Returns the current state of the `AudioContext`.
- `requestDecodeAudioData(ctx_handle: AudioContextHandle, audio_data: []const u8, user_request_id: u32) bool`: Initiates asynchronous decoding.

### JavaScript Setup (`js/webaudio.js`)

**Core Functions:**
- `export function setupWebAudio(instance)`:
    - `instance`: The instantiated Wasm module instance (specifically, `instance.exports` is used for callbacks if needed, and `instance.exports.memory` for reading data). This function primarily stores the Wasm instance for later use by async callbacks from JavaScript to Zig.
- **FFI Exports (JavaScript functions callable by Zig):**
    - `export function env_createAudioContext()`: Creates an `AudioContext`, stores it, and returns an ID.
    - `export async function env_decodeAudioData(context_id, data_ptr, data_len, user_request_id)`: Reads audio data from Wasm memory, uses `AudioContext.decodeAudioData`, and then calls `wasmInstance.exports.zig_internal_on_audio_buffer_decoded` or `wasmInstance.exports.zig_internal_on_decode_error`.
    - `export function env_playDecodedAudio(context_id, js_decoded_buffer_id)`: Plays a specified, previously decoded audio buffer.
    - `export function env_playLoopingTaggedSound(context_id, js_buffer_id, sound_instance_tag)`: Plays a looping sound, managing it by a tag.
    - `export function env_stopTaggedSound(context_id, sound_instance_tag)`: Stops a sound managed by its tag.

### Project Integration

**1. `build.zig` and `main.js` Generation:**

Your main JavaScript file (often generated or influenced by `build.zig`) needs to:
1. Import the FFI functions (like `env_createAudioContext`, `env_decodeAudioData`, `env_playDecodedAudio`, `env_playLoopingTaggedSound`, `env_stopTaggedSound`) and the `setupWebAudio` function from `js/webaudio.js`.
2. Provide these FFI functions in the `env` object when instantiating the Wasm module.
3. Call `setupWebAudio(instance)` after the Wasm module is instantiated.

**Example `main.js` structure (conceptual):**

```javascript
// main.js (likely generated or influenced by build.zig)

import { 
    env_createAudioContext, 
    env_decodeAudioData,
    env_playDecodedAudio,
    env_playLoopingTaggedSound,
    env_stopTaggedSound,
    setupWebAudio
} from './webaudio.js'; // Assuming webaudio.js is copied to dist/

async function initWasm() {
    const imports_obj = {
        env: {
            // FFI imports for WebAudio
            env_createAudioContext,
            env_decodeAudioData,
            env_playDecodedAudio,
            env_playLoopingTaggedSound,
            env_stopTaggedSound,

            // ... any other FFI imports your app needs ...
            js_log_string: (ptr, len) => { /* ... console log from Wasm ... */ },
        }
    };

    const { instance } = await WebAssembly.instantiateStreaming(fetch('app.wasm'), imports_obj);

    // Initialize the WebAudio JS glue AFTER Wasm instantiation
    setupWebAudio(instance); 

    // Call your Zig application's main function
    if (instance.exports.main) {
        instance.exports.main();
    }
}

initWasm().catch(console.error);
```

Your `build.zig` script (as shown in the main `README.md` of `zig-wasm-ffi`) should handle:
- Copying `js/webaudio.js` to the output directory (e.g., `dist/`) if "webaudio" is listed in `used_apis`.
- Generating the `main.js` file with the correct JavaScript imports from `./webaudio.js` and including `env_createAudioContext`, `env_decodeAudioData`, `env_playDecodedAudio`, `env_playLoopingTaggedSound`, and `env_stopTaggedSound` in the `env` object passed to `WebAssembly.instantiateStreaming`.
- Injecting the `setupWebAudio(instance);` call into the generated `main.js` after instantiation.

**2. Example Zig Application Usage (`src/main.zig`):**

```zig
const std = @import("std");
const webaudio = @import("zig-wasm-ffi").webaudio; // Adjust import path

// FFI import for logging (defined in user's main.js)
extern fn js_log_string(message_ptr: [*]const u8, message_len: usize) void;

fn log(message: []const u8) void {
    js_log_string(message.ptr, message.len);
}

// Example: Load and decode an audio file (simulated data)
const audio_file_request_id: u32 = 1;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub export fn main() !void {
    log("Zig main started for WebAudio demo.");

    // Initialize webaudio module state (optional, good for clean test runs)
    webaudio.init_webaudio_module_state();

    // 1. Create AudioContext
    const audio_context = webaudio.createAudioContext() orelse {
        log("Failed to create AudioContext from Zig.");
        return;
    };
    log("AudioContext created, handle: ?"); // Logging the handle directly isn't straightforward from here

    switch (webaudio.getAudioContextState()) {
        .Ready => log("AudioContext state: Ready"),
        .Error => log("AudioContext state: Error after creation attempt!"),
        else => log("AudioContext state: Unexpected"),
    }

    // 2. Simulate loading audio data (e.g., from an embedded file or fetched resource)
    //    For a real scenario, you'd get these bytes from JS or embed them.
    const allocator = gpa.allocator();
    const simulated_mp3_data: []const u8 = try allocator.dupe(u8, "dummy mp3 data, this is not a real mp3");
    defer allocator.free(simulated_mp3_data);

    log("Requesting audio data decoding...");
    if (!webaudio.requestDecodeAudioData(audio_context, simulated_mp3_data, audio_file_request_id)) {
        log("Failed to submit audio decode request.");
        return;
    }
    log("Audio decode request submitted.");

    // 3. In a real app, you'd poll or have an update loop. Here we'll just check status once.
    //    This check might be too soon as decoding is async.
    //    A more robust approach would be to check in an exported `update_frame` function
    //    called by JavaScript's requestAnimationFrame.
    check_audio_status();
}

// This function could be called from a game loop driven by requestAnimationFrame
pub export fn check_audio_status() void {
    switch (webaudio.getDecodeRequestStatus(audio_file_request_id)) {
        .Pending => log("Audio decoding status: Pending..."),
        .Success => {
            log("Audio decoding status: Success!");
            const info = webaudio.getDecodedAudioBufferInfo(audio_file_request_id).?;
            log("  Buffer Info:");
            // Note: Direct logging of u32 from Zig to JS console needs formatting or separate log calls.
            // This is a simplified representation.
            log("    JS Buffer ID: (some id)"); // info.js_buffer_id
            log("    Duration (ms): (duration)"); // info.duration_ms
            log("    Length (samples): (length)"); // info.length_samples
            log("    Channels: (channels)"); // info.num_channels
            log("    Sample Rate (Hz): (rate)"); // info.sample_rate_hz

            // Play the sound!
            webaudio.playDecodedAudio(audio_context, info.js_buffer_id);
            log("Playback requested.");

            // Once successful, release the request if no longer observing its info
            webaudio.releaseDecodeRequest(audio_file_request_id);
            log("Decode request released.");
        },
        .Error => log("Audio decoding status: Error!"),
        .Free => log("Audio decoding status: Slot is Free (should not happen if request was made and not released)."),
        else => log("Audio decoding status: Unknown or request ID not found."),
    }
}
```

## Testing Challenges and Future Solutions

As of the current implementation, running `zig test src/lib.zig` (which includes `src/webaudio.test.zig`) results in a linker error:
```
error(link): DLL import library for -lenv not found
```

### Cause of the Issue
This error occurs because:
1.  `webaudio.zig` declares `extern "env"` functions (e.g., `env_createAudioContext`, `env_decodeAudioData`). These tell the Zig compiler that these functions will be provided by the "environment" when compiled to WebAssembly (i.e., by JavaScript).
2.  When `zig test` is run, it typically compiles the code (including `webaudio.zig`) into a **native executable** to run the tests on the host system.
3.  The native linker on the host system (e.g., LLD) does not know what "env" is or where to find these functions, as they are specific to the WebAssembly JavaScript host environment. It's looking for a system library or object file named "env," which doesn't exist for native builds in this context.

The `webinput.zig` module does not face this issue in its core mouse/keyboard tests because it primarily *exports* functions for JavaScript to call. Its native tests call these exported Zig functions directly, simulating JavaScript's role, without `webinput.zig` itself needing to call `extern "env"` functions for its basic operations.

### Potential Future Solutions

To enable robust native testing of `webaudio.zig` (and other modules that call `extern "env"` functions), the FFI calls need to be handled differently for test builds versus WebAssembly builds. Here are a few approaches:

1.  **Compile-Time Conditional FFI (using `builtin.target`):**
    *   **Concept:** Within `webaudio.zig`, use `comptime` blocks and `@import("builtin").target` to detect if the build is for `wasm32-freestanding` or a native target.
    *   **Implementation:**
        *   Define function pointer types for the FFI functions (e.g., `CreateAudioContextFnPtr = fn () callconv(.C) u32;`).
        *   Declare `pub var` for these function pointers (e.g., `pub var active_createAudioContext: CreateAudioContextFnPtr;`).
        *   `comptime` block:
            *   If `wasm32-freestanding`: Define the actual `extern "env" my_js_func_impl()` and assign `active_my_js_func = my_js_func_impl;`.
            *   If native target: Initialize `active_my_js_func` to a placeholder function that panics (e.g., `fn placeholder() { @panic("FFI used in native test without mock"); }`).
        *   The main `webaudio.zig` code would always call through `active_my_js_func()`.
        *   The `webaudio.test.zig` file, in its test setup, would then assign its own mock Zig functions to these `pub var` pointers (e.g., `webaudio.active_createAudioContext = my_test_mock_createAudioContext;`).
    *   **Pros:** Keeps FFI concerns mostly within `webaudio.zig`. No extra files for simple cases.
    *   **Cons:** `pub var` for function pointers might feel a bit too exposed if not clearly documented for testing.

2.  **Separate FFI Abstraction File (e.g., `webaudio_ffi.zig`):**
    *   **Concept:** Create a dedicated file that handles the FFI linkage.
    *   **Implementation:**
        *   `webaudio_ffi.zig` would define the function pointer types and the `pub var` pointers.
        *   It would contain an `init_wasm_bindings()` function that, if compiling for WASM, defines the `extern "env"` functions and assigns them to the pointers.
        *   It would also contain a `testing_setup_mocks(mock_fn1, mock_fn2, ...)` function that tests can call to assign their mock functions to the pointers.
        *   `webaudio.zig` would import from `webaudio_ffi.zig` and only use the function pointers.
    *   **Pros:** Clear separation of FFI concerns. `webaudio.zig` becomes agnostic to the FFI binding mechanism.
    *   **Cons:** Adds an extra file and a bit more boilerplate.

3.  **Build System Flags and Separate Source Files (Advanced):**
    *   **Concept:** Use build system flags to compile in either the real FFI implementations or mock implementations.
    *   **Implementation:**
        *   Have `webaudio_ffi_wasm.zig` (with `extern "env"`) and `webaudio_ffi_mock.zig` (with Zig mock functions).
        *   The `build.zig` would choose which one to compile and link into `webaudio.zig` based on the target or a test flag.
    *   **Pros:** Strongest separation, no `pub var` function pointers needed in the main module.
    *   **Cons:** More complex build system logic.

The **Compile-Time Conditional FFI** (Option 1) is often a good balance of simplicity and effectiveness for many Zig projects facing this testing scenario. It avoids the linker error by not trying to link against "env" during native test builds and provides a clear way for tests to inject mock behavior.

This documentation outlines the current state and provides a path forward for enhancing the testability and functionality of the `webaudio` module.
