struct Particle {
    pos_x: f32,
    pos_y: f32,
    vel_vx: f32,
    vel_vy: f32,
    species_id: u32,
}

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
}

struct ForceParams {
    strength: f32,
    radius: f32,
    collisionRadius: f32,
}

@group(0) @binding(0) var<storage, read_write> particles: array<Particle>;
@group(0) @binding(1) var<uniform> sim_params: SimParams;
@group(0) @binding(2) var<storage, read> bin_offsets: array<u32>;
@group(0) @binding(3) var<storage, read> species_forces: array<ForceParams>;

const WORKGROUP_SIZE: u32 = 64u;

fn getBinInfo(pos: vec2<f32>, params: ptr<uniform, SimParams>) -> vec2<u32> {
    let col = u32(floor((pos.x - (*params).left) / (*params).binSize));
    let row = u32(floor((pos.y - (*params).bottom) / (*params).binSize));
    let clamped_col = clamp(col, 0u, (*params).gridCols - 1u);
    let clamped_row = clamp(row, 0u, (*params).gridRows - 1u);
    return vec2<u32>(clamped_col, clamped_row);
}

@compute @workgroup_size(WORKGROUP_SIZE)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let particle_index = global_id.x;
    if (particle_index >= sim_params.particle_count) {
        return;
    }

    var current_particle = particles[particle_index];
    let particle_pos = vec2<f32>(current_particle.pos_x, current_particle.pos_y);

    var total_force_vec = vec2<f32>(0.0, 0.0);

    let particle_bin_coords = getBinInfo(particle_pos, &sim_params);

    for (var dy: i32 = -1; dy <= 1; dy = dy + 1) {
        for (var dx: i32 = -1; dx <= 1; dx = dx + 1) {
            let neighbor_bin_col_signed = i32(particle_bin_coords.x) + dx;
            let neighbor_bin_row_signed = i32(particle_bin_coords.y) + dy;

            if (neighbor_bin_col_signed >= 0 && neighbor_bin_col_signed < i32(sim_params.gridCols) &&
                neighbor_bin_row_signed >= 0 && neighbor_bin_row_signed < i32(sim_params.gridRows)) {
                
                let neighbor_bin_col = u32(neighbor_bin_col_signed);
                let neighbor_bin_row = u32(neighbor_bin_row_signed);
                let neighbor_bin_flat_index = neighbor_bin_row * sim_params.gridCols + neighbor_bin_col;

                if (neighbor_bin_flat_index >= arrayLength(&bin_offsets) - 1u) {
                    continue;
                }
                let start_index_in_sorted_buffer = bin_offsets[neighbor_bin_flat_index];
                let end_index_in_sorted_buffer = bin_offsets[neighbor_bin_flat_index + 1u];

                for (var j = start_index_in_sorted_buffer; j < end_index_in_sorted_buffer; j = j + 1u) {
                    if (j == particle_index) {
                        continue;
                    }
                    if (j >= sim_params.particle_count) {
                        continue;
                    }

                    let other_particle = particles[j];
                    let other_pos = vec2<f32>(other_particle.pos_x, other_particle.pos_y);
                    
                    let r_vec = other_pos - particle_pos;
                    let dist_sq = dot(r_vec, r_vec);

                    let actual_force_params_index = current_particle.species_id * sim_params.species_count + other_particle.species_id;

                    if (actual_force_params_index >= arrayLength(&species_forces)) {
                        continue;
                    }
                    let force_interaction = species_forces[actual_force_params_index];

                    if (dist_sq > 0.00001 && dist_sq < force_interaction.radius * force_interaction.radius) {
                        let dist = sqrt(dist_sq);
                        let r_norm_vec = r_vec / dist;
                        
                        var force_magnitude = force_interaction.strength * max(0.0, 1.0 - dist / force_interaction.radius);
                        
                        force_magnitude = force_magnitude - 10.0 * abs(force_interaction.strength) * max(0.0, 1.0 - dist / force_interaction.collisionRadius);

                        total_force_vec = total_force_vec + force_magnitude * r_norm_vec;
                    }
                }
            }
        }
    }

    current_particle.vel_vx = current_particle.vel_vx + total_force_vec.x * sim_params.dt;
    current_particle.vel_vy = current_particle.vel_vy + total_force_vec.y * sim_params.dt;

    current_particle.vel_vx = current_particle.vel_vx * sim_params.friction_factor;
    current_particle.vel_vy = current_particle.vel_vy * sim_params.friction_factor;

    current_particle.pos_x = current_particle.pos_x + current_particle.vel_vx * sim_params.dt;
    current_particle.pos_y = current_particle.pos_y + current_particle.vel_vy * sim_params.dt;

    // Boundary conditions: Reflect particles
    if (current_particle.pos_x < sim_params.left) {
        current_particle.pos_x = sim_params.left;
        current_particle.vel_vx = current_particle.vel_vx * -1.0;
    }
    if (current_particle.pos_x > sim_params.right) {
        current_particle.pos_x = sim_params.right;
        current_particle.vel_vx = current_particle.vel_vx * -1.0;
    }
    if (current_particle.pos_y < sim_params.bottom) {
        current_particle.pos_y = sim_params.bottom;
        current_particle.vel_vy = current_particle.vel_vy * -1.0;
    }
    if (current_particle.pos_y > sim_params.top) {
        current_particle.pos_y = sim_params.top;
        current_particle.vel_vy = current_particle.vel_vy * -1.0;
    }

    particles[particle_index] = current_particle;
}
