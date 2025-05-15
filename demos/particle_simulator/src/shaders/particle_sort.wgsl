// src/shaders/particle_sort.wgsl

// Match Zig's core.Particle
struct Particle {
    pos_x: f32,
    pos_y: f32,
    vel_vx: f32,
    vel_vy: f32,
    species_id: u32,
};

// Renamed from SimulationOptions to SimParams for consistency
struct SimParams {
    dt: f32,
    particle_count: u32,
    left: f32,
    right: f32,
    bottom: f32,
    top: f32,
    friction_factor: f32,
    binSize: f32,
    gridCols: u32,
    gridRows: u32,
    species_count: u32,
};

const WORKGROUP_SIZE: u32 = 64u;

// Helper function to get the 1D bin index for a particle
// Changed sim_opts: ptr<function, SimulationOptions> to sim_params_ptr: ptr<uniform, SimParams>
fn getBinIndex(pos: vec2<f32>, sim_params_ptr: ptr<uniform, SimParams>) -> u32 {
    let col = u32(floor((pos.x - (*sim_params_ptr).left) / (*sim_params_ptr).binSize));
    let row = u32(floor((pos.y - (*sim_params_ptr).bottom) / (*sim_params_ptr).binSize));
    let clamped_col = clamp(col, 0u, (*sim_params_ptr).gridCols - 1u);
    let clamped_row = clamp(row, 0u, (*sim_params_ptr).gridRows - 1u);
    return clamped_row * (*sim_params_ptr).gridCols + clamped_col;
}

// --- Shader 1: Clear Sort Indices ---
// This buffer will store atomic counters, one for each bin,
// to correctly place particles into the sorted buffer.
@group(0) @binding(0) var<storage, read_write> sort_indices_for_clear: array<atomic<u32>>; // Renamed for clarity

@compute @workgroup_size(64) // Or 256
fn cs_clear_sort_indices(@builtin(global_invocation_id) id: vec3<u32>) {
    let index = id.x;
    let num_indices = arrayLength(&sort_indices_for_clear);
    if (index >= num_indices) {
        return;
    }
    atomicStore(&sort_indices_for_clear[index], 0u);
}


// --- Shader 2: Sort Particles ---
// Group 0: Main data buffers for sorting operation
@group(0) @binding(0) var<storage, read> source_particles: array<Particle>;                // Input: g_particle_temp_state_buffer
@group(0) @binding(1) var<storage, read_write> destination_particles: array<Particle>;        // Output: g_particle_state_buffer
@group(0) @binding(2) var<storage, read> bin_offsets: array<u32>;                         // Input: g_bin_offsets_buffer (prefix sum results)
@group(0) @binding(3) var<storage, read_write> sort_indices_for_sort: array<atomic<u32>>; // Input/Output: g_sort_indices_buffer (atomic counters for placing particles)

// Group 1: Simulation Parameters
@group(1) @binding(0) var<uniform> sim_params: SimParams;


@compute @workgroup_size(WORKGROUP_SIZE)
fn cs_sort_particles(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let particle_index = global_id.x;
    if (particle_index >= sim_params.particle_count) {
        return;
    }

    let current_particle = source_particles[particle_index];
    let particle_pos = vec2<f32>(current_particle.pos_x, current_particle.pos_y);
    
    // Use the updated getBinIndex with the correct pointer type for sim_params
    let bin_idx = getBinIndex(particle_pos, &sim_params);

    // Ensure bin_index is within bounds for bin_offsets and sort_indices_for_sort
    // These buffers are typically (BIN_COUNT + 1) in size.
    // getBinIndex already clamps, so bin_index should be valid for BIN_COUNT elements.
    if (bin_idx >= arrayLength(&bin_offsets) -1u || bin_idx >= arrayLength(&sort_indices_for_sort)) {
        // Should not happen if getBinIndex clamps correctly and buffers are sized BIN_COUNT or BIN_COUNT+1
        return;
    }
    
    let start_offset = bin_offsets[bin_idx];
    let local_offset_in_bin = atomicAdd(&sort_indices_for_sort[bin_idx], 1u);
    
    let destination_idx = start_offset + local_offset_in_bin;

    if (destination_idx < arrayLength(&destination_particles)) {
        destination_particles[destination_idx] = current_particle;
    }
} 