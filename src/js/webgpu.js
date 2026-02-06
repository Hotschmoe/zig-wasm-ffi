// zig-wasm-ffi/js/webgpu.js

let wasmInstance = null;

// --- Handle Registry ---
// Zig references WebGPU objects by integer handle IDs.
const handles = {
    nextId: 1,
    map: new Map(),

    create(obj) {
        const id = this.nextId++;
        this.map.set(id, obj);
        return id;
    },

    get(id) {
        return this.map.get(id);
    },

    release(id) {
        this.map.delete(id);
    },
};

// --- WebGPU State ---
let device = null;
let adapter = null;
let context = null;
let preferredFormat = null;
let commandEncoder = null;
let renderPassEncoder = null;

// --- Setup Function ---

/**
 * Initializes the WebGPU subsystem: requests adapter/device, configures the
 * canvas context, and stores the device as handle ID 1.
 *
 * After setup completes it calls the WASM export `setDevice(1)` so the Zig
 * side knows which handle to use for the GPU device.
 *
 * @param {object} instance  The instantiated WASM module instance (with .exports).
 * @param {HTMLCanvasElement} canvasElement  The canvas to render into.
 * @returns {Promise<void>}
 */
export async function setupWebGPU(instance, canvasElement) {
    if (!instance || !instance.exports) {
        console.error("[webgpu.js] WASM instance or exports not provided to setupWebGPU.");
        return;
    }
    wasmInstance = instance;

    if (!navigator.gpu) {
        throw new Error("WebGPU is not supported in this browser.");
    }

    adapter = await navigator.gpu.requestAdapter();
    if (!adapter) {
        throw new Error("Failed to obtain a WebGPU adapter.");
    }

    device = await adapter.requestDevice();
    preferredFormat = navigator.gpu.getPreferredCanvasFormat();

    context = canvasElement.getContext("webgpu");
    context.configure({
        device,
        format: preferredFormat,
        alphaMode: "opaque",
    });

    // Device is always handle 1.
    handles.create(device);

    if (wasmInstance.exports.setDevice) {
        wasmInstance.exports.setDevice(1);
    }

    console.log("[webgpu.js] WebGPU initialized. Format:", preferredFormat);
}

// --- Blue Noise Texture Loader ---

/**
 * Loads an image from `imageUrl`, uploads it as an rgba8unorm WebGPU texture,
 * and passes the texture + view handles to the WASM export `setBlueNoiseTexture`.
 *
 * @param {object} instance  The WASM instance (with .exports).
 * @param {string} imageUrl  URL of the blue-noise PNG.
 * @returns {Promise<void>}
 */
export async function loadBlueNoiseTexture(instance, imageUrl) {
    if (!device) {
        console.error("[webgpu.js] loadBlueNoiseTexture called before setupWebGPU.");
        return;
    }

    const response = await fetch(imageUrl);
    const blob = await response.blob();
    const bitmap = await createImageBitmap(blob, { colorSpaceConversion: "none" });

    const texture = device.createTexture({
        format: "rgba8unorm",
        size: [bitmap.width, bitmap.height],
        usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST | GPUTextureUsage.RENDER_ATTACHMENT,
    });

    device.queue.copyExternalImageToTexture(
        { source: bitmap },
        { texture },
        { width: bitmap.width, height: bitmap.height },
    );

    const view = texture.createView();
    const textureHandle = handles.create(texture);
    const viewHandle = handles.create(view);

    console.log("[webgpu.js] Blue noise texture loaded:", bitmap.width, "x", bitmap.height);

    const wasm = instance || wasmInstance;
    if (wasm && wasm.exports && wasm.exports.setBlueNoiseTexture) {
        wasm.exports.setBlueNoiseTexture(textureHandle, viewHandle);
    }
}

// --- Helper: read WASM memory ---

function mem() {
    return wasmInstance.exports.memory;
}

function decodeString(ptr, len) {
    return new TextDecoder().decode(new Uint8Array(mem().buffer, ptr, len));
}

// --- Texture format enum mapping ---

const TEXTURE_FORMATS = [
    "rgba16float",     // 0
    "rgba32float",     // 1
    "bgra8unorm",      // 2
    "rgba8unorm",      // 3
    "rgba8unorm-srgb", // 4
    "depth24plus",     // 5
    "depth32float",    // 6
];

// --- env_* FFI Functions (imported by WASM as "env") ---

// === Buffer Management ===

