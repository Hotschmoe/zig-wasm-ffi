# Project Roadmap

This document outlines the development status and future plans for `zig-wasm-ffi`.

## API Binding Status

The goal is to provide comprehensive bindings for key browser APIs. The current status of each planned API is as follows:

| API Name        | Not Started | Not Working | Working | Complete |
|-----------------|:-----------:|:-----------:|:-------:|:--------:|
| WebGPU          | ☐           | ☑           | ☐       | ☐        |
| Web Audio       | ☐           | ☑           | ☐       | ☐        |
| Web Input       | ☐           | ☐           | ☑       | ☐        |
| Web Networking  | ☑           | ☐           | ☐       | ☐        |
| Web Storage     | ☑           | ☐           | ☐       | ☐        |
| Web Workers     | ☑           | ☐           | ☐       | ☐        |
| Fullscreen API  | ☑           | ☐           | ☐       | ☐        |
| WebRTC          | ☑           | ☐           | ☐       | ☐        |
| WebXR           | ☑           | ☐           | ☐       | ☐        |

## Development Milestones & Notes

### Next Milestones:
1.  **Web Audio**:
    *   Focus on achieving "Working" status for Web Audio bindings.
    *   The implementation should follow the syntax and flow established in `webinput.zig` and its corresponding JavaScript glue file.
    *   Develop `webaudio.test.zig` for comprehensive unit testing.
2.  **WebGPU**:
    *   After Web Audio, shift focus to WebGPU bindings.
    *   The implementation should also align with the patterns from `webinput.zig` and its JavaScript glue.
    *   Develop `webgpu.test.zig` for comprehensive unit testing.

### General Development Practices:
*   **Test Files**: For every API binding (e.g., `someapi.zig`), a corresponding `someapi.test.zig` file must be created to ensure robustness and correctness. These tests will utilize Zig's standard library and testing capabilities, as demonstrated by `webinput.test.zig`.
*   **Demo Implementations**: A `demos/` (or potentially expanding the existing `example/`) directory will be maintained to showcase practical implementations of the completed API bindings. This will provide clear usage examples for developers.

### Future API Considerations:
*   Once Web Audio and WebGPU are in a "Working" or "Complete" state, development will proceed to other planned APIs (Web Networking, Web Storage, etc.) based on priority and community feedback.
*   "Future" APIs (Fullscreen, WebRTC, WebXR) will be addressed after the core set of planned APIs is well-established.

This roadmap will be updated as the project progresses.
