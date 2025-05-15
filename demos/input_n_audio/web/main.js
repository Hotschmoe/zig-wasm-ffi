// example/web/main.js

// Import all exports from the API-specific JS glue files.
// These files are copied from the zig-wasm-ffi dependency to the 'dist' 
// directory alongside this main.js and app.wasm by the build.zig script.
import * as webaudio_glue from './webaudio.js';
import * as webinput_glue from './webinput.js';
// If you add "webgpu" to `used_web_apis` in example/build.zig, 
// you would also add: import * as webgpu_glue from './webgpu.js';

let wasmInstance = null; // To hold the Wasm instance for access by js_log_string and animation loop
let canvasElement = null; // To hold the canvas element reference

function resizeCanvas() {
    if (canvasElement) {
        canvasElement.width = window.innerWidth;
        canvasElement.height = window.innerHeight;
        console.log(`[Main.js] Canvas resized to ${canvasElement.width}x${canvasElement.height}`);
        // Optional: Notify Zig about the resize if it needs to adapt (e.g., viewport, aspect ratio)
        // if (wasmInstance && wasmInstance.exports && wasmInstance.exports.zig_handle_resize) {
        //     wasmInstance.exports.zig_handle_resize(canvasElement.width, canvasElement.height);
        // }
    }
}

async function initWasm() {
    console.log("[Main.js] initWasm() called.");

    canvasElement = document.getElementById('zigCanvas');
    if (!canvasElement) {
        console.error("[Main.js] Canvas element 'zigCanvas' not found in the DOM!");
        // Display error on page as well
        const errorParagraph = document.createElement('p');
        errorParagraph.textContent = "Error: Canvas element 'zigCanvas' not found. Application cannot start.";
        errorParagraph.style.color = "red";
        document.body.prepend(errorParagraph);
        return; // Stop initialization if canvas is missing
    }
    // Initial resize
    resizeCanvas(); 

    const importObject = {
        env: {
            // Function for Zig to log strings to the browser console
            js_log_string: (messagePtr, messageLen) => {
                if (!wasmInstance || !wasmInstance.exports.memory) {
                    console.error("[Main.js] js_log_string: Wasm instance or memory not available.");
                    return;
                }
                try {
                    const memoryBuffer = wasmInstance.exports.memory.buffer;
                    const textDecoder = new TextDecoder('utf-8');
                    const messageBytes = new Uint8Array(memoryBuffer, messagePtr, messageLen);
                    const message = textDecoder.decode(messageBytes);
                    console.log("Zig:", message);
                } catch (e) {
                    console.error("[Main.js] Error in js_log_string:", e);
                }
            },
            // Spread all functions from the imported glue modules.
            // The Zig FFI declarations (e.g., pub extern "env" fn zig_internal_on_mouse_move...)
            // must match the names of the functions exported by these JS modules.
            ...webaudio_glue, // Example if webaudio was used
            ...webinput_glue,  // This makes setupInputSystem, etc. from webinput.js available if they were FFI imports
                               // However, setupInputSystem itself is called from JS, not imported by Zig FFI.
                               // The spread here is for functions webinput.js might export *to be called by Zig*,
                               // which in our current design for webinput is none (Zig exports to JS).
                               // The key is that zig_internal_... functions are part of wasmInstance.exports.
            // ...webgpu_glue, // Add if webgpu is used
        }
    };

    try {
        // 'app.wasm' is expected to be in the same directory (dist/) as this main.js
        const response = await fetch('app.wasm');
        if (!response.ok) {
            throw new Error(`[Main.js] Failed to fetch app.wasm: ${response.status} ${response.statusText}`);
        }
        
        const { instance, module } = await WebAssembly.instantiateStreaming(response, importObject);
        wasmInstance = instance; // Store the instance
        console.log("[Main.js] Wasm module instantiated.");
        
        // Initialize the webinput system after Wasm is instantiated and its exports are available.
        // The `webinput_glue` object contains `setupInputSystem` from our `js/webinput.js`.
        if (webinput_glue.setupInputSystem) {
            console.log("[Main.js] Calling webinput_glue.setupInputSystem...");
            webinput_glue.setupInputSystem(wasmInstance.exports, canvasElement); // Pass the element directly
        } else {
            console.error("[Main.js] setupInputSystem not found in webinput_glue. Ensure js/webinput.js (from zig-wasm-ffi) exports it and is correctly copied to dist.");
        }

        // Setup FFI glue for webaudio
        if (webaudio_glue && webaudio_glue.setupWebAudio) {
            console.log("[Main.js] Calling webaudio_glue.setupWebAudio...");
            webaudio_glue.setupWebAudio(wasmInstance);
        } else {
            console.error("[Main.js] webaudio_glue.setupWebAudio not found or webaudio_glue module not loaded. Audio will not work.");
        }

        // Call the exported '_start' function from the Zig WASM module
        if (wasmInstance.exports && wasmInstance.exports._start) {
            wasmInstance.exports._start();
            console.log("[Main.js] WASM module '_start' function called.");
        } else {
            console.error("[Main.js] WASM module does not export an '_start' function or exports object is missing. Check Zig export.");
        }

        window.addEventListener('resize', resizeCanvas);

        // Start the animation loop to call update_frame continuously
        function animationLoop() {
            if (wasmInstance && wasmInstance.exports && wasmInstance.exports.update_frame) {
                try {
                    wasmInstance.exports.update_frame();
                } catch (e) {
                    console.error("[Main.js] Error in Wasm update_frame:", e);
                    window.removeEventListener('resize', resizeCanvas); // Clean up listener
                    return; // Stop the loop on error
                }
            }
            requestAnimationFrame(animationLoop);
        }
        requestAnimationFrame(animationLoop);
        console.log("[Main.js] Animation loop started for update_frame.");

    } catch (e) {
        console.error("[Main.js] Error loading or instantiating WASM:", e);
        const errorParagraph = document.createElement('p');
        errorParagraph.textContent = `Failed to load WASM module: ${e.message}. Check the console for more details.`;
        errorParagraph.style.color = "red";
        document.body.prepend(errorParagraph);
        // Clean up resize listener if Wasm loading fails critically
        window.removeEventListener('resize', resizeCanvas);
    }
}

// Defer initWasm until the DOM is fully loaded
document.addEventListener('DOMContentLoaded', () => {
    console.log("[Main.js] DOMContentLoaded event fired. Running initWasm().");
    initWasm();
});