export function env_webgpu_create_buffer(deviceId, size, usage, mappedAtCreation) {
    const dev = handles.get(deviceId);
    if (!dev) { console.error("[webgpu.js] Invalid device handle:", deviceId); return 0; }

    const buffer = dev.createBuffer({
        size: Number(size),
        usage,
        mappedAtCreation,
    });
    return handles.create(buffer);
}

export function env_webgpu_buffer_write(deviceId, bufferId, offset, dataPtr, dataLen) {
    const dev = handles.get(deviceId);
    const buffer = handles.get(bufferId);
    if (!dev || !buffer) { console.error("[webgpu.js] Invalid device or buffer handle"); return; }

    const data = new Uint8Array(mem().buffer, dataPtr, dataLen);
    dev.queue.writeBuffer(buffer, Number(offset), data);
}

export function env_webgpu_buffer_destroy(bufferId) {
    const buffer = handles.get(bufferId);
    if (buffer) {
        buffer.destroy();
        handles.release(bufferId);
    }
}

export function env_webgpu_copy_buffer_to_buffer(srcId, srcOffset, dstId, dstOffset, size) {
    const src = handles.get(srcId);
    const dst = handles.get(dstId);
    if (!src || !dst) { console.error("[webgpu.js] Invalid buffer handle for copy"); return; }

    const encoder = device.createCommandEncoder();
    encoder.copyBufferToBuffer(src, Number(srcOffset), dst, Number(dstOffset), Number(size));
    device.queue.submit([encoder.finish()]);
}

export function env_webgpu_copy_buffer_to_buffer_in_encoder(encoderId, srcId, srcOffset, dstId, dstOffset, size) {
    const encoder = handles.get(encoderId);
    const src = handles.get(srcId);
    const dst = handles.get(dstId);
    if (!encoder || !src || !dst) { console.error("[webgpu.js] Invalid handle for encoder buffer copy"); return; }

    encoder.copyBufferToBuffer(src, Number(srcOffset), dst, Number(dstOffset), Number(size));
}

// === Shader Management ===

export function env_webgpu_create_shader_module(deviceId, sourcePtr, sourceLen) {
    const dev = handles.get(deviceId);
    if (!dev) { console.error("[webgpu.js] Invalid device handle:", deviceId); return 0; }

    const source = decodeString(sourcePtr, sourceLen);
    try {
        const shaderModule = dev.createShaderModule({ code: source });
        return handles.create(shaderModule);
    } catch (e) {
        console.error("[webgpu.js] Shader compilation error:", e);
        console.error("[webgpu.js] Shader source:", source);
        return 0;
    }
}

// === Texture Management ===

export function env_webgpu_create_texture(deviceId, width, height, format, usage) {
    const dev = handles.get(deviceId);
    if (!dev) { console.error("[webgpu.js] Invalid device handle"); return 0; }

    const formatString = TEXTURE_FORMATS[format] || "rgba8unorm";
    try {
        const texture = dev.createTexture({
            size: { width, height, depthOrArrayLayers: 1 },
            format: formatString,
            usage,
            dimension: "2d",
        });
        return handles.create(texture);
    } catch (e) {
        console.error("[webgpu.js] Failed to create texture:", e);
        return 0;
    }
}

export function env_webgpu_create_texture_view(textureId) {
    const texture = handles.get(textureId);
    if (!texture) { console.error("[webgpu.js] Invalid texture handle"); return 0; }

    try {
        return handles.create(texture.createView());
    } catch (e) {
        console.error("[webgpu.js] Failed to create texture view:", e);
        return 0;
    }
}

export function env_webgpu_destroy_texture(textureId) {
    const texture = handles.get(textureId);
    if (texture) {
        handles.release(textureId);
    }
}

// === Bind Group Layout ===

// Layout: binding(u32) visibility(u32) entry_type(u32) buffer_type(u32)
//         has_min_size(u32) has_dynamic_offset(u32) min_size(u64) padding(u64)
// Total: 40 bytes per entry
const BGL_ENTRY_SIZE = 40;

