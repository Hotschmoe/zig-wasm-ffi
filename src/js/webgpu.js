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
    bindGroupLayouts: [null], // Added for GPUBindGroupLayout handles
    bindGroups: {}, // Added for BindGroup
    pipelineLayouts: [null], // Added for GPUPipelineLayout handles
    computePipelines: [null], // Added for GPUComputePipeline handles
    renderPipelines: [null], // Added for GPURenderPipeline handles
    commandEncoders: [null], // Added for GPUCommandEncoder handles
    computePassEncoders: [null], // Added for GPUComputePassEncoder handles
    renderPassEncoders: [null], // Added for GPURenderPassEncoder handles
    querySets: [null], // Added for GPUQuerySet handles
    error: null,      // To store the last error message
    wasmExports: null, // To store Wasm exports like zig_receive_adapter
    memory: null, // To store Wasm memory
    nextHandle: 1, // Added for BindGroup
    errorBuffer: new Uint8Array(1024), // Buffer for error messages
    errorBufferLen: 0, // Length of the last error message
    // Callback functions from Zig
    zig_receive_adapter: null,
    zig_receive_device: null,
    commandBuffers: [null], // Added for GPUCommandBuffer handles
    samplers: [null], // Added for GPUSampler handles
};

// Function to be called by main.js after Wasm instantiation
export function initWebGPUJs(exports, wasmMemory, canvas) {
    globalWebGPU.wasmExports = exports;
    globalWebGPU.memory = wasmMemory;
    if (canvas) {
        globalWebGPU.canvas = canvas;
        console.log("[webgpu.js] Canvas element stored.");
    }
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

function storeBindGroupLayout(bgl) {
    if (!bgl) return 0;
    const handle = globalWebGPU.bindGroupLayouts.length;
    globalWebGPU.bindGroupLayouts.push(bgl);
    return handle;
}

function storeBindGroup(bindGroup) {
    const handle = globalWebGPU.nextHandle++;
    globalWebGPU.bindGroups[handle] = bindGroup;
    return handle;
}

function storePipelineLayout(pipelineLayout) {
    if (!pipelineLayout) return 0;
    const handle = globalWebGPU.pipelineLayouts.length; // Assuming globalWebGPU.pipelineLayouts exists
    globalWebGPU.pipelineLayouts.push(pipelineLayout);
    return handle;
}

function storeComputePipeline(pipeline) {
    if (!pipeline) return 0;
    const handle = globalWebGPU.computePipelines.length;
    globalWebGPU.computePipelines.push(pipeline);
    return handle;
}

function storeRenderPipeline(pipeline) {
    if (!pipeline) return 0;
    const handle = globalWebGPU.renderPipelines.length;
    globalWebGPU.renderPipelines.push(pipeline);
    return handle;
}

function storeCommandEncoder(encoder) {
    if (!encoder) return 0;
    const handle = globalWebGPU.commandEncoders.length;
    globalWebGPU.commandEncoders.push(encoder);
    return handle;
}

function storeComputePassEncoder(pass) {
    if (!pass) return 0;
    const handle = globalWebGPU.computePassEncoders.length;
    globalWebGPU.computePassEncoders.push(pass);
    return handle;
}

function storeRenderPassEncoder(pass) {
    if (!pass) return 0;
    const handle = globalWebGPU.renderPassEncoders.length;
    globalWebGPU.renderPassEncoders.push(pass);
    return handle;
}

function storeCommandBuffer(buffer) {
    if (!buffer) return 0;
    const handle = globalWebGPU.commandBuffers.length;
    globalWebGPU.commandBuffers.push(buffer);
    return handle;
}

function storeSampler(sampler) {
    if (!sampler) return 0;
    const handle = globalWebGPU.samplers.length;
    globalWebGPU.samplers.push(sampler);
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

    env_wgpu_queue_write_buffer_js: function(queue_handle, buffer_handle, buffer_offset, data_size, data_ptr) {
        const queue = globalWebGPU.queues[queue_handle];
        if (!queue) {
            return recordError(`Invalid queue handle for writeBuffer: ${queue_handle}`);
        }
        const buffer = globalWebGPU.buffers[buffer_handle];
        if (!buffer) {
            return recordError(`Invalid buffer handle for writeBuffer: ${buffer_handle}`);
        }
        if (!this.wasmMemory) {
            return recordError("Wasm memory not available for writeBuffer.");
        }
        try {
            const memory = new Uint8Array(this.wasmMemory.buffer, data_ptr, Number(data_size));
            queue.writeBuffer(buffer, Number(buffer_offset), memory);
        } catch (e) {
            recordError(`Error in writeBuffer: ${e.message}`);
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
            case 9: if (handle > 0 && handle < globalWebGPU.samplers.length) globalWebGPU.samplers[handle] = null; break; // Added for Sampler
            case 10: if (handle > 0 && handle < globalWebGPU.bindGroupLayouts.length) globalWebGPU.bindGroupLayouts[handle] = null; break;
            case 11: if (handle > 0 && handle < globalWebGPU.bindGroups.length) globalWebGPU.bindGroups[handle] = null; break;
            case 12: if (handle > 0 && handle < globalWebGPU.pipelineLayouts.length) globalWebGPU.pipelineLayouts[handle] = null; break;
            case 13: if (handle > 0 && handle < globalWebGPU.computePipelines.length) globalWebGPU.computePipelines[handle] = null; break;
            case 14: if (handle > 0 && handle < globalWebGPU.renderPipelines.length) globalWebGPU.renderPipelines[handle] = null; break;
            case 15: if (handle > 0 && handle < globalWebGPU.commandEncoders.length) globalWebGPU.commandEncoders[handle] = null; break;
            case 17: if (handle > 0 && handle < globalWebGPU.computePassEncoders.length) globalWebGPU.computePassEncoders[handle] = null; break;
            case 18: if (handle > 0 && handle < globalWebGPU.renderPassEncoders.length) globalWebGPU.renderPassEncoders[handle] = null; break; // Added for RenderPassEncoder
            case 16: if (handle > 0 && handle < globalWebGPU.commandBuffers.length) globalWebGPU.commandBuffers[handle] = null; break; // Added for CommandBuffer (typeId 16 is from webgpu.zig)
            default: console.warn(`[webgpu.js] Unknown type_id for release_handle: ${type_id}`);
        }
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
            // On wasm32, u64 requires 8-byte alignment, so there's padding after the 4-byte pointer:
            // offset 0: label (4 bytes)
            // offset 4: padding (4 bytes) 
            // offset 8: size (8 bytes)
            // offset 16: usage (4 bytes)
            // offset 20: mappedAtCreation (1 byte)
            const size = memoryView.getBigUint64(descriptor_ptr + 8, true); // 8-byte aligned offset
            const usage = memoryView.getUint32(descriptor_ptr + 16, true); // After size field
            const mappedAtCreation = memoryView.getUint8(descriptor_ptr + 20, true) !== 0; // After usage field

            const jsDescriptor = {
                size: Number(size), // GPUSize64 can be a Number in JS if not exceeding MAX_SAFE_INTEGER
                usage: usage,
                mappedAtCreation: mappedAtCreation,
                // label: readStringFromWasm(label_ptr), // Helper function needed for full label support
            };

            const buffer = device.createBuffer(jsDescriptor);
            const handle = storeBuffer(buffer);
            // Debug: Uncomment for detailed buffer creation logging
            // console.log(`[webgpu.js] Buffer created with handle: ${handle}, size: ${Number(size)}, usage: ${usage}, mappedAtCreation: ${mappedAtCreation}`);
            return handle;
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
            const wgsl_code_descriptor_field_offset = 4; // Offset assuming label is a ?[*c]u8 (4 bytes for wasm32 pointer)

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
            // label: ?[*:0]const u8, (offset 0, size 4 for ?ptr in wasm32)
            // size: Extent3D, (offset 4)
            //    width: u32, (offset 4 + 0 = 4)
            //    height: u32, (offset 4 + 4 = 8)
            //    depth_or_array_layers: u32, (offset 4 + 8 = 12)
            // mip_level_count: u32, (offset 4 + 12 = 16)
            // sample_count: u32, (offset 20)
            // dimension: TextureDimension (u32 enum), (offset 24)
            // format: TextureFormat (u32 enum), (offset 28)
            // usage: u32 (GPUTextureUsageFlags), (offset 32)
            // view_formats: ?[*]const TextureFormat = null, (offset 36, size 4 for ?ptr)
            // view_formats_count: usize = 0, (offset 40, size 4 for usize in wasm32)

            // Skipping label for now
            const size_width = memoryView.getUint32(descriptor_ptr + 4, true);
            const size_height = memoryView.getUint32(descriptor_ptr + 8, true);
            const size_depth_or_array_layers = memoryView.getUint32(descriptor_ptr + 12, true);
            const mip_level_count = memoryView.getUint32(descriptor_ptr + 16, true);
            const sample_count = memoryView.getUint32(descriptor_ptr + 20, true);
            const dimension_enum_val = memoryView.getUint32(descriptor_ptr + 24, true);
            const format_enum_val = memoryView.getUint32(descriptor_ptr + 28, true);
            const usage = memoryView.getUint32(descriptor_ptr + 32, true);
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

    env_wgpu_device_create_bind_group_layout_js: function(device_handle, descriptor_ptr) {
        try {
            const device = globalWebGPU.devices[device_handle];
            if (!device) {
                return recordError(`Device not found for handle: ${device_handle}`);
            }
            globalWebGPU.errorBufferLen = 0; // Clear error before reading
            const descriptor = readBindGroupLayoutDescriptorFromMemory(descriptor_ptr);
            
            if (!descriptor) { // Implies an error was recorded by the reader
                // const errorMsg = readStringFromMemory(globalWebGPU.errorBuffer.byteOffset, globalWebGPU.errorBufferLen); 
                // recordError is already called by the reader, and it returns 0 (error handle)
                return 0; 
            }

            const bindGroupLayout = device.createBindGroupLayout(descriptor);
            bindGroupLayout.js_entries_internal = descriptor.js_entries_internal; // Attach for later use
            const bglHandle = storeBindGroupLayout(bindGroupLayout);
            return bglHandle;
        } catch (e) {
            return recordError(e.message);
        }
    },

    env_wgpu_device_create_bind_group_js: function(device_handle, descriptor_ptr) {
        try {
            const device = globalWebGPU.devices[device_handle];
            if (!device) {
                return recordError(`Device not found for handle: ${device_handle}`);
            }

            const wasmMemoryU8 = new Uint8Array(globalWebGPU.memory.buffer);
            const wasmMemoryU32 = new Uint32Array(globalWebGPU.memory.buffer);
            const wasmMemoryU64 = new BigUint64Array(globalWebGPU.memory.buffer); // For u64 fields

            // Read BindGroupDescriptor (label, layout_handle, entries_ptr, entries_len)
            // struct BindGroupDescriptor {
            //     label: ?[*:0]const u8 = null, (ptr)
            //     layout: BindGroupLayout, (u32 handle)
            //     entries: [*]const BindGroupEntry, (ptr)
            //     entries_len: usize, (u32)
            // };
            let offset = descriptor_ptr / 4; // Assuming descriptor_ptr is u32 aligned
            const label_ptr = wasmMemoryU32[offset++];
            const layout_handle = wasmMemoryU32[offset++];
            const entries_ptr = wasmMemoryU32[offset++];
            const entries_len = wasmMemoryU32[offset++];

            const jsDescriptor = {};
            if (label_ptr) {
                jsDescriptor.label = readStringFromMemory(label_ptr);
            }

            const bindGroupLayout = globalWebGPU.bindGroupLayouts[layout_handle];
            if (!bindGroupLayout) {
                return recordError(`BindGroupLayout not found for handle: ${layout_handle}`);
            }
            jsDescriptor.layout = bindGroupLayout;

            jsDescriptor.entries = [];
            let entry_offset_bytes = entries_ptr;
            for (let i = 0; i < entries_len; i++) {
                // struct BindGroupEntry {
                //     binding: u32,
                //     resource: Resource, (union)
                // };
                // Resource union: buffer: BufferBinding, sampler: SamplerBinding, texture: TextureBinding
                // struct BufferBinding { buffer: u32, offset: u64, size: u64 }
                // struct SamplerBinding { sampler: u32 }
                // struct TextureBinding { texture_view: u32 }

                const jsEntry = {};
                let current_entry_ptr_u32 = entry_offset_bytes / 4;

                jsEntry.binding = wasmMemoryU32[current_entry_ptr_u32++];
                // Debug: Uncomment for detailed bind group entry debugging
                // console.log(`[webgpu.js] Reading entry ${i}: offset_bytes=${entry_offset_bytes}, offset_u32=${current_entry_ptr_u32-1}, binding=${jsEntry.binding}`);

                // The resource is a union. The Zig code must tell us which field of the union is active.
                // For now, we assume the BindGroupLayout provides enough context to know what type is expected.
                // This is a simplification. A robust solution would need type tags in the BindGroupEntry from Zig,
                // or to infer from the BindGroupLayout.
                // Let's assume for now the layout implies the type, and the demo will pass correct resource handles.
                
                // Heuristic: Check the type of resource based on the BGL this BG is created for.
                // This requires introspecting the BGL, which is complex here.
                // Alternative: Zig must send a type tag for the union within BindGroupEntry.
                // For the demo, we'll assume `renderer.zig` creates entries matching BGL types.
                // The simplest approach is to try and find a valid handle in one of the expected stores.

                // Let's assume a simplified BindGroupEntry.Resource structure from Zig for now:
                // It would have one field for each type, and only one handle would be non-zero.
                // This means the Zig union needs to be read carefully.
                // The Zig extern union has fields: buffer, sampler, texture.
                // The offset for these will be current_entry_ptr_u32.
                
                // Reading the *first field* of the union (e.g. buffer.buffer handle)
                const resource_handle1 = wasmMemoryU32[current_entry_ptr_u32]; 

                // We need to know the *active* field of the Zig union.
                // The BGL has this info. We look up the entry in the BGL by binding index.
                const bglEntry = bindGroupLayout.js_entries_internal[jsEntry.binding];
                if (!bglEntry) {
                    return recordError(`No BindGroupLayout entry found for binding ${jsEntry.binding}`);
                }

                if (bglEntry.buffer !== undefined) { // It's a buffer binding
                    // Fix: Resource union starts after binding field (offset 4 bytes)
                    // BindGroupEntry layout: binding: u32 (0-3), resource: Resource (4-27)
                    // BufferBinding layout within resource: buffer: u32 (0-3), padding: u32 (4-7), offset: u64 (8-15), size: u64 (16-23)
                    const resource_offset = current_entry_ptr_u32 + 1; // +1 u32 = +4 bytes for resource union
                    const buffer_handle = wasmMemoryU32[resource_offset + 0]; // buffer: u32 at resource offset 0
                    // Skip padding at offset 1 (4-7 bytes)  
                    const buffer_offset_lo = wasmMemoryU32[resource_offset + 2]; // offset: u64 low at offset 8
                    const buffer_offset_hi = wasmMemoryU32[resource_offset + 3]; // offset: u64 high at offset 12
                    const buffer_size_lo = wasmMemoryU32[resource_offset + 4]; // size: u64 low at offset 16
                    const buffer_size_hi = wasmMemoryU32[resource_offset + 5]; // size: u64 high at offset 20

                    // Debug: Uncomment for buffer handle debugging
                    // console.log(`[webgpu.js] Bind group entry binding ${jsEntry.binding}: buffer_handle=${buffer_handle}`);
                    
                    // Enhanced error checking for buffer handle 0
                    if (buffer_handle === 0) {
                        return recordError(`Invalid buffer handle 0 at binding ${jsEntry.binding}. Buffer handles must be >= 1. This indicates a Zig-side initialization issue where a BufferBinding.buffer field was not properly set.`);
                    }
                    
                    const gpuBuffer = globalWebGPU.buffers[buffer_handle];
                    if (!gpuBuffer) {
                        const availableHandles = globalWebGPU.buffers.map((buf, idx) => idx).filter(idx => idx > 0 && globalWebGPU.buffers[idx]);
                        return recordError(`GPUBuffer not found for handle ${buffer_handle} at binding ${jsEntry.binding}. Available handles: [${availableHandles.join(', ')}]`);
                    }
                    jsEntry.resource = { 
                        buffer: gpuBuffer,
                        offset: Number(BigInt(buffer_offset_hi) << 32n | BigInt(buffer_offset_lo)),
                        // Handle WHOLE_SIZE sentinel - check if this is the max u64 value (Zig's WHOLE_SIZE)
                        size: (buffer_size_hi === 0xFFFFFFFF) ? undefined : Number(BigInt(buffer_size_hi) << 32n | BigInt(buffer_size_lo)),
                    };
                    // FIX: BindGroupEntry size is 32 bytes (binding u32 + resource union 24 bytes + padding)
                    // We should advance by the full struct size, not calculate individual field sizes
                    entry_offset_bytes += 32; // Advance by size of BindGroupEntry struct
                } else if (bglEntry.texture !== undefined) { // It's a texture view binding
                    const resource_offset = current_entry_ptr_u32 + 1; // +1 u32 = +4 bytes for resource union
                    const texture_view_handle = wasmMemoryU32[resource_offset + 0]; // struct TextureBinding { texture_view: TextureView (u32) }
                    const gpuTextureView = globalWebGPU.textureViews[texture_view_handle];
                    if (!gpuTextureView) return recordError(`GPUTextureView not found for handle ${texture_view_handle} at binding ${jsEntry.binding}`);
                    jsEntry.resource = gpuTextureView;
                    // FIX: Use consistent BindGroupEntry struct size of 32 bytes
                    entry_offset_bytes += 32; // Advance by size of BindGroupEntry struct
                } else if (bglEntry.sampler !== undefined) { // It's a sampler binding - Placeholder
                    // const sampler_handle = wasmMemoryU32[current_entry_ptr_u32 + 0]; // struct SamplerBinding { sampler: Sampler (u32) }
                    // const gpuSampler = globalWebGPU.samplers[sampler_handle];
                    // if (!gpuSampler) return recordError(`GPUSampler not found for handle ${sampler_handle} at binding ${jsEntry.binding}`);
                    // jsEntry.resource = gpuSampler;
                    // entry_offset_bytes += 24; // 4 (binding) + 20 (resource union) = 24 bytes
                    return recordError(`Sampler binding not yet fully implemented in env_wgpu_device_create_bind_group_js for binding ${jsEntry.binding}`);
                } else {
                    return recordError(`Unknown resource type in BindGroupLayout for binding ${jsEntry.binding}`);
                }
                jsDescriptor.entries.push(jsEntry);
            }

            const bindGroup = device.createBindGroup(jsDescriptor);
            const bgHandle = storeBindGroup(bindGroup);
            // console.log(`JS: Created BindGroup, handle: ${bgHandle}`, bindGroup);
            return bgHandle;
        } catch (e) {
            return recordError(e.message);
        }
    },

    env_wgpu_device_create_pipeline_layout_js: function(device_handle, descriptor_ptr) {
        try {
            const device = globalWebGPU.devices[device_handle];
            if (!device) {
                return recordError(`Device not found for handle: ${device_handle}`);
            }

            const wasmMemoryU32 = new Uint32Array(globalWebGPU.memory.buffer);
            let offset_u32 = descriptor_ptr / 4;

            const label_ptr = wasmMemoryU32[offset_u32++];
            const bind_group_layouts_ptr = wasmMemoryU32[offset_u32++];
            const bind_group_layouts_len = wasmMemoryU32[offset_u32++];

            const jsDescriptor = {};
            if (label_ptr) {
                jsDescriptor.label = readStringFromMemory(label_ptr);
            }

            jsDescriptor.bindGroupLayouts = [];
            let current_bgl_handle_ptr_u32 = bind_group_layouts_ptr / 4;
            for (let i = 0; i < bind_group_layouts_len; i++) {
                const bgl_handle = wasmMemoryU32[current_bgl_handle_ptr_u32++];
                const bgl = globalWebGPU.bindGroupLayouts[bgl_handle];
                if (!bgl) {
                    return recordError(`BindGroupLayout not found for handle: ${bgl_handle} at index ${i}`);
                }
                jsDescriptor.bindGroupLayouts.push(bgl);
            }

            const pipelineLayout = device.createPipelineLayout(jsDescriptor);
            const plHandle = storePipelineLayout(pipelineLayout);
            return plHandle;
        } catch (e) {
            return recordError(e.message);
        }
    },

    env_wgpu_device_create_compute_pipeline_js: function(device_handle, descriptor_ptr) {
        try {
            const device = globalWebGPU.devices[device_handle];
            if (!device) {
                return recordError(`Device not found for handle: ${device_handle}`);
            }

            const wasmMemoryU32 = new Uint32Array(globalWebGPU.memory.buffer);
            const wasmMemoryF64 = new Float64Array(globalWebGPU.memory.buffer);
            let offset_u32 = descriptor_ptr / 4;

            const jsDescriptor = {};

            // Read ComputePipelineDescriptor
            const label_ptr = wasmMemoryU32[offset_u32++];
            const layout_handle = wasmMemoryU32[offset_u32++]; // This is actually ?PipelineLayout, so 0 means null/auto
            // Next is compute: ProgrammableStageDescriptor (module_handle, entry_point_ptr, constants_ptr, constants_len)
            const compute_module_handle = wasmMemoryU32[offset_u32++];
            const compute_entry_point_ptr = wasmMemoryU32[offset_u32++];
            const compute_constants_ptr = wasmMemoryU32[offset_u32++];
            const compute_constants_len = wasmMemoryU32[offset_u32++];

            if (label_ptr) {
                jsDescriptor.label = readStringFromMemory(label_ptr);
            }

            if (layout_handle !== 0) { // 0 is the sentinel for null PipelineLayout (auto)
                jsDescriptor.layout = globalWebGPU.pipelineLayouts[layout_handle];
                if (!jsDescriptor.layout) {
                    return recordError(`PipelineLayout not found for handle: ${layout_handle}`);
                }
            } else {
                jsDescriptor.layout = 'auto';
            }

            jsDescriptor.compute = {};
            jsDescriptor.compute.module = globalWebGPU.shaderModules[compute_module_handle];
            if (!jsDescriptor.compute.module) {
                return recordError(`ShaderModule not found for compute stage handle: ${compute_module_handle}`);
            }

            if (compute_entry_point_ptr) {
                jsDescriptor.compute.entryPoint = readStringFromMemory(compute_entry_point_ptr);
            }

            if (compute_constants_len > 0 && compute_constants_ptr) {
                jsDescriptor.compute.constants = {};
                let constant_offset_bytes = compute_constants_ptr;
                for (let i = 0; i < compute_constants_len; i++) {
                    // ConstantEntry: key_ptr (u32), value (f64)
                    // Need to be careful with memory alignment for f64
                    const key_ptr_for_constant = wasmMemoryU32[constant_offset_bytes / 4];
                    const value_for_constant = wasmMemoryF64[(constant_offset_bytes + 4) / 8]; 
                    jsDescriptor.compute.constants[readStringFromMemory(key_ptr_for_constant)] = value_for_constant;
                    constant_offset_bytes += 12; // sizeof(ConstantEntry)
                }
            }

            const computePipeline = device.createComputePipeline(jsDescriptor);
            const cpHandle = storeComputePipeline(computePipeline);
            return cpHandle;
        } catch (e) {
            return recordError(e.message);
        }
    },

    env_wgpu_device_create_render_pipeline_js: function(device_handle, descriptor_ptr) {
        try {
            const device = globalWebGPU.devices[device_handle];
            if (!device) {
                return recordError(`Device not found for handle: ${device_handle}`);
            }

            const wasmMemoryU32 = new Uint32Array(globalWebGPU.memory.buffer);
            const wasmMemoryF64 = new Float64Array(globalWebGPU.memory.buffer);
            const wasmMemoryI32 = new Int32Array(globalWebGPU.memory.buffer);
            const wasmMemoryF32 = new Float32Array(globalWebGPU.memory.buffer);
            const wasmMemoryU64 = new BigUint64Array(globalWebGPU.memory.buffer); // Added missing declaration
            let descriptor_offset_u32 = descriptor_ptr / 4;

            // Helper function to read ProgrammableStageDescriptor (used by compute and vertex/fragment stages)
            function readProgrammableStage(base_ptr_u32) {
                let offset = base_ptr_u32;
                const module_handle = wasmMemoryU32[offset++];
                const entry_point_ptr = wasmMemoryU32[offset++];
                const constants_ptr = wasmMemoryU32[offset++];
                const constants_len = wasmMemoryU32[offset++];

                const stage = {};
                stage.module = globalWebGPU.shaderModules[module_handle];
                if (!stage.module) {
                    recordError(`ShaderModule not found for stage handle: ${module_handle}`);
                    return null;
                }
                if (entry_point_ptr) {
                    stage.entryPoint = readStringFromMemory(entry_point_ptr);
                }
                if (constants_len > 0 && constants_ptr) {
                    stage.constants = {};
                    let constant_offset_bytes = constants_ptr;
                    for (let i = 0; i < constants_len; i++) {
                        const key_ptr_for_constant = wasmMemoryU32[constant_offset_bytes / 4];
                        const value_for_constant = wasmMemoryF64[(constant_offset_bytes + 4) / 8]; 
                        stage.constants[readStringFromMemory(key_ptr_for_constant)] = value_for_constant;
                        constant_offset_bytes += 12; // sizeof(ConstantEntry)
                    }
                }
                return stage;
            }

            const jsDescriptor = {};

            // Read RenderPipelineDescriptor
            const label_ptr = wasmMemoryU32[descriptor_offset_u32++];
            const layout_handle = wasmMemoryU32[descriptor_offset_u32++]; // ?PipelineLayout
            // vertex: VertexState (ProgrammableStage + buffers)
            const vertex_stage_ptr_u32 = descriptor_offset_u32;
            jsDescriptor.vertex = readProgrammableStage(vertex_stage_ptr_u32);
            if (!jsDescriptor.vertex) return 0; // Error already recorded
            descriptor_offset_u32 += 4; // Advance past ProgrammableStage part of VertexState (module, entry_point, constants_ptr, constants_len)
            
            const vertex_buffers_ptr = wasmMemoryU32[descriptor_offset_u32++];
            const vertex_buffers_len = wasmMemoryU32[descriptor_offset_u32++];
            if (vertex_buffers_len > 0 && vertex_buffers_ptr) {
                jsDescriptor.vertex.buffers = [];
                let vb_layout_offset_bytes = vertex_buffers_ptr;
                for (let i = 0; i < vertex_buffers_len; i++) {
                    const jsVbLayout = {};
                    jsVbLayout.arrayStride = Number(wasmMemoryU64[vb_layout_offset_bytes / 8]);
                    jsVbLayout.stepMode = ZIG_VERTEX_STEP_MODE_TO_JS[wasmMemoryU32[(vb_layout_offset_bytes + 8) / 4]];
                    const attributes_ptr = wasmMemoryU32[(vb_layout_offset_bytes + 12) / 4];
                    const attributes_len = wasmMemoryU32[(vb_layout_offset_bytes + 16) / 4];
                    jsVbLayout.attributes = [];
                    if (attributes_len > 0 && attributes_ptr) {
                        let attr_offset_bytes = attributes_ptr;
                        for (let j = 0; j < attributes_len; j++) {
                            jsVbLayout.attributes.push({
                                format: ZIG_VERTEX_FORMAT_TO_JS[wasmMemoryU32[attr_offset_bytes / 4]], // offset 0: format (u32)
                                offset: Number(wasmMemoryU64[(attr_offset_bytes + 8) / 8]), // offset 8: offset (u64) after 4-byte padding
                                shaderLocation: wasmMemoryU32[(attr_offset_bytes + 16) / 4], // offset 16: shader_location (u32)
                            });
                            attr_offset_bytes += 24; // sizeof(VertexAttribute): format(u32) + padding(4) + offset(u64) + shader_location(u32) + padding(4) = 24 bytes
                        }
                    }
                    jsDescriptor.vertex.buffers.push(jsVbLayout);
                    vb_layout_offset_bytes += 20; // sizeof(VertexBufferLayout): array_stride(u64), step_mode(u32), attributes_ptr(u32), attributes_len(u32) = 8+4+4+4 = 20
                }
            }

            // primitive: PrimitiveState (topology, strip_index_format, strip_index_format_is_present, front_face, cull_mode)
            jsDescriptor.primitive = {};
            jsDescriptor.primitive.topology = ZIG_PRIMITIVE_TOPOLOGY_TO_JS[wasmMemoryU32[descriptor_offset_u32++]];
            const strip_index_format_val = wasmMemoryU32[descriptor_offset_u32++]; // GPUIndexFormat
            const strip_index_format_is_present = wasmMemoryU32[descriptor_offset_u32++] !== 0; // bool
            if (strip_index_format_is_present) {
                jsDescriptor.primitive.stripIndexFormat = ZIG_INDEX_FORMAT_TO_JS[strip_index_format_val];
            }
            // Note: stripIndexFormat is omitted when not present, which is what WebGPU expects
            jsDescriptor.primitive.frontFace = ZIG_FRONT_FACE_TO_JS[wasmMemoryU32[descriptor_offset_u32++]];
            jsDescriptor.primitive.cullMode = ZIG_CULL_MODE_TO_JS[wasmMemoryU32[descriptor_offset_u32++]];
            // unclippedDepth is skipped for now

            // depth_stencil: ?*const DepthStencilState
            const depth_stencil_ptr = wasmMemoryU32[descriptor_offset_u32++];
            if (depth_stencil_ptr) {
                jsDescriptor.depthStencil = {};
                let ds_offset_u32 = depth_stencil_ptr / 4;
                jsDescriptor.depthStencil.format = mapTextureFormatZigToJs(wasmMemoryU32[ds_offset_u32++]);
                jsDescriptor.depthStencil.depthWriteEnabled = wasmMemoryU32[ds_offset_u32++] !== 0; // bool
                jsDescriptor.depthStencil.depthCompare = ZIG_COMPARE_FUNCTION_TO_JS[wasmMemoryU32[ds_offset_u32++]];
                // StencilFaceState: front and back (compare, failOp, depthFailOp, passOp)
                function readStencilFaceState(sfs_offset_u32) {
                    return {
                        compare: ZIG_COMPARE_FUNCTION_TO_JS[wasmMemoryU32[sfs_offset_u32++]],
                        failOp: ZIG_STENCIL_OP_TO_JS[wasmMemoryU32[sfs_offset_u32++]],
                        depthFailOp: ZIG_STENCIL_OP_TO_JS[wasmMemoryU32[sfs_offset_u32++]],
                        passOp: ZIG_STENCIL_OP_TO_JS[wasmMemoryU32[sfs_offset_u32++]],
                    };
                }
                jsDescriptor.depthStencil.stencilFront = readStencilFaceState(ds_offset_u32); ds_offset_u32 += 4;
                jsDescriptor.depthStencil.stencilBack = readStencilFaceState(ds_offset_u32); ds_offset_u32 += 4;
                jsDescriptor.depthStencil.stencilReadMask = wasmMemoryU32[ds_offset_u32++];
                jsDescriptor.depthStencil.stencilWriteMask = wasmMemoryU32[ds_offset_u32++];
                jsDescriptor.depthStencil.depthBias = wasmMemoryI32[ds_offset_u32++];
                jsDescriptor.depthStencil.depthBiasSlopeScale = wasmMemoryF32[ds_offset_u32++];
                jsDescriptor.depthStencil.depthBiasClamp = wasmMemoryF32[ds_offset_u32++];
            }

            // multisample: MultisampleState (count, mask, alphaToCoverageEnabled)
            jsDescriptor.multisample = {};
            jsDescriptor.multisample.count = wasmMemoryU32[descriptor_offset_u32++];
            jsDescriptor.multisample.mask = wasmMemoryU32[descriptor_offset_u32++];
            jsDescriptor.multisample.alphaToCoverageEnabled = wasmMemoryU32[descriptor_offset_u32++] !== 0;

            // fragment: ?*const FragmentState
            const fragment_ptr = wasmMemoryU32[descriptor_offset_u32++];
            if (fragment_ptr) {
                let frag_stage_base_u32 = fragment_ptr / 4;
                jsDescriptor.fragment = readProgrammableStage(frag_stage_base_u32);
                if (!jsDescriptor.fragment) return 0; // Error recorded
                frag_stage_base_u32 += 4; // Advance past ProgrammableStage part

                const targets_ptr = wasmMemoryU32[frag_stage_base_u32++];
                const targets_len = wasmMemoryU32[frag_stage_base_u32++];
                jsDescriptor.fragment.targets = [];
                if (targets_len > 0 && targets_ptr) {
                    let target_offset_bytes = targets_ptr;
                    for (let i = 0; i < targets_len; i++) {
                        const jsTarget = {};
                        let ct_offset_u32 = target_offset_bytes / 4;
                        jsTarget.format = mapTextureFormatZigToJs(wasmMemoryU32[ct_offset_u32++]);
                        const blend_ptr = wasmMemoryU32[ct_offset_u32++]; // ?*const BlendState
                        if (blend_ptr) {
                            jsTarget.blend = {};
                            let blend_offset_u32 = blend_ptr / 4;
                            // color: BlendComponent
                            jsTarget.blend.color = {
                                operation: ZIG_BLEND_OP_TO_JS[wasmMemoryU32[blend_offset_u32++]],
                                srcFactor: ZIG_BLEND_FACTOR_TO_JS[wasmMemoryU32[blend_offset_u32++]],
                                dstFactor: ZIG_BLEND_FACTOR_TO_JS[wasmMemoryU32[blend_offset_u32++]],
                            };
                            // alpha: BlendComponent
                            jsTarget.blend.alpha = {
                                operation: ZIG_BLEND_OP_TO_JS[wasmMemoryU32[blend_offset_u32++]],
                                srcFactor: ZIG_BLEND_FACTOR_TO_JS[wasmMemoryU32[blend_offset_u32++]],
                                dstFactor: ZIG_BLEND_FACTOR_TO_JS[wasmMemoryU32[blend_offset_u32++]],
                            };
                        }
                        jsTarget.writeMask = wasmMemoryU32[ct_offset_u32++];
                        jsDescriptor.fragment.targets.push(jsTarget);
                        target_offset_bytes += 12; // sizeof(ColorTargetState): format(u32), blend_ptr(u32), write_mask(u32) = 12
                    }
                }
            }

            if (label_ptr) {
                jsDescriptor.label = readStringFromMemory(label_ptr);
            }
            if (layout_handle !== 0) {
                jsDescriptor.layout = globalWebGPU.pipelineLayouts[layout_handle];
                if (!jsDescriptor.layout) return recordError(`PipelineLayout not found: ${layout_handle}`);
            } else {
                jsDescriptor.layout = 'auto';
            }

            const renderPipeline = device.createRenderPipeline(jsDescriptor);
            const rpHandle = storeRenderPipeline(renderPipeline);
            return rpHandle;
        } catch (e) {
            return recordError(e.message);
        }
    },

    env_wgpu_device_create_command_encoder_js: function(device_handle, descriptor_ptr) {
        try {
            const device = globalWebGPU.devices[device_handle];
            if (!device) {
                return recordError(`Device not found for handle: ${device_handle}`);
            }
            
            let jsDescriptor = undefined;
            if (descriptor_ptr) {
                // Assuming CommandEncoderDescriptor has only a label for now.
                // struct CommandEncoderDescriptor { label: ?[*:0]const u8 = null }
                const wasmMemoryU32 = new Uint32Array(globalWebGPU.memory.buffer);
                const label_ptr = wasmMemoryU32[descriptor_ptr / 4]; // Read the pointer to the label string
                if (label_ptr) {
                    jsDescriptor = { label: readStringFromMemory(label_ptr) };
                }
            }
            const encoder = device.createCommandEncoder(jsDescriptor);
            return storeCommandEncoder(encoder);
        } catch (e) {
            return recordError(e.message);
        }
    },

    env_wgpu_command_encoder_copy_buffer_to_buffer_js: function(encoder_handle, source_buffer_handle, source_offset_low, source_offset_high, destination_buffer_handle, destination_offset_low, destination_offset_high, size_low, size_high) {
        try {
            console.log(`[webgpu.js] DEBUG copyBufferToBuffer: encoder=${encoder_handle}, src=${source_buffer_handle}, dst=${destination_buffer_handle}`);
            
            const encoder = globalWebGPU.commandEncoders[encoder_handle];
            if (!encoder) return recordError(`CommandEncoder not found: ${encoder_handle}`);
            const sourceBuffer = globalWebGPU.buffers[source_buffer_handle];
            if (!sourceBuffer) return recordError(`Source Buffer not found: ${source_buffer_handle}`);
            const destinationBuffer = globalWebGPU.buffers[destination_buffer_handle];
            if (!destinationBuffer) return recordError(`Destination Buffer not found: ${destination_buffer_handle}`);

            const sourceOffset = combineToBigInt(source_offset_low, source_offset_high);
            const destinationOffset = combineToBigInt(destination_offset_low, destination_offset_high);
            const size = combineToBigInt(size_low, size_high);

            console.log(`[webgpu.js] DEBUG copyBufferToBuffer: srcOffset=${sourceOffset}, dstOffset=${destinationOffset}, size=${size}`);

            encoder.copyBufferToBuffer(
                sourceBuffer, Number(sourceOffset), 
                destinationBuffer, Number(destinationOffset), 
                Number(size)
            );
        } catch (e) {
            recordError(e.message); // Errors in void functions are recorded for Zig to check later if desired
        }
    },

    env_wgpu_command_encoder_begin_compute_pass_js: function(encoder_handle, descriptor_ptr) {
        try {
            const encoder = globalWebGPU.commandEncoders[encoder_handle];
            if (!encoder) return recordError(`CommandEncoder not found: ${encoder_handle}`);

            let jsDescriptor = undefined;
            if (descriptor_ptr) {
                jsDescriptor = {};
                const wasmMemoryU32 = new Uint32Array(globalWebGPU.memory.buffer);
                let offset_u32 = descriptor_ptr / 4;

                const label_ptr = wasmMemoryU32[offset_u32++];
                if (label_ptr) jsDescriptor.label = readStringFromMemory(label_ptr);

                const timestamp_writes_ptr = wasmMemoryU32[offset_u32++];
                const timestamp_writes_len = wasmMemoryU32[offset_u32++];

                if (timestamp_writes_len > 0 && timestamp_writes_ptr) {
                    jsDescriptor.timestampWrites = [];
                    let ts_write_offset_u32 = timestamp_writes_ptr / 4;
                    for (let i = 0; i < timestamp_writes_len; i++) {
                        const query_set_handle = wasmMemoryU32[ts_write_offset_u32++];
                        const query_index = wasmMemoryU32[ts_write_offset_u32++];
                        const location_enum_val = wasmMemoryU32[ts_write_offset_u32++];
                        
                        const querySet = globalWebGPU.querySets[query_set_handle]; // Assuming querySets array exists
                        if (!querySet) return recordError(`QuerySet not found: ${query_set_handle}`);

                        jsDescriptor.timestampWrites.push({
                            querySet: querySet,
                            queryIndex: query_index,
                            location: location_enum_val === 0 ? "beginning" : "end",
                        });
                    }
                }
            }
            const pass = encoder.beginComputePass(jsDescriptor);
            return storeComputePassEncoder(pass);
        } catch (e) {
            return recordError(e.message);
        }
    },

    env_wgpu_compute_pass_encoder_set_pipeline_js: function(pass_handle, pipeline_handle) {
        try {
            const pass = globalWebGPU.computePassEncoders[pass_handle];
            if (!pass) return recordError(`ComputePassEncoder not found: ${pass_handle}`);
            const pipeline = globalWebGPU.computePipelines[pipeline_handle];
            if (!pipeline) return recordError(`ComputePipeline not found: ${pipeline_handle}`);
            pass.setPipeline(pipeline);
        } catch (e) {
            recordError(e.message);
        }
    },

    env_wgpu_compute_pass_encoder_set_bind_group_js: function(pass_handle, index, bind_group_handle, dynamic_offsets_data_ptr, dynamic_offsets_data_start, dynamic_offsets_data_length) {
        try {
            const pass = globalWebGPU.computePassEncoders[pass_handle];
            if (!pass) return recordError(`ComputePassEncoder not found: ${pass_handle}`);
            const bindGroup = globalWebGPU.bindGroups[bind_group_handle]; // bindGroups is an object
            if (!bindGroup) return recordError(`BindGroup not found: ${bind_group_handle}`);

            if (dynamic_offsets_data_ptr && dynamic_offsets_data_length > 0) {
                const wasmMemoryU32 = new Uint32Array(globalWebGPU.memory.buffer);
                // dynamic_offsets_data_start is likely 0 if ptr is base of a new array from Zig for just these offsets.
                // It is specified in bytes by some specs or element count by others. Here it is element count into wasmMemoryU32.
                // Let's assume dynamic_offsets_data_ptr is the actual pointer to the data in wasm memory.
                const offsets = wasmMemoryU32.subarray(dynamic_offsets_data_ptr / 4, dynamic_offsets_data_ptr / 4 + dynamic_offsets_data_length);
                pass.setBindGroup(index, bindGroup, offsets);
            } else {
                pass.setBindGroup(index, bindGroup);
            }
        } catch (e) {
            recordError(e.message);
        }
    },

    env_wgpu_compute_pass_encoder_dispatch_workgroups_js: function(pass_handle, workgroup_count_x, workgroup_count_y, workgroup_count_z) {
        try {
            const pass = globalWebGPU.computePassEncoders[pass_handle];
            if (!pass) return recordError(`ComputePassEncoder not found: ${pass_handle}`);
            pass.dispatchWorkgroups(workgroup_count_x, workgroup_count_y, workgroup_count_z);
        } catch (e) {
            recordError(e.message);
        }
    },

    env_wgpu_compute_pass_encoder_dispatch_workgroups_indirect_js: function(pass_handle, indirect_buffer_handle, indirect_offset_low, indirect_offset_high) {
        try {
            const pass = globalWebGPU.computePassEncoders[pass_handle];
            if (!pass) return recordError(`ComputePassEncoder not found: ${pass_handle}`);
            const indirectBuffer = globalWebGPU.buffers[indirect_buffer_handle];
            if (!indirectBuffer) return recordError(`Indirect buffer not found: ${indirect_buffer_handle}`);
            const indirectOffset = combineToBigInt(indirect_offset_low, indirect_offset_high);
            pass.dispatchWorkgroupsIndirect(indirectBuffer, Number(indirectOffset));
        } catch (e) {
            recordError(e.message);
        }
    },
    
    env_wgpu_compute_pass_encoder_write_timestamp_js: function(pass_handle, query_set_handle, query_index) {
        try {
            const pass = globalWebGPU.computePassEncoders[pass_handle];
            if (!pass) return recordError(`ComputePassEncoder not found: ${pass_handle}`);
            const querySet = globalWebGPU.querySets[query_set_handle]; // Assuming querySets array exists
            if (!querySet) return recordError(`QuerySet not found: ${query_set_handle}`);
            
            // The `particle_sim.html` uses timestampWrites in the descriptor.
            // This explicit call is for completeness or if other use cases need it.
            if (typeof pass.writeTimestamp === 'function') {
                 pass.writeTimestamp(querySet, query_index);
            } else {
                console.warn("[webgpu.js] computePassEncoder.writeTimestamp not available or not called due to descriptor usage.")
            }
        } catch (e) {
            recordError(e.message);
        }
    },

    env_wgpu_compute_pass_encoder_end_js: function(pass_handle) {
        try {
            const pass = globalWebGPU.computePassEncoders[pass_handle];
            if (!pass) return recordError(`ComputePassEncoder not found: ${pass_handle}`);
            pass.end();
            // Invalidate the handle on JS side as the pass is ended
            if (pass_handle > 0 && pass_handle < globalWebGPU.computePassEncoders.length) {
                globalWebGPU.computePassEncoders[pass_handle] = null;
            }
        } catch (e) {
            recordError(e.message);
        }
    },

    // Render Pass will go here

    env_wgpu_command_encoder_begin_render_pass_js: function(encoder_handle, descriptor_ptr) {
        try {
            const encoder = globalWebGPU.commandEncoders[encoder_handle];
            if (!encoder) return recordError(`CommandEncoder not found: ${encoder_handle}`);
            if (!descriptor_ptr) return recordError("RenderPassDescriptor pointer is null");

            const wasmMemoryU32 = new Uint32Array(globalWebGPU.memory.buffer);
            const wasmMemoryU8 = new Uint8Array(globalWebGPU.memory.buffer);
            const wasmMemoryF64 = new Float64Array(globalWebGPU.memory.buffer);
            let offset_u32 = descriptor_ptr / 4;

            const jsDescriptor = {};
            const label_ptr = wasmMemoryU32[offset_u32++];
            if (label_ptr) jsDescriptor.label = readStringFromMemory(label_ptr);

            const color_attachments_ptr = wasmMemoryU32[offset_u32++];
            const color_attachments_len = wasmMemoryU32[offset_u32++];
            jsDescriptor.colorAttachments = [];

            const ZIG_LOAD_OP_TO_JS = { 0: "load", 1: "clear" };
            const ZIG_STORE_OP_TO_JS = { 0: "store", 1: "discard" };

            let ca_offset_bytes = color_attachments_ptr;
            for (let i = 0; i < color_attachments_len; i++) {
                const jsAttachment = {};
                
                // Zig RenderPassColorAttachment struct layout:
                // view: TextureView (u32, offset 0)
                // resolve_target: TextureView (u32, offset 4)
                // resolve_target_is_present: bool (1 byte, offset 8)
                // padding (3 bytes, offset 9-11)
                // clear_value: ?*const Color (8 bytes, offset 16-23, pointer aligned)
                // load_op: GPULoadOp (u32, offset 24)
                // store_op: GPUStoreOp (u32, offset 28)
                // Total size: 32 bytes
                
                const view_handle = wasmMemoryU32[ca_offset_bytes / 4];
                jsAttachment.view = globalWebGPU.textureViews[view_handle];
                if (!jsAttachment.view) return recordError(`TextureView not found for colorAttachment ${i}: handle ${view_handle}`);

                const resolve_target_handle = wasmMemoryU32[(ca_offset_bytes + 4) / 4];
                const resolve_target_is_present = wasmMemoryU8[ca_offset_bytes + 8] !== 0;
                if (resolve_target_is_present && resolve_target_handle) {
                    jsAttachment.resolveTarget = globalWebGPU.textureViews[resolve_target_handle];
                    if (!jsAttachment.resolveTarget) return recordError(`Resolve Target TextureView not found for colorAttachment ${i}: handle ${resolve_target_handle}`);
                }

                // Read clear_value pointer (8 bytes at offset 16)
                // Fixed struct alignment: clear_value is now at offset 16 (not 12)
                const clear_value_ptr_low = wasmMemoryU32[(ca_offset_bytes + 16) / 4];
                const clear_value_ptr_high = wasmMemoryU32[(ca_offset_bytes + 20) / 4];
                const clear_value_ptr = Number(combineToBigInt(clear_value_ptr_low, clear_value_ptr_high));
                
                // Only log debug info for problematic clear values
                if (clear_value_ptr > 0 && clear_value_ptr < 1000) {
                    console.log(`[webgpu.js] DEBUG clearValue: ptr_low=${clear_value_ptr_low}, ptr_high=${clear_value_ptr_high}, ptr=${clear_value_ptr}`);
                }
                
                // Check for valid pointer (not null, not out of bounds)
                if (clear_value_ptr && clear_value_ptr > 0 && clear_value_ptr < (globalWebGPU.memory.buffer.byteLength - 32)) {
                    let cv_offset_f64 = clear_value_ptr / 8; // Color struct is 4 * f64
                    // Additional bounds check for the Color struct (4 f64 values = 32 bytes)
                    if (cv_offset_f64 + 3 < wasmMemoryF64.length) {
                        const r = wasmMemoryF64[cv_offset_f64];
                        const g = wasmMemoryF64[cv_offset_f64 + 1];
                        const b = wasmMemoryF64[cv_offset_f64 + 2];
                        const a = wasmMemoryF64[cv_offset_f64 + 3];
                        
                        // Only log components if they seem problematic
                        if (isNaN(r) || isNaN(g) || isNaN(b) || isNaN(a)) {
                            console.log(`[webgpu.js] DEBUG clearValue components: r=${r}, g=${g}, b=${b}, a=${a}`);
                        }
                        
                        jsAttachment.clearValue = { r, g, b, a };
                    } else {
                        console.warn(`[webgpu.js] Clear value pointer ${clear_value_ptr} (f64 offset ${cv_offset_f64}) out of bounds. Memory length: ${wasmMemoryF64.length}`);
                        jsAttachment.clearValue = { r: 0.1, g: 0.1, b: 0.2, a: 1.0 }; // Default dark blue
                    }
                } else {
                    // No clear value pointer provided, use default clear color
                    jsAttachment.clearValue = { r: 0.1, g: 0.1, b: 0.2, a: 1.0 }; // Default dark blue
                }
                
                // Fixed struct alignment: load_op and store_op are now at offsets 24 and 28 
                const loadOpValue = wasmMemoryU32[(ca_offset_bytes + 24) / 4];
                let storeOpValue = wasmMemoryU32[(ca_offset_bytes + 28) / 4]; // Original offset
                
                // Use the value that makes sense (0 or 1), otherwise default to "store"
                if (!(storeOpValue === 0 || storeOpValue === 1)) {
                    storeOpValue = 0; // Default to "store"
                }
                
                jsAttachment.loadOp = ZIG_LOAD_OP_TO_JS[loadOpValue];
                jsAttachment.storeOp = ZIG_STORE_OP_TO_JS[storeOpValue];
                
                if (!jsAttachment.loadOp || !jsAttachment.storeOp) {
                    console.error(`[webgpu.js] ERROR: loadOp or storeOp mapping failed. loadOp=${jsAttachment.loadOp}, storeOp=${jsAttachment.storeOp}`);
                    return recordError(`Invalid loadOp (${loadOpValue}) or storeOp (${storeOpValue}) value in render pass color attachment`);
                }
                
                jsDescriptor.colorAttachments.push(jsAttachment);
                ca_offset_bytes += 32; // Size of RenderPassColorAttachment struct: 32 bytes
            }

            const depth_stencil_attachment_ptr = wasmMemoryU32[offset_u32++];
            if (depth_stencil_attachment_ptr) {
                // Basic reading, assuming only view for now as per particle_sim.html
                const ds_view_handle = wasmMemoryU32[depth_stencil_attachment_ptr / 4];
                const ds_view = globalWebGPU.textureViews[ds_view_handle];
                if (!ds_view) return recordError(`TextureView for depthStencilAttachment not found: handle ${ds_view_handle}`);
                jsDescriptor.depthStencilAttachment = { view: ds_view }; 
                // Full parsing of RenderPassDepthStencilAttachment would go here if used
            }

            const occlusion_query_set_handle = wasmMemoryU32[offset_u32++];
            if (occlusion_query_set_handle) {
                jsDescriptor.occlusionQuerySet = globalWebGPU.querySets[occlusion_query_set_handle];
                 if (!jsDescriptor.occlusionQuerySet) return recordError(`OcclusionQuerySet not found: handle ${occlusion_query_set_handle}`);
            }

            const timestamp_writes_ptr = wasmMemoryU32[offset_u32++];
            if (timestamp_writes_ptr) {
                let tw_offset_u32 = timestamp_writes_ptr / 4;
                const query_set_handle = wasmMemoryU32[tw_offset_u32++];
                const beginning_index = wasmMemoryU32[tw_offset_u32++]; // Assuming 0xFFFFFFFF from Zig if null
                const end_index = wasmMemoryU32[tw_offset_u32++];       // Assuming 0xFFFFFFFF from Zig if null

                const querySet = globalWebGPU.querySets[query_set_handle];
                if (!querySet) return recordError(`QuerySet for timestampWrites not found: ${query_set_handle}`);
                jsDescriptor.timestampWrites = { querySet: querySet };
                if (beginning_index !== 0xFFFFFFFF) jsDescriptor.timestampWrites.beginningOfPassWriteIndex = beginning_index;
                if (end_index !== 0xFFFFFFFF) jsDescriptor.timestampWrites.endOfPassWriteIndex = end_index;
            }
            
            const pass = encoder.beginRenderPass(jsDescriptor);
            return storeRenderPassEncoder(pass);
        } catch (e) {
            return recordError(e.message);
        }
    },

    env_wgpu_render_pass_encoder_set_pipeline_js: function(pass_handle, pipeline_handle) {
        try {
            const pass = globalWebGPU.renderPassEncoders[pass_handle];
            if (!pass) return recordError(`RenderPassEncoder not found: ${pass_handle}`);
            const pipeline = globalWebGPU.renderPipelines[pipeline_handle];
            if (!pipeline) return recordError(`RenderPipeline not found: ${pipeline_handle}`);
            pass.setPipeline(pipeline);
        } catch (e) {
            recordError(e.message);
        }
    },

    env_wgpu_render_pass_encoder_set_bind_group_js: function(pass_handle, index, bind_group_handle, dynamic_offsets_data_ptr, dynamic_offsets_data_start, dynamic_offsets_data_length) {
        try {
            const pass = globalWebGPU.renderPassEncoders[pass_handle];
            if (!pass) return recordError(`RenderPassEncoder not found: ${pass_handle}`);
            const bindGroup = globalWebGPU.bindGroups[bind_group_handle];
            if (!bindGroup) return recordError(`BindGroup not found: ${bind_group_handle}`);

            if (dynamic_offsets_data_ptr && dynamic_offsets_data_length > 0) {
                const wasmMemoryU32 = new Uint32Array(globalWebGPU.memory.buffer);
                const offsets = wasmMemoryU32.subarray(dynamic_offsets_data_ptr / 4, dynamic_offsets_data_ptr / 4 + dynamic_offsets_data_length);
                pass.setBindGroup(index, bindGroup, offsets);
            } else {
                pass.setBindGroup(index, bindGroup);
            }
        } catch (e) {
            recordError(e.message);
        }
    },

    env_wgpu_render_pass_encoder_set_vertex_buffer_js: function(pass_handle, slot, buffer_handle, offset, size) {
        // SetVertexBuffer function - working correctly now!
        
        try {
            const pass = globalWebGPU.renderPassEncoders[pass_handle];
            if (!pass) return recordError(`RenderPassEncoder not found: ${pass_handle}`);
            const buffer = buffer_handle ? globalWebGPU.buffers[buffer_handle] : null;
            if (buffer_handle && !buffer) return recordError(`VertexBuffer not found: ${buffer_handle}`);
            
            // Convert offset and size to safe JavaScript numbers
            // Note: Zig u64 values may come as JavaScript BigInt or Number
            let offsetNum = 0;
            let sizeParam = undefined;
            
            // Convert offset and size parameters properly
            if (typeof offset === 'bigint') {
                offsetNum = Number(offset);
            } else if (typeof offset === 'number') {
                offsetNum = offset;
            }
            
            if (typeof size === 'bigint') {
                // Check if this is WHOLE_SIZE (0xffffffffffffffff or -1 as BigInt)
                if (size === 0xffffffffffffffffn || size === -1n) {
                    sizeParam = undefined; // WebGPU undefined means whole buffer
                } else {
                    sizeParam = Number(size);
                }
            } else if (typeof size === 'number') {
                // Check for WHOLE_SIZE as a regular number
                if (size === 0xffffffffffffffff || size === -1) {
                    sizeParam = undefined;
                } else {
                    sizeParam = size;
                }
            }

            if (buffer) {
                if (sizeParam !== undefined) {
                    pass.setVertexBuffer(slot, buffer, offsetNum, sizeParam);
                } else {
                    pass.setVertexBuffer(slot, buffer, offsetNum); // Omit size for whole buffer
                }
            } else {
                pass.setVertexBuffer(slot, null); // Unsetting buffer
            }
        } catch (e) {
            recordError(e.message);
        }
    },

    env_wgpu_render_pass_encoder_set_index_buffer_js: function(pass_handle, buffer_handle, index_format_enum, offset, size) {
        try {
            const pass = globalWebGPU.renderPassEncoders[pass_handle];
            if (!pass) return recordError(`RenderPassEncoder not found: ${pass_handle}`);
            const buffer = globalWebGPU.buffers[buffer_handle];
            if (!buffer) return recordError(`IndexBuffer not found: ${buffer_handle}`);

            const ZIG_INDEX_FORMAT_TO_JS = { 0: "uint16", 1: "uint32" };
            const indexFormat = ZIG_INDEX_FORMAT_TO_JS[index_format_enum];
            if(!indexFormat) return recordError(`Invalid index format: ${index_format_enum}`);

            // Convert offset and size to safe JavaScript numbers
            let offsetNum = 0;
            let sizeParam = 0;
            
            if (typeof offset === 'bigint') {
                offsetNum = Number(offset);
            } else if (typeof offset === 'number') {
                offsetNum = offset;
            }
            
            if (typeof size === 'bigint') {
                // Check if this is WHOLE_SIZE (0xffffffffffffffff or -1 as BigInt)
                if (size === 0xffffffffffffffffn || size === -1n) {
                    sizeParam = undefined; // WebGPU undefined means whole buffer
                } else {
                    sizeParam = Number(size);
                }
            } else if (typeof size === 'number') {
                // Check for WHOLE_SIZE as a regular number (if it fits in Number range)
                if (size === 0xffffffffffffffff || size === -1) {
                    sizeParam = undefined;
                } else {
                    sizeParam = size;
                }
            }

            if (sizeParam !== undefined) {
                pass.setIndexBuffer(buffer, indexFormat, offsetNum, sizeParam);
            } else {
                pass.setIndexBuffer(buffer, indexFormat, offsetNum); // Omit size for whole buffer
            }
        } catch (e) {
            recordError(e.message);
        }
    },

    env_wgpu_render_pass_encoder_draw_js: function(pass_handle, vertex_count, instance_count, first_vertex, first_instance) {
        try {
            const pass = globalWebGPU.renderPassEncoders[pass_handle];
            if (!pass) return recordError(`RenderPassEncoder not found: ${pass_handle}`);
            pass.draw(vertex_count, instance_count, first_vertex, first_instance);
        } catch (e) {
            recordError(e.message);
        }
    },

    env_wgpu_render_pass_encoder_draw_indexed_js: function(pass_handle, index_count, instance_count, first_index, base_vertex, first_instance) {
        try {
            const pass = globalWebGPU.renderPassEncoders[pass_handle];
            if (!pass) return recordError(`RenderPassEncoder not found: ${pass_handle}`);
            pass.drawIndexed(index_count, instance_count, first_index, base_vertex, first_instance);
        } catch (e) {
            recordError(e.message);
        }
    },

    env_wgpu_render_pass_encoder_draw_indirect_js: function(pass_handle, indirect_buffer_handle, indirect_offset_low, indirect_offset_high) {
        try {
            const pass = globalWebGPU.renderPassEncoders[pass_handle];
            if (!pass) return recordError(`RenderPassEncoder not found: ${pass_handle}`);
            const indirectBuffer = globalWebGPU.buffers[indirect_buffer_handle];
            if (!indirectBuffer) return recordError(`IndirectBuffer not found for drawIndirect: ${indirect_buffer_handle}`);
            const indirectOffset = combineToBigInt(indirect_offset_low, indirect_offset_high);
            pass.drawIndirect(indirectBuffer, Number(indirectOffset));
        } catch (e) {
            recordError(e.message);
        }
    },

    env_wgpu_render_pass_encoder_draw_indexed_indirect_js: function(pass_handle, indirect_buffer_handle, indirect_offset_low, indirect_offset_high) {
        try {
            const pass = globalWebGPU.renderPassEncoders[pass_handle];
            if (!pass) return recordError(`RenderPassEncoder not found: ${pass_handle}`);
            const indirectBuffer = globalWebGPU.buffers[indirect_buffer_handle];
            if (!indirectBuffer) return recordError(`IndirectBuffer not found for drawIndexedIndirect: ${indirect_buffer_handle}`);
            const indirectOffset = combineToBigInt(indirect_offset_low, indirect_offset_high);
            pass.drawIndexedIndirect(indirectBuffer, Number(indirectOffset));
        } catch (e) {
            recordError(e.message);
        }
    },

    env_wgpu_render_pass_encoder_write_timestamp_js: function(pass_handle, query_set_handle, query_index) {
        try {
            const pass = globalWebGPU.renderPassEncoders[pass_handle];
            if (!pass) return recordError(`RenderPassEncoder not found: ${pass_handle}`);
            const querySet = globalWebGPU.querySets[query_set_handle];
            if (!querySet) return recordError(`QuerySet not found for writeTimestamp: ${query_set_handle}`);
            
            if (typeof pass.writeTimestamp === 'function') {
                pass.writeTimestamp(querySet, query_index);
            } else {
                console.warn("[webgpu.js] renderPassEncoder.writeTimestamp not available or not called due to descriptor usage.");
            }
        } catch (e) {
            recordError(e.message);
        }
    },

    env_wgpu_render_pass_encoder_end_js: function(pass_handle) {
        try {
            const pass = globalWebGPU.renderPassEncoders[pass_handle];
            if (!pass) return recordError(`RenderPassEncoder not found: ${pass_handle}`);
            pass.end();
            if (pass_handle > 0 && pass_handle < globalWebGPU.renderPassEncoders.length) {
                globalWebGPU.renderPassEncoders[pass_handle] = null;
            }
        } catch (e) {
            recordError(e.message);
        }
    },

    // Command Finishing and Submission will go here

    env_wgpu_command_encoder_finish_js: function(encoder_handle, descriptor_ptr) {
        try {
            const encoder = globalWebGPU.commandEncoders[encoder_handle];
            if (!encoder) return recordError(`CommandEncoder not found for finish: ${encoder_handle}`);

            let jsDescriptor = undefined;
            if (descriptor_ptr) {
                const wasmMemoryU32 = new Uint32Array(globalWebGPU.memory.buffer);
                const label_ptr = wasmMemoryU32[descriptor_ptr / 4];
                if (label_ptr) {
                    jsDescriptor = { label: readStringFromMemory(label_ptr) };
                }
            }
            const commandBuffer = encoder.finish(jsDescriptor);
            if (encoder_handle > 0 && encoder_handle < globalWebGPU.commandEncoders.length) {
                globalWebGPU.commandEncoders[encoder_handle] = null; // Encoder is consumed
            }
            return storeCommandBuffer(commandBuffer);
        } catch (e) {
            return recordError(e.message);
        }
    },

    env_wgpu_queue_submit_js: function(queue_handle, command_buffers_ptr, command_buffers_len) {
        try {
            const queue = globalWebGPU.queues[queue_handle];
            if (!queue) return recordError(`Queue not found for submit: ${queue_handle}`);
            if (!command_buffers_ptr || command_buffers_len === 0) {
                return; 
            }

            const wasmMemoryU32 = new Uint32Array(globalWebGPU.memory.buffer);
            const jsCommandBuffers = [];
            let cb_ptr_offset = command_buffers_ptr / 4;
            for (let i = 0; i < command_buffers_len; i++) {
                const cb_handle = wasmMemoryU32[cb_ptr_offset++];
                const commandBuffer = globalWebGPU.commandBuffers[cb_handle];
                if (!commandBuffer) return recordError(`CommandBuffer not found in list for submit: handle ${cb_handle}`);
                jsCommandBuffers.push(commandBuffer);
                // CommandBuffers are consumed after submit, mark them as null in our store
                // if (cb_handle > 0 && cb_handle < globalWebGPU.commandBuffers.length) { 
                //     globalWebGPU.commandBuffers[cb_handle] = null;
                // }
            }
            queue.submit(jsCommandBuffers);
        } catch (e) {
            recordError(e.message);
        }
    },

    env_wgpu_queue_on_submitted_work_done_js: function(queue_handle) {
        try {
            const queue = globalWebGPU.queues[queue_handle];
            if (!queue) {
                // Cannot call recordError AND then the Zig callback easily without promise ID system.
                // So, if queue is invalid, we try to call Zig callback with error status directly.
                console.error(`[webgpu.js] Invalid queue handle for onSubmittedWorkDone: ${queue_handle}`);
                if (globalWebGPU.wasmExports && globalWebGPU.wasmExports.zig_on_queue_work_done) {
                    globalWebGPU.wasmExports.zig_on_queue_work_done(queue_handle, 0); // 0 for error status
                } else {
                    console.error("[webgpu.js] Wasm exports not ready for onSubmittedWorkDone error callback.");
                }
                return;
            }

            queue.onSubmittedWorkDone()
                .then(() => {
                    if (globalWebGPU.wasmExports && globalWebGPU.wasmExports.zig_on_queue_work_done) {
                        globalWebGPU.wasmExports.zig_on_queue_work_done(queue_handle, 1); // 1 for success status
                    } else {
                        console.error("[webgpu.js] Wasm exports not ready for onSubmittedWorkDone success callback.");
                    }
                })
                .catch(err => {
                    recordError(`Error in onSubmittedWorkDone for queue ${queue_handle}: ${err.message}`);
                    if (globalWebGPU.wasmExports && globalWebGPU.wasmExports.zig_on_queue_work_done) {
                        globalWebGPU.wasmExports.zig_on_queue_work_done(queue_handle, 0); // 0 for error status
                    } else {
                        console.error("[webgpu.js] Wasm exports not ready for onSubmittedWorkDone failure callback.");
                    }
                });
        } catch (e) {
            // This catch is for immediate errors in setting up the promise, not for the promise resolution itself.
            recordError(`Immediate error setting up onSubmittedWorkDone for queue ${queue_handle}: ${e.message}`);
            if (globalWebGPU.wasmExports && globalWebGPU.wasmExports.zig_on_queue_work_done) {
                globalWebGPU.wasmExports.zig_on_queue_work_done(queue_handle, 0); // 0 for error status
            } else {
                console.error("[webgpu.js] Wasm exports not ready for onSubmittedWorkDone setup failure callback.");
            }
        }
    },

    env_wgpu_configure_canvas_js: function(device_handle, format_enum_val) {
        const device = globalWebGPU.devices[device_handle];
        if (!device) {
            return recordError(`Invalid device handle for configureCanvas: ${device_handle}`);
        }
        if (!globalWebGPU.canvas) {
            return recordError("Canvas not available to configure.");
        }
        try {
            const context = globalWebGPU.canvas.getContext('webgpu');
            if (!context) {
                return recordError("Failed to get WebGPU context from canvas.");
            }
            const format = mapTextureFormatZigToJs(format_enum_val);
            context.configure({
                device: device,
                format: format,
                alphaMode: 'opaque',
            });
            globalWebGPU.canvasContext = context;
            return 1; // Success
        } catch (e) {
            return recordError(`Error configuring canvas: ${e.message}`);
        }
    },

    env_wgpu_get_current_texture_view_js: function() {
        if (!globalWebGPU.canvasContext) {
            return recordError("Canvas context not configured or available.");
        }
        try {
            const texture = globalWebGPU.canvasContext.getCurrentTexture();
            const view = texture.createView();
            return storeTextureView(view);
        } catch (e) {
            return recordError(`Error getting current texture view: ${e.message}`);
        }
    },

    env_wgpu_device_create_sampler_js: function(device_handle, descriptor_ptr) {
        try {
            const device = globalWebGPU.devices[device_handle];
            if (!device) return recordError(`Device not found for createSampler: ${device_handle}`);

            let jsDescriptor = {}; // Default sampler if descriptor_ptr is null

            if (descriptor_ptr) {
                const wasmMemoryU32 = new Uint32Array(globalWebGPU.memory.buffer);
                const wasmMemoryF32 = new Float32Array(globalWebGPU.memory.buffer);
                const wasmMemoryU16 = new Uint16Array(globalWebGPU.memory.buffer);
                let offset_u32 = descriptor_ptr / 4;

                // SamplerDescriptor layout from webgpu.zig:
                // label: ?[*:0]const u8 = null, (ptr, offset 0)
                // address_mode_u: GPUAddressMode = .clamp_to_edge, (u32, offset 8 after label ptr)
                // address_mode_v: GPUAddressMode = .clamp_to_edge, (u32, offset 12)
                // address_mode_w: GPUAddressMode = .clamp_to_edge, (u32, offset 16)
                // mag_filter: GPUFilterMode = .nearest, (u32, offset 20)
                // min_filter: GPUFilterMode = .nearest, (u32, offset 24)
                // mipmap_filter: GPUMipmapFilterMode = .nearest, (u32, offset 28)
                // lod_min_clamp: f32 = 0.0, (f32, offset 32)
                // lod_max_clamp: f32 = 32.0, (f32, offset 36)
                // compare: ?GPUCompareFunction = null, (u32 for enum value + u8 for has_value, say offset 40 for value, 44 for has_value)
                // max_anisotropy: u16 = 1 (u16, offset 48 assuming compare took 8 bytes with padding)

                const label_ptr = wasmMemoryU32[offset_u32++]; // Reads label ptr (descriptor_ptr + 0)
                // offset_u32 is now (descriptor_ptr/4) + 1. For next field (address_mode_u), which is at byte offset 8 from desc start (if label_ptr is 8 bytes)
                // If label_ptr is 4 bytes, then addr_mode_u is at byte offset 4.
                // Let's assume Zig pointer is 4 bytes for wasm32.
                // label: ptr (4 bytes)
                // address_mode_u (4 bytes)
                // address_mode_v (4 bytes)
                // address_mode_w (4 bytes)
                // mag_filter (4 bytes)
                // min_filter (4 bytes)
                // mipmap_filter (4 bytes)
                // lod_min_clamp (4 bytes)
                // lod_max_clamp (4 bytes)
                // compare_value (4 bytes) + compare_has_value (1 byte, padded to 4 for alignment? -> total 8 bytes for optional compare)
                // max_anisotropy (2 bytes)

                if (label_ptr) jsDescriptor.label = readStringFromMemory(label_ptr);

                jsDescriptor.addressModeU = ZIG_ADDRESS_MODE_TO_JS[wasmMemoryU32[offset_u32++]];
                jsDescriptor.addressModeV = ZIG_ADDRESS_MODE_TO_JS[wasmMemoryU32[offset_u32++]];
                jsDescriptor.addressModeW = ZIG_ADDRESS_MODE_TO_JS[wasmMemoryU32[offset_u32++]];
                jsDescriptor.magFilter = ZIG_FILTER_MODE_TO_JS[wasmMemoryU32[offset_u32++]];
                jsDescriptor.minFilter = ZIG_FILTER_MODE_TO_JS[wasmMemoryU32[offset_u32++]];
                jsDescriptor.mipmapFilter = ZIG_MIPMAP_FILTER_MODE_TO_JS[wasmMemoryU32[offset_u32++]];
                jsDescriptor.lodMinClamp = wasmMemoryF32[offset_u32++]; 
                jsDescriptor.lodMaxClamp = wasmMemoryF32[offset_u32++];
                
                const compare_val = wasmMemoryU32[offset_u32++];
                // Assuming Zig passes compare: ?GPUCompareFunction as two fields in extern struct if not using a more complex optional representation:
                // compare_value: u32, compare_is_present: bool (u8/u32)
                // For Zig `?EnumType = null`, if it's a direct field, it needs a presence indicator.
                // Let's assume Zig wrapper ensures `compare_val` is a special value (e.g. MAX_U32) if null,
                // or descriptor_ptr itself implies if it's a default or full descriptor.
                // The current SamplerDescriptor in Zig has `compare: ?GPUCompareFunction = null`.
                // If Zig just passes the value of the enum (or 0/sentinel for null), need to check that sentinel carefully.
                // The ZIG_COMPARE_FUNCTION_TO_JS handles a default if value not found.
                // If we assume Zig passes 0 if the optional compare function is not set (and 0 is not a valid compare func for this map)
                // This mapping needs to be robust to `undefined` if 0 is passed for null.
                // The `ZIG_COMPARE_FUNCTION_TO_JS` mapping does not have 0 as a valid input for 'never' (it starts 'never' at 0).
                // This is fine. If Zig sends 0 for no-compare, and our map for 0 is 'never', WebGPU will error if 'never' is used on non-comparison sampler.
                // WebGPU API: `compare` is only valid for comparison samplers.
                // So, if Zig `compare` field is null, we should NOT set `jsDescriptor.compare`.
                // A robust way is for Zig to pass a boolean flag for optional fields in extern structs.
                // For now, assuming if `compare_val` maps to something via `ZIG_COMPARE_FUNCTION_TO_JS` it's used.
                // This will require care on Zig side. A better way: Zig sends specific sentinel for null, or a has_value byte.
                // Let's assume Zig struct will have `compare_value: u32` and `compare_has_value: bool` (u8 then padded)
                // So, after compare_val: `const compare_is_present = wasmMemoryU32[offset_u32++] !== 0;` (if bool is u32)
                // If using the `compare: ?GPUCompareFunction = null` approach from Zig, need to verify how Zig compiler handles this for extern structs.
                // Assuming for now that if compare is null in Zig, it won't be included or will be a sentinel.
                // The current Zig struct has compare: ?GPUCompareFunction = null. This means it will have a has_value byte.
                // The value itself is at offset_u32. The has_value is at (descriptor_ptr + current_byte_offset_of_has_value_field)
                // Let's adjust reading to be more explicit about struct layout for optional enum. Field order: lodMaxClamp (f32), compare_value (u32), compare_has_value (u8), max_anisotropy (u16).
                // Offset of compare_value from start of descriptor: label(4) + 6*u32_enums(24) + 2*f32_lods(8) = 36 bytes. So offset_u32 points to compare_val.
                const compare_is_present_offset_bytes = descriptor_ptr + 36 + 4; // After compare_val (u32)
                const compare_is_present = new Uint8Array(globalWebGPU.memory.buffer, compare_is_present_offset_bytes, 1)[0] !== 0;
                if (compare_is_present) {
                    jsDescriptor.compare = ZIG_COMPARE_FUNCTION_TO_JS[compare_val];
                }
                // offset_u32 was already advanced past compare_val. Now advance past compare_is_present (assuming it was padded to 4 bytes for alignment)
                offset_u32++; // Assuming compare_value (u32) and compare_is_present (u32 due to padding)
                
                // max_anisotropy is u16. It would be at byte_offset = descriptor_ptr + 36(label+enums) + 8(lods) + 8(compare_opt) = 52
                jsDescriptor.maxAnisotropy = wasmMemoryU16[ (descriptor_ptr / 2) + (52 / 2) ]; // Careful with u16 indexing from base u32 offset_ptr
                                                                                                // Simpler: use byte offset for DataView
                const max_anisotropy_offset_bytes = descriptor_ptr + 36 + 8 + 8; // Label(4)+Enums(24)+LODs(8)+CompareOpt(8 for val+flag+pad) = 52
                jsDescriptor.maxAnisotropy = new DataView(globalWebGPU.memory.buffer).getUint16(max_anisotropy_offset_bytes, true);

            } else { // No descriptor_ptr, use WebGPU defaults (which are mostly what our Zig defaults are)
                // JS default for createSampler({}) is fine.
            }

            const sampler = device.createSampler(jsDescriptor);
            return storeSampler(sampler);
        } catch (e) {
            return recordError(e.message);
        }
    },

    // Other queue functions ...

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
    3: "2d-array", 
    4: "cube", 
    5: "cube-array",
    // Add more as needed e.g. from a distinct GPUTextureViewDimension enum in Zig if created
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

const ZIG_BUFFER_BINDING_TYPE_TO_JS = {
    0: "uniform",
    1: "storage",
    2: "read-only-storage",
};
function mapBufferBindingTypeZigToJs(zigValue) {
    return ZIG_BUFFER_BINDING_TYPE_TO_JS[zigValue] || "uniform";
}

const ZIG_TEXTURE_SAMPLE_TYPE_TO_JS = {
    0: "float",
    1: "unfilterable-float",
    2: "depth",
    3: "sint",
    4: "uint",
};
function mapTextureSampleTypeZigToJs(zigValue) {
    return ZIG_TEXTURE_SAMPLE_TYPE_TO_JS[zigValue] || "float";
}

const ZIG_VERTEX_STEP_MODE_TO_JS = {
    0: "vertex",
    1: "instance",
};

const ZIG_VERTEX_FORMAT_TO_JS = {
    0: "uint8x2", 1: "uint8x4", 2: "sint8x2", 3: "sint8x4", 4: "unorm8x2", 5: "unorm8x4",
    6: "snorm8x2", 7: "snorm8x4", 8: "uint16x2", 9: "uint16x4", 10: "sint16x2", 11: "sint16x4",
    12: "unorm16x2", 13: "unorm16x4", 14: "snorm16x2", 15: "snorm16x4", 16: "float16x2", 17: "float16x4",
    18: "float32", 19: "float32x2", 20: "float32x3", 21: "float32x4",
    22: "uint32", 23: "uint32x2", 24: "uint32x3", 25: "uint32x4",
    26: "sint32", 27: "sint32x2", 28: "sint32x3", 29: "sint32x4",
    // Add all other vertex formats as they are added to Zig enum
};

const ZIG_PRIMITIVE_TOPOLOGY_TO_JS = {
    0: "point-list", 1: "line-list", 2: "line-strip", 3: "triangle-list", 4: "triangle-strip",
};

const ZIG_INDEX_FORMAT_TO_JS = {
    0: "uint16", 1: "uint32",
};

const ZIG_FRONT_FACE_TO_JS = {
    0: "ccw", 1: "cw",
};

const ZIG_CULL_MODE_TO_JS = {
    0: "none", 1: "front", 2: "back",
};

const ZIG_COMPARE_FUNCTION_TO_JS = {
    0: "never", 1: "less", 2: "equal", 3: "less-equal", 4: "greater", 5: "not-equal", 6: "greater-equal", 7: "always",
};

const ZIG_STENCIL_OP_TO_JS = {
    0: "keep", 1: "zero", 2: "replace", 3: "invert", 4: "increment-clamp", 5: "decrement-clamp", 6: "increment-wrap", 7: "decrement-wrap",
};

const ZIG_BLEND_OP_TO_JS = {
    0: "add", 1: "subtract", 2: "reverse-subtract", 3: "min", 4: "max",
};

const ZIG_BLEND_FACTOR_TO_JS = {
    0: "zero", 1: "one", 2: "src", 3: "one-minus-src", 4: "src-alpha", 5: "one-minus-src-alpha", 
    6: "dst", 7: "one-minus-dst", 8: "dst-alpha", 9: "one-minus-dst-alpha", 
    10: "src-alpha-saturated", 11: "constant", 12: "one-minus-constant",
};

const ZIG_ADDRESS_MODE_TO_JS = {
    0: "clamp-to-edge",
    1: "repeat",
    2: "mirror-repeat"
};

const ZIG_FILTER_MODE_TO_JS = {
    0: "nearest",
    1: "linear"
};

const ZIG_MIPMAP_FILTER_MODE_TO_JS = {
    0: "nearest",
    1: "linear"
};

// It's important that wasmInstance is set on webGPUNativeImports after Wasm instantiation.
// Example: webGPUNativeImports.wasmInstance = instance;
// And webGPUNativeImports.wasmMemory = instance.exports.memory;

function readStringFromMemory(ptr, len = 0) {
    const wasmMemoryU8 = new Uint8Array(globalWebGPU.memory.buffer);
    if (len === 0) { // Assume null-terminated if len is not provided
        let end = ptr;
        while (wasmMemoryU8[end] !== 0) {
            end++;
        }
        len = end - ptr;
    }
    return new TextDecoder().decode(wasmMemoryU8.subarray(ptr, ptr + len));
}

function recordError(message) {
    console.error("[webgpu.js]", message);
    const M = globalWebGPU.errorBuffer;
    const len = new TextEncoder().encodeInto(message, M).written;
    globalWebGPU.errorBufferLen = len;
    return 0; // Standard error return for FFI calls
}

function readBindGroupLayoutDescriptorFromMemory(descriptor_ptr) {
    globalWebGPU.errorBufferLen = 0; // Clear previous error for this read operation
    const wasmMemoryU32 = new Uint32Array(globalWebGPU.memory.buffer);
    let offset_u32 = descriptor_ptr / 4; // Current offset in u32 words

    const label_ptr = wasmMemoryU32[offset_u32++];
    const entries_ptr = wasmMemoryU32[offset_u32++];
    const entries_len = wasmMemoryU32[offset_u32++];

    const jsDescriptor = {};
    if (label_ptr) {
        jsDescriptor.label = readStringFromMemory(label_ptr);
    }

    jsDescriptor.entries = [];
    const js_entries_internal = {}; 

    let current_bgl_entry_ptr_bytes = entries_ptr;

    // Size estimations for Zig structs (for calculating stride):
    // BufferBindingLayout: type(u32), has_dynamic_offset(bool->u8), pad(3), min_binding_size(u64) = 4+1+3+8 = 16 bytes
    // TextureBindingLayout: sample_type(u32), view_dimension(u32), multisampled(bool->u8), pad(3) = 4+4+1+3 = 12 bytes, but might align to 16.
    // BindGroupLayoutEntry: binding(u32) + visibility(u32) + resource_type(u32) + layout(union)
    //                       = 4 + 4 + 4 + size_of_active_union_member. Union is aligned to largest member (8 for u64 in BufferBindingLayout).
    // So, entry is 12 bytes + layout. Total size must be multiple of 8.
    // If buffer: 12 + 16 = 28. Padded to 32.
    // If texture: 12 + 12 = 24. Stays 24.

    for (let i = 0; i < entries_len; i++) {
        let entry_base_offset_u32 = current_bgl_entry_ptr_bytes / 4;
        const jsEntry = {};
        
        jsEntry.binding = wasmMemoryU32[entry_base_offset_u32 + 0]; // offset 0 from entry start
        jsEntry.visibility = wasmMemoryU32[entry_base_offset_u32 + 1]; // offset 4
        const resource_type_zig_enum = wasmMemoryU32[entry_base_offset_u32 + 2]; // offset 8
        
        // The 'layout' union starts after binding, visibility, and resource_type fields
        const layout_union_offset_bytes = current_bgl_entry_ptr_bytes + 12; // 3 * u32 = 12 bytes
        let current_entry_size_bytes = 12; // Base size (binding + visibility + resource_type)

        // BGLResourceType enum from Zig:
        // buffer = 0, texture = 1, sampler = 2, storage_texture = 3, external_texture = 4
        switch (resource_type_zig_enum) {
            case 0: // buffer
                jsEntry.buffer = readBufferBindingLayoutFromMemory(layout_union_offset_bytes);
                if (globalWebGPU.errorBufferLen > 0) return null; // Error in sub-reader
                current_entry_size_bytes += 16; // Size of BufferBindingLayout
                if (current_entry_size_bytes % 8 !== 0) { // Ensure alignment to 8 for the whole entry
                    current_entry_size_bytes += 8 - (current_entry_size_bytes % 8);
                }
                break;
            case 1: // texture
                jsEntry.texture = readTextureBindingLayoutFromMemory(layout_union_offset_bytes);
                if (globalWebGPU.errorBufferLen > 0) return null; // Error in sub-reader
                current_entry_size_bytes += 16; // Size of TextureBindingLayout (12 bytes + 4 padding for 8-byte alignment)
                if (current_entry_size_bytes % 8 !== 0) { // Ensure alignment to 8 for the whole entry
                    current_entry_size_bytes += 8 - (current_entry_size_bytes % 8);
                }
                break;
            case 2: // sampler
                recordError(`SamplerBindingLayout in BGL not yet implemented for binding ${jsEntry.binding}`); return null;
                // current_entry_size_bytes += SIZEOF_SAMPLER_LAYOUT; // Placeholder
                break;
            case 3: // storage_texture
                recordError(`StorageTextureBindingLayout in BGL not yet implemented for binding ${jsEntry.binding}`); return null;
                // current_entry_size_bytes += SIZEOF_STORAGE_TEXTURE_LAYOUT; // Placeholder
                break;
            default:
                recordError(`BGL Entry for binding ${jsEntry.binding} has unknown resource_type: ${resource_type_zig_enum}.`); return null;
        }

        jsDescriptor.entries.push(jsEntry);
        js_entries_internal[jsEntry.binding] = jsEntry; 
        current_bgl_entry_ptr_bytes += current_entry_size_bytes; // Advance by the determined size of this entry
    }
    jsDescriptor.js_entries_internal = js_entries_internal; 
    return jsDescriptor;
}

function readBufferBindingLayoutFromMemory(layout_ptr) {
    // layout_ptr is the absolute byte offset of the BufferBindingLayout struct
    // Zig extern struct layout: type(u32), has_dynamic_offset(bool), padding(3), min_binding_size(u64)
    // Total: 16 bytes with proper alignment
    const wasmMemoryView = new DataView(globalWebGPU.memory.buffer);

    const typeZig = wasmMemoryView.getUint32(layout_ptr + 0, true); // offset 0
    const hasDynamicOffsetByte = wasmMemoryView.getUint8(layout_ptr + 4); // offset 4 (bool is 1 byte)
    const hasDynamicOffset = hasDynamicOffsetByte !== 0;
    // bool is followed by 3 padding bytes due to u64 alignment requirement
    const minBindingSize = wasmMemoryView.getBigUint64(layout_ptr + 8, true); // offset 8 (after padding)

    // Debug logging for buffer binding layout (only log issues)
    // if (hasDynamicOffsetByte > 1) {
    //     console.log(`[webgpu.js] DEBUG BufferBindingLayout: type=${typeZig}, hasDynamicOffsetByte=${hasDynamicOffsetByte}, hasDynamicOffset=${hasDynamicOffset}, minBindingSize=${minBindingSize}`);
    // }
    
    const jsType = mapBufferBindingTypeZigToJs(typeZig);

    return {
        type: jsType,
        hasDynamicOffset: hasDynamicOffset,
        minBindingSize: Number(minBindingSize),
    };
}

function readTextureBindingLayoutFromMemory(layout_ptr) {
    // layout_ptr is the absolute byte offset of the TextureBindingLayout struct
    const wasmMemoryView = new DataView(globalWebGPU.memory.buffer);

    const sampleTypeZig = wasmMemoryView.getUint32(layout_ptr + 0, true); // offset 0
    const viewDimensionZig = wasmMemoryView.getUint32(layout_ptr + 4, true); // offset 4
    const multisampled = wasmMemoryView.getUint8(layout_ptr + 8) !== 0; // offset 8 (bool)
    // Similar alignment consideration for bool as in BufferBindingLayout
    // Assuming sampleType(u32), viewDimension(u32), multisampled(u32 if padded, or u8 then pad for total struct size)

    // Debug logging for texture binding layout (only log issues)
    // if (viewDimensionZig === 0 || multisampled === true) {
    //     console.log(`[webgpu.js] DEBUG TextureBindingLayout: sampleType=${sampleTypeZig}, viewDimension=${viewDimensionZig}, multisampled=${multisampled}`);
    // }

    const jsViewDimension = mapTextureViewDimensionZigToJs(viewDimensionZig);
    // if (viewDimensionZig === 0) {
    //     console.log(`[webgpu.js] DEBUG Mapped viewDimension: ${viewDimensionZig} -> ${jsViewDimension}`);
    // }

    return {
        sampleType: mapTextureSampleTypeZigToJs(sampleTypeZig),
        viewDimension: jsViewDimension, 
        multisampled: multisampled,
    };
}

function combineToBigInt(low, high) {
    return (BigInt(high) << 32n) | BigInt(low);
}
