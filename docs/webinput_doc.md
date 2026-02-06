# WebInput Module

## Overview

The `webinput` module provides Zig FFI bindings for mouse and keyboard input in browser-based WASM applications. JavaScript event listeners forward input data to exported Zig functions, which update internal state that the application polls each frame.

## Zig API (`src/webinput.zig`)

### Types

- `MousePosition: struct { x: f32, y: f32 }`
- `MouseWheelDelta: struct { dx: f32, dy: f32 }`

### Internal State

- `MouseState` -- tracks position, button states (current + previous frame), wheel delta
- `KeyboardState` -- tracks key states (current + previous frame)
- Constants: `MAX_KEY_CODES = 256`, `MAX_MOUSE_BUTTONS = 5`

### Public Functions

| Function | Description |
|----------|-------------|
| `update_input_frame_start()` | Call at frame start. Copies current to previous state, resets wheel delta |
| `get_mouse_position() MousePosition` | Current mouse position (canvas-relative) |
| `is_mouse_button_down(button) bool` | Button currently held |
| `was_mouse_button_just_pressed(button) bool` | Button pressed this frame |
| `was_mouse_button_just_released(button) bool` | Button released this frame |
| `get_mouse_wheel_delta() MouseWheelDelta` | Wheel movement this frame |
| `is_key_down(key_code) bool` | Key currently held |
| `was_key_just_pressed(key_code) bool` | Key pressed this frame |
| `was_key_just_released(key_code) bool` | Key released this frame |

Mouse button codes follow `event.button`: 0 = left, 1 = middle, 2 = right. Key codes correspond to `event.keyCode`.

### Exported Functions (called by JavaScript)

These `pub export` functions are called by `js/webinput.js` event listeners:

- `zig_internal_on_mouse_move(x, y)`
- `zig_internal_on_mouse_button(button_code, is_down, x, y)`
- `zig_internal_on_mouse_wheel(delta_x, delta_y)`
- `zig_internal_on_key_event(key_code, is_down)`

## JavaScript Glue (`src/js/webinput.js`)

### Setup

```javascript
import { setupInputSystem } from './webinput.js';

// After WASM instantiation:
setupInputSystem(instance.exports, 'canvas');
```

`setupInputSystem(instanceExports, canvasElementOrId)`:
- `instanceExports`: the WASM module's `exports` object
- `canvasElementOrId`: canvas element or its string ID. Mouse events bind to this canvas (coordinates are canvas-relative). Keyboard events attach to `window`.

No `env` imports are needed -- `webinput.js` only calls into Zig exports, it does not provide `extern "env"` functions.

### Event Flow

```
Browser event -> JS listener -> exported Zig function -> internal state update
                                                              |
Application frame -> update_input_frame_start() -> poll with get_*/is_*/was_*
```

## Usage Example

```zig
const webinput = @import("zig-wasm-ffi").webinput;

pub export fn update_frame() void {
    webinput.update_input_frame_start();

    const pos = webinput.get_mouse_position();
    if (webinput.was_mouse_button_just_pressed(0)) {
        // left click at pos.x, pos.y
    }
    if (webinput.was_key_just_pressed(32)) {
        // spacebar pressed
    }
}
```

## Future: Gamepad Support

Gamepad support is planned but not yet implemented. It will use `extern "env"` functions for polling (`navigator.getGamepads()`), providing button and axis state per connected gamepad. The API will follow the same poll-per-frame pattern as mouse/keyboard.
