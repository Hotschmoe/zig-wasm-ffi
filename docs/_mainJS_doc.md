# Modular JavaScript Glue Initialization in `main.js`

The main JavaScript file (`web/main.js` in the demo projects) employs a modular and configurable approach to initialize the WebAssembly (Wasm) module and its associated JavaScript FFI (Foreign Function Interface) glue code. This design is crucial for achieving the `zig-wasm-ffi` project's goals of leanness, explicit build configuration, and ease of use, as outlined in the main `README.MD`.

## Core Concepts

1.  **Explicit Imports**: Users explicitly import the JavaScript glue files for the Web APIs they intend to use at the top of `main.js`.
    ```javascript
    // 1. Import all POTENTIAL glue modules.
    import * as webinput from './webinput.js'; 
    // import * as webaudio from './webaudio.js'; // User would uncomment to use
    import * as webgpu from './webgpu.js';   // User would uncomment to use
    ```

2.  **`activeModules` Configuration Array**: A central array, `activeModules`, allows users to declare which of the imported glue modules are currently active and how they should be configured. This array acts as the single source of truth for module setup.
    ```javascript
    const activeModules = [
        {
            name: "WebInput",    // Descriptive name for logging
            glue: webinput,      // The imported JavaScript module object
            providesToZig: false,// Does this module export `env_` functions for Zig to call?
            jsSetupFunction: webinput.setupInputSystem, // JS-side setup function (if any)
            jsSetupArgs: (instance, canvasEl) => [instance.exports, canvasEl] // Function to get args for setup
        },
        {
            name: "WebGPU",
            glue: webgpu,
            providesToZig: true, 
            jsSetupFunction: webgpu.setupWebGPU, 
            jsSetupArgs: (instance, canvasEl) => [instance, canvasEl] 
        }
        // Example for a hypothetical WebAudio module:
        // {
        //     name: "WebAudio",
        //     glue: webaudio, 
        //     providesToZig: true, 
        //     jsSetupFunction: webaudio.setupWebAudio,
        //     jsSetupArgs: (instance, _canvasEl) => [instance]
        // }
    ];
    ```
    Each object in this array specifies:
    *   `name`: A string name for the module, primarily for logging.
    *   `glue`: A reference to the imported JavaScript module object.
    *   `providesToZig`: A boolean. If `true`, `main.js` will scan this module for functions prefixed with `env_` and add them to the `importObject.env` passed to the Wasm module. This allows Zig to call these JavaScript functions.
    *   `jsSetupFunction`: A reference to a function within the glue module that should be called from JavaScript to initialize that module (e.g., `webinput.setupInputSystem`). This is optional; some modules might only provide FFI functions for Zig.
    *   `jsSetupArgs`: A function that, when called, returns an array of arguments needed by the `jsSetupFunction`. This allows different setup functions to receive different context (e.g., the Wasm `instance`, specific `instance.exports`, or the `canvasElement`).

3.  **Dynamic `importObject.env` Construction**: The `initWasm` function iterates through `activeModules`. For each module where `providesToZig` is `true`, it inspects the `glue` object and adds any functions prefixed with `env_` to the `envImports` object. This `envImports` object becomes `importObject.env`, which is passed to `WebAssembly.instantiateStreaming`.
    ```javascript
    // ... inside initWasm ...
    const envImports = { /* js_log_string and other common envs */ };
    for (const mod of activeModules) {
        if (mod.providesToZig && mod.glue) {
            for (const key in mod.glue) {
                // Convention: only spread env_ prefixed functions
                if (Object.prototype.hasOwnProperty.call(mod.glue, key) && key.startsWith("env_")) {
                    envImports[key] = mod.glue[key];
                }
            }
        }
    }
    const importObject = { env: envImports };
    // ... instantiate Wasm with importObject ...
    ```

4.  **Dynamic JavaScript-Side Setup**: After the Wasm module is instantiated, `initWasm` iterates through `activeModules` again. If a module has a `jsSetupFunction` defined, it's called. The arguments for this setup function are dynamically retrieved by executing its `jsSetupArgs` function, passing the Wasm `instance` and `canvasElement` as context.
    ```javascript
    // ... after Wasm instantiation ...
    for (const mod of activeModules) {
        if (mod.jsSetupFunction && typeof mod.jsSetupFunction === 'function') {
            console.log(`[Main.js] Setting up ${mod.name}...`);
            const args = mod.jsSetupArgs(wasmInstance, canvasElement);
            mod.jsSetupFunction(...args);
        }
    }
    ```

## Importance for `zig-wasm-ffi` and Modularity

This `main.js` structure directly supports the core principles of `zig-wasm-ffi` as outlined in the `README.MD`:

