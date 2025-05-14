// zig-wasm-ffi/js/webinput.js

let wasmExports = null;
let canvas = null;

// --- Core Input System Setup ---

/**
 * Initializes the input system by setting up event listeners for mouse and keyboard.
 * @param {object} instanceExports The `exports` object from the instantiated Wasm module.
 * @param {HTMLCanvasElement|string} canvasElementOrId The canvas element or its ID for mouse events.
 */
export function setupInputSystem(instanceExports, canvasElementOrId) {
    if (!instanceExports) {
        console.error("WebInput: Wasm exports not provided to setupInputSystem.");
        return;
    }
    wasmExports = instanceExports;

    if (typeof canvasElementOrId === 'string') {
        canvas = document.getElementById(canvasElementOrId);
    } else {
        canvas = canvasElementOrId;
    }

    if (!canvas) {
        // Log warning instead of error, as keyboard input can still work globally.
        console.warn("WebInput: Canvas element not found or provided. Mouse input will not be available.");
    }

    _setupMouseListeners();
    _setupKeyListeners();

    console.log("WebInput: System initialized for mouse and keyboard.");
}

// --- Event Listener Setup ---

function _setupMouseListeners() {
    if (!canvas) return; // Mouse listeners require a canvas

    canvas.addEventListener('mousemove', (event) => {
        if (wasmExports && wasmExports.zig_internal_on_mouse_move) {
            const rect = canvas.getBoundingClientRect();
            wasmExports.zig_internal_on_mouse_move(event.clientX - rect.left, event.clientY - rect.top);
        }
    });

    canvas.addEventListener('mousedown', (event) => {
        if (wasmExports && wasmExports.zig_internal_on_mouse_button) {
            const rect = canvas.getBoundingClientRect();
            wasmExports.zig_internal_on_mouse_button(event.button, true, event.clientX - rect.left, event.clientY - rect.top);
        }
    });

    canvas.addEventListener('mouseup', (event) => {
        if (wasmExports && wasmExports.zig_internal_on_mouse_button) {
            const rect = canvas.getBoundingClientRect();
            wasmExports.zig_internal_on_mouse_button(event.button, false, event.clientX - rect.left, event.clientY - rect.top);
        }
    });

    canvas.addEventListener('wheel', (event) => {
        if (wasmExports && wasmExports.zig_internal_on_mouse_wheel) {
            event.preventDefault(); // Prevent page scrolling
            let deltaX = event.deltaX;
            let deltaY = event.deltaY;
            if (event.deltaMode === 1) { // DOM_DELTA_LINE
                deltaX *= 16; 
                deltaY *= 16;
            } else if (event.deltaMode === 2) { // DOM_DELTA_PAGE
                deltaX *= (canvas.width || window.innerWidth) * 0.8; // Fallback if canvas has no dimensions yet
                deltaY *= (canvas.height || window.innerHeight) * 0.8;
            }
            wasmExports.zig_internal_on_mouse_wheel(deltaX, deltaY);
        }
    });

    // Optional: Prevent context menu on right-click if desired for the canvas
    // canvas.addEventListener('contextmenu', event => event.preventDefault());
}

function _setupKeyListeners() {
    window.addEventListener('keydown', (event) => {
        if (wasmExports && wasmExports.zig_internal_on_key_event) {
            wasmExports.zig_internal_on_key_event(event.keyCode, true);
            // To prevent default browser actions for certain keys (e.g., space, arrows scrolling the page)
            // you might add: if (isAppKey(event.keyCode)) { event.preventDefault(); }
            // where isAppKey is a helper to check if the key is handled by your app.
        }
    });

    window.addEventListener('keyup', (event) => {
        if (wasmExports && wasmExports.zig_internal_on_key_event) {
            wasmExports.zig_internal_on_key_event(event.keyCode, false);
        }
    });
}

// Gamepad related code (constants, cache, FFI functions) has been removed.
// For future gamepad integration, the FFI functions (platform_poll_gamepads, etc.)
// would be implemented here.