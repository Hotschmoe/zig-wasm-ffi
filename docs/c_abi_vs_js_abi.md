# C ABI vs JS ABI for Browser FFI

This document captures the rationale for using JS ABI (direct `extern "env"` FFI) over C ABI (`@cImport` with native headers like `webgpu.h`) in `zig-wasm-ffi`.

## Why JS ABI

Browser APIs (WebGPU, Web Audio, etc.) are only accessible through JavaScript. Both approaches require a JavaScript shim -- the question is how much indirection sits between Zig and that shim.

**C ABI path**: Zig -> `@cImport("webgpu.h")` -> C function signatures -> JavaScript shim implementing C API -> browser API

**JS ABI path**: Zig -> `extern "env" fn` declarations -> JavaScript shim -> browser API

The JS ABI removes an entire layer (C headers) without sacrificing runtime performance, since the actual WASM-to-JS call boundary is identical in both cases.

## Key Advantages of JS ABI

- **No C headers**: No need to maintain or vendor `webgpu.h` or similar header files. Zig `extern "env"` declarations are the contract.
- **Simpler build**: No `@cImport` step, no header search paths, no linking against native libraries.
- **Smaller shim**: The JS shim only needs to implement the functions you actually declare, not an entire C API surface.
- **Same performance**: WASM-to-JS call overhead is identical regardless of how the import was declared in Zig. Buffer writes to WASM linear memory work the same way.
- **Direct mapping**: Zig's `extern "env"` functions map 1:1 to entries in the WebAssembly import object. What you declare is exactly what gets wired up.

## When C ABI Makes Sense

- **Native portability**: If the same Zig code needs to run outside the browser (e.g., with Dawn or wgpu-native), C ABI headers provide a common interface across browser and native targets.
- **Existing ecosystems**: Projects already using `wgpu-native` or similar C-API libraries may prefer consistency.

For `zig-wasm-ffi`, the target is exclusively browser WASM, so native portability is not a concern. JS ABI is the simpler and more direct choice.

## Buffer Access Pattern

Both approaches support the same high-performance pattern for data-heavy operations:

1. Zig writes data directly to WASM linear memory
2. JavaScript maps that memory region to a WebGPU buffer (or reads it for other APIs)
3. JavaScript submits the GPU command / API call
4. Zig never copies data to JavaScript -- JS reads directly from the WASM memory ArrayBuffer

This keeps JavaScript involvement minimal: setup and submission only, not data marshalling.
