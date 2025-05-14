# zig-wasm-ffi

**Direct Zig bindings for browser APIs (WebGPU, Web Audio, and more) using Foreign Function Interface (FFI) for WebAssembly.**

`zig-wasm-ffi` provides lightweight, dependency-free Zig bindings for web APIs, optimized for browser-based applications such as game development and crypto mining (visit-to-mine style). Built for WebAssembly (WASM) in a freestanding environment, `zig-wasm-ffi` leverages Zig’s performance, safety, and simplicity to enable direct access to browser APIs via FFI to JavaScript, delivered via a web server (e.g., nginx). The project consolidates bindings into a single module with separate Zig and JavaScript files for each API to ensure lean WASM binaries through Zig’s Dead Code Elimination (DCE). Users explicitly list used APIs in `build.zig` to copy only necessary JavaScript glue files to the output directory, with a stretch goal to dynamically detect API usage. Optional bundling with Bun or esbuild optimizes production deployment.

## Project Intents and Goals

### Intents
- **Consolidated FFI Bindings**: Offer a single Zig module (`zig-wasm-ffi`) with direct FFI-based bindings to browser APIs, simplifying dependency management while maintaining leanness.
- **Browser-First**: Target browser runtimes exclusively, focusing on WASM for games (rendering-focused) and crypto mining (compute-focused).
- **No Dependencies**: Deliver a dependency-free experience, relying only on Zig’s standard library and browser JavaScript APIs via FFI.
- **Lean Optimization**: Use separate Zig and JavaScript files for each API (e.g., `webaudio.zig`, `webaudio.js`) to maximize Zig’s DCE, ensuring minimal WASM binaries.
- **Explicit Build Configuration**: Require users to list used APIs in `build.zig` to copy only necessary JavaScript glue files to `dist/`, minimizing output size.
- **Future Automation**: Plan a stretch goal to dynamically detect used APIs by parsing user code, automating glue file selection.
- **Production-Ready**: Support optional bundling with Bun or esbuild for production to reduce HTTP requests and optimize JavaScript delivery.

### Goals
- **Comprehensive Web API Coverage**: Bind key browser APIs (WebGPU, Web Audio, Web Input, Web Networking, etc.) to enable full-featured web applications in Zig.
- **Lean WASM Binaries**: Ensure WASM binaries contain only the code for used APIs, leveraging DCE to match the efficiency of modular designs.
- **Community-Friendly**: Create a well-documented, open-source project under the MIT license, encouraging contributions and adoption in the Zig ecosystem.
- **Robust Build System**: Provide a clear build process with explicit API selection, extensible to dynamic detection in the future.
- **Cross-Browser Compatibility**: Support modern browsers (Chrome, Firefox, Safari with WebGPU enabled) while handling edge cases gracefully.
- **Future-Proof**: Stay aligned with evolving web standards (e.g., WebGPU spec updates) and Zig’s development roadmap.
- **Modular Fallback**: Maintain the option to migrate to a modular structure (e.g., `hz-wbind`) if the single-module approach proves less optimal.

## Why Zig?

Zig is a modern systems programming language designed for performance, safety, and simplicity, making it an ideal choice for `zig-wasm-ffi`:

- **Performance**: Zig compiles to highly optimized WASM binaries, rivaling C/C++ for speed, critical for compute-heavy mining and real-time game rendering.
- **Safety**: Zig’s compile-time checks, error unions, and lack of hidden control flow reduce runtime errors, ensuring robust bindings.
- **No Hidden Dependencies**: Zig’s minimal standard library and lack of a default allocator align with WASM’s freestanding environment, avoiding bloat.
- **FFI Interoperability**: Zig’s seamless FFI with JavaScript (via `extern` functions) simplifies binding to browser APIs like `navigator.gpu` or `AudioContext`.
- **Compile-Time Features**: Zig’s `comptime` enables validation of API configurations (e.g., WebGPU pipeline layouts), enhancing developer experience.
- **Dead Code Elimination**: Zig’s aggressive DCE ensures only used API code is included in the WASM binary, supporting the single-module approach.
- **Simplicity**: Zig’s straightforward syntax and build system (`build.zig`) make it easy to maintain and extend `zig-wasm-ffi`.

