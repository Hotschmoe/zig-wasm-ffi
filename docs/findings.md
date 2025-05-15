## Findings on zig-wasm-ffi Build for `wasm32-freestanding`

1.  **JavaScript FFI and Standard Library Linkage:**
    *   **Observation:** When targeting `wasm32-freestanding`, if Zig code calls an `extern fn` that is intended to be implemented by an imported JavaScript file (e.g., `@import("webaudio.js")`), the Zig compiler links in parts of the standard library like `std.Thread` and `std.posix`.
    *   **Evidence:** This causes compilation errors (e.g., "Unsupported operating system freestanding" from `std.Thread`, or missing POSIX symbols) because these stdlib components are not compatible with the `freestanding` environment.
    *   **Verification:**
        *   Commenting out the call to the `extern fn` in `example/src/main.zig` allowed the example project to build successfully.
        *   Further isolating this by commenting out the `extern fn` declaration and the `@import("*.js")` line in the library file (`src/webaudio.zig`), and making the calling Zig function return a dummy value, also allowed the example project to build successfully, even when the Zig function itself was still called from `main.zig`.
    *   **Conclusion:** The FFI mechanism for JavaScript interoperation appears to be the trigger for these unwanted stdlib dependencies in a `wasm32-freestanding` build.

2.  **Ineffectiveness of `exclude_libc`:**
    *   **Observation:** Adding `exe.exclude_libc = true;` to the `b.addExecutable` step in the `example/build.zig` (the consuming project) did not prevent the `std.Thread` and `std.posix` related compilation errors when JavaScript FFI was used by the library.
    *   **Conclusion:** This option does not appear to influence the specific stdlib components being pulled in by the JS FFI mechanism in this context.

3.  **FFI Import Mechanism as the Key Difference:**
    *   **Observation:** A working `wasm-particles` project (which uses `wasm32-freestanding` and JS FFI without stdlib linkage issues) declares its `extern` JavaScript functions without an accompanying `@import("some_module.js")` in the Zig source. Instead, its `extern` functions are likely satisfied by an imports object provided by the JavaScript runtime during WASM instantiation (some marked with `extern "env"`).
    *   **Hypothesis:** The Zig build system's mechanism for handling `@import("*.js")` for FFI in `wasm32-freestanding` is what pulls in unnecessary `std.Thread` and `std.posix` components. By removing the `@import("*.js")` and relying on the JS host to provide the imported functions (e.g., via the `env` module for `extern "env" fn`), we avoid this problematic linkage path in Zig's build process.
    *   **Action:** Modified `src/webaudio.zig` and `src/webinput.zig` to remove `@import("*.js")` and changed `extern fn` to `pub extern "env" fn` to align with this pattern.

4.  **Error Sets in `main` for `wasm32-freestanding`:**
    *   **Observation:** Despite changes in FFI style (using `extern "env" fn` and removing `@[scriptName]`), `std.Thread` and `std.posix` errors persisted.
    *   **Hypothesis:** If the root source file's `main` function (for `b.addExecutable`) is declared to return an error set (e.g., `pub fn main() !void`), the Zig compiler might attempt to link stdlib components for error reporting (like stack traces or default print handlers) that are incompatible with `wasm32-freestanding`.
    *   **Comparison:** The `wasm-particles` example uses `void` for its exported JS-callable functions and its `main() !void` is not the effective entry point for its WASM build with `entry = .disabled`.
    *   **Action (Successful):** Modified `zig-wasm-ffi/src/webaudio.zig` to make `createAudioContext` return `?*AudioContext` (removing the error set). Modified `example/src/main.zig` to have `pub fn main() void` (removing the error set) and handle the nullable pointer directly.
    *   **Result:** This change successfully resolved the `std.Thread` and `std.posix` compilation errors in the `example` project.
    *   **Conclusion:** For `wasm32-freestanding` targets, especially when JS FFI is involved, avoid returning error sets from the `main` function specified in `b.addExecutable` (even if `.entry = .disabled`) to prevent the Zig compiler from linking incompatible stdlib error handling components.
