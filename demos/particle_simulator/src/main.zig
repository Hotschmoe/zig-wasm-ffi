const std = @import("std");
const webgpu = @import("zig-wasm-ffi").webgpu;
const webinput = @import("zig-wasm-ffi").webinput;
const webutils = @import("zig-wasm-ffi").webutils;
const webgpu_handler = @import("webgpu_engine/webgpu_handler.zig");
const input_handler = @import("input_handler.zig");

// Enhanced particle data for particle life simulation
const Particle = extern struct {
    x: f32,
    y: f32,
    vx: f32,
    vy: f32,
    species: f32, // Species ID (0-3 for 4 species)
    // Padding for alignment
    _padding: f32,
};

// Species configuration
const Species = struct {
    color: [4]f32, // RGBA
    forces: [4]f32, // Forces to other species [0-3]
};

// Simulation parameters
const SimulationParams = struct {
    particle_count: u32 = 2048,
    species_count: u32 = 4,
    world_size: f32 = 2.0,
    force_range: f32 = 0.1,
    friction: f32 = 0.99,
    dt: f32 = 0.016,
    force_scale: f32 = 0.001,
};

// Simple renderer that draws particles with species colors and physics
var particle_life_renderer: ?ParticleLifeRenderer = null;
var allocator: std.mem.Allocator = undefined;

// Global static clear color
const static_clear_color = webgpu.Color{ .r = 0.05, .g = 0.05, .b = 0.1, .a = 1.0 };