*   **Explicit Configuration & Leanness**:
    *   Users explicitly choose which API bindings are active by managing the top-level JavaScript imports and the `activeModules` array. This aligns with the `README.MD` goal: "Require users to list used APIs in `build.zig` to copy only necessary JavaScript glue files to `dist/`". While this `main.js` doesn't *replace* the `build.zig` step for copying files, it provides the runtime counterpart for selecting and initializing only the *used* glue code.
    *   Only the FFI functions (`env_*`) from *active* modules (marked `providesToZig: true`) are passed to the Wasm instance. This prevents unnecessary linkage if a glue module is imported but not actively used.
    *   Zig's Dead Code Elimination (DCE) on the Zig side works in concert with this. If Zig code doesn't call functions from a particular `zig-wasm-ffi` sub-module (e.g., `webaudio.zig`), that Zig code can be stripped. This `main.js` ensures the JavaScript side is also lean by only setting up and linking what's configured.

*   **Ease of Use & Maintainability**:
    *   Adding or removing a Web API binding primarily involves:
        1.  Adding/removing the `import * as ...` line.
        2.  Adding/removing/commenting its corresponding entry in the `activeModules` array.
    *   The core logic within `initWasm` for constructing `importObject.env` and calling setup functions remains unchanged, making `main.js` more stable and easier to manage as more API bindings are added.
    *   This pattern reduces the chance of errors that might occur from manually editing multiple parts of `initWasm` for each new API.

*   **Flexibility**:
    *   The `jsSetupArgs` function provides flexibility in how each JavaScript glue module is initialized. Some might need the Wasm `instance`, others only `instance.exports`, and some might need the `canvasElement`. This is handled per module without complicating the core loop.

*   **Alignment with Build System**:
    *   This `main.js` structure is designed to work with a `build.zig` that copies the necessary JavaScript glue files (e.g., `webinput.js`, `webgpu.js`) to the output directory. The user's configuration in `activeModules` should ideally mirror what's specified in `build.zig`'s `used_apis` list.

## Animation Loop and Delta Time

The `main.js` also includes a standard `requestAnimationFrame` loop that calls the exported `update_frame` function from the Wasm module. A key improvement is the calculation and passing of `deltaTime` (the time elapsed since the last frame in milliseconds) to `update_frame`.

```javascript
// ... inside initWasm, after _start is called ...
let lastTime = 0;
function animationLoop(currentTime) {
    if (!lastTime) lastTime = currentTime;
    const deltaTime = currentTime - lastTime;
    lastTime = currentTime;

    if (wasmInstance && wasmInstance.exports && wasmInstance.exports.update_frame) {
        try {
            // Pass actual delta time (e.g., as f32 if Zig expects it)
            wasmInstance.exports.update_frame(deltaTime); 
        } catch (e) {
            // ... error handling ...
            return; 
        }
    }
    requestAnimationFrame(animationLoop);
}
requestAnimationFrame(animationLoop);
```
This allows for frame-rate independent animations and physics updates within the Zig application, as the Zig `update_frame(delta_time_ms: f32)` function can use this delta time in its calculations.

## Summary

The refined `main.js` provides a robust, configurable, and maintainable way to integrate various `zig-wasm-ffi` JavaScript glue modules into a WebAssembly application. It promotes modularity by centralizing the configuration of active modules and automates the process of linking FFI imports and executing JavaScript-side initializations, aligning perfectly with the project's goals for a lean and developer-friendly FFI solution.

## Stretch Goal: Dynamic `main.js` Generation via `build.zig`

While the current `main.js` structure is highly configurable by manually editing the `activeModules` array and import statements, a future enhancement could involve `build.zig` dynamically generating the entire `main.js` (or key parts of it) based on the `used_web_apis` array (or a similar mechanism) defined in the user's `build.zig` file.

This would offer several advantages:

*   **Single Source of Truth**: The `build.zig` file would become the definitive place to declare which Web API bindings are used in a project. This reduces the chance of mismatches between `build.zig` (which handles file copying and conditional compilation of Zig code) and `main.js` (which handles JS-side FFI setup).
*   **Automated Imports**: The necessary `import * as ... from './module.js'` statements at the top of `main.js` could be generated automatically.
*   **Automated `activeModules` Configuration**: The `activeModules` array could be constructed dynamically based on the `used_web_apis` list. This would require a way to store metadata about each glue module (e.g., its name, whether it `providesToZig`, its `jsSetupFunction`, and `jsSetupArgs` structure) in a way that `build.zig` can access and use to generate the JavaScript code.
*   **Maximizing Leanness**: Ensures that only the absolute minimum JavaScript code is included and configured in the final `main.js` delivered to the browser, perfectly aligning with the project's leanness goal.

Implementing this would involve:
1.  Defining a metadata format for each JavaScript glue module (e.g., a small JSON file alongside each `.js` glue file, or conventions within the `build.zig` itself).
2.  Adding logic to `build.zig` to read this metadata for each API listed in `used_web_apis`.
3.  Using `build.zig`'s capabilities to template or write out the `main.js` file content, including dynamic imports and the `activeModules` array.

This approach would further enhance the "explicit build configuration" principle by making the JavaScript initialization a direct outcome of the Zig build process.
