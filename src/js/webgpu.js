// zig-wasm-ffi/src/js/webgpu.js

const globalWebGPU = {
    // promises: [null], // Index 0 is unused, promise IDs are > 0 - REMOVED
    adapters: [null], // Index 0 is unused, adapter handles are > 0
    devices: [null],  // Index 0 is unused, device handles are > 0
    queues: [null],   // Index 0 is unused, queue handles are > 0
    buffers: [null], // Added for GPUBuffer handles
    shaderModules: [null], // Added for GPUShaderModule handles
    error: null,      // To store the last error message
    wasmExports: null, // To store Wasm exports like zig_receive_adapter
    memory: null, // To store Wasm memory
};

// Function to be called by main.js after Wasm instantiation
export function initWebGPUJs(exports, wasmMemory) {
    globalWebGPU.wasmExports = exports;
    globalWebGPU.memory = wasmMemory;
    console.log("[webgpu.js] WebGPU FFI JS initialized with Wasm exports and memory.");
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

function storeBuffer(buffer) {
    if (!buffer) return 0;
    const handle = globalWebGPU.buffers.length;
    globalWebGPU.buffers.push(buffer);
    return handle;
}

function storeShaderModule(shaderModule) {
    if (!shaderModule) return 0;
    const handle = globalWebGPU.shaderModules.length;
    globalWebGPU.shaderModules.push(shaderModule);
    return handle;
}

// For env_wgpu_get_last_error_msg_ptr_js and related functions
let lastErrorBytes = null;

// --- Public FFI Functions (callable from Zig) ---
// These will be part of the env object provided to Wasm

export const webGPUNativeImports = {
    wasmMemory: null, // This will be set by main.js after Wasm instantiation
    wasmInstance: null, // Added to access Zig exports like callbacks

    // Request Adapter
    // Invokes a Zig callback: zig_receive_adapter(adapter_handle, status_code)
    // status_code: 0 for success, 1 for error
    env_wgpu_request_adapter_js: function() {
        if (!navigator.gpu) {
            globalWebGPU.error = "WebGPU not supported on this browser.";
            console.error(globalWebGPU.error);
            // Even if WebGPU is not supported, we need to call back to Zig to signal failure.
            if (globalWebGPU.wasmExports && globalWebGPU.wasmExports.zig_receive_adapter) {
                globalWebGPU.wasmExports.zig_receive_adapter(0, 0); // 0 handle, 0 status for error
            } else {
                console.error("[webgpu.js] Wasm exports not ready for error callback in requestAdapter (no WebGPU).");
            }
            return;
        }

        navigator.gpu.requestAdapter()
            .then(adapter => {
                if (globalWebGPU.wasmExports && globalWebGPU.wasmExports.zig_receive_adapter) {
                    const adapterHandle = storeAdapter(adapter);
                    globalWebGPU.wasmExports.zig_receive_adapter(adapterHandle, adapterHandle !== 0 ? 1 : 0); // 1 for success, 0 for error
                } else {
                    globalWebGPU.error = "[webgpu.js] Wasm instance or zig_receive_adapter not ready for success callback.";
                    console.error(globalWebGPU.error); 
                }
            })
            .catch(err => {
                globalWebGPU.error = "Failed to request WebGPU adapter: " + err.message;
                console.error(globalWebGPU.error);
                if (globalWebGPU.wasmExports && globalWebGPU.wasmExports.zig_receive_adapter) {
                    globalWebGPU.wasmExports.zig_receive_adapter(0, 0); // 0 handle, 0 status for error
                } else {
                    console.error("[webgpu.js] Wasm exports not ready for error callback in requestAdapter.");
                }
            });
    },

    // Request Device from Adapter
    // Takes adapter_handle.
    // Invokes a Zig callback: zig_receive_device(device_handle, status_code)
    // status_code: 0 for success, 1 for error
    env_wgpu_adapter_request_device_js: function(adapter_handle) {
        const adapter = globalWebGPU.adapters[adapter_handle];
        if (!adapter) {
            globalWebGPU.error = `Invalid adapter handle: ${adapter_handle}`;
            console.error(globalWebGPU.error);
            if (globalWebGPU.wasmExports && globalWebGPU.wasmExports.zig_receive_device) {
                globalWebGPU.wasmExports.zig_receive_device(0, 0); // 0 handle, 0 status for error
            } else {
                console.error("[webgpu.js] Wasm exports not ready for error callback in requestDevice (invalid adapter).");
            }
            return;
        }

        adapter.requestDevice()
            .then(device => {
                if (globalWebGPU.wasmExports && globalWebGPU.wasmExports.zig_receive_device) {
                    const deviceHandle = storeDevice(device);
                    // Also store the queue immediately if device is obtained
                    if (deviceHandle !== 0) {
                        storeQueue(device.queue); // Assuming direct storage, not a separate handle for queue from this call
                    }
                    globalWebGPU.wasmExports.zig_receive_device(deviceHandle, deviceHandle !== 0 ? 1 : 0);
                } else {
                    globalWebGPU.error = "[webgpu.js] Wasm instance or zig_receive_device not ready for success callback.";
                    console.error(globalWebGPU.error);
                }
            })
            .catch(err => {
                globalWebGPU.error = "Failed to request WebGPU device: " + err.message;
                console.error(globalWebGPU.error);
                if (globalWebGPU.wasmExports && globalWebGPU.wasmExports.zig_receive_device) {
                    globalWebGPU.wasmExports.zig_receive_device(0, 0); // 0 handle, 0 status for error
                } else {
                    console.error("[webgpu.js] Wasm exports not ready for error callback in requestDevice.");
                }
            });
    },

    // REMOVED env_wgpu_poll_promise_js
    // REMOVED env_wgpu_get_adapter_from_promise_js
    // REMOVED env_wgpu_get_device_from_promise_js

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
                return;
            }
            const wasmMemoryArray = new Uint8Array(memory.buffer, buffer_ptr, buffer_len);
            const lenToCopy = Math.min(lastErrorBytes.length, buffer_len);
            for (let i = 0; i < lenToCopy; i++) {
                wasmMemoryArray[i] = lastErrorBytes[i];
            }
            if (lenToCopy === lastErrorBytes.length) {
                 lastErrorBytes = null;
                 globalWebGPU.error = null; 
            }
        }
    },

    // Function to release JS-side objects to prevent memory leaks
    env_wgpu_release_handle_js: function(type_id, handle) {
        // type_id: 1 for promise (REMOVED), 2 for adapter, 3 for device, 4 for queue, 5 for buffer, 6 for shader module
        switch (type_id) {
            // case 1: // Promise handle - REMOVED
            //     if (handle > 0 && handle < globalWebGPU.promises.length) {
            //         globalWebGPU.promises[handle] = null;
            //     }
            //     break;
            case 2: if (handle > 0 && handle < globalWebGPU.adapters.length) globalWebGPU.adapters[handle] = null; break;
            case 3: if (handle > 0 && handle < globalWebGPU.devices.length) globalWebGPU.devices[handle] = null; break;
            case 4: if (handle > 0 && handle < globalWebGPU.queues.length) globalWebGPU.queues[handle] = null; break;
            case 5: if (handle > 0 && handle < globalWebGPU.buffers.length) globalWebGPU.buffers[handle] = null; break;
            case 6: if (handle > 0 && handle < globalWebGPU.shaderModules.length) globalWebGPU.shaderModules[handle] = null; break;
            default: console.warn(`[webgpu.js] Unknown type_id for release_handle: ${type_id}`);
        }
    },

    // Logging function for Zig
    js_log_string: function(message_ptr, message_len) {
        if (!globalWebGPU.memory) {
            console.error("[webgpu.js] Wasm memory not available for js_log_string.");
            return;
        }
        const buffer = new Uint8Array(globalWebGPU.memory.buffer, message_ptr, message_len);
        const text = new TextDecoder('utf-8').decode(buffer);
        console.log("[Zig Wasm]", text);
    },

    env_wgpu_device_create_buffer_js: function(device_handle, descriptor_ptr) {
        const device = globalWebGPU.devices[device_handle];
        if (!device) {
            globalWebGPU.error = "Invalid device handle for createBuffer.";
            console.error("[webgpu.js]", globalWebGPU.error);
            return 0;
        }
        if (!this.wasmMemory) {
            globalWebGPU.error = "Wasm memory not available for createBuffer descriptor.";
            console.error("[webgpu.js]", globalWebGPU.error);
            return 0;
        }
        try {
            const memoryView = new DataView(this.wasmMemory.buffer);
            // Read BufferDescriptor from Wasm memory
            // struct BufferDescriptor { label: ?[*:0]const u8, size: u64, usage: u32, mappedAtCreation: bool }
            // For simplicity, assuming label is null for now. A full implementation would read the pointer.
            // const label_ptr = memoryView.getUint32(descriptor_ptr, true); // Assuming pointer size is 4
            const size = memoryView.getBigUint64(descriptor_ptr + 8, true); // Offset by label_ptr (assuming 4 or 8) and then size of ptr (8 for ?ptr)
            const usage = memoryView.getUint32(descriptor_ptr + 16, true);
            const mappedAtCreation = memoryView.getUint8(descriptor_ptr + 20, true) !== 0;

            const jsDescriptor = {
                size: Number(size), // GPUSize64 can be a Number in JS if not exceeding MAX_SAFE_INTEGER
                usage: usage,
                mappedAtCreation: mappedAtCreation,
                // label: readStringFromWasm(label_ptr), // Helper function needed for full label support
            };

            const buffer = device.createBuffer(jsDescriptor);
            return storeBuffer(buffer);
        } catch (e) {
            const errorMsg = `Error in deviceCreateBuffer: ${e.message}`;
            globalWebGPU.error = errorMsg;
            console.error("[webgpu.js]", errorMsg);
            return 0;
        }
    },

    env_wgpu_device_create_shader_module_js: function(device_handle, descriptor_ptr) {
        const device = globalWebGPU.devices[device_handle];
        if (!device) {
            globalWebGPU.error = "Invalid device handle for createShaderModule.";
            console.error("[webgpu.js]", globalWebGPU.error);
            return 0;
        }
        if (!this.wasmMemory) {
            globalWebGPU.error = "Wasm memory not available for createShaderModule descriptor.";
            console.error("[webgpu.js]", globalWebGPU.error);
            return 0;
        }
        try {
            const memoryView = new DataView(this.wasmMemory.buffer);
            // Read ShaderModuleDescriptor from Wasm memory
            // struct ShaderModuleDescriptor { label: ?[*:0]const u8, wgsl_code: ShaderModuleWGSLDescriptor }
            // struct ShaderModuleWGSLDescriptor { code_ptr: [*c]const u8, code_len: usize }
            // Again, simplifying label for now.
            // const label_ptr = memoryView.getUint32(descriptor_ptr, true);
            const wgsl_code_descriptor_ptr = descriptor_ptr + 8; // Assuming label_ptr is 8 bytes (?ptr)
            const code_ptr = memoryView.getUint32(wgsl_code_descriptor_ptr + 0, true); // Assuming [*c]u8 is a 4-byte ptr
            const code_len = memoryView.getUint32(wgsl_code_descriptor_ptr + 4, true); // Assuming usize is 4 bytes in wasm32

            const wgslBytes = new Uint8Array(this.wasmMemory.buffer, code_ptr, code_len);
            const wgslCode = new TextDecoder().decode(wgslBytes);

            const jsDescriptor = {
                code: wgslCode,
                // label: readStringFromWasm(label_ptr),
            };
            const shaderModule = device.createShaderModule(jsDescriptor);
            return storeShaderModule(shaderModule);
        } catch (e) {
            const errorMsg = `Error in deviceCreateShaderModule: ${e.message}`;
            globalWebGPU.error = errorMsg;
            console.error("[webgpu.js]", errorMsg);
            return 0;
        }
    },
};

// It's important that wasmInstance is set on webGPUNativeImports after Wasm instantiation.
// Example: webGPUNativeImports.wasmInstance = instance;
// And webGPUNativeImports.wasmMemory = instance.exports.memory;
