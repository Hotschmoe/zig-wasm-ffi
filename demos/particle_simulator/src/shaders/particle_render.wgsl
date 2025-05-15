// shaders/particle_render.wgsl

// Structs matching Zig definitions (ensure alignment/size matches)
struct Particle {
    pos_x: f32, // Maintained for directness, but internally will map to pos.x
    pos_y: f32, // Maintained for directness, but internally will map to pos.y
    vel_vx: f32, // Not used by render shader but part of the struct
    vel_vy: f32, // Not used by render shader but part of the struct
    species_id: u32, // Corrected to match Zig's core.Particle and compute shader's Particle
};

struct Species {
    color: vec4<f32>,
};

// Uniforms (Example: Camera - not used yet, but good structure)
struct Camera {
    center : vec2<f32>,
    extent : vec2<f32>,
};
@group(0) @binding(0) var<uniform> camera: Camera;

// Storage Buffers
@group(1) @binding(0) var<storage, read> particles: array<Particle>;
@group(1) @binding(1) var<storage, read> species_list: array<Species>; // Renamed to avoid conflict with struct name

const particle_radius: f32 = 1.0; // Each particle quad will be particle_radius * 2 wide/high

// Offsets for a unit quad (2 triangles, 6 vertices)
// (-1,-1), (1,-1), (-1,1),  (-1,1), (1,-1), (1,1)
const quad_vertex_offsets = array<vec2<f32>, 6>(
    vec2<f32>(-1.0, -1.0),
    vec2<f32>( 1.0, -1.0),
    vec2<f32>(-1.0,  1.0),
    vec2<f32>(-1.0,  1.0),
    vec2<f32>( 1.0, -1.0),
    vec2<f32>( 1.0,  1.0)
);

// Vertex output for shaders that draw quads (glow, circle)
struct QuadVertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) offset_for_frag: vec2<f32>, // Renamed from 'offset' to be clear it's for fragment
    @location(1) color: vec4<f32>,
};

// Vertex output for point shader
struct PointVertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) color: vec4<f32>, // Changed location to 0 to be consistent
};

// --- Glow Shader ---
@vertex
fn vs_glow(@builtin(vertex_index) vertex_idx : u32) -> QuadVertexOutput {
    let particle_id = vertex_idx / 6u;
    let vertex_id_in_quad = vertex_idx % 6u;

    let p = particles[particle_id];
    let s = species_list[p.species_id];
    let q_offset = quad_vertex_offsets[vertex_id_in_quad];

    // Glow particles are larger
    let particle_world_pos = vec2(p.pos_x, p.pos_y) + q_offset * 8.0; // 8.0 is glow size factor from particles.html
    
    let clip_pos = (particle_world_pos - camera.center) / camera.extent;

    var out : QuadVertexOutput;
    out.position = vec4(clip_pos, 0.0, 1.0);
    out.offset_for_frag = q_offset;
    out.color = s.color;
    return out;
}

@fragment
fn fs_glow(in: QuadVertexOutput) -> @location(0) vec4<f32> {
    let l = length(in.offset_for_frag);
    // Glow effect: smooth falloff, divided by 16 for fainter glow as in particles.html
    let alpha = smoothstep(1.0, 0.0, l) * (1.0 / 16.0); 
    return vec4(in.color.rgb, in.color.a * alpha);
}

// --- Circle Shader ---
const circle_particle_radius: f32 = 1.0; // Default radius for circle particles

@vertex
fn vs_circle(@builtin(vertex_index) vertex_idx : u32) -> QuadVertexOutput {
    let particle_id = vertex_idx / 6u;
    let vertex_id_in_quad = vertex_idx % 6u;

    let p = particles[particle_id];
    let s = species_list[p.species_id];
    let q_offset = quad_vertex_offsets[vertex_id_in_quad];

    let particle_world_pos = vec2(p.pos_x, p.pos_y) + q_offset * circle_particle_radius;
    
    let clip_pos = (particle_world_pos - camera.center) / camera.extent;

    var out : QuadVertexOutput;
    out.position = vec4(clip_pos, 0.0, 1.0);
    out.offset_for_frag = q_offset; // Pass the original quad offset
    out.color = s.color;
    return out;
}

@fragment
fn fs_circle(in: QuadVertexOutput) -> @location(0) vec4<f32> {
    let l = length(in.offset_for_frag); // Using the passed offset
    let eps = fwidth(l);
    // Sharp circle edge using smoothstep and fwidth
    let alpha = smoothstep(1.0, 1.0 - eps, l); 
    return vec4(in.color.rgb, in.color.a * alpha);
}

// --- Point Shader ---
@vertex
fn vs_point(@builtin(vertex_index) particle_id : u32) -> PointVertexOutput {
    let p = particles[particle_id];
    let s = species_list[p.species_id];

    let particle_world_pos = vec2(p.pos_x, p.pos_y);
    let clip_pos = (particle_world_pos - camera.center) / camera.extent;

    var out: PointVertexOutput;
    out.position = vec4(clip_pos, 0.0, 1.0);
    out.color = s.color;
    return out;
}

@fragment
fn fs_point(in: PointVertexOutput) -> @location(0) vec4<f32> {
    return in.color;
}