export function env_webgpu_create_bind_group_layout(deviceId, entriesPtr, entriesLen) {
    const dev = handles.get(deviceId);
    if (!dev) { console.error("[webgpu.js] Invalid device handle"); return 0; }

    const view = new DataView(mem().buffer, entriesPtr, entriesLen * BGL_ENTRY_SIZE);
    const entries = [];

    for (let i = 0; i < entriesLen; i++) {
        const off = i * BGL_ENTRY_SIZE;
        const binding    = view.getUint32(off, true);
        const visibility = view.getUint32(off + 4, true);
        const entryType  = view.getUint32(off + 8, true);
        const bufferType = view.getUint32(off + 12, true);
        const hasMinSize = view.getUint32(off + 16, true);
        const hasDynOff  = view.getUint32(off + 20, true);
        const minSize    = Number(view.getBigUint64(off + 24, true));

        const entry = { binding, visibility };

        if (entryType === 0) {
            entry.buffer = {
                type: ["uniform", "storage", "read-only-storage"][bufferType] || "storage",
            };
            if (hasMinSize) entry.buffer.minBindingSize = minSize;
            if (hasDynOff) entry.buffer.hasDynamicOffset = true;
        } else if (entryType === 1) {
            entry.texture = { sampleType: "float", viewDimension: "2d", multisampled: false };
        } else if (entryType === 2) {
            entry.sampler = { type: "filtering" };
        }

        entries.push(entry);
    }

    return handles.create(dev.createBindGroupLayout({ entries }));
}

// === Bind Group ===

// Layout: binding(u32) entry_type(u32) resource_handle(u32) padding(u32)
//         offset(u64) size(u64)
// Total: 32 bytes per entry
const BG_ENTRY_SIZE = 32;

export function env_webgpu_create_bind_group(deviceId, layoutId, entriesPtr, entriesLen) {
    const dev = handles.get(deviceId);
    const layout = handles.get(layoutId);
    if (!dev || !layout) { console.error("[webgpu.js] Invalid device or layout handle"); return 0; }

    const view = new DataView(mem().buffer, entriesPtr, entriesLen * BG_ENTRY_SIZE);
    const entries = [];

    for (let i = 0; i < entriesLen; i++) {
        const off = i * BG_ENTRY_SIZE;
        const binding        = view.getUint32(off, true);
        const entryType      = view.getUint32(off + 4, true);
        const resourceHandle = view.getUint32(off + 8, true);
        const bufferOffset   = Number(view.getBigUint64(off + 16, true));
        const size           = Number(view.getBigUint64(off + 24, true));

        const resource = handles.get(resourceHandle);
        if (!resource) { console.error("[webgpu.js] Invalid resource handle in bind group"); return 0; }

        const entry = { binding };
        if (entryType === 0) {
            entry.resource = { buffer: resource, offset: bufferOffset, size };
        } else if (entryType === 1) {
            entry.resource = resource;
        }
        entries.push(entry);
    }

    return handles.create(dev.createBindGroup({ layout, entries }));
}

// === Pipeline Layout ===

export function env_webgpu_create_pipeline_layout(deviceId, layoutsPtr, layoutsLen) {
    const dev = handles.get(deviceId);
    if (!dev) { console.error("[webgpu.js] Invalid device handle"); return 0; }

    const ids = new Uint32Array(mem().buffer, layoutsPtr, layoutsLen);
    const bindGroupLayouts = [];
    for (let i = 0; i < layoutsLen; i++) {
        const l = handles.get(ids[i]);
        if (!l) { console.error("[webgpu.js] Invalid bind group layout handle"); return 0; }
        bindGroupLayouts.push(l);
    }

    return handles.create(dev.createPipelineLayout({ bindGroupLayouts }));
}

// === Compute Pipeline ===

export function env_webgpu_create_compute_pipeline(deviceId, layoutId, shaderId, entryPointPtr, entryPointLen) {
    const dev = handles.get(deviceId);
    const layout = handles.get(layoutId);
    const shader = handles.get(shaderId);
    if (!dev || !layout || !shader) { console.error("[webgpu.js] Invalid handle for compute pipeline"); return 0; }

    const entryPoint = decodeString(entryPointPtr, entryPointLen);
    try {
        const pipeline = dev.createComputePipeline({
            layout,
            compute: { module: shader, entryPoint },
        });
        return handles.create(pipeline);
    } catch (e) {
        console.error("[webgpu.js] Compute pipeline creation error:", e);
        return 0;
    }
}

// === Render Pipeline ===

