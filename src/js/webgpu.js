// zig-wasm-ffi/src/js/webgpu.js

const globalWebGPU = {
    promises: [null], // Index 0 is unused, promise IDs are > 0
    adapters: [null], // Index 0 is unused, adapter handles are > 0
    devices: [null],  // Index 0 is unused, device handles are > 0
    queues: [null],   // Index 0 is unused, queue handles are > 0
    error: null,      // To store the last error message
};

function storePromise(promise) {
    const id = globalWebGPU.promises.length;
    globalWebGPU.promises.push(promise);
    return id;
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

// --- Public FFI Functions (callable from Zig) ---

// Request Adapter
// Returns a promise_id
export function env_wgpu_request_adapter_async() {
    if (!navigator.gpu) {
        globalWebGPU.error = "navigator.gpu is not available.";
        console.error("[webgpu.js]", globalWebGPU.error);
        return 0; // 0 indicates immediate error, no promise created
    }
    try {
        const promise = navigator.gpu.requestAdapter().then(adapter => {
            return { status: 'fulfilled', value: storeAdapter(adapter) };
        }).catch(e => {
            globalWebGPU.error = `Failed to request adapter: ${e.message}`;
            console.error("[webgpu.js]", globalWebGPU.error);
            return { status: 'rejected', error: globalWebGPU.error };
        });
        return storePromise(promise);
    } catch (e) {
        globalWebGPU.error = `Error in requestAdapterAsync: ${e.message}`;
        console.error("[webgpu.js]", globalWebGPU.error);
        return 0; // Error creating promise
    }
}

// Request Device from Adapter
// Takes adapter_handle, returns a promise_id
export function env_wgpu_adapter_request_device_async(adapter_handle) {
    const adapter = globalWebGPU.adapters[adapter_handle];
    if (!adapter) {
        globalWebGPU.error = "Invalid adapter handle for requestDevice.";
        console.error("[webgpu.js]", globalWebGPU.error);
        return 0;
    }
    try {
        const promise = adapter.requestDevice().then(device => {
            return { status: 'fulfilled', value: storeDevice(device) };
        }).catch(e => {
            globalWebGPU.error = `Failed to request device: ${e.message}`;
            console.error("[webgpu.js]", globalWebGPU.error);
            return { status: 'rejected', error: globalWebGPU.error };
        });
        return storePromise(promise);
    } catch (e) {
        globalWebGPU.error = `Error in adapterRequestDeviceAsync: ${e.message}`;
        console.error("[webgpu.js]", globalWebGPU.error);
        return 0;
    }
}

// Poll Promise Status & Get Result
// Takes promise_id.
// Returns:
//   0: pending
//   1: fulfilled (result is ready)
//  -1: rejected (error occurred)
// For fulfilled promises, you then call the specific get_xxx_result function.
// The promise in the array is replaced with its resolved value upon fulfillment/rejection.
export function env_wgpu_poll_promise(promise_id) {
    const promise_entry = globalWebGPU.promises[promise_id];

    if (!promise_entry) {
        globalWebGPU.error = `Invalid promise_id: ${promise_id}`;
        console.error("[webgpu.js]", globalWebGPU.error);
        return -1; // Error
    }

    // If it's already a resolved object, return its status
    if (promise_entry.status === 'fulfilled') return 1;
    if (promise_entry.status === 'rejected') return -1;

    return 0; // Simplistic: assume pending if not already a result object.
}

// Get Adapter from a resolved promise
// Takes promise_id, returns adapter_handle or 0 on error/not ready.
export function env_wgpu_get_adapter_from_promise(promise_id) {
    const result = globalWebGPU.promises[promise_id];
    if (result && result.status === 'fulfilled') {
        return result.value; // This is the adapter_handle
    }
    if (result && result.status === 'rejected') {
        globalWebGPU.error = result.error;
    }
    return 0; // Not ready, or error
}

// Get Device from a resolved promise
// Takes promise_id, returns device_handle or 0 on error/not ready.
export function env_wgpu_get_device_from_promise(promise_id) {
    const result = globalWebGPU.promises[promise_id];
    if (result && result.status === 'fulfilled') {
        return result.value; // This is the device_handle
    }
    if (result && result.status === 'rejected') {
        globalWebGPU.error = result.error;
    }
    return 0; // Not ready, or error
}


// Get Device Queue
// Takes device_handle, returns queue_handle
export function env_wgpu_device_get_queue(device_handle) {
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
}

// Get the last error message pointer and length for Zig
let lastErrorBytes = null;
export function env_wgpu_get_last_error_msg_ptr() {
    if (globalWebGPU.error) {
        const encoder = new TextEncoder();
        lastErrorBytes = encoder.encode(globalWebGPU.error);
        return 1; // Indicates an error is available
    }
    return 0; // No error
}

export function env_wgpu_get_last_error_msg_len() {
    if (lastErrorBytes) {
        return lastErrorBytes.length;
    }
    return 0;
}

// Zig calls this with a buffer to copy the error message into.
// The `this.wasmMemory` will be bound by main.js when setting up imports.
export function env_wgpu_copy_last_error_msg(buffer_ptr, buffer_len) {
    if (lastErrorBytes && buffer_ptr && buffer_len > 0) {
        const memory = this.wasmMemory; 
        if (!memory) {
            console.error("[webgpu.js] Wasm memory not available for copy_last_error_msg.");
            // So Zig doesn't try to read garbage, clear the error state
            globalWebGPU.error = "Wasm memory not available to JS for error reporting.";
            const encoder = new TextEncoder();
            lastErrorBytes = encoder.encode(globalWebGPU.error);
            return;
        }
        const wasmMemoryArray = new Uint8Array(memory.buffer, buffer_ptr, buffer_len);
        const lenToCopy = Math.min(lastErrorBytes.length, buffer_len);
        for (let i = 0; i < lenToCopy; i++) {
            wasmMemoryArray[i] = lastErrorBytes[i];
        }
        // Clear error after copying to prevent it from being reported multiple times
        // or if Zig requests less than the full length.
        if (lenToCopy === lastErrorBytes.length) {
             lastErrorBytes = null;
             globalWebGPU.error = null;
        } // If not fully copied, Zig might call again for the rest. Or we decide to clear always.
        // For simplicity, let's clear always after an attempt.
        lastErrorBytes = null;
        globalWebGPU.error = null;
    }
}

// Function to release JS-side objects to prevent memory leaks
export function env_wgpu_release_handle(type_id, handle) {
    // type_id: 1 for promise, 2 for adapter, 3 for device, 4 for queue
    switch (type_id) {
        case 1: if (handle > 0 && handle < globalWebGPU.promises.length) globalWebGPU.promises[handle] = null; break;
        case 2: if (handle > 0 && handle < globalWebGPU.adapters.length) globalWebGPU.adapters[handle] = null; break;
        case 3: if (handle > 0 && handle < globalWebGPU.devices.length) globalWebGPU.devices[handle] = null; break;
        case 4: if (handle > 0 && handle < globalWebGPU.queues.length) globalWebGPU.queues[handle] = null; break;
        default: console.warn(`[webgpu.js] Unknown type_id for release_handle: ${type_id}`);
    }
}
