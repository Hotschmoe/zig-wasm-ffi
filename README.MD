# zig-wasm-ffi

Direct Zig FFI bindings for browser APIs, targeting wasm32-freestanding.

## What This Is

Write Zig, target the browser, skip the emscripten bloat. `zig-wasm-ffi` provides lightweight, dependency-free bindings to browser APIs via FFI to JavaScript. Built for `wasm32-freestanding`, it produces lean WASM binaries with no standard library dependency -- just your code and the APIs you use.

The project targets any browser-based application that benefits from near-native performance: games, audio tools, compute workloads, visualizations, and more.

## Why Zig + WASM

- **Performance**: Zig compiles to highly optimized WASM binaries rivaling C/C++, ideal for real-time rendering and compute.
- **FFI interop**: Zig's `extern` functions map directly to JavaScript imports -- no wrapper layers, no code generation.
- **Dead code elimination**: Separate API files (`webaudio.zig`, `webinput.zig`, etc.) let Zig strip everything you don't use.
- **No hidden dependencies**: No default allocator, no implicit runtime. You control what ships in your binary.
- **Sandboxed execution**: WASM runs in the browser sandbox -- safe by default, portable across all modern browsers.
- **Universal runtime**: Ship one `.wasm` binary that runs in Chrome, Firefox, and Safari without native dependencies.

## Supported APIs

| API             | Status      |
|-----------------|-------------|
| Web Audio       | Working     |
| Web Input       | Working     |
| WebGPU          | Not Started |
| Web Networking  | Not Started |
| Web Storage     | Not Started |
| Web Workers     | Not Started |
| Fullscreen API  | Not Started |
| WebRTC          | Not Started |
| WebXR           | Not Started |

See [ROADMAP.MD](ROADMAP.MD) for priorities and details.

## File Structure

```
zig-wasm-ffi/
├── src/
│   ├── lib.zig              # Entry point, exports API namespaces
│   ├── webaudio.zig         # Web Audio bindings
│   ├── webaudio.test.zig    # Web Audio tests
│   ├── webinput.zig         # Web Input bindings
│   ├── webinput.test.zig    # Web Input tests
│   ├── webgpu.zig           # WebGPU bindings (stub)
│   ├── webgpu.test.zig      # WebGPU tests (stub)
│   └── js/                  # JavaScript glue files
│       ├── webaudio.js
│       ├── webinput.js
│       └── webgpu.js
├── demos/
│   ├── input_n_audio/       # Input + audio demo
│   └── particle_simulator/  # Particle simulator demo
├── docs/                    # Documentation
├── webgpu_ref_projects/     # Reference implementations
├── build.zig                # Build configuration
└── build.zig.zon            # Module metadata
```

## Building

Build the WASM library:

```bash
zig build wasm -Doptimize=ReleaseSmall
```

Output: `zig-out/bin/zig_wasm_ffi.wasm`

Build a demo (e.g., input_n_audio):

```bash
cd demos/input_n_audio
zig build -Doptimize=ReleaseSmall
```

Serve the output with any static file server to run in the browser.

## Testing

Tests are co-located with the code they test (`src/*.test.zig`) and aggregated through `src/lib.zig`.

Using the build system (recommended):

```bash
zig build test
```

Running tests directly:

```bash
zig test src/lib.zig
```

## Contributing

Contributions are welcome! Please:
1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/new-binding`).
3. Commit changes (`git commit -am 'Add WebRTC binding'`).
4. Push to the branch (`git push origin feature/new-binding`).
5. Open a pull request.

## License

`zig-wasm-ffi` is licensed under the MIT License:

```
MIT License

Copyright (c) 2025 hotschmoe

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Contact

- **Issues**: Report bugs or request features at [github.com/hotschmoe/zig-wasm-ffi/issues](https://github.com/hotschmoe/zig-wasm-ffi/issues).
- **Discussion**: Join the Zig community on [Discord](https://ziglang.org/community/) or [Reddit](https://reddit.com/r/zig).
- **Email**: Contact hotschmoe at [email@example.com](mailto:email@example.com).
