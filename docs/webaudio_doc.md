# WebAudio Module

## Overview

The `webaudio` module provides Zig FFI bindings for the browser's Web Audio API. It supports creating audio contexts, decoding audio data, one-shot playback, and looping tagged sounds.

Zig calls `extern "env"` functions implemented in JavaScript. For async operations (like decoding), JavaScript calls back into exported Zig functions with the results.

## Zig API (`src/webaudio.zig`)

### Types

- `AudioContextHandle: u32` -- opaque handle representing a JavaScript `AudioContext`
- `AudioContextState: enum { Uninitialized, Ready, Error, NotCreatedYet }`
- `DecodeStatus: enum { Free, Pending, Success, Error }`
- `AudioBufferInfo: struct` -- decoded buffer details (JS ID, duration, length, channels, sample rate)

### Public Functions

| Function | Description |
|----------|-------------|
| `init_webaudio_module_state()` | Reset internal state (useful for testing) |
| `createAudioContext() ?AudioContextHandle` | Create an AudioContext, returns handle or null |
| `getAudioContextState() AudioContextState` | Current AudioContext state |
| `requestDecodeAudioData(ctx, data, request_id) bool` | Start async decode, returns success |
| `getDecodeRequestStatus(request_id) ?DecodeStatus` | Poll decode status |
| `getDecodedAudioBufferInfo(request_id) ?AudioBufferInfo` | Get decoded buffer info |
| `playDecodedAudio(ctx, js_buffer_id)` | Play a decoded buffer (one-shot) |
| `playLoopingTaggedSound(ctx, js_buffer_id, tag)` | Play a looping sound with a tag |
| `stopTaggedSound(ctx, tag)` | Stop a tagged looping sound |
| `releaseDecodeRequest(request_id)` | Free a decode request slot |

### Exported Functions (called by JavaScript)

These are `pub export` functions that JavaScript calls to deliver async results:

- `zig_internal_on_audio_buffer_decoded(request_id, js_buffer_id, duration_ms, length_samples, num_channels, sample_rate_hz)`
- `zig_internal_on_decode_error(request_id)`

### FFI Imports (provided by JavaScript)

These `extern "env"` functions must be in the WebAssembly import object:

- `env_createAudioContext() u32`
- `env_decodeAudioData(context_id, audio_data_ptr, audio_data_len, user_request_id)`
- `env_playDecodedAudio(audio_context_id, js_decoded_buffer_id)`
- `env_playLoopingTaggedSound(audio_context_id, js_buffer_id, sound_instance_tag)`
- `env_stopTaggedSound(audio_context_id, sound_instance_tag)`

## JavaScript Glue (`src/js/webaudio.js`)

### Setup

Call `setupWebAudio(wasmInstance)` after WASM instantiation. This stores the instance so JavaScript can call back into Zig exports for async results.

### Integration

```javascript
import {
    env_createAudioContext,
    env_decodeAudioData,
    env_playDecodedAudio,
    env_playLoopingTaggedSound,
    env_stopTaggedSound,
    setupWebAudio
} from './webaudio.js';

const imports = {
    env: {
        env_createAudioContext,
        env_decodeAudioData,
        env_playDecodedAudio,
        env_playLoopingTaggedSound,
        env_stopTaggedSound,
    }
};

const { instance } = await WebAssembly.instantiateStreaming(fetch('app.wasm'), imports);
setupWebAudio(instance);
```

## Testing Notes

Running `zig test src/lib.zig` hits a linker error for `webaudio.test.zig` because the native linker cannot resolve `extern "env"` functions:

```
error(link): DLL import library for -lenv not found
```

This is expected. The `extern "env"` functions only exist in the browser's JS runtime. See `findings.md` for background and potential solutions (compile-time conditional FFI with mock functions for native test builds).

## Future Enhancements

- Audio graph manipulation (GainNode, PannerNode, OscillatorNode)
- Microphone input via MediaStreamAudioSourceNode
- AudioWorklet support
- Advanced playback controls (pause, resume, gain, panning)