export function env_webgpu_create_render_pipeline(deviceId, layoutId, shaderId, vertexEntryPtr, vertexEntryLen, fragmentEntryPtr, fragmentEntryLen) {
    const dev = handles.get(deviceId);
    const layout = handles.get(layoutId);
    const shader = handles.get(shaderId);
    if (!dev || !layout || !shader) { console.error("[webgpu.js] Invalid handle for render pipeline"); return 0; }

    const vertexEntry = decodeString(vertexEntryPtr, vertexEntryLen);
    const fragmentEntry = decodeString(fragmentEntryPtr, fragmentEntryLen);

    try {
        const pipeline = dev.createRenderPipeline({
            layout,
            vertex: { module: shader, entryPoint: vertexEntry },
            primitive: { topology: "triangle-list" },
            fragment: {
                module: shader,
                entryPoint: fragmentEntry,
                targets: [{
                    format: preferredFormat,
                    blend: {
                        color: { srcFactor: "src-alpha", dstFactor: "one-minus-src-alpha" },
                        alpha: { srcFactor: "one", dstFactor: "one-minus-src-alpha" },
                    },
                }],
            },
        });
        return handles.create(pipeline);
    } catch (e) {
        console.error("[webgpu.js] Render pipeline creation error:", e);
        return 0;
    }
}

export function env_webgpu_create_render_pipeline_hdr(deviceId, layoutId, shaderId, vertexEntryPtr, vertexEntryLen, fragmentEntryPtr, fragmentEntryLen, targetFormat, enableBlending) {
    const dev = handles.get(deviceId);
    const layout = handles.get(layoutId);
    const shader = handles.get(shaderId);
    if (!dev || !layout || !shader) { console.error("[webgpu.js] Invalid handle for HDR render pipeline"); return 0; }

    const vertexEntry = decodeString(vertexEntryPtr, vertexEntryLen);
    const fragmentEntry = decodeString(fragmentEntryPtr, fragmentEntryLen);

    const HDR_FORMATS = ["rgba16float", "rgba32float", "bgra8unorm", "rgba8unorm", "rgba8unorm-srgb"];
    const formatString = HDR_FORMATS[targetFormat] || "bgra8unorm";

    try {
        const desc = {
            layout,
            vertex: { module: shader, entryPoint: vertexEntry },
            primitive: { topology: "triangle-list" },
            fragment: {
                module: shader,
                entryPoint: fragmentEntry,
                targets: [{ format: formatString }],
            },
        };

        if (enableBlending) {
            desc.fragment.targets[0].blend = {
                color: { srcFactor: "src-alpha", dstFactor: "one", operation: "add" },
                alpha: { srcFactor: "one", dstFactor: "one", operation: "add" },
            };
        }

        return handles.create(dev.createRenderPipeline(desc));
    } catch (e) {
        console.error("[webgpu.js] HDR render pipeline creation error:", e);
        return 0;
    }
}

// === Command Encoder ===

export function env_webgpu_create_command_encoder(deviceId) {
    const dev = handles.get(deviceId);
    if (!dev) { console.error("[webgpu.js] Invalid device handle"); return 0; }
    return handles.create(dev.createCommandEncoder());
}

export function env_webgpu_command_encoder_finish(encoderId) {
    const encoder = handles.get(encoderId);
    if (!encoder) { console.error("[webgpu.js] Invalid encoder handle"); return 0; }

    const cmdBuf = encoder.finish();
    handles.release(encoderId);
    return handles.create(cmdBuf);
}

export function env_webgpu_queue_submit(deviceId, commandBufferId) {
    const dev = handles.get(deviceId);
    const cmdBuf = handles.get(commandBufferId);
    if (!dev || !cmdBuf) { console.error("[webgpu.js] Invalid device or command buffer handle"); return; }

    dev.queue.submit([cmdBuf]);
    handles.release(commandBufferId);
}

// === Compute Pass ===

export function env_webgpu_begin_compute_pass(encoderId) {
    const encoder = handles.get(encoderId);
    if (!encoder) { console.error("[webgpu.js] Invalid encoder handle"); return 0; }
    return handles.create(encoder.beginComputePass());
}

export function env_webgpu_encoder_begin_compute_pass(encoderId) {
    const encoder = handles.get(encoderId);
    if (!encoder) { console.error("[webgpu.js] Invalid encoder handle"); return 0; }
    return handles.create(encoder.beginComputePass());
}

export function env_webgpu_compute_pass_set_pipeline(passId, pipelineId) {
    const pass = handles.get(passId);
    const pipeline = handles.get(pipelineId);
    if (!pass || !pipeline) { console.error("[webgpu.js] Invalid pass or pipeline handle"); return; }
    pass.setPipeline(pipeline);
}

