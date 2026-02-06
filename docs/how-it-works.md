# How It Works

This document explains how `zig-wasm-ffi` connects Zig code to browser APIs at build time and runtime, using the `demos/input_n_audio` project as a concrete example.

## Two Pipelines

The library delivers two things to a consuming project:

1. **Zig modules** -- imported via the Zig build system (`@import("zig-wasm-ffi")`)
2. **JavaScript glue files** -- copied from the library's `src/js/` directory into the project's `dist/` output

These are completely separate pipelines that happen to pull from the same dependency.

```
zig-wasm-ffi/
  src/
    lib.zig  ---------> Zig build system (addImport)  ---> compiled into app.wasm
    webaudio.zig            |
    webinput.zig            |
    js/                     |
      webaudio.js ----> build.zig file copy -------------> dist/webaudio.js
      webinput.js ----> build.zig file copy -------------> dist/webinput.js
```

## Build Time

### Step 1: Declare the dependency (`build.zig.zon`)

```zig
.@"zig-wasm-ffi" = .{ .path = "../../" },
// or for remote:
// .@"zig-wasm-ffi" = .{ .url = "git+https://...", .hash = "..." },
```

### Step 2: Import the Zig module (`build.zig`)

```zig
const dep = b.dependency("zig-wasm-ffi", .{ .target = ..., .optimize = ... });
exe.root_module.addImport("zig-wasm-ffi", dep.module("zig-wasm-ffi"));
```

This lets application code write `@import("zig-wasm-ffi")` to access `webaudio`, `webinput`, etc.

### Step 3: Copy JS glue files (`build.zig`)

```zig
const used_web_apis = [_][]const u8{ "webaudio", "webinput" };

for (used_web_apis) |api_name| {
    const source = dep.path(b.fmt("src/js/{s}.js", .{api_name}));
    const dest = b.fmt("../dist/{s}.js", .{api_name});
    b.addInstallFile(source, dest);
}
```

The build script reaches into the library dependency's file tree via `dep.path(...)` to locate each JS file, then copies it to `dist/`. The `used_web_apis` array controls which files get copied -- only the APIs you actually use.

### Step 4: Copy static web assets (`build.zig`)

The demo's own `web/` directory (containing `main.js`, `index.html`, etc.) is copied wholesale into `dist/`.

### Build output

```
dist/
  app.wasm          <-- compiled from demo src/main.zig + library Zig modules
  main.js           <-- from demo web/main.js (hand-written)
  index.html        <-- from demo web/index.html
  webaudio.js       <-- from library src/js/webaudio.js
  webinput.js       <-- from library src/js/webinput.js
```

## Runtime

Once served to a browser, `main.js` wires everything together.

### Wiring diagram

```
+------------------+       +------------------+       +------------------+
|    index.html    |       |     main.js      |       |    app.wasm      |
|                  |------>|                  |------>|                  |
| <script src=     |       | 1. import glue   |       | Zig code with    |
|  "main.js">      |       | 2. build imports |       | extern "env" fn  |
+------------------+       | 3. instantiate   |       | and pub export   |
                            | 4. setup glue    |       +--------+---------+
                            | 5. start loop    |                |
                            +--------+---------+                |
                                     |                          |
                      +--------------+-------------+            |
                      |              |             |            |
               +------v-----+ +-----v------+ +----v-----+     |
               | webaudio.js| | webinput.js| | (more...)  |     |
               +------+-----+ +-----+------+ +----+-----+     |
                      |              |             |            |
                      +--------------+-------------+            |
                                     |                          |
                                     v                          v
                            +--------+---------------------------+
                            |        Browser APIs                |
                            |  AudioContext, addEventListener,   |
                            |  navigator.gpu, ...                |
                            +------------------------------------+
```

### Step-by-step runtime flow

**1. Import JS glue files**

```javascript
import * as webaudio_glue from './webaudio.js';
import * as webinput_glue from './webinput.js';
```

**2. Build the WASM import object**

```javascript
const importObject = {
    env: {
        js_log_string,        // app-specific FFI
        ...webaudio_glue,     // provides env_createAudioContext, env_decodeAudioData, etc.
        ...webinput_glue,     // webinput has no env imports, but spread is harmless
    }
};
```

The `env` object satisfies every `extern "env" fn` declaration in the Zig code. When Zig calls `extern "env" fn env_createAudioContext()`, the browser routes it to `webaudio_glue.env_createAudioContext()`.

**3. Instantiate WASM**

```javascript
const { instance } = await WebAssembly.instantiateStreaming(fetch('app.wasm'), importObject);
```

**4. Post-instantiation setup**

```javascript
webinput_glue.setupInputSystem(instance.exports, canvasElement);
webaudio_glue.setupWebAudio(instance);
```

This gives the JS glue a reference to the WASM exports, enabling the reverse direction: JS calling into Zig. For example, `webinput.js` attaches DOM event listeners that call `instance.exports.zig_internal_on_mouse_move()`.

**5. Start the application loop**

```javascript
instance.exports._start();          // one-time init
requestAnimationFrame(loop);        // loop calls instance.exports.update_frame()
```

## Data flow directions

The FFI is bidirectional, but each API module uses it differently:

```
WEBAUDIO (bidirectional):
  Zig ---> JS:  extern "env" fn env_createAudioContext()     Zig initiates audio ops
  JS ---> Zig:  exports.zig_internal_on_audio_buffer_decoded()  JS delivers async results

WEBINPUT (JS-to-Zig only):
  JS ---> Zig:  exports.zig_internal_on_mouse_move()         JS forwards DOM events
  Zig polls:    webinput.is_key_down(), get_mouse_position()  App reads state each frame
```

WebAudio needs `extern "env"` imports because Zig initiates actions (create context, decode audio, play sound). WebInput does not -- JavaScript pushes events into Zig, and Zig polls the accumulated state.

## Adding a new API

To integrate a new API (e.g., WebGPU):

1. Add `webgpu.zig` to `src/` with `extern "env" fn` declarations and public API
2. Add `webgpu.js` to `src/js/` implementing the `extern "env"` functions
3. Export the module from `src/lib.zig`: `pub const webgpu = @import("webgpu.zig");`
4. In the consuming project's `build.zig`, add `"webgpu"` to `used_web_apis`
5. In the consuming project's `main.js`:
   - `import * as webgpu_glue from './webgpu.js';`
   - Spread into env: `...webgpu_glue`
   - Call any setup function after instantiation