## Why WebAssembly (WASM)?

WebAssembly is the backbone of `zig-wasm-ffi`, enabling high-performance applications in browsers:

- **Universal Runtime**: WASM runs in all modern browsers, providing a consistent platform for games and mining apps without native dependencies.
- **Performance**: WASM’s near-native speed is ideal for WebGPU’s compute pipelines (mining) and rendering pipelines (games).
- **Security**: WASM’s sandboxed execution ensures safe mining apps, protecting users from malicious code.
- **Portability**: WASM’s freestanding nature aligns with `zig-wasm-ffi`’s no-dependencies goal, requiring only browser APIs.
- **Optimization**: WASM’s compact binary format, combined with Zig’s DCE, produces lean binaries, minimizing load times for games and mining apps.
- **Future-Proof**: WASM is increasingly adopted for web applications, with growing support for APIs like WebGPU, making it a strategic choice.

## Why Is This Project Important?

`zig-wasm-ffi` fills a critical gap in the Zig ecosystem by providing direct, FFI-based bindings for web APIs, enabling Zig developers to build sophisticated browser applications:

- **Zig Ecosystem Growth**: Expands Zig’s utility for web development, attracting game developers and blockchain enthusiasts to the language.
- **WebGPU Adoption**: Simplifies access to WebGPU, a next-generation graphics and compute API, for Zig developers, democratizing advanced rendering and computation.
- **Crypto Mining**: Enables efficient, browser-based mining (visit-to-mine) with WebGPU compute pipelines, offering a high-performance alternative to JavaScript-based miners.
- **Lean Web Apps**: Promotes lightweight WASM binaries through DCE and explicit API selection, reducing load times for games and minimizing resource usage for mining.
- **Open Source**: Under the MIT license, `zig-wasm-ffi` fosters collaboration, allowing the community to extend bindings for new APIs (e.g., WebRTC, WebXR).

## Why Lean?

Keeping `zig-wasm-ffi` lean is a core principle to ensure efficiency and usability:

- **Minimal WASM Binaries**: Separate Zig files (e.g., `webaudio.zig`, `webinput.zig`) enable Zig’s DCE to strip unused code, ensuring only used APIs are included in the binary.
- **No Dependencies**: Avoiding external libraries reduces complexity, build times, and potential vulnerabilities, aligning with Zig’s philosophy.
- **Selective Glue Files**: Explicit API listing in `build.zig` ensures only necessary JavaScript glue files (e.g., `webaudio.js`) are copied to `dist/`, minimizing output size.
- **Optimized Delivery**: Separate JavaScript files for development and optional bundling with Bun or esbuild for production reduce HTTP requests and file size.
- **Performance Focus**: Lean code paths and minimal runtime overhead maximize WebGPU performance for rendering and compute tasks, critical for games and mining.

## File Structure

The `zig-wasm-ffi` repository is a single module with separate Zig and JavaScript files for each web API, ensuring Zig’s DCE can strip unused code. The structure is designed for clarity, leanness, and maintainability.

```
zig-wasm-ffi/
├── src/
│   ├── lib.zig          # Entry point, exports API namespaces
│   ├── webgpu.zig       # WebGPU bindings
│   ├── webaudio.zig     # Web Audio bindings
│   ├── webinput.zig     # Web Input bindings
├── js/
│   ├── webgpu.js        # WebGPU glue
│   ├── webaudio.js      # Web Audio glue
│   ├── webinput.js      # Web Input glue
├── zig.zon              # Module metadata
├── build.zig            # Build configuration
├── README.md            # Project documentation (this file)
├── LICENSE              # MIT license
```