export function env_webgpu_compute_pass_set_bind_group(passId, index, bindGroupId) {
    const pass = handles.get(passId);
    const bindGroup = handles.get(bindGroupId);
    if (!pass || !bindGroup) { console.error("[webgpu.js] Invalid pass or bind group handle"); return; }
    pass.setBindGroup(index, bindGroup);
}

export function env_webgpu_compute_pass_set_bind_group_with_offset(passId, index, bindGroupId, dynamicOffset) {
    const pass = handles.get(passId);
    const bindGroup = handles.get(bindGroupId);
    if (!pass || !bindGroup) { console.error("[webgpu.js] Invalid pass or bind group handle"); return; }
    pass.setBindGroup(index, bindGroup, [dynamicOffset]);
}

export function env_webgpu_compute_pass_dispatch(passId, x, y, z) {
    const pass = handles.get(passId);
    if (!pass) { console.error("[webgpu.js] Invalid pass handle"); return; }
    pass.dispatchWorkgroups(x, y, z);
}

export function env_webgpu_compute_pass_end(passId) {
    const pass = handles.get(passId);
    if (!pass) { console.error("[webgpu.js] Invalid pass handle"); return; }
    pass.end();
    handles.release(passId);
}

// === Render Pass ===

export function env_webgpu_begin_render_pass(r, g, b, a) {
    if (!device || !context) { console.error("[webgpu.js] Device or context not initialized"); return 0; }

    commandEncoder = device.createCommandEncoder();
    const textureView = context.getCurrentTexture().createView();

    renderPassEncoder = commandEncoder.beginRenderPass({
        colorAttachments: [{
            view: textureView,
            clearValue: { r, g, b, a },
            loadOp: "clear",
            storeOp: "store",
        }],
    });

    return handles.create(renderPassEncoder);
}

export function env_webgpu_begin_render_pass_for_particles(r, g, b, a) {
    if (!device || !context) { console.error("[webgpu.js] Device or context not initialized"); return 0; }

    if (!commandEncoder) {
        commandEncoder = device.createCommandEncoder();
    }

    const textureView = context.getCurrentTexture().createView();

    renderPassEncoder = commandEncoder.beginRenderPass({
        colorAttachments: [{
            view: textureView,
            clearValue: { r, g, b, a },
            loadOp: "clear",
            storeOp: "store",
        }],
    });

    return handles.create(renderPassEncoder);
}

export function env_webgpu_begin_render_pass_hdr(textureViewId, r, g, b, a) {
    if (!device) { console.error("[webgpu.js] Device not initialized"); return 0; }

    const textureView = handles.get(textureViewId);
    if (!textureView) { console.error("[webgpu.js] Invalid texture view handle"); return 0; }

    if (!commandEncoder) {
        commandEncoder = device.createCommandEncoder();
    }

    renderPassEncoder = commandEncoder.beginRenderPass({
        colorAttachments: [{
            view: textureView,
            clearValue: { r, g, b, a },
            loadOp: "clear",
            storeOp: "store",
        }],
    });

    return handles.create(renderPassEncoder);
}

export function env_webgpu_render_pass_set_pipeline(passId, pipelineId) {
    const pass = handles.get(passId);
    const pipeline = handles.get(pipelineId);
    if (!pass || !pipeline) { console.error("[webgpu.js] Invalid pass or pipeline handle"); return; }
    pass.setPipeline(pipeline);
}

export function env_webgpu_render_pass_set_bind_group(passId, index, bindGroupId) {
    const pass = handles.get(passId);
    const bindGroup = handles.get(bindGroupId);
    if (!pass || !bindGroup) { console.error("[webgpu.js] Invalid pass or bind group handle"); return; }
    pass.setBindGroup(index, bindGroup);
}

export function env_webgpu_render_pass_draw(passId, vertexCount, instanceCount, firstVertex, firstInstance) {
    const pass = handles.get(passId);
    if (!pass) { console.error("[webgpu.js] Invalid pass handle"); return; }
    pass.draw(vertexCount, instanceCount, firstVertex, firstInstance);
}

export function env_webgpu_render_pass_end(passId) {
    if (renderPassEncoder) {
        renderPassEncoder.end();
        renderPassEncoder = null;
    }
}

// === Present ===

export function env_webgpu_present() {
    if (commandEncoder && device) {
        device.queue.submit([commandEncoder.finish()]);
        commandEncoder = null;
    }
}
