// example/web/main.js

import * as webGPU_module from './webgpu.js'; // Renamed to avoid conflict with a potential global
// Import WebInput module
import * as webInput from './webinput.js'; 

// Global state for the demo
const globalState = {
    wasmInstance: null,
    canvas: null,
    animationFrameId: null,
    lastTimestamp: 0,
    // webInput instance is now set by its setupJS function, not stored directly here initially by main.js
    // but can be accessed via activeModules.WebInput.instance if needed after setup.
};

// Configuration for active modules and their JS setup/dependencies
const activeModules = {
    "WebGPU":  {
        // nativeImports should point to the object containing the env_ functions
        nativeImports: webGPU_module.webGPUNativeImports, 
        setupJS: webGPU_module.initWebGPUJs // This is correct
    },
    "WebInput":{
        nativeImports: null,        
        setupJS: (wasmExports, wasmMemory) => { 
            if (!globalState.canvas) {
                console.error("[Main.js] Canvas not initialized before WebInput setup.");
                return null;
            }
            webInput.initWebInputJs(wasmExports, globalState.canvas); 
            console.log("[Main.js] WebInput setup complete via webInput.initWebInputJs.");
            return null; 
        }
    }
};

async function initWasm() {
    console.log("[Main.js] initWasm() called.");
    
    globalState.canvas = document.getElementById('zigCanvas'); // Corrected ID
    if (!globalState.canvas) {
        console.error("Canvas element with ID 'zigCanvas' not found.");
        return;
    }
    setupCanvas();

    const importObject = {
        env: {},
    };

    for (const moduleName in activeModules) {
        const moduleConfig = activeModules[moduleName];
        if (moduleConfig.nativeImports) {
            for (const key in moduleConfig.nativeImports) {
                if (typeof moduleConfig.nativeImports[key] === 'function' && 
                    Object.prototype.hasOwnProperty.call(moduleConfig.nativeImports, key)) {
                    // Critical: Ensure 'this' context is correct if methods rely on it
                    // Binding to the nativeImports object ensures its internal 'this' is preserved if necessary
                    importObject.env[key] = moduleConfig.nativeImports[key].bind(moduleConfig.nativeImports);
                }
            }
        }
    }
    
    try {
        const response = await fetch('app.wasm'); // Corrected path
        if (!response.ok) {
            throw new Error(`Failed to fetch app.wasm: ${response.status} ${response.statusText}`);
        }
        const buffer = await response.arrayBuffer();
        const { instance, module } = await WebAssembly.instantiate(buffer, importObject);
        
        globalState.wasmInstance = instance;
        const wasmExports = instance.exports;
        const wasmMemory = wasmExports.memory;

        console.log("[Main.js] Wasm module instantiated.");

        // Pass Wasm memory to webGPUNativeImports if it expects it (for error reporting, etc.)
        // This was a step in the previous version of webgpu.js that might still be relevant.
        if (webGPU_module.webGPUNativeImports && typeof webGPU_module.webGPUNativeImports === 'object') {
             webGPU_module.webGPUNativeImports.wasmMemory = wasmMemory;
        }

        for (const moduleName in activeModules) {
            const moduleConfig = activeModules[moduleName];
            if (moduleConfig.setupJS) {
                console.log(`[Main.js] Setting up ${moduleName}...`);
                moduleConfig.setupJS(wasmExports, wasmMemory); 
            }
        }
        
        if (wasmExports._start) {
            console.log("[Main.js] Calling Wasm module '_start' function...");
            wasmExports._start();
            console.log("[Main.js] WASM module '_start' function called.");
        } else {
            console.error("[Main.js] Wasm module does not export '_start'.");
            return;
        }

        if (!globalState.animationFrameId) {
            globalState.lastTimestamp = performance.now();
            globalState.animationFrameId = requestAnimationFrame(animationLoop);
            console.log("[Main.js] Animation loop started.");
        }

    } catch (e) {
        console.error("Error loading or instantiating Wasm module:", e);
    }
}

function animationLoop(timestamp) {
    if (!globalState.wasmInstance || !globalState.wasmInstance.exports.update_frame) {
        if (globalState.animationFrameId) { 
             globalState.animationFrameId = requestAnimationFrame(animationLoop);
        }
        return;
    }
    const deltaTime = timestamp - globalState.lastTimestamp;
    globalState.lastTimestamp = timestamp;
    globalState.wasmInstance.exports.update_frame(deltaTime);
    globalState.animationFrameId = requestAnimationFrame(animationLoop);
}

function setupCanvas() {
    if (!globalState.canvas) return;
    globalState.canvas.width = globalState.canvas.clientWidth;
    globalState.canvas.height = globalState.canvas.clientHeight;
    console.log(`[Main.js] Canvas resized to ${globalState.canvas.width}x${globalState.canvas.height}`);
}

window.addEventListener('DOMContentLoaded', () => {
    console.log("[Main.js] DOMContentLoaded event fired. Running initWasm().");
    initWasm();
});
window.addEventListener('resize', setupCanvas);

window.addEventListener('beforeunload', () => {
    if (globalState.wasmInstance && globalState.wasmInstance.exports._wasm_shutdown) {
        console.log("[Main.js] Calling _wasm_shutdown before unload...");
        globalState.wasmInstance.exports._wasm_shutdown();
    }
});