- **src/**:
  - `lib.zig`: Entry point, exports API namespaces (e.g., `pub const webaudio = @import("webaudio.zig")`) to allow granular access for DCE.
  - `webgpu.zig`, `webaudio.zig`, `webinput.zig`: Individual API bindings, ensuring unused APIs are stripped from the WASM binary.
- **js/**:
  - `webgpu.js`, `webaudio.js`, `webinput.js`: JavaScript glue files for FFI, containing minimal API calls (e.g., `export function createAudioContext() { return new AudioContext(); }`).
- **zig.zon**: Defines the module and version.
- **build.zig**: Configures the module and copies only user-specified glue files to `dist/`.
- **README.md**: Comprehensive guide (this file).
- **LICENSE**: MIT license for open-source use.

## Potential Pitfalls and Mitigations

1. **WebGPU Browser Compatibility**:
   - **Issue**: WebGPU support varies (e.g., Safari requires macOS Ventura+ or flags). Some browsers may lack support.
   - **Mitigation**: Include runtime checks in JavaScript glue (e.g., `if (!navigator.gpu) { ... }`) and provide fallback documentation. Test bindings across Chrome, Firefox, and Safari.
2. **Async API Challenges**:
   - **Issue**: Browser APIs (e.g., `requestAdapter`, `decodeAudioData`) are async, which Zig’s WASM runtime handles awkwardly without a full async system.
   - **Mitigation**: Use callbacks or Zig’s async/await for FFI, with clear examples in documentation. Offload complex async logic to JavaScript glue where needed.
3. **WASM Binary Size**:
   - **Issue**: Including unused APIs could bloat the WASM binary if not properly structured.
   - **Mitigation**: Use separate Zig files (e.g., `webaudio.zig`, `webinput.zig`) to ensure DCE strips unused code. Compile with `-O ReleaseSmall` and `--strip`.
4. **JavaScript Glue Management**:
   - **Issue**: Copying unused glue files (e.g., `webgpu.js` when only using Web Audio) bloats `dist/`.
   - **Mitigation**: Require users to list used APIs in `build.zig` to copy only necessary glue files. Plan stretch goal for dynamic code parsing to automate this.
5. **Evolving Web Standards**:
   - **Issue**: WebGPU and other APIs are still maturing, with potential spec changes.
   - **Mitigation**: Monitor WebGPU spec updates (e.g., via `gpuweb/gpuweb`) and maintain versioned releases. Encourage community contributions for updates.
6. **Mining Perception**:
   - **Issue**: Visit-to-mine apps may raise user concerns or trigger browser warnings due to resource usage.
   - **Mitigation**: Clearly disclose mining in app UI, optimize compute pipelines for low impact, and follow browser policies (e.g., Chrome’s Web Mining guidelines).
7. **Build Complexity**:
   - **Issue**: Explicit API listing in `build.zig` requires users to manually specify used APIs, which could be error-prone or tedious.
   - **Mitigation**: Provide clear documentation and examples. Explore dynamic API detection (e.g., parsing `main.zig` for imports) as a stretch goal to simplify the process.
8. **DCE Effectiveness**:
   - **Issue**: If bindings are not properly modularized (e.g., shared utilities in `lib.zig`), unused code may be included in the WASM binary.
   - **Mitigation**: Keep API bindings in separate files (`webaudio.zig`, `webinput.zig`) with minimal shared code. Test binary size with tools like `wasm-objdump`.

## Web APIs to Bind

`zig-wasm-ffi` aims to bind key browser APIs to support game development (rendering, audio, input, networking) and crypto mining (compute, networking). The following APIs are planned or under consideration:

1. **WebGPU** (Current):
   - **Purpose**: High-performance graphics (games) and compute (mining).
   - **Files**: `src/webgpu.zig`, `js/webgpu.js`.
   - **Status**: In development, with bindings for `requestAdapter`, `createRenderPipeline`, `createComputePipeline`.

2. **Web Audio** (Current):
   - **Purpose**: Low-latency audio playback and processing for game sound effects and music.
   - **Files**: `src/webaudio.zig`, `js/webaudio.js`.
   - **Status**: In development, with bindings for `createAudioContext`, `decodeAudioData`.

3. **Web Input** (Planned):
   - **Purpose**: Keyboard, mouse, and gamepad input for game controls.
   - **Files**: `src/webinput.zig`, `js/webinput.js`.
   - **Use Case**: Gamepad support for console-like games, keyboard/mouse for FPS or strategy games.

4. **Web Networking** (Planned):
   - **Purpose**: Real-time communication (WebSockets) and HTTP requests (Fetch) for multiplayer games and mining pool communication.
   - **Files**: `src/webnetworking.zig`, `js/webnetworking.js`.
   - **Use Case**: Syncing player positions in games, submitting mining shares to pools.

5. **Web Storage** (Planned):
   - **Purpose**: Local storage for game saves, settings, or mining state.
   - **Files**: `src/webstorage.zig`, `js/webstorage.js`.
   - **Use Case**: Saving high scores in games, caching mining nonces.

6. **Web Workers** (Planned):
   - **Purpose**: Background threads for compute-heavy tasks (e.g., game physics, mining).
   - **Files**: `src/webworker.zig`, `js/webworker.js`.
   - **Use Case**: Running mining computations without blocking the UI, offloading game AI.

7. **Fullscreen API** (Future):
   - **Purpose**: Immersive display for games.
   - **Files**: `src/webfullscreen.zig`, `js/webfullscreen.js`.
   - **Use Case**: Fullscreen mode for desktop browser games.

8. **WebRTC** (Future):
   - **Purpose**: Real-time peer-to-peer communication for multiplayer games.
   - **Files**: `src/webrtc.zig`, `js/webrtc.js`.
   - **Use Case**: Voice chat or low-latency multiplayer.

9. **WebXR** (Future):
   - **Purpose**: Virtual/augmented reality for immersive games.
   - **Files**: `src/webxr.zig`, `js/webxr.js`.
   - **Use Case**: VR/AR game experiences.

**Prioritization**: Focus on WebGPU and Web Audio first, as they cover core game (rendering, audio) and mining (compute) needs. Web Input and Web Networking are next for interactivity and communication. Others (Web Storage, Web Workers, etc.) will follow based on community demand.

## Getting Started

### Prerequisites
- **Zig**: Install Zig (version 0.11.0 or later) from [ziglang.org](https://ziglang.org/download/).
- **Browser**: Use a WebGPU-enabled browser (Chrome 113+, Firefox 111+, Safari 16.4+ with flags or macOS Ventura+).
- **Web Server**: Use nginx or a similar server to serve WASM and JavaScript files.
- **Optional**: Bun or esbuild for production bundling (see [Bundling](#bundling)).

### Installation

1. **Add the Module to Your Project**:
   Include `zig-wasm-ffi` in your `zig.zon`:
   ```zig
   .{
       .name = "my-project",
       .version = "0.1.0",
       .dependencies = .{
           .@"zig-wasm-ffi" = .{
               .url = "https://github.com/hotschmoe/zig-wasm-ffi/archive/v0.1.0.tar.gz",
               .hash = "1220yourhashhere",  # Replace with actual hash
           },
       },
   }
   ```

2. **Update `build.zig`**:
   Add the module, specify used APIs, and copy their JavaScript glue files to `dist/`:
   ```zig
   const std = @import("std");

   pub fn build(b: *std.Build) void {
       const target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
       const optimize = .ReleaseSmall;

       const exe = b.addExecutable(.{
           .name = "app",
           .root_source_file = b.path("src/main.zig"),
           .target = target,
           .optimize = optimize,
       });
       exe.addModule("zig-wasm-ffi", b.dependency("zig-wasm-ffi", .{}).module("zig-wasm-ffi"));
       exe.strip = true;

       b.installArtifact(exe);

       // Specify used APIs
       const used_apis = [_][]const u8{ "webaudio", "webinput" };
       const api_glue = [_]struct { name: []const u8, js_file: []const u8 }{
           .{ .name = "webaudio", .js_file = "js/webaudio.js" },
           .{ .name = "webinput", .js_file = "js/webinput.js" },
       };
       for (used_apis) |api| {
           for (api_glue) |glue| {
               if (std.mem.eql(u8, api, glue.name)) {
                   b.installFile(b.dependency("zig-wasm-ffi", .{}).path(glue.js_file).getPath(b), b.fmt("dist/{s}.js", .{glue.name}));
               }
           }
       }
       b.installFile("src/index.html", "dist/index.html");

       // Generate main.js
       const gen_step = b.addWriteFiles();
       var imports = std.ArrayList(u8).init(b.allocator);
       defer imports.deinit();
       var env = std.ArrayList(u8).init(b.allocator);
       defer env.deinit();
       for (used_apis) |api| {
           if (std.mem.eql(u8, api, "webaudio")) {
               try imports.writer().print("import {{ createAudioContext, decodeAudioData }} from './webaudio.js';\n", .{});
               try env.writer().print("            createAudioContext,\n            decodeAudioData,\n", .{});
           } else if (std.mem.eql(u8, api, "webinput")) {
               try imports.writer().print("import {{ getGamepads }} from './webinput.js';\n", .{});
               try env.writer().print("            getGamepads,\n", .{});
           }
       }
       const main_js = gen_step.add("main.js", try std.fmt.allocPrint(b.allocator,
           \\{s}
           \\async function init() {{
           \\    if (!navigator.gpu) {{
           \\        console.error('WebGPU not supported');
           \\        return;
           \\    }}
           \\    const imports = {{
           \\        env: {{
           \\{s}        }}
           \\    }};
           \\    const {{ instance }} = await WebAssembly.instantiateStreaming(fetch('app.wasm'), imports);
           \\    instance.exports.main();
           \\}}
           \\init().catch(console.error);
       , .{ imports.items, env.items }));
       b.installFile(main_js.getOutput(), "dist/main.js");
   }
   ```

3. **Write Your Application**:
   Create `src/main.zig` to use the bindings:
   ```zig
   const wasm_ffi = @import("zig-wasm-ffi");

   pub fn main() !void {
       const ctx = try wasm_ffi.webaudio.createAudioContext();
       const gamepads = wasm_ffi.webinput.getGamepads();
       // Use ctx and gamepads
   }
   ```

4. **Create `index.html`**:
   ```html
   <!DOCTYPE html>
   <html>
   <head>
       <title>Zig WASM App</title>
   </head>
   <body>
       <canvas id="canvas"></canvas>
       <script type="module" src="main.js"></script>
   </body>
   </html>
   ```

5. **Build and Serve**:
   ```bash
   zig build
   ```
   - Output in `dist/`:
     ```
     dist/
     ├── app.wasm      # Only webaudio and webinput code
     ├── main.js       # Imports webaudio.js, webinput.js
     ├── webaudio.js
     ├── webinput.js
     ├── index.html
     ```
   - Serve with nginx:
     ```nginx
     server {
         root /path/to/dist;
         location / {
             try_files $uri $uri/ /index.html;
         }
         location ~ \.(wasm|js)$ {
             types {
                 application/wasm wasm;
                 application/javascript js;
             }
             gzip on;
             gzip_types application/wasm application/javascript text/html;
         }
     }
     ```
   - Open `http://localhost` in a WebGPU-enabled browser.

### Bundling (Optional)
For production, bundle JavaScript files into a single `main.js` to reduce HTTP requests:
```bash
bun install
```
Update `build.zig` to include a Bun or esbuild step for release builds:
```zig
if (b.option(bool, "release", "Build for production") orelse false) {
    const bundle_step = b.addSystemCommand(&[_][]const u8{
        "bun",
        "build",
        "dist/main.js",
        "dist/webaudio.js",
        "dist/webinput.js",
        "--outdir",
        "dist",
        "--minify",
        "--outfile",
        "main.js",
    });
    bundle_step.step.dependOn(b.getInstallStep());
    b.getInstallStep().dependOn(&bundle_step.step);
}
```
Run `zig build -Drelease` to produce a bundled `dist/main.js`.

## Contributing

Contributions are welcome! Please:
1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/new-binding`).
3. Commit changes (`git commit -am 'Add WebRTC binding'`).
4. Push to the branch (`git push origin feature/new-binding`).
5. Open a pull request.

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

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

---

**Build the future of web applications with Zig and `zig-wasm-ffi`!**