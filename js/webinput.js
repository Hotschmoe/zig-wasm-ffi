// zig-wasm-ffi/js/webinput.js

let wasmExports = null;
let canvas = null;

// Flags to prevent spamming console with errors if Wasm exports are missing
let mouseMoveErrorLogged = false;
let mouseButtonErrorLogged = false;
let mouseWheelErrorLogged = false;
let keyEventErrorLogged = false;

// --- Core Input System Setup ---

/**
 * Initializes the input system by setting up event listeners for mouse and keyboard.
 * Must be called after the Wasm module is instantiated.
 * @param {object} instanceExports The `exports` object from the instantiated Wasm module.
 * @param {HTMLCanvasElement|string} canvasElementOrId The canvas element or its ID for mouse events.
 */
export function setupInputSystem(instanceExports, canvasElementOrId) {
    if (!instanceExports) {
        console.error("[WebInput.js] Wasm exports not provided to setupInputSystem. Input system will not work.");
        return;
    }
    wasmExports = instanceExports;

    if (typeof canvasElementOrId === 'string') {
        canvas = document.getElementById(canvasElementOrId);
    } else if (canvasElementOrId instanceof HTMLCanvasElement) {
        canvas = canvasElementOrId;
    } else {
        console.error("[WebInput.js] Invalid canvasElementOrId provided. Must be an ID string or an HTMLCanvasElement. Mouse input will not be available.");
        canvas = null; // Ensure canvas is null if invalid
    }

    if (!canvas) {
        console.warn("[WebInput.js] Canvas element not found or invalid. Mouse input will not be available. Canvas ID/element was:", canvasElementOrId);
    }

    _setupMouseListeners();
    _setupKeyListeners();

    console.log("[WebInput.js] Input system initialized. Canvas element:", canvas);
}

// --- Event Listener Setup ---

function _setupMouseListeners() {
    if (!canvas) {
        // Warning already logged in setupInputSystem if canvas is essential
        return;
    }

    canvas.addEventListener('mousemove', (event) => {
        // console.log("[WebInput.js TEMP] mousemove event fired"); // TEMP LOG - uncomment if needed
        if (wasmExports && wasmExports.zig_internal_on_mouse_move) {
            const rect = canvas.getBoundingClientRect();
            // console.log("[WebInput.js TEMP] Calling zig_internal_on_mouse_move"); // TEMP LOG - uncomment if needed
            wasmExports.zig_internal_on_mouse_move(event.clientX - rect.left, event.clientY - rect.top);
        } else if (!mouseMoveErrorLogged) {
            console.error("[WebInput.js] Wasm export 'zig_internal_on_mouse_move' not found.");
            mouseMoveErrorLogged = true;
        }
    });

    canvas.addEventListener('mousedown', (event) => {
        console.log("[WebInput.js TEMP] mousedown event fired. Button:", event.button);
        if (wasmExports && wasmExports.zig_internal_on_mouse_button) {
            const rect = canvas.getBoundingClientRect();
            console.log("[WebInput.js TEMP] Calling zig_internal_on_mouse_button (down)");
            wasmExports.zig_internal_on_mouse_button(event.button, true, event.clientX - rect.left, event.clientY - rect.top);
        } else if (!mouseButtonErrorLogged) {
            console.error("[WebInput.js] Wasm export 'zig_internal_on_mouse_button' not found (for mousedown).");
            mouseButtonErrorLogged = true;
        }
    });

    canvas.addEventListener('mouseup', (event) => {
        console.log("[WebInput.js TEMP] mouseup event fired. Button:", event.button);
        if (wasmExports && wasmExports.zig_internal_on_mouse_button) {
            const rect = canvas.getBoundingClientRect();
            console.log("[WebInput.js TEMP] Calling zig_internal_on_mouse_button (up)");
            wasmExports.zig_internal_on_mouse_button(event.button, false, event.clientX - rect.left, event.clientY - rect.top);
        } else if (!mouseButtonErrorLogged) {
            console.error("[WebInput.js] Wasm export 'zig_internal_on_mouse_button' not found (for mouseup).");
            mouseButtonErrorLogged = true;
        }
    });

    canvas.addEventListener('wheel', (event) => {
        // console.log("[WebInput.js TEMP] wheel event fired"); // TEMP LOG - uncomment if needed
        if (wasmExports && wasmExports.zig_internal_on_mouse_wheel) {
            event.preventDefault(); // Prevent page scrolling
            let deltaX = event.deltaX;
            let deltaY = event.deltaY;

            // Normalize delta values based on deltaMode
            // DOM_DELTA_PIXEL: 0 (default) - The delta values are specified in pixels.
            // DOM_DELTA_LINE: 1 - The delta values are specified in lines.
            // DOM_DELTA_PAGE: 2 - The delta values are specified in pages.
            // Heuristic values for line/page scrolling, can be adjusted.
            const LINE_HEIGHT = 16; // Approximate pixels per line
            const PAGE_FACTOR = 0.8; // Factor of canvas dimension

            if (event.deltaMode === WheelEvent.DOM_DELTA_LINE) {
                deltaX *= LINE_HEIGHT;
                deltaY *= LINE_HEIGHT;
            } else if (event.deltaMode === WheelEvent.DOM_DELTA_PAGE) {
                deltaX *= (canvas.width || window.innerWidth) * PAGE_FACTOR;
                deltaY *= (canvas.height || window.innerHeight) * PAGE_FACTOR;
            }
            // console.log("[WebInput.js TEMP] Calling zig_internal_on_mouse_wheel"); // TEMP LOG - uncomment if needed
            wasmExports.zig_internal_on_mouse_wheel(deltaX, deltaY);
        } else if (!mouseWheelErrorLogged) {
            console.error("[WebInput.js] Wasm export 'zig_internal_on_mouse_wheel' not found.");
            mouseWheelErrorLogged = true;
        }
    });

    // Disable context menu on right-click on the canvas for better game-like experience
    canvas.addEventListener('contextmenu', (event) => {
        event.preventDefault();
    });
}

function _setupKeyListeners() {
    // Key events are typically global
    window.addEventListener('keydown', (event) => {
        // console.log("[WebInput.js TEMP] keydown event fired. KeyCode:", event.keyCode); // TEMP LOG - uncomment if needed
        if (wasmExports && wasmExports.zig_internal_on_key_event) {
            // console.log("[WebInput.js TEMP] Calling zig_internal_on_key_event (down)"); // TEMP LOG - uncomment if needed
            wasmExports.zig_internal_on_key_event(event.keyCode, true); // true for is_down
        } else if (!keyEventErrorLogged) {
            console.error("[WebInput.js] Wasm export 'zig_internal_on_key_event' not found (for keydown).");
            keyEventErrorLogged = true;
        }
    });

    window.addEventListener('keyup', (event) => {
        // console.log("[WebInput.js TEMP] keyup event fired. KeyCode:", event.keyCode); // TEMP LOG - uncomment if needed
        if (wasmExports && wasmExports.zig_internal_on_key_event) {
            // console.log("[WebInput.js TEMP] Calling zig_internal_on_key_event (up)"); // TEMP LOG - uncomment if needed
            wasmExports.zig_internal_on_key_event(event.keyCode, false); // false for is_down
        } else if (!keyEventErrorLogged) {
            console.error("[WebInput.js] Wasm export 'zig_internal_on_key_event' not found (for keyup).");
            keyEventErrorLogged = true;
        }
    });
}

// Gamepad related code and old comments/FFI stubs have been removed.