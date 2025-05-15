// src/shaders/particle_binning.wgsl

// Structs matching Zig definitions (ensure layout/size matches)
struct Particle {
    pos_x: f32,
    pos_y: f32,
    vel_vx: f32, // Unused here, but part of struct
    vel_vy: f32, // Unused here, but part of struct
    species_id: u32, // Unused here, but part of struct
};

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
    _padding1: u32,
    _padding2: u32,
}; // Matches Zig's SimParams (48 bytes)

// Bindings - Define groups and bindings clearly
// Unified bin_counts buffer for both clear and fill operations
@group(0) @binding(0) var<storage, read_write> bin_counts: array<atomic<u32>>;

// Group 1: Simulation-wide data (used by cs_fill_bin_counts)
@group(1) @binding(0) var<storage, read> particles_input: array<Particle>; // Read-only for this shader
@group(1) @binding(1) var<uniform> sim_params_fill: SimParams;

// Helper function to determine bin index for a particle
// Matches the BinInfo struct logic from particles.html, simplified to return vec2<i32>
// and expects sim_params to provide simulation box boundaries and bin_size.
fn getBinInfo(particle_pos: vec2<f32>, sim_params_in: SimParams) -> vec2<i32> {
    // Calculate position relative to the simulation box origin (bottom-left)
    let x_in_sim_coords = particle_pos.x - sim_params_in.left;
    let y_in_sim_coords = particle_pos.y - sim_params_in.bottom;

    // Calculate bin column and row
    // Ensure casting to i32 after floor, before clamping.
    var bin_col = i32(floor(x_in_sim_coords / sim_params_in.binSize));
    var bin_row = i32(floor(y_in_sim_coords / sim_params_in.binSize));

    // Clamp to grid dimensions. gridCols and gridRows are u32, cast to i32 for clamp.
    bin_col = clamp(bin_col, 0i, i32(sim_params_in.gridCols) - 1i);
    bin_row = clamp(bin_row, 0i, i32(sim_params_in.gridRows) - 1i);

    return vec2<i32>(bin_col, bin_row);
}

// --- Entry Points ---

// Clears the bin_counts buffer
@compute @workgroup_size(64) // Match common workgroup size
fn cs_clear_bin_counts(@builtin(global_invocation_id) global_id: vec3<u32>)
{
    let bin_idx = global_id.x;
    if (bin_idx < arrayLength(&bin_counts)) { // Use unified bin_counts
        atomicStore(&bin_counts[bin_idx], 0u);
    }
}

// Fills the bin_counts buffer by atomically incrementing counters based on particle positions.
@compute @workgroup_size(64) // Workgroup size can be tuned
fn cs_fill_bin_counts(@builtin(global_invocation_id) global_id: vec3<u32>)
{
    let particle_idx = global_id.x;

    if (particle_idx >= arrayLength(&particles_input)) {
        return;
    }

    let p = particles_input[particle_idx];
    let particle_current_pos = vec2<f32>(p.pos_x, p.pos_y);

    let bin_id_vec = getBinInfo(particle_current_pos, sim_params_fill);

    // Calculate flat bin index
    // Ensure gridCols is treated as u32 for the multiplication.
    let flat_bin_idx = u32(bin_id_vec.y) * sim_params_fill.gridCols + u32(bin_id_vec.x);

    if (flat_bin_idx < arrayLength(&bin_counts)) { // Use unified bin_counts
        atomicAdd(&bin_counts[flat_bin_idx], 1u);
    }
} 