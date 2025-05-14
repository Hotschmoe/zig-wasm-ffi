// example/web/main.js

// Import all exports from the API-specific JS glue files.
// These files are copied from the zig-wasm-ffi dependency to the 'dist' 
// directory alongside this main.js and app.wasm by the build.zig script.
import * as webaudio_glue from './webaudio.js';
import * as webinput_glue from './webinput.js';
// If you add "webgpu" to `used_web_apis` in example/build.zig, 
// you would also add: import * as webgpu_glue from './webgpu.js';

async function initWasm() {
    const importObject = {
        env: {
            // Spread all functions from the imported glue modules.
            // The Zig FFI declarations (e.g., pub extern "env" fn js_createAudioContext...)
            // must match the names of the functions exported by these JS modules.
            ...webaudio_glue,
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
        
        // Call the exported 'main' function from the Zig WASM module
        if (instance.exports.main) {
            instance.exports.main();
            console.log("WASM module initialized and main function called.");
        } else {
            console.error("WASM module does not export a 'main' function.");
        }
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