const ParticleLifeRenderer = struct {
    device: webgpu.Device,
    queue: webgpu.Queue,

    // Buffers
    particle_buffer: webgpu.Buffer,
    species_buffer: webgpu.Buffer,
    params_buffer: webgpu.Buffer,

    // Bind groups and layouts
    uniform_bind_group_layout: webgpu.BindGroupLayout,
    uniform_bind_group: webgpu.BindGroup,

    // Pipelines
    render_pipeline: webgpu.RenderPipeline,

    // Simulation data
    particles: []Particle,
    species: [4]Species,
    params: SimulationParams,
    frame_count: u32,

    pub fn init(device: webgpu.Device, queue: webgpu.Queue, surface_format: webgpu.TextureFormat) !ParticleLifeRenderer {
        webutils.log("ParticleLifeRenderer.init() called");

        var self = ParticleLifeRenderer{
            .device = device,
            .queue = queue,
            .particle_buffer = undefined,
            .species_buffer = undefined,
            .params_buffer = undefined,
            .uniform_bind_group_layout = undefined,
            .uniform_bind_group = undefined,
            .render_pipeline = undefined,
            .particles = undefined,
            .species = undefined,
            .params = SimulationParams{},
            .frame_count = 0,
        };

        webutils.log("Initializing particle life simulation...");
        try self.initializeSimulation();

        webutils.log("Creating buffers...");
        try self.createBuffers();

        webutils.log("Creating bind groups...");
        try self.createBindGroups();

        webutils.log("Creating render pipeline...");
        try self.createRenderPipeline(surface_format);

        webutils.log("ParticleLifeRenderer.init() completed successfully");
        return self;
    }

    fn initializeSimulation(self: *ParticleLifeRenderer) !void {
        // Allocate particles
        self.particles = try allocator.alloc(Particle, self.params.particle_count);

        // Initialize species with different colors and random forces
        self.species[0] = Species{
            .color = [4]f32{ 1.0, 0.3, 0.3, 1.0 }, // Red
            .forces = [4]f32{ 0.2, -0.1, 0.05, -0.05 },
        };
        self.species[1] = Species{
            .color = [4]f32{ 0.3, 1.0, 0.3, 1.0 }, // Green
            .forces = [4]f32{ -0.1, 0.15, -0.08, 0.12 },
        };
        self.species[2] = Species{
            .color = [4]f32{ 0.3, 0.3, 1.0, 1.0 }, // Blue
            .forces = [4]f32{ 0.08, -0.05, 0.1, -0.15 },
        };
        self.species[3] = Species{
            .color = [4]f32{ 1.0, 1.0, 0.3, 1.0 }, // Yellow
            .forces = [4]f32{ -0.05, 0.1, -0.12, 0.08 },
        };

        // Initialize particles randomly
        for (self.particles, 0..) |*particle, i| {
            const fi = @as(f32, @floatFromInt(i));

            // Random position
            particle.x = (pseudoRandom(fi * 0.1) - 0.5) * self.params.world_size;
            particle.y = (pseudoRandom(fi * 0.2 + 100.0) - 0.5) * self.params.world_size;

            // Small random initial velocity
            particle.vx = (pseudoRandom(fi * 0.3 + 200.0) - 0.5) * 0.01;
            particle.vy = (pseudoRandom(fi * 0.4 + 300.0) - 0.5) * 0.01;

            // Assign species (distribute evenly)
            particle.species = @floatFromInt(i % self.params.species_count);
            particle._padding = 0.0;
        }
    }

    // Simple pseudo-random function for deterministic results
    fn pseudoRandom(seed: f32) f32 {
        const x = @sin(seed * 12.9898 + seed * 78.233) * 43758.5453;
        return x - @floor(x);
    }

    fn createBuffers(self: *ParticleLifeRenderer) !void {
        // Particle buffer
        self.particle_buffer = try webgpu.deviceCreateBuffer(self.device, &webgpu.BufferDescriptor{
            .label = "particle_buffer",
            .size = @sizeOf(Particle) * self.params.particle_count,
            .usage = webgpu.GPUBufferUsage.VERTEX | webgpu.GPUBufferUsage.COPY_DST,
            .mappedAtCreation = false,
        });

        // Species buffer
        self.species_buffer = try webgpu.deviceCreateBuffer(self.device, &webgpu.BufferDescriptor{
            .label = "species_buffer",
            .size = @sizeOf(Species) * 4,
            .usage = webgpu.GPUBufferUsage.UNIFORM | webgpu.GPUBufferUsage.COPY_DST,
            .mappedAtCreation = false,
        });

        // Params buffer
        self.params_buffer = try webgpu.deviceCreateBuffer(self.device, &webgpu.BufferDescriptor{
            .label = "params_buffer",
            .size = @sizeOf(SimulationParams),
            .usage = webgpu.GPUBufferUsage.UNIFORM | webgpu.GPUBufferUsage.COPY_DST,
            .mappedAtCreation = false,
        });

        // Write initial data
        webgpu.queueWriteBuffer(self.queue, self.particle_buffer, 0, @sizeOf(Particle) * self.params.particle_count, @ptrCast(self.particles.ptr));
        webgpu.queueWriteBuffer(self.queue, self.species_buffer, 0, @sizeOf(Species) * 4, @ptrCast(&self.species));
        webgpu.queueWriteBuffer(self.queue, self.params_buffer, 0, @sizeOf(SimulationParams), @ptrCast(&self.params));
    }

    fn createBindGroups(self: *ParticleLifeRenderer) !void {
        // Bind group layout for uniforms
        const uniform_entries = [_]webgpu.BindGroupLayoutEntry{
            webgpu.BindGroupLayoutEntry.newBuffer(0, webgpu.ShaderStage.VERTEX | webgpu.ShaderStage.FRAGMENT, .{
                .type = .uniform,
                .has_dynamic_offset = false,
                .min_binding_size = 0,
            }),
            webgpu.BindGroupLayoutEntry.newBuffer(1, webgpu.ShaderStage.VERTEX | webgpu.ShaderStage.FRAGMENT, .{
                .type = .uniform,
                .has_dynamic_offset = false,
                .min_binding_size = 0,
            }),
        };

        self.uniform_bind_group_layout = try webgpu.deviceCreateBindGroupLayout(self.device, &webgpu.BindGroupLayoutDescriptor{
            .label = "uniform_bgl",
            .entries = &uniform_entries,
            .entries_len = uniform_entries.len,
        });

        self.uniform_bind_group = try webgpu.deviceCreateBindGroup(self.device, &webgpu.BindGroupDescriptor{
            .label = "uniform_bg",
            .layout = self.uniform_bind_group_layout,
            .entries = &[_]webgpu.BindGroupEntry{
                .{
                    .binding = 0,
                    .resource = .{ .buffer = .{
                        .buffer = self.species_buffer,
                        .offset = 0,
                        .size = webgpu.WHOLE_SIZE,
                    } },
                },
                .{
                    .binding = 1,
                    .resource = .{ .buffer = .{
                        .buffer = self.params_buffer,
                        .offset = 0,
                        .size = webgpu.WHOLE_SIZE,
                    } },
                },
            },
            .entries_len = 2,
        });
    }

    fn createRenderPipeline(self: *ParticleLifeRenderer, surface_format: webgpu.TextureFormat) !void {
        const vertex_shader_source =
            \\struct VertexInput {
            \\    @location(0) position: vec2<f32>,
            \\    @location(1) velocity: vec2<f32>,
            \\    @location(2) species: f32,
            \\}
            \\
            \\struct VertexOutput {
            \\    @builtin(position) clip_position: vec4<f32>,
            \\    @location(0) color: vec4<f32>,
            \\}
            \\
            \\struct Species {
            \\    color: vec4<f32>,
            \\    forces: vec4<f32>,
            \\}
            \\
            \\@group(0) @binding(0) var<uniform> species_data: array<Species, 4>;
            \\
            \\@vertex
            \\fn vs_main(vertex: VertexInput) -> VertexOutput {
            \\    var out: VertexOutput;
            \\    out.clip_position = vec4<f32>(vertex.position, 0.0, 1.0);
            \\    
            \\    let species_idx = u32(vertex.species);
            \\    out.color = species_data[species_idx].color;
            \\    
            \\    return out;
            \\}
        ;

        const fragment_shader_source =
            \\struct VertexOutput {
            \\    @builtin(position) clip_position: vec4<f32>,
            \\    @location(0) color: vec4<f32>,
            \\}
            \\
            \\@fragment
            \\fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
            \\    // Create a circular particle with smooth edges
            \\    let center = vec2<f32>(0.5, 0.5);
            \\    let coord = (in.clip_position.xy / in.clip_position.w + 1.0) * 0.5;
            \\    let dist = distance(coord, center);
            \\    let alpha = 1.0 - smoothstep(0.0, 0.02, dist);
            \\    
            \\    return vec4<f32>(in.color.rgb, in.color.a * alpha);
            \\}
        ;

        const vertex_shader = try webgpu.deviceCreateShaderModule(self.device, &webgpu.ShaderModuleDescriptor{
            .label = "vertex_shader",
            .wgsl_code = .{
                .code_ptr = vertex_shader_source.ptr,
                .code_len = vertex_shader_source.len,
            },
        });

        const fragment_shader = try webgpu.deviceCreateShaderModule(self.device, &webgpu.ShaderModuleDescriptor{
            .label = "fragment_shader",
            .wgsl_code = .{
                .code_ptr = fragment_shader_source.ptr,
                .code_len = fragment_shader_source.len,
            },
        });

        const pipeline_layout = try webgpu.deviceCreatePipelineLayout(self.device, &webgpu.PipelineLayoutDescriptor{
            .label = "render_pipeline_layout",
            .bind_group_layouts = &[_]webgpu.BindGroupLayout{self.uniform_bind_group_layout},
            .bind_group_layouts_len = 1,
        });

        const vertex_attributes = [_]webgpu.VertexAttribute{
            .{ .offset = 0, .shader_location = 0, .format = .float32x2 }, // position
            .{ .offset = 8, .shader_location = 1, .format = .float32x2 }, // velocity
            .{ .offset = 16, .shader_location = 2, .format = .float32 }, // species
        };

        const vertex_buffer_layout = webgpu.VertexBufferLayout{
            .array_stride = @sizeOf(Particle),
            .step_mode = .vertex,
            .attributes = &vertex_attributes,
            .attributes_len = vertex_attributes.len,
        };

        self.render_pipeline = try webgpu.deviceCreateRenderPipeline(self.device, &webgpu.RenderPipelineDescriptor{
            .label = "render_pipeline",
            .layout = pipeline_layout,
            .vertex = .{
                .module = vertex_shader,
                .entry_point = "vs_main",
                .buffers = &[_]webgpu.VertexBufferLayout{vertex_buffer_layout},
                .buffers_len = 1,
            },
            .primitive = .{
                .topology = .point_list,
                .strip_index_format = .uint16,
                .strip_index_format_is_present = false,
                .front_face = .ccw,
                .cull_mode = .none,
            },
            .depth_stencil = null,
            .multisample = .{
                .count = 1,
                .mask = 0xFFFFFFFF,
                .alpha_to_coverage_enabled = false,
            },
            .fragment = &webgpu.FragmentState{
                .module = fragment_shader,
                .entry_point = "fs_main",
                .targets = &[_]webgpu.ColorTargetState{
                    .{
                        .format = surface_format,
                        .blend = &webgpu.BlendState{
                            .color = .{
                                .operation = .add,
                                .src_factor = .src_alpha,
                                .dst_factor = .one_minus_src_alpha,
                            },
                            .alpha = .{
                                .operation = .add,
                                .src_factor = .one,
                                .dst_factor = .zero,
                            },
                        },
                        .write_mask = webgpu.ColorWriteMask.ALL,
                    },
                },
                .targets_len = 1,
            },
        });
    }

    pub fn updateSimulation(self: *ParticleLifeRenderer) void {
        // CPU-based physics simulation (will move to compute shader later)
        const dt = self.params.dt;
        const force_range = self.params.force_range;
        const force_scale = self.params.force_scale;
        const friction = self.params.friction;

        // Apply forces between particles
        for (self.particles, 0..) |*particle_a, i| {
            var fx: f32 = 0.0;
            var fy: f32 = 0.0;

            const species_a = @as(u32, @intFromFloat(particle_a.species));

            // Check forces from nearby particles
            for (self.particles, 0..) |particle_b, j| {
                if (i == j) continue;

                const dx = particle_b.x - particle_a.x;
                const dy = particle_b.y - particle_a.y;
                const dist_sq = dx * dx + dy * dy;
                const dist = @sqrt(dist_sq);

                if (dist < force_range and dist > 0.01) {
                    const species_b = @as(u32, @intFromFloat(particle_b.species));
                    const force_strength = self.species[species_a].forces[species_b];

                    const force_magnitude = force_strength * force_scale / (dist_sq + 0.001);
                    fx += force_magnitude * dx;
                    fy += force_magnitude * dy;
                }
            }

            // Update velocity with forces and friction
            particle_a.vx = (particle_a.vx + fx * dt) * friction;
            particle_a.vy = (particle_a.vy + fy * dt) * friction;

            // Update position
            particle_a.x += particle_a.vx * dt;
            particle_a.y += particle_a.vy * dt;

            // Wrap around world boundaries
            const half_world = self.params.world_size * 0.5;
            if (particle_a.x > half_world) particle_a.x -= self.params.world_size;
            if (particle_a.x < -half_world) particle_a.x += self.params.world_size;
            if (particle_a.y > half_world) particle_a.y -= self.params.world_size;
            if (particle_a.y < -half_world) particle_a.y += self.params.world_size;
        }
    }

    pub fn render(self: *ParticleLifeRenderer, surface_view: webgpu.TextureView) !void {
        // Update physics simulation
        self.updateSimulation();
        self.frame_count += 1;

        // Update particle buffer
        webgpu.queueWriteBuffer(self.queue, self.particle_buffer, 0, @sizeOf(Particle) * self.params.particle_count, @ptrCast(self.particles.ptr));

        const command_encoder = try webgpu.deviceCreateCommandEncoder(self.device, &webgpu.CommandEncoderDescriptor{
            .label = "render_encoder",
        });

        const render_pass = try webgpu.commandEncoderBeginRenderPass(command_encoder, &webgpu.RenderPassDescriptor{
            .label = "render_pass",
            .color_attachments = &[_]webgpu.RenderPassColorAttachment{
                .{
                    .view = surface_view,
                    .resolve_target = 0,
                    .resolve_target_is_present = false,
                    .load_op = .clear,
                    .store_op = .store,
                    .clear_value = &static_clear_color,
                },
            },
            .color_attachments_len = 1,
            .depth_stencil_attachment = null,
            .occlusion_query_set = 0,
            .occlusion_query_set_is_present = false,
        });

        webgpu.renderPassEncoderSetPipeline(render_pass, self.render_pipeline);
        webgpu.renderPassEncoderSetBindGroup(render_pass, 0, self.uniform_bind_group, null);
        webgpu.renderPassEncoderSetVertexBuffer(render_pass, 0, self.particle_buffer, 0, webgpu.WHOLE_SIZE);
        webgpu.renderPassEncoderDraw(render_pass, self.params.particle_count, 1, 0, 0);

        webgpu.renderPassEncoderEnd(render_pass);

        const command_buffer = try webgpu.commandEncoderFinish(command_encoder, &webgpu.CommandBufferDescriptor{
            .label = "render_commands",
        });

        webgpu.queueSubmit(self.queue, &[_]webgpu.CommandBuffer{command_buffer});
    }

    pub fn deinit(self: *ParticleLifeRenderer) void {
        if (self.particles.len > 0) {
            allocator.free(self.particles);
        }
    }
};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

