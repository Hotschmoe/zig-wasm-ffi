# Targeting Wasm32-Freestanding

When developing for WebAssembly with `zig-wasm-ffi`, projects target `wasm32-freestanding`. This environment is "bare-metal" -- it does not provide standard POSIX-like operating system APIs that much of Zig's standard library (`std`) relies on (file system access, environment variables, some memory allocation patterns, or console I/O that assumes a system terminal).

## Why Avoid `std`

- **POSIX dependencies**: Many `std` modules (`std.fs`, `std.os`, `std.process`, and parts of `std.debug.print` or `std.heap` allocators that expect system calls) can fail to compile or cause runtime errors because the underlying OS calls are absent in the browser's WASM sandbox.
- **Binary size**: Even if some parts of `std` are usable, importing it can pull in dependencies that are not tree-shaken effectively for freestanding targets, increasing binary size.
- **Explicit control**: Relying on FFI for browser interactions (console logging, Web API access) gives more clarity about what browser functionalities are used.

## Recommendations

- **Minimize `std` usage**: Avoid `@import("std")` altogether where possible. If specific functionality is needed (e.g., data structures from `std.ArrayList`), carefully review its dependencies or consider reimplementing a lightweight version.
- **Use FFI for browser interaction**: For tasks like printing to the developer console or calling Web APIs, use Zig's FFI to call JavaScript glue functions. This is the primary mechanism `zig-wasm-ffi` uses for its bindings.
- **Custom implementations**: For utilities like allocators or formatting, provide custom freestanding-compatible implementations if the `std` versions are not suitable.

By following these practices, your Zig WASM modules stay lean, efficient, and correctly interact with the browser environment without relying on unavailable system-level features.
