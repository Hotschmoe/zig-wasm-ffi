// example/web/main.js

// Import all exports from the API-specific JS glue files.
// These files are copied from the zig-wasm-ffi dependency to the 'dist' 
// directory alongside this main.js and app.wasm by the build.zig script.
// import * as webaudio_glue from './webaudio.js';
import * as webinput_glue from './webinput.js';
// If you add "webgpu" to `used_web_apis` in example/build.zig, 
// you would also add: import * as webgpu_glue from './webgpu.js';

let wasmInstance = null; // To hold the Wasm instance for access by js_log_string and animation loop

async function initWasm() {
    console.log("[Main.js] initWasm() called."); // TEMP LOG
    const importObject = {
        env: {
            // Function for Zig to log strings to the browser console
            js_log_string: (messagePtr, messageLen) => {
                if (!wasmInstance) {
                    console.error("[Main.js] js_log_string called before Wasm instance is available."); // MODIFIED LOG
                    return;
                }
                try {
                    const memoryBuffer = wasmInstance.exports.memory.buffer;
                    const textDecoder = new TextDecoder('utf-8');
                    const messageBytes = new Uint8Array(memoryBuffer, messagePtr, messageLen);
                    const message = textDecoder.decode(messageBytes);
                    console.log("Zig:", message);
                } catch (e) {
                    console.error("[Main.js] Error in js_log_string:", e); // MODIFIED LOG
                }
            },
            // Spread all functions from the imported glue modules.
            // The Zig FFI declarations (e.g., pub extern "env" fn js_createAudioContext...)
            // must match the names of the functions exported by these JS modules.
            // ...webaudio_glue,
            ...webinput_glue,
            // ...webgpu_glue, // Add if webgpu is used
        }
    };

    try {
        // 'app.wasm' is expected to be in the same directory (dist/) as this main.js
        const response = await fetch('app.wasm');
        if (!response.ok) {
            throw new Error(`[Main.js] Failed to fetch app.wasm: ${response.status} ${response.statusText}`);
        }
        
        const { instance } = await WebAssembly.instantiateStreaming(response, importObject);
        wasmInstance = instance; // Store the instance
        console.log("[Main.js] Wasm module instantiated."); // TEMP LOG
        
        // Initialize the webinput system after Wasm is instantiated
        // Ensure you have a canvas element in your HTML, e.g., <canvas id="zigCanvas"></canvas>
        // Pass the Wasm instance's exports and the canvas ID (or element) to setupInputSystem.
        if (webinput_glue.setupInputSystem) {
            console.log("[Main.js] Calling setupInputSystem..."); // TEMP LOG
            webinput_glue.setupInputSystem(wasmInstance.exports, 'zigCanvas'); // ASSUMES canvas with id="zigCanvas"
            // console.log("[Main.js] WebInput system initialized by main.js."); // Covered by webinput.js log
        } else {
            console.error("[Main.js] setupInputSystem not found in webinput_glue. Ensure js/webinput.js exports it.");
        }

        // Call the exported '_start' function from the Zig WASM module
        if (wasmInstance.exports._start) {
            wasmInstance.exports._start();
            console.log("[Main.js] WASM module '_start' function called."); // MODIFIED LOG
        } else {
            console.error("[Main.js] WASM module does not export an '_start' function. Check Zig export."); // MODIFIED LOG
        }

        // Start the animation loop to call update_frame continuously
        function animationLoop() {
            if (wasmInstance && wasmInstance.exports.update_frame) {
                try {
                    wasmInstance.exports.update_frame();
                } catch (e) {
                    console.error("[Main.js] Error in Wasm update_frame:", e); // MODIFIED LOG
                    // Optionally, stop the loop if update_frame errors out consistently
                    // requestAnimationFrame = () => {}; // Stop the loop by no-oping rAF
                    return; 
                }
            }
            requestAnimationFrame(animationLoop);
        }
        requestAnimationFrame(animationLoop);
        console.log("[Main.js] Animation loop started for update_frame."); // MODIFIED LOG

    } catch (e) {
        console.error("[Main.js] Error loading or instantiating WASM:", e); // MODIFIED LOG
        // Provide a simple visual error indication on the page for easier debugging
        const errorParagraph = document.createElement('p');
        errorParagraph.textContent = `Failed to load WASM module: ${e.message}. Check the console for more details.`;
        errorParagraph.style.color = "red";
        document.body.prepend(errorParagraph);
    }
}

// Defer initWasm until the DOM is fully loaded
document.addEventListener('DOMContentLoaded', () => {
    console.log("[Main.js] DOMContentLoaded event fired. Running initWasm()."); // TEMP LOG
    initWasm();
});
