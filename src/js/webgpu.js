// zig-wasm-ffi/src/js/webgpu.js

const globalWebGPU = {
    // promises: [null], // Index 0 is unused, promise IDs are > 0 - REMOVED
    adapters: [null], // Index 0 is unused, adapter handles are > 0
    devices: [null],  // Index 0 is unused, device handles are > 0
    queues: [null],   // Index 0 is unused, queue handles are > 0
    buffers: [null], // Added for GPUBuffer handles
    shaderModules: [null], // Added for GPUShaderModule handles
    textures: [null], // Added for GPUTexture handles
    textureViews: [null], // Added for GPUTextureView handles
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

function storeTexture(texture) {
    if (!texture) return 0;
    const handle = globalWebGPU.textures.length;
    globalWebGPU.textures.push(texture);
    return handle;
}

function storeTextureView(textureView) {
    if (!textureView) return 0;
    const handle = globalWebGPU.textureViews.length;
    globalWebGPU.textureViews.push(textureView);
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
        // type_id: 1 for promise (REMOVED), 2 for adapter, 3 for device, 4 for queue, 5 for buffer, 6 for shader module, 7 for texture, 8 for texture view
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
            case 7: if (handle > 0 && handle < globalWebGPU.textures.length) globalWebGPU.textures[handle] = null; break;
            case 8: if (handle > 0 && handle < globalWebGPU.textureViews.length) globalWebGPU.textureViews[handle] = null; break;
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
            
            // Simplification: label is not read yet. Assuming descriptor_ptr points directly to wgsl_code effectively if label is null.
            // Or, more accurately, label is the first field.
            // For now, assume label handling matches createBuffer (i.e., label is skipped or needs readStringFromWasm)
            const label_ptr_offset = 0; // Placeholder
            const wgsl_code_descriptor_field_offset = 8; // Offset assuming label is a ?[*c]u8 (typically 4 or 8 bytes for pointer, let's assume 8 for safety with nullable pointers)

            const wgsl_code_descriptor_ptr = descriptor_ptr + wgsl_code_descriptor_field_offset; 
            const code_ptr = memoryView.getUint32(wgsl_code_descriptor_ptr + 0, true); 
            const code_len = memoryView.getUint32(wgsl_code_descriptor_ptr + 4, true); // Assuming usize is 4 bytes in wasm32

            const wgslBytes = new Uint8Array(this.wasmMemory.buffer, code_ptr, code_len);
            const wgslCode = new TextDecoder().decode(wgslBytes);
            
            // const label = readStringFromWasm(memoryView.getUint32(descriptor_ptr + label_ptr_offset, true)); // Example
            const jsDescriptor = {
                code: wgslCode,
                // label: label, // Add if label reading is implemented
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

    env_wgpu_device_create_texture_js: function(device_handle, descriptor_ptr) {
        const device = globalWebGPU.devices[device_handle];
        if (!device) {
            globalWebGPU.error = "Invalid device handle for createTexture.";
            console.error("[webgpu.js]", globalWebGPU.error);
            return 0;
        }
        if (!this.wasmMemory) {
            globalWebGPU.error = "Wasm memory not available for createTexture descriptor.";
            console.error("[webgpu.js]", globalWebGPU.error);
            return 0;
        }
        try {
            const memoryView = new DataView(this.wasmMemory.buffer);
            // TextureDescriptor layout from webgpu.zig:
            // label: ?[*:0]const u8, (offset 0, size 8 for ?ptr)
            // size: Extent3D, (offset 8)
            //    width: u32, (offset 8 + 0 = 8)
            //    height: u32, (offset 8 + 4 = 12)
            //    depth_or_array_layers: u32, (offset 8 + 8 = 16)
            // mip_level_count: u32, (offset 8 + 12 = 20)
            // sample_count: u32, (offset 24)
            // dimension: TextureDimension (u32 enum), (offset 28)
            // format: TextureFormat (u32 enum), (offset 32)
            // usage: u32 (GPUTextureUsageFlags), (offset 36)
            // view_formats: ?[*]const TextureFormat = null, (offset 40, size 8 for ?ptr)
            // view_formats_count: usize = 0, (offset 48, size 4 for usize in wasm32)

            // Skipping label for now
            const size_width = memoryView.getUint32(descriptor_ptr + 8, true);
            const size_height = memoryView.getUint32(descriptor_ptr + 12, true);
            const size_depth_or_array_layers = memoryView.getUint32(descriptor_ptr + 16, true);
            const mip_level_count = memoryView.getUint32(descriptor_ptr + 20, true);
            const sample_count = memoryView.getUint32(descriptor_ptr + 24, true);
            const dimension_enum_val = memoryView.getUint32(descriptor_ptr + 28, true);
            const format_enum_val = memoryView.getUint32(descriptor_ptr + 32, true);
            const usage = memoryView.getUint32(descriptor_ptr + 36, true);
            // Skipping view_formats for now

            const jsDescriptor = {
                size: { width: size_width, height: size_height, depthOrArrayLayers: size_depth_or_array_layers },
                mipLevelCount: mip_level_count,
                sampleCount: sample_count,
                dimension: mapTextureDimensionZigToJs(dimension_enum_val),
                format: mapTextureFormatZigToJs(format_enum_val),
                usage: usage,
                // label: readStringFromWasm(...) // If label reading implemented
                // viewFormats: [] // If view_formats reading implemented
            };

            const texture = device.createTexture(jsDescriptor);
            return storeTexture(texture);
        } catch (e) {
            const errorMsg = `Error in deviceCreateTexture: ${e.message}`;
            globalWebGPU.error = errorMsg;
            console.error("[webgpu.js]", errorMsg);
            return 0;
        }
    },

    env_wgpu_texture_create_view_js: function(texture_handle, descriptor_ptr) {
        const texture = globalWebGPU.textures[texture_handle];
        if (!texture) {
            globalWebGPU.error = "Invalid texture handle for createView.";
            console.error("[webgpu.js]", globalWebGPU.error);
            return 0;
        }

        let jsDescriptor = undefined; // Default view if descriptor_ptr is null
        if (descriptor_ptr) {
            if (!this.wasmMemory) {
                globalWebGPU.error = "Wasm memory not available for createView descriptor.";
                console.error("[webgpu.js]", globalWebGPU.error);
                return 0;
            }
            try {
                const memoryView = new DataView(this.wasmMemory.buffer);
                // TextureViewDescriptor layout from webgpu.zig:
                // label: ?[*:0]const u8, (offset 0, size 8 for ?ptr)
                // format: ?TextureFormat = null, (offset 8, size 8 for ?enum -> value + has_value_byte or similar)
                //    Actually, ?Enum in Zig for extern is typically just the value, 0 if null, or separate bool.
                //    Let's assume for ?TextureFormat it's value (u32) + presence_byte (u8). Total size 5, padded to 8?
                //    For simplicity now: assume it's just the u32 value, and 0 means not present if underlying type allows 0 as valid.
                //    If TextureFormat enum starts at 0, this is problematic. So zig should pass special value for 'null' or explicit bool.
                //    The Zig struct defines it as `format: ?TextureFormat = null`. If it's a pointer to optional, that's different.
                //    If it's an optional field itself, it's more complex. Assuming Zig sends 0 for no-value if underlying enum cannot be 0.
                //    Revisiting: `format: ?TextureFormat = null` in extern struct usually means it has a `has_value` byte.
                //    offset 8: format_value (u32), offset 12: format_has_value (u8), pad to 16 for next field
                //    dimension: ?TextureDimension = null, (offset 16: dim_val, offset 20: dim_has_value), pad to 24
                //    aspect: TextureAspect = .all, (offset 24, u32)
                //    base_mip_level: u32 = 0, (offset 28)
                //    mip_level_count: ?u32 = null, (offset 32: count_val, offset 36: count_has_value), pad to 40
                //    base_array_layer: u32 = 0, (offset 40)
                //    array_layer_count: ?u32 = null, (offset 44: count_val, offset 48: count_has_value), pad to 52
                // This struct packing is tricky. Let's assume Zig passes a null pointer for an entirely default descriptor.
                // If descriptor_ptr is non-null, all fields are present as per their ?type interpretation.
                // For now, a simplified read assuming direct values or 0/special value for non-present optionals.

                jsDescriptor = {};
                // Skipping label
                // Format (optional)
                const format_val = memoryView.getUint32(descriptor_ptr + 8, true); // Assuming offset of format value for now
                const format_is_present = memoryView.getUint8(descriptor_ptr + 12, true); // Assuming presence byte after value
                if (format_is_present) jsDescriptor.format = mapTextureFormatZigToJs(format_val);

                // Dimension (optional)
                const dim_val = memoryView.getUint32(descriptor_ptr + 16, true);
                const dim_is_present = memoryView.getUint8(descriptor_ptr + 20, true);
                if (dim_is_present) jsDescriptor.dimension = mapTextureViewDimensionZigToJs(dim_val);
                
                jsDescriptor.aspect = mapTextureAspectZigToJs(memoryView.getUint32(descriptor_ptr + 24, true));
                jsDescriptor.baseMipLevel = memoryView.getUint32(descriptor_ptr + 28, true);
                
                // MipLevelCount (optional)
                const mip_count_val = memoryView.getUint32(descriptor_ptr + 32, true);
                const mip_count_is_present = memoryView.getUint8(descriptor_ptr + 36, true);
                if (mip_count_is_present) jsDescriptor.mipLevelCount = mip_count_val;
                
                jsDescriptor.baseArrayLayer = memoryView.getUint32(descriptor_ptr + 40, true);

                // ArrayLayerCount (optional)
                const array_count_val = memoryView.getUint32(descriptor_ptr + 44, true);
                const array_count_is_present = memoryView.getUint8(descriptor_ptr + 48, true);
                if (array_count_is_present) jsDescriptor.arrayLayerCount = array_count_val;

            } catch (e) {
                const errorMsg = `Error reading TextureViewDescriptor: ${e.message}`;
                globalWebGPU.error = errorMsg;
                console.error("[webgpu.js]", errorMsg);
                return 0; // Error reading descriptor
            }
        }

        try {
            const view = texture.createView(jsDescriptor);
            return storeTextureView(view);
        } catch (e) {
            const errorMsg = `Error in texture.createView: ${e.message}`;
            globalWebGPU.error = errorMsg;
            console.error("[webgpu.js]", errorMsg);
            return 0;
        }
    },

};

// --- Helper Mappings for Enum Zig -> JS ---
// These map the Zig enum integer values (as defined in webgpu.zig) to JS WebGPU strings

const ZIG_TEXTURE_DIMENSION_TO_JS = {
    0: "1d",
    1: "2d",
    2: "3d",
};
function mapTextureDimensionZigToJs(zigValue) {
    return ZIG_TEXTURE_DIMENSION_TO_JS[zigValue] || "2d"; // Default to "2d"
}

// GPUTextureViewDimension can be different from GPUTextureDimension (e.g., "cube", "cube-array")
// For now, TextureViewDescriptor in Zig uses TextureDimension enum. If GPUTextureViewDimension strings needed, this map expands.
const ZIG_TEXTURE_VIEW_DIMENSION_TO_JS = {
    0: "1d",
    1: "2d",
    2: "3d",
    // Add more as needed e.g. from a distinct GPUTextureViewDimension enum in Zig if created
    // 3: "2d-array", 4: "cube", 5: "cube-array", etc.
};
function mapTextureViewDimensionZigToJs(zigValue) {
    return ZIG_TEXTURE_VIEW_DIMENSION_TO_JS[zigValue] || "2d";
}


const ZIG_TEXTURE_FORMAT_TO_JS = {
    0: "r8unorm", 1: "r8snorm", 2: "r8uint", 3: "r8sint",
    4: "r16uint", 5: "r16sint", 6: "r16float",
    7: "rg8unorm", 8: "rg8snorm", 9: "rg8uint", 10: "rg8sint",
    11: "r32uint", 12: "r32sint", 13: "r32float",
    14: "rg16uint", 15: "rg16sint", 16: "rg16float",
    17: "rgba8unorm", 18: "rgba8unorm-srgb", 19: "rgba8snorm",
    20: "rgba8uint", 21: "rgba8sint",
    22: "bgra8unorm", 23: "bgra8unorm-srgb",
    24: "rgb9e5ufloat", 25: "rgb10a2unorm", 26: "rg11b10ufloat",
    27: "rg32uint", 28: "rg32sint", 29: "rg32float",
    30: "rgba16uint", 31: "rgba16sint", 32: "rgba16float",
    33: "rgba32uint", 34: "rgba32sint", 35: "rgba32float",
    36: "stencil8", 37: "depth16unorm", 38: "depth24plus",
    39: "depth24plus-stencil8", 40: "depth32float", 41: "depth32float-stencil8",
    // Add other formats as they are added to Zig enum
};
function mapTextureFormatZigToJs(zigValue) {
    const format = ZIG_TEXTURE_FORMAT_TO_JS[zigValue];
    if (!format) {
        console.warn(`[webgpu.js] Unknown Zig TextureFormat enum value: ${zigValue}`);
        return "rgba8unorm"; // Default or throw error
    }
    return format;
}

const ZIG_TEXTURE_ASPECT_TO_JS = {
    0: "all",
    1: "stencil-only",
    2: "depth-only",
};
function mapTextureAspectZigToJs(zigValue) {
    return ZIG_TEXTURE_ASPECT_TO_JS[zigValue] || "all";
}


// It's important that wasmInstance is set on webGPUNativeImports after Wasm instantiation.
// Example: webGPUNativeImports.wasmInstance = instance;
// And webGPUNativeImports.wasmMemory = instance.exports.memory;
