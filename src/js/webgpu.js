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
        if (!entry) {
            // This can happen if Zig released the handle before the JS promise resolved/rejected.
            console.warn(`[webgpu.js] updatePromiseState called for an already released promise_id: ${promise_id}. Status: ${status}`);
            // If it was an error, ensure it's captured globally if not already.
            if (status === 'rejected' && !globalWebGPU.error) {
                globalWebGPU.error = valueOrError;
            }
            return;
        }
        entry.status = status;
        if (status === 'fulfilled') {
            entry.value = valueOrError;
            entry.error = null; // Clear any prior error if it was somehow set
        } else if (status === 'rejected') {
            entry.error = valueOrError;
            entry.value = null; // Clear any prior value
            globalWebGPU.error = valueOrError; // Also store globally for simpler error fetching
        }
    } else {
        console.error(`[webgpu.js] Invalid promise_id ${promise_id} for updatePromiseState`);
        // If it was an error, ensure it's captured globally if not already.
        if (status === 'rejected' && !globalWebGPU.error) {
            globalWebGPU.error = valueOrError;
        }
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
            const errorMsg = "navigator.gpu is not available.";
            globalWebGPU.error = errorMsg;
            console.error("[webgpu.js]", errorMsg);
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
            const errorMsg = `Error in requestAdapterAsync: ${e.message}`;
            globalWebGPU.error = errorMsg;
            console.error("[webgpu.js]", errorMsg);
            return 0; // Error creating promise
        }
    },

    // Request Device from Adapter
    // Takes adapter_handle, returns a promise_id
    env_wgpu_adapter_request_device_async_js: function(adapter_handle) {
        const adapter = globalWebGPU.adapters[adapter_handle];
        if (!adapter) {
            const errorMsg = "Invalid adapter handle for requestDevice.";
            globalWebGPU.error = errorMsg;
            console.error("[webgpu.js]", errorMsg);
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
            const errorMsg = `Error in adapterRequestDeviceAsync: ${e.message}`;
            globalWebGPU.error = errorMsg;
            console.error("[webgpu.js]", errorMsg);
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
        if (promise_id <= 0 || promise_id >= globalWebGPU.promises.length || !globalWebGPU.promises[promise_id]) {
             // If promise_id is invalid or entry is null (already released)
             // Avoid setting globalWebGPU.error here as it might overwrite a more relevant error
             // console.warn(`[webgpu.js] Polling invalid or released promise_id: ${promise_id}`);
             return -1; // Indicate error or invalid state for polling
        }
        const promise_entry = globalWebGPU.promises[promise_id];

        // This check is theoretically redundant due to the one above, but kept for safety.
        if (!promise_entry) { 
            // console.error("[webgpu.js] Null promise entry during poll, id:", promise_id); // Should be caught above
            return -1; 
        }

        if (promise_entry.status === 'fulfilled') return 1;
        if (promise_entry.status === 'rejected') return -1;
        return 0; // pending
    },

    // Get Adapter from a resolved promise
    // Takes promise_id, returns adapter_handle or 0 on error/not ready.
    env_wgpu_get_adapter_from_promise_js: function(promise_id) {
        if (promise_id <= 0 || promise_id >= globalWebGPU.promises.length || !globalWebGPU.promises[promise_id]) return 0;
        const result = globalWebGPU.promises[promise_id];
        if (result && result.status === 'fulfilled') {
            return result.value; 
        }
        // If rejected, updatePromiseState would have set globalWebGPU.error.
        // If pending, or other invalid state, return 0.
        return 0; 
    },

    // Get Device from a resolved promise
    // Takes promise_id, returns device_handle or 0 on error/not ready.
    env_wgpu_get_device_from_promise_js: function(promise_id) {
        if (promise_id <= 0 || promise_id >= globalWebGPU.promises.length || !globalWebGPU.promises[promise_id]) return 0;
        const result = globalWebGPU.promises[promise_id];
        if (result && result.status === 'fulfilled') {
            return result.value; 
        }
        return 0; 
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
            const errorMsg = `Error in deviceGetQueue: ${e.message}`;
            globalWebGPU.error = errorMsg;
            console.error("[webgpu.js]", errorMsg);
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
                const tempError = "Wasm memory not available to JS for error reporting.";
                console.error("[webgpu.js]", tempError);
                const encoder = new TextEncoder();
                lastErrorBytes = encoder.encode(tempError); 
                // globalWebGPU.error should not be cleared here, as Zig couldn't get it.
                return;
            }
            const wasmMemoryArray = new Uint8Array(memory.buffer, buffer_ptr, buffer_len);
            const lenToCopy = Math.min(lastErrorBytes.length, buffer_len);
            for (let i = 0; i < lenToCopy; i++) {
                wasmMemoryArray[i] = lastErrorBytes[i];
            }
            // Only clear the error if Zig could copy all of it.
            // Otherwise, Zig might need to call again with a larger buffer or handle partial error.
            if (lenToCopy === lastErrorBytes.length) {
                 lastErrorBytes = null;
                 globalWebGPU.error = null; 
            }
        }
    },

    // Function to release JS-side objects to prevent memory leaks
    env_wgpu_release_handle_js: function(type_id, handle) {
        // type_id: 1 for promise (placeholder object), 2 for adapter, 3 for device, 4 for queue
        switch (type_id) {
            case 1: 
                if (handle > 0 && handle < globalWebGPU.promises.length) {
                    // console.log(`[webgpu.js] Releasing promise handle: ${handle}`);
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
