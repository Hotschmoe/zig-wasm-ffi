// zig-wasm-ffi/js/webinput.js

// Module-scoped variables, similar to globalWebGPU in webgpu.js
const localInputState = {
    wasmExports: null,
    canvas: null,
    // Flags to prevent spamming console with errors if Wasm exports are missing
    mouseMoveErrorLogged: false,
    mouseButtonErrorLogged: false,
    mouseWheelErrorLogged: false,
    keyEventErrorLogged: false,
};

// --- Core Input System Setup --- Internal function
function _setupInputSystemInternal() {
    if (!localInputState.canvas) {
        // Warning already logged in initWebInputJs if canvas is essential
        return;
    }

    _setupMouseListeners();
    _setupKeyListeners();

    console.log("[WebInput.js] Internal input system setup complete.");
}

/**
 * Initializes the input system by setting up event listeners for mouse and keyboard.
 * Must be called after the Wasm module is instantiated.
 * @param {object} exports The `exports` object from the instantiated Wasm module.
 * @param {HTMLCanvasElement|string} canvasElementOrId The canvas element or its ID for mouse events.
 */
export function initWebInputJs(exports, canvasElementOrId) {
    if (!exports) {
        console.error("[WebInput.js] Wasm exports not provided to initWebInputJs. Input system will not work.");
        return;
    }
    localInputState.wasmExports = exports;

    if (typeof canvasElementOrId === 'string') {
        localInputState.canvas = document.getElementById(canvasElementOrId);
    } else if (canvasElementOrId instanceof HTMLCanvasElement) {
        localInputState.canvas = canvasElementOrId;
    } else {
        console.error("[WebInput.js] Invalid canvasElementOrId provided. Must be an ID string or an HTMLCanvasElement. Mouse input will not be available.");
        localInputState.canvas = null; // Ensure canvas is null if invalid
    }

    if (!localInputState.canvas) {
        console.warn("[WebInput.js] Canvas element not found or invalid. Mouse input will not be available. Canvas ID/element was:", canvasElementOrId);
    }

    // Call the internal setup function that now uses module-scoped variables
    _setupInputSystemInternal(); 

    console.log("[WebInput.js] Input system initialized via initWebInputJs.");
}

// --- Event Listener Setup --- (These remain largely the same, but use localInputState)

function _setupMouseListeners() {
    if (!localInputState.canvas) {
        return;
    }
    const canvas = localInputState.canvas; // For brevity in listeners

    canvas.addEventListener('mousemove', (event) => {
        if (localInputState.wasmExports && localInputState.wasmExports.zig_internal_on_mouse_move) {
            const rect = canvas.getBoundingClientRect();
            localInputState.wasmExports.zig_internal_on_mouse_move(event.clientX - rect.left, event.clientY - rect.top);
        } else if (!localInputState.mouseMoveErrorLogged) {
            console.error("[WebInput.js] Wasm export 'zig_internal_on_mouse_move' not found.");
            localInputState.mouseMoveErrorLogged = true;
        }
    });

    canvas.addEventListener('mousedown', (event) => {
        if (localInputState.wasmExports && localInputState.wasmExports.zig_internal_on_mouse_button) {
            const rect = canvas.getBoundingClientRect();
            localInputState.wasmExports.zig_internal_on_mouse_button(event.button, true, event.clientX - rect.left, event.clientY - rect.top);
        } else if (!localInputState.mouseButtonErrorLogged) {
            console.error("[WebInput.js] Wasm export 'zig_internal_on_mouse_button' not found (for mousedown).");
            localInputState.mouseButtonErrorLogged = true;
        }
    });

    canvas.addEventListener('mouseup', (event) => {
        if (localInputState.wasmExports && localInputState.wasmExports.zig_internal_on_mouse_button) {
            const rect = canvas.getBoundingClientRect();
            localInputState.wasmExports.zig_internal_on_mouse_button(event.button, false, event.clientX - rect.left, event.clientY - rect.top);
        } else if (!localInputState.mouseButtonErrorLogged) {
            console.error("[WebInput.js] Wasm export 'zig_internal_on_mouse_button' not found (for mouseup).");
            localInputState.mouseButtonErrorLogged = true;
        }
    });

    canvas.addEventListener('wheel', (event) => {
        if (localInputState.wasmExports && localInputState.wasmExports.zig_internal_on_mouse_wheel) {
            event.preventDefault(); 
            let deltaX = event.deltaX;
            let deltaY = event.deltaY;
            const LINE_HEIGHT = 16; 
            const PAGE_FACTOR = 0.8; 

            if (event.deltaMode === WheelEvent.DOM_DELTA_LINE) {
                deltaX *= LINE_HEIGHT;
                deltaY *= LINE_HEIGHT;
            } else if (event.deltaMode === WheelEvent.DOM_DELTA_PAGE) {
                deltaX *= (canvas.width || window.innerWidth) * PAGE_FACTOR;
                deltaY *= (canvas.height || window.innerHeight) * PAGE_FACTOR;
            }
            localInputState.wasmExports.zig_internal_on_mouse_wheel(deltaX, deltaY);
        } else if (!localInputState.mouseWheelErrorLogged) {
            console.error("[WebInput.js] Wasm export 'zig_internal_on_mouse_wheel' not found.");
            localInputState.mouseWheelErrorLogged = true;
        }
    });

    canvas.addEventListener('contextmenu', (event) => {
        event.preventDefault();
    });
}

function _setupKeyListeners() {
    window.addEventListener('keydown', (event) => {
        if (localInputState.wasmExports && localInputState.wasmExports.zig_internal_on_key_event) {
            localInputState.wasmExports.zig_internal_on_key_event(event.keyCode, true); 
        } else if (!localInputState.keyEventErrorLogged) {
            console.error("[WebInput.js] Wasm export 'zig_internal_on_key_event' not found (for keydown).");
            localInputState.keyEventErrorLogged = true;
        }
    });

    window.addEventListener('keyup', (event) => {
        if (localInputState.wasmExports && localInputState.wasmExports.zig_internal_on_key_event) {
            localInputState.wasmExports.zig_internal_on_key_event(event.keyCode, false); 
        } else if (!localInputState.keyEventErrorLogged) {
            console.error("[WebInput.js] Wasm export 'zig_internal_on_key_event' not found (for keyup).");
            localInputState.keyEventErrorLogged = true;
        }
    });
}

// If webinput.js were to provide functions for Zig to call (env_ functions),
// they would be defined here and exported as part of an object, e.g.:
// export const webInputNativeImports = {
//    env_example_input_func: () => { /* ... */ }
// };
// For now, it primarily exports initWebInputJs.