// src/shaders/particle_prefix_sum.wgsl

struct PrefixSumParams {
    step_size: u32,
    // Add element_count if needed, though arrayLength can often be used.
};

// Group 0: Uniforms
@group(0) @binding(0) var<uniform> params: PrefixSumParams;

// Group 1: Buffers (swap roles on different passes)
@group(1) @binding(0) var<storage, read> source_buffer: array<u32>; // Use u32 for counts/offsets
@group(1) @binding(1) var<storage, read_write> destination_buffer: array<u32>;

@compute @workgroup_size(64) // Or 256 if supported and beneficial
fn cs_prefix_sum_step(@builtin(global_invocation_id) id: vec3<u32>) {
    let index = id.x;
    let element_count = arrayLength(&source_buffer); // Get buffer size

    if (index >= element_count) {
        return;
    }

    let step = params.step_size;

    // Basic Blelloch scan step:
    // Each element reads its own value and the value 'step_size' positions behind it.
    // If index < step_size, it just copies its own value.
    // Otherwise, it adds the value from step_size positions behind.
    if (index < step) {
        destination_buffer[index] = source_buffer[index];
    } else {
        destination_buffer[index] = source_buffer[index - step] + source_buffer[index];
    }
} 