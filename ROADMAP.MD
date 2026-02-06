# Roadmap

## API Status

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

## Current Priorities

1. **WebGPU** -- next API to implement
2. Polish Web Audio + Web Input toward "Complete"

## Development Practices

- Test files for every API (`someapi.test.zig`)
- Demos for completed APIs
- `wasm32-freestanding` target, minimize `std` usage
- Follow patterns established in `webinput.zig` / `webaudio.zig`
