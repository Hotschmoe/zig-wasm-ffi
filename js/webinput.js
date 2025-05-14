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
        console.error("[WebInput.js] Wasm exports not provided to setupInputSystem.");
        return;
    }
    wasmExports = instanceExports;

    if (typeof canvasElementOrId === 'string') {
        canvas = document.getElementById(canvasElementOrId);
    } else {
        canvas = canvasElementOrId;
    }

    if (!canvas) {
        console.warn("[WebInput.js] Canvas element is NULL after setup. Mouse input will not be available. ID used was:", canvasElementOrId);
    }

    _setupMouseListeners();
    _setupKeyListeners();

    console.log("[WebInput.js] System initialized for mouse and keyboard.");
}

// --- Event Listener Setup ---

function _setupMouseListeners() {
    if (!canvas) {
        console.warn("[WebInput.js TEMP] _setupMouseListeners: No canvas object, skipping mouse listeners.");
        return;
    }
    console.log("[WebInput.js TEMP] _setupMouseListeners: Valid canvas found. Attaching mouse listeners...");

    canvas.addEventListener('mousemove', (event) => {
        if (wasmExports && wasmExports.zig_internal_on_mouse_move) {
            const rect = canvas.getBoundingClientRect();
            wasmExports.zig_internal_on_mouse_move(event.clientX - rect.left, event.clientY - rect.top);
        } else {
            if (!this.mouseMoveErrorLogged) {
                console.error("[WebInput.js TEMP] zig_internal_on_mouse_move NOT available or wasmExports error. Exports:", wasmExports);
                this.mouseMoveErrorLogged = true;
            }
        }
    });

    console.log("[WebInput.js TEMP] Attaching mousedown listener (simplified)...");
    canvas.addEventListener('mousedown', (event) => {
        console.log("[WebInput.js TEMP] SIMPLIFIED JS mousedown CALLBACK FIRED! Button:", event.button);
    });

    canvas.addEventListener('mouseup', (event) => {
        console.log("[WebInput.js TEMP] JS mouseup. Button:", event.button);
        if (wasmExports && wasmExports.zig_internal_on_mouse_button) {
            const rect = canvas.getBoundingClientRect();
            wasmExports.zig_internal_on_mouse_button(event.button, false, event.clientX - rect.left, event.clientY - rect.top);
        } else {
            if (!this.mouseUpErrorLogged) {
                console.error("[WebInput.js TEMP] zig_internal_on_mouse_button (mouseup) NOT available or wasmExports error. Exports:", wasmExports);
                this.mouseUpErrorLogged = true;
            }
        }
    });

    canvas.addEventListener('wheel', (event) => {
        console.log("[WebInput.js TEMP] JS wheel. DeltaY:", event.deltaY);
        if (wasmExports && wasmExports.zig_internal_on_mouse_wheel) {
            event.preventDefault();
            let deltaX = event.deltaX;
            let deltaY = event.deltaY;
            if (event.deltaMode === 1) { deltaX *= 16; deltaY *= 16;} 
            else if (event.deltaMode === 2) { deltaX *= (canvas.width || window.innerWidth) * 0.8; deltaY *= (canvas.height || window.innerHeight) * 0.8; }
            wasmExports.zig_internal_on_mouse_wheel(deltaX, deltaY);
        } else {
            if (!this.mouseWheelErrorLogged) {
                console.error("[WebInput.js TEMP] zig_internal_on_mouse_wheel NOT available or wasmExports error. Exports:", wasmExports);
                this.mouseWheelErrorLogged = true;
            }
        }
    });
    console.log("[WebInput.js TEMP] All mouse listeners attached (or attempted). BoundingRect:", canvas.getBoundingClientRect());
}

function _setupKeyListeners() {
    window.addEventListener('keydown', (event) => {
        if (wasmExports && wasmExports.zig_internal_on_key_event) {
            wasmExports.zig_internal_on_key_event(event.keyCode, true);
        } else {
            if (!this.keyDownErrorLogged) {
                console.error("[WebInput.js TEMP] zig_internal_on_key_event NOT available or wasmExports error. Exports:", wasmExports);
                this.keyDownErrorLogged = true;
            }
        }
    });

    window.addEventListener('keyup', (event) => {
        if (wasmExports && wasmExports.zig_internal_on_key_event) {
            wasmExports.zig_internal_on_key_event(event.keyCode, false);
        } else {
            if (!this.keyUpErrorLogged) {
                console.error("[WebInput.js TEMP] zig_internal_on_key_event (keyup) NOT available or wasmExports error. Exports:", wasmExports);
                this.keyUpErrorLogged = true;
            }
        }
    });
}

// Gamepad related code (constants, cache, FFI functions) has been removed.
// For future gamepad integration, the FFI functions (platform_poll_gamepads, etc.)
// would be implemented here.