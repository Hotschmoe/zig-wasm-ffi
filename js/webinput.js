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
    // console.log("[WebInput.js TEMP] setupInputSystem called. Exports:", instanceExports); // TEMP LOG
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
        console.warn("[WebInput.js] Canvas element not found or provided (", canvasElementOrId, "). Mouse input will not be available."); // MODIFIED LOG
    }

    _setupMouseListeners();
    _setupKeyListeners();

    console.log("[WebInput.js] System initialized for mouse and keyboard.");
}

// --- Event Listener Setup ---

function _setupMouseListeners() {
    if (!canvas) {
        // console.log("[WebInput.js TEMP] _setupMouseListeners: No canvas, skipping mouse listeners."); // TEMP LOG
        return;
    }
    // console.log("[WebInput.js TEMP] _setupMouseListeners: Setting up mouse listeners for canvas:", canvas); // TEMP LOG

    canvas.addEventListener('mousemove', (event) => {
        console.log("[WebInput.js TEMP] JS mousemove. ClientX:", event.clientX, "ClientY:", event.clientY); // TEMP LOG
        if (wasmExports && wasmExports.zig_internal_on_mouse_move) {
            // console.log("[WebInput.js TEMP] zig_internal_on_mouse_move IS available. Calling."); // TEMP LOG
            const rect = canvas.getBoundingClientRect();
            wasmExports.zig_internal_on_mouse_move(event.clientX - rect.left, event.clientY - rect.top);
        } else {
            console.error("[WebInput.js TEMP] zig_internal_on_mouse_move NOT available or wasmExports error. Exports:", wasmExports); // TEMP LOG
        }
    });

    canvas.addEventListener('mousedown', (event) => {
        console.log("[WebInput.js TEMP] JS mousedown. Button:", event.button); // TEMP LOG
        if (wasmExports && wasmExports.zig_internal_on_mouse_button) {
            // console.log("[WebInput.js TEMP] zig_internal_on_mouse_button IS available. Calling."); // TEMP LOG
            const rect = canvas.getBoundingClientRect();
            wasmExports.zig_internal_on_mouse_button(event.button, true, event.clientX - rect.left, event.clientY - rect.top);
        } else {
            console.error("[WebInput.js TEMP] zig_internal_on_mouse_button NOT available or wasmExports error. Exports:", wasmExports); // TEMP LOG
        }
    });

    canvas.addEventListener('mouseup', (event) => {
        console.log("[WebInput.js TEMP] JS mouseup. Button:", event.button); // TEMP LOG
        if (wasmExports && wasmExports.zig_internal_on_mouse_button) {
            // console.log("[WebInput.js TEMP] zig_internal_on_mouse_button (mouseup) IS available. Calling."); // TEMP LOG
            const rect = canvas.getBoundingClientRect();
            wasmExports.zig_internal_on_mouse_button(event.button, false, event.clientX - rect.left, event.clientY - rect.top);
        } else {
            console.error("[WebInput.js TEMP] zig_internal_on_mouse_button (mouseup) NOT available or wasmExports error. Exports:", wasmExports); // TEMP LOG
        }
    });

    canvas.addEventListener('wheel', (event) => {
        console.log("[WebInput.js TEMP] JS wheel. DeltaY:", event.deltaY); // TEMP LOG
        if (wasmExports && wasmExports.zig_internal_on_mouse_wheel) {
            // console.log("[WebInput.js TEMP] zig_internal_on_mouse_wheel IS available. Calling."); // TEMP LOG
            event.preventDefault();
            let deltaX = event.deltaX;
            let deltaY = event.deltaY;
            if (event.deltaMode === 1) { deltaX *= 16; deltaY *= 16;} 
            else if (event.deltaMode === 2) { deltaX *= (canvas.width || window.innerWidth) * 0.8; deltaY *= (canvas.height || window.innerHeight) * 0.8; }
            wasmExports.zig_internal_on_mouse_wheel(deltaX, deltaY);
        } else {
            console.error("[WebInput.js TEMP] zig_internal_on_mouse_wheel NOT available or wasmExports error. Exports:", wasmExports); // TEMP LOG
        }
    });

    // Optional: Prevent context menu on right-click if desired for the canvas
    // canvas.addEventListener('contextmenu', event => event.preventDefault());
}

function _setupKeyListeners() {
    // console.log("[WebInput.js TEMP] _setupKeyListeners: Setting up key listeners for window."); // TEMP LOG
    window.addEventListener('keydown', (event) => {
        console.log("[WebInput.js TEMP] JS keydown. KeyCode:", event.keyCode, "Code:", event.code); // TEMP LOG
        if (wasmExports && wasmExports.zig_internal_on_key_event) {
            // console.log("[WebInput.js TEMP] zig_internal_on_key_event IS available. Calling."); // TEMP LOG
            wasmExports.zig_internal_on_key_event(event.keyCode, true);
            // To prevent default browser actions for certain keys (e.g., space, arrows scrolling the page)
            // you might add: if (isAppKey(event.keyCode)) { event.preventDefault(); }
            // where isAppKey is a helper to check if the key is handled by your app.
        } else {
            console.error("[WebInput.js TEMP] zig_internal_on_key_event NOT available or wasmExports error. Exports:", wasmExports); // TEMP LOG
        }
    });

    window.addEventListener('keyup', (event) => {
        console.log("[WebInput.js TEMP] JS keyup. KeyCode:", event.keyCode, "Code:", event.code); // TEMP LOG
        if (wasmExports && wasmExports.zig_internal_on_key_event) {
            // console.log("[WebInput.js TEMP] zig_internal_on_key_event (keyup) IS available. Calling."); // TEMP LOG
            wasmExports.zig_internal_on_key_event(event.keyCode, false);
        } else {
            console.error("[WebInput.js TEMP] zig_internal_on_key_event (keyup) NOT available or wasmExports error. Exports:", wasmExports); // TEMP LOG
        }
    });
}

// Gamepad related code (constants, cache, FFI functions) has been removed.
// For future gamepad integration, the FFI functions (platform_poll_gamepads, etc.)
// would be implemented here.