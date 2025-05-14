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
    const importObject = {
        env: {
            // Function for Zig to log strings to the browser console
            js_log_string: (messagePtr, messageLen) => {
                if (!wasmInstance) {
                    console.error("js_log_string called before Wasm instance is available.");
                    return;
                }
                try {
                    const memoryBuffer = wasmInstance.exports.memory.buffer;
                    const textDecoder = new TextDecoder('utf-8');
                    const messageBytes = new Uint8Array(memoryBuffer, messagePtr, messageLen);
                    const message = textDecoder.decode(messageBytes);
                    console.log("Zig:", message);
                } catch (e) {
                    console.error("Error in js_log_string:", e);
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
            throw new Error(`Failed to fetch app.wasm: ${response.status} ${response.statusText}`);
        }
        
        const { instance } = await WebAssembly.instantiateStreaming(response, importObject);
        wasmInstance = instance; // Store the instance
        
        // Initialize the webinput system after Wasm is instantiated
        // Ensure you have a canvas element in your HTML, e.g., <canvas id="zigCanvas"></canvas>
        // Pass the Wasm instance's exports and the canvas ID (or element) to setupInputSystem.
        if (webinput_glue.setupInputSystem) {
            webinput_glue.setupInputSystem(wasmInstance.exports, 'zigCanvas'); // ASSUMES canvas with id="zigCanvas"
            console.log("WebInput system initialized.");
        } else {
            console.error("setupInputSystem not found in webinput_glue. Ensure js/webinput.js exports it.");
        }

        // Call the exported '_start' function from the Zig WASM module
        if (wasmInstance.exports._start) {
            wasmInstance.exports._start();
            console.log("WASM module '_start' function called.");
        } else {
            console.error("WASM module does not export an '_start' function. Check Zig export.");
        }

        // Start the animation loop to call update_frame continuously
        function animationLoop() {
            if (wasmInstance && wasmInstance.exports.update_frame) {
                try {
                    wasmInstance.exports.update_frame();
                } catch (e) {
                    console.error("Error in Wasm update_frame:", e);
                    // Optionally, stop the loop if update_frame errors out consistently
                    // requestAnimationFrame = () => {}; // Stop the loop by no-oping rAF
                    return; 
                }
            }
            requestAnimationFrame(animationLoop);
        }
        requestAnimationFrame(animationLoop);
        console.log("Animation loop started for update_frame.");

    } catch (e) {
        console.error("Error loading or instantiating WASM:", e);
        // Provide a simple visual error indication on the page for easier debugging
        const errorParagraph = document.createElement('p');
        errorParagraph.textContent = `Failed to load WASM module: ${e.message}. Check the console for more details.`;
        errorParagraph.style.color = "red";
        document.body.prepend(errorParagraph);
    }
}

// Run the WASM initialization
initWasm();