export fn _start() void {
    allocator = gpa.allocator();
    webutils.log("Starting particle life simulation...");

    // Initialize WebGPU through the handler
    webgpu_handler.initGlobalHandler();
    webutils.log("WebGPU initialization started (async)...");
}

export fn update_frame() void {
    // Update input handling first
    input_handler.update();

    // Check if WebGPU is ready
    if (!webgpu_handler.isGlobalHandlerInitialized()) {
        if (webgpu_handler.hasGlobalHandlerFailed()) {
            webutils.log("WebGPU initialization failed, cannot proceed.");
        }
        return; // Wait for WebGPU to be ready
    }

    if (particle_life_renderer == null) {
        webutils.log("Attempting to initialize particle life renderer...");
        const device = webgpu_handler.g_wgpu_handler_instance.device;
        const queue = webgpu_handler.g_wgpu_handler_instance.queue;

        if (device == 0 or queue == 0) {
            return;
        }

        // Get surface format
        const surface_format = webgpu_handler.g_wgpu_handler_instance.getPreferredCanvasFormat() orelse .bgra8unorm;

        particle_life_renderer = ParticleLifeRenderer.init(device, queue, surface_format) catch |err| {
            webutils.log("Failed to initialize particle life renderer: ");
            webutils.log(@errorName(err));
            return;
        };

        webutils.log("Particle life renderer initialized successfully!");
        return;
    }

    // Get surface view and render
    const surface_view = webgpu.getCurrentTextureView() catch {
        return;
    };

    particle_life_renderer.?.render(surface_view) catch |err| {
        webutils.log("Render error: ");
        webutils.log(@errorName(err));
    };
}

export fn shutdown() void {
    webutils.log("Wasm shutdown requested.");

    if (particle_life_renderer) |*r| {
        webutils.log("Deinitializing Particle Life Renderer...");
        r.deinit();
        particle_life_renderer = null;
        webutils.log("Particle Life Renderer deinitialized.");
    }

    webgpu_handler.deinitGlobalHandler();
}
