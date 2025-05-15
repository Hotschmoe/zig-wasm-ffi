// zig-wasm-ffi/src/js/webgpu.js

const globalWebGPU = {
    promises: [null], // Index 0 is unused, promise IDs are > 0
    adapters: [null], // Index 0 is unused, adapter handles are > 0
    devices: [null],  // Index 0 is unused, device handles are > 0
    queues: [null],   // Index 0 is unused, queue handles are > 0
    error: null,      // To store the last error message
};

function storePromisePlaceholder() {
    const id = globalWebGPU.promises.length;
    globalWebGPU.promises.push({ status: 'pending', value: null, error: null });
    return id;
}

function updatePromiseState(promise_id, status, valueOrError) {
    if (promise_id > 0 && promise_id < globalWebGPU.promises.length) {
        const entry = globalWebGPU.promises[promise_id];
        entry.status = status;
        if (status === 'fulfilled') {
            entry.value = valueOrError;
        } else if (status === 'rejected') {
            entry.error = valueOrError;
            globalWebGPU.error = valueOrError; // Also store globally for simpler error fetching for now
        }
    } else {
        console.error(`[webgpu.js] Invalid promise_id ${promise_id} for updatePromiseState`);
    }
}

function storeAdapter(adapter) {
    if (!adapter) return 0;
    const handle = globalWebGPU.adapters.length;
    globalWebGPU.adapters.push(adapter);
    return handle;
}

function storeDevice(device) {
    if (!device) return 0;
    const handle = globalWebGPU.devices.length;
    globalWebGPU.devices.push(device);
    return handle;
}

function storeQueue(queue) {
    if (!queue) return 0;
    const handle = globalWebGPU.queues.length;
    globalWebGPU.queues.push(queue);
    return handle;
}

// For env_wgpu_get_last_error_msg_ptr_js and related functions
let lastErrorBytes = null;

// --- Public FFI Functions (callable from Zig) ---
// These will be part of the env object provided to Wasm

