// example/web/main.js

// 1. Import all POTENTIAL glue modules.
import * as webinput from './webinput.js'; 
// import * as webaudio from './webaudio.js'; // Example: User would uncomment to use
import { webGPUNativeImports } from './webgpu.js';   // Import the specific object

let wasmInstance = null;
let canvasElement = null;

// --- Configuration for Used FFI Modules ---
const activeModules = [
    {
        name: "WebInput",
        glue: webinput,
        providesToZig: false, // webinput.js calls Zig exports, doesn't provide env_ funcs for Zig to call
        jsSetupFunction: webinput.setupInputSystem,
        jsSetupArgs: (instance, canvasEl) => [instance.exports, canvasEl]
    },
    // {
    //     name: "WebAudio",
    //     glue: webaudio, // Assuming 'webaudio' is the imported module
    //     providesToZig: true, 
    //     jsSetupFunction: webaudio.setupWebAudio,
    //     jsSetupArgs: (instance, _canvasEl) => [instance]
    // },
    {
        name: "WebGPU",
        glue: webGPUNativeImports, // Use the imported object directly
        providesToZig: true, // True as webGPUNativeImports contains env_ functions
        // jsSetupFunction: webgpu.setupWebGPU, // Removed, FFI functions are called from Zig
        // jsSetupArgs: (instance, canvasEl) => [instance, canvasEl] 
    }
];

function getCanvas() {
    canvasElement = document.getElementById('zigCanvas');
    if (!canvasElement) {
        console.error("[Main.js] Canvas element 'zigCanvas' not found in the DOM!");
        const errorParagraph = document.createElement('p');
        errorParagraph.textContent = "Error: Canvas element 'zigCanvas' not found. Application cannot start.";
        errorParagraph.style.color = "red";
        document.body.prepend(errorParagraph);
        return null;
    }
    return canvasElement;
}

function resizeCanvas() {
    if (canvasElement) {
        canvasElement.width = window.innerWidth;
        canvasElement.height = window.innerHeight;
        console.log(`[Main.js] Canvas resized to ${canvasElement.width}x${canvasElement.height}`);
        // Optional: Notify Zig about the resize if it needs to adapt
        // if (wasmInstance && wasmInstance.exports && wasmInstance.exports.zig_handle_resize) {
        //     wasmInstance.exports.zig_handle_resize(canvasElement.width, canvasElement.height);
        // }
    }
}

async function initWasm() {
    console.log("[Main.js] initWasm() called.");

    if (!getCanvas()) return;
    resizeCanvas(); 

    const envImports = {
        // js_log_string is now part of webGPUNativeImports and will be added by the loop below
    };

    for (const mod of activeModules) {
        if (mod.providesToZig && mod.glue) {
            for (const key in mod.glue) {
                if (Object.prototype.hasOwnProperty.call(mod.glue, key) && (key.startsWith("env_") || key === "js_log_string")) { // Include js_log_string if defined in glue
                    if (typeof mod.glue[key] === 'function') {
                        envImports[key] = mod.glue[key].bind(mod.glue); // Bind `this` to mod.glue
                    } else {
                        // If it's not a function (e.g., wasmMemory itself), don't try to bind it.
                        // Though wasmMemory is not an env_ function, so this path shouldn't be taken for it.
                        envImports[key] = mod.glue[key];
                    }
                }
            }
        }
    }
    const importObject = { env: envImports };

    try {
        const response = await fetch('app.wasm');
        if (!response.ok) {
            throw new Error(`[Main.js] Failed to fetch app.wasm: ${response.status} ${response.statusText}`);
        }
        
        const { instance } = await WebAssembly.instantiateStreaming(response, importObject);
        wasmInstance = instance;
        console.log("[Main.js] Wasm module instantiated.");

        // CRITICAL STEP: Set the wasmMemory for the JS glue functions that need it
        // This is done on the original imported object, which the bound functions will reference.
        if (webGPUNativeImports.wasmMemory !== undefined) { // Check if the property exists
            webGPUNativeImports.wasmMemory = wasmInstance.exports.memory;
            console.log("[Main.js] Wasm memory assigned to webGPUNativeImports.");
        }
        
        for (const mod of activeModules) {
            if (mod.jsSetupFunction && typeof mod.jsSetupFunction === 'function') {
                console.log(`[Main.js] Setting up ${mod.name}...`);
                const args = mod.jsSetupArgs(wasmInstance, canvasElement);
                mod.jsSetupFunction(...args);
            } else if (mod.glue && mod.providesToZig && !mod.jsSetupFunction) {
                 console.log(`[Main.js] Module ${mod.name} is active (provides to Zig) but has no specific JS setup function defined in activeModules array.`);
            } else if (mod.glue && !mod.jsSetupFunction && !mod.providesToZig && mod.name === "WebInput") {
                 // This case is fine for WebInput if its setup is primary and it doesn't provide env_ funcs
                 // But the setup call itself is conditional on jsSetupFunction, so this log might be redundant
            }
        }
        
        if (wasmInstance.exports && wasmInstance.exports._start) {
            wasmInstance.exports._start();
            console.log("[Main.js] WASM module '_start' function called.");
        } else if (wasmInstance.exports && wasmInstance.exports.main) { // Fallback to 'main' if '_start' not found
            wasmInstance.exports.main();
            console.log("[Main.js] WASM module 'main' function called.");
        } else {
            console.error("[Main.js] WASM module does not export an '_start' or 'main' function or exports object is missing.");
        }

        window.addEventListener('resize', resizeCanvas);
        
        let lastTime = 0;
        function animationLoop(currentTime) {
            if (!lastTime) lastTime = currentTime;
            const deltaTime = currentTime - lastTime;
            lastTime = currentTime;

            if (wasmInstance && wasmInstance.exports && wasmInstance.exports.update_frame) {
                try {
                    wasmInstance.exports.update_frame(deltaTime); // Pass actual delta time
                } catch (e) {
                    console.error("[Main.js] Error in Wasm update_frame:", e);
                    window.removeEventListener('resize', resizeCanvas); 
                    return; 
                }
            }
            requestAnimationFrame(animationLoop);
        }
        requestAnimationFrame(animationLoop);
        console.log("[Main.js] Animation loop started.");

    } catch (e) {
        console.error("[Main.js] Error loading or instantiating WASM:", e);
        const errorParagraph = document.createElement('p');
        errorParagraph.textContent = `Failed to load WASM module: ${e.message}. Check console.`;
        errorParagraph.style.color = "red";
        document.body.prepend(errorParagraph);
        window.removeEventListener('resize', resizeCanvas);
    }
}

document.addEventListener('DOMContentLoaded', () => {
    console.log("[Main.js] DOMContentLoaded event fired. Running initWasm().");
    initWasm();
});