export const webGPUNativeImports = {
    wasmMemory: null, // This will be set by main.js after Wasm instantiation

    // Request Adapter
    // Returns a promise_id
    env_wgpu_request_adapter_async_js: function() {
        if (!navigator.gpu) {
            globalWebGPU.error = "navigator.gpu is not available.";
            console.error("[webgpu.js]", globalWebGPU.error);
            return 0; // 0 indicates immediate error, no promise created
        }
        try {
            const promise_id = storePromisePlaceholder();
            navigator.gpu.requestAdapter().then(adapter => {
                updatePromiseState(promise_id, 'fulfilled', storeAdapter(adapter));
            }).catch(e => {
                const errorMsg = `Failed to request adapter: ${e.message}`;
                console.error("[webgpu.js]", errorMsg);
                updatePromiseState(promise_id, 'rejected', errorMsg);
            });
            return promise_id;
        } catch (e) {
            globalWebGPU.error = `Error in requestAdapterAsync: ${e.message}`;
            console.error("[webgpu.js]", globalWebGPU.error);
            // If a promise_id was created before exception, mark it as rejected
            // This path is less likely if storePromisePlaceholder is simple.
            return 0; // Error creating promise
        }
    },

    // Request Device from Adapter
    // Takes adapter_handle, returns a promise_id
    env_wgpu_adapter_request_device_async_js: function(adapter_handle) {
        const adapter = globalWebGPU.adapters[adapter_handle];
        if (!adapter) {
            globalWebGPU.error = "Invalid adapter handle for requestDevice.";
            console.error("[webgpu.js]", globalWebGPU.error);
            return 0;
        }
        try {
            const promise_id = storePromisePlaceholder();
            adapter.requestDevice().then(device => {
                updatePromiseState(promise_id, 'fulfilled', storeDevice(device));
            }).catch(e => {
                const errorMsg = `Failed to request device: ${e.message}`;
                console.error("[webgpu.js]", errorMsg);
                updatePromiseState(promise_id, 'rejected', errorMsg);
            });
            return promise_id;
        } catch (e) {
            globalWebGPU.error = `Error in adapterRequestDeviceAsync: ${e.message}`;
            console.error("[webgpu.js]", globalWebGPU.error);
            return 0;
        }
    },

    // Poll Promise Status
    // Takes promise_id.
    // Returns:
    //   0: pending
    //   1: fulfilled (result is ready)
    //  -1: rejected (error occurred)
    env_wgpu_poll_promise_js: function(promise_id) {
        if (promise_id <= 0 || promise_id >= globalWebGPU.promises.length) {
             globalWebGPU.error = `Invalid promise_id for polling: ${promise_id}`;
             console.error("[webgpu.js]", globalWebGPU.error);
             return -1; // Error
        }
        const promise_entry = globalWebGPU.promises[promise_id];

        if (!promise_entry) { // Should not happen if id is valid
            globalWebGPU.error = `No promise entry found for promise_id: ${promise_id}`;
            console.error("[webgpu.js]", globalWebGPU.error);
            return -1; // Error
        }

        if (promise_entry.status === 'fulfilled') return 1;
        if (promise_entry.status === 'rejected') return -1;
        return 0; // pending
    },

    // Get Adapter from a resolved promise
    // Takes promise_id, returns adapter_handle or 0 on error/not ready.
    env_wgpu_get_adapter_from_promise_js: function(promise_id) {
        if (promise_id <= 0 || promise_id >= globalWebGPU.promises.length) return 0;
        const result = globalWebGPU.promises[promise_id];
        if (result && result.status === 'fulfilled') {
            return result.value; // This is the adapter_handle
        }
        // Error message is already set in globalWebGPU.error by updatePromiseState if rejected
        return 0; // Not ready, or error
    },

    // Get Device from a resolved promise
    // Takes promise_id, returns device_handle or 0 on error/not ready.
    env_wgpu_get_device_from_promise_js: function(promise_id) {
        if (promise_id <= 0 || promise_id >= globalWebGPU.promises.length) return 0;
        const result = globalWebGPU.promises[promise_id];
        if (result && result.status === 'fulfilled') {
            return result.value; // This is the device_handle
        }
        return 0; // Not ready, or error
    },

    // Get Device Queue
    // Takes device_handle, returns queue_handle
    env_wgpu_device_get_queue_js: function(device_handle) {
        const device = globalWebGPU.devices[device_handle];
        if (!device) {
            globalWebGPU.error = "Invalid device handle for getQueue.";
            console.error("[webgpu.js]", globalWebGPU.error);
            return 0;
        }
        try {
            const queue = device.queue;
            return storeQueue(queue);
        } catch (e) {
            globalWebGPU.error = `Error in deviceGetQueue: ${e.message}`;
            console.error("[webgpu.js]", globalWebGPU.error);
            return 0;
        }
    },

    // Get the last error message pointer and length for Zig
    env_wgpu_get_last_error_msg_ptr_js: function() {
        if (globalWebGPU.error) {
            const encoder = new TextEncoder();
            lastErrorBytes = encoder.encode(globalWebGPU.error);
            return 1; 
        }
        lastErrorBytes = null;
        return 0; 
    },

    env_wgpu_get_last_error_msg_len_js: function() {
        if (lastErrorBytes) {
            return lastErrorBytes.length;
        }
        return 0;
    },

    env_wgpu_copy_last_error_msg_js: function(buffer_ptr, buffer_len) {
        if (lastErrorBytes && buffer_ptr && buffer_len > 0) {
            const memory = this.wasmMemory;
            if (!memory) {
                console.error("[webgpu.js] Wasm memory not available for copy_last_error_msg.");
                const tempError = "Wasm memory not available to JS for error reporting.";
                const encoder = new TextEncoder();
                lastErrorBytes = encoder.encode(tempError); 
                return;
            }
            const wasmMemoryArray = new Uint8Array(memory.buffer, buffer_ptr, buffer_len);
            const lenToCopy = Math.min(lastErrorBytes.length, buffer_len);
            for (let i = 0; i < lenToCopy; i++) {
                wasmMemoryArray[i] = lastErrorBytes[i];
            }
            lastErrorBytes = null;
            globalWebGPU.error = null; 
        }
    },

    // Function to release JS-side objects to prevent memory leaks
    env_wgpu_release_handle_js: function(type_id, handle) {
        // type_id: 1 for promise (placeholder object), 2 for adapter, 3 for device, 4 for queue
        switch (type_id) {
            case 1: 
                if (handle > 0 && handle < globalWebGPU.promises.length) {
                    globalWebGPU.promises[handle] = null; // Clear the placeholder
                }
                break;
            case 2: if (handle > 0 && handle < globalWebGPU.adapters.length) globalWebGPU.adapters[handle] = null; break;
            case 3: if (handle > 0 && handle < globalWebGPU.devices.length) globalWebGPU.devices[handle] = null; break;
            case 4: if (handle > 0 && handle < globalWebGPU.queues.length) globalWebGPU.queues[handle] = null; break;
            default: console.warn(`[webgpu.js] Unknown type_id for release_handle: ${type_id}`);
        }
    },

    // Logging function for Zig
    js_log_string: function(message_ptr, message_len) {
        if (!this.wasmMemory) {
            console.error("[webgpu.js] Wasm memory not available for js_log_string. Message Ptr:", message_ptr, "Len:", message_len);
            if(message_ptr && message_len) console.log("[Zig Wasm] (memory unavailable) Tried to log message of length:", message_len);
            return;
        }
        try {
            const memory = new Uint8Array(this.wasmMemory.buffer);
            const messageBytes = memory.subarray(message_ptr, message_ptr + message_len);
            const message = new TextDecoder('utf-8').decode(messageBytes);
            console.log("[Zig Wasm]", message);
        } catch (e) {
            console.error("[webgpu.js] Error in js_log_string:", e, "Message Ptr:", message_ptr, "Len:", message_len);
        }
    }
};
