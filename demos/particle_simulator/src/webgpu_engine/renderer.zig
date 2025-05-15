const std = @import("std");
const webgpu = @import("zig-wasm-ffi").webgpu;
const WebGPUHandler = @import("webgpu_handler.zig").WebGPUHandler;
const log = @import("zig-wasm-ffi").utils.log;
const math = std.math;
const random = std.crypto.random;

// Embed shader code
const particle_binning_wgsl = @embedFile("../../shaders/particle_binning.wgsl");
const particle_compute_wgsl = @embedFile("../../shaders/particle_compute.wgsl");
const particle_prefix_sum_wgsl = @embedFile("../../shaders/particle_prefix_sum.wgsl");
const particle_render_wgsl = @embedFile("../../shaders/particle_render.wgsl");
const particle_sort_wgsl = @embedFile("../../shaders/particle_sort.wgsl");
const particle_compose_wgsl = @embedFile("../../shaders/particle_compose.wgsl");

// --- Data Structs (mirroring WGSL) ---
const Particle = extern struct {
    x: f32,
    y: f32,
    vx: f32,
    vy: f32,
    species_id: f32, // WGSL uses f32, could be u32 if shader adapted
};

const Species = extern struct {
    color: [4]f32, // vec4f
};

const Force = extern struct {
    strength: f32,
    radius: f32,
    collision_strength: f32,
    collision_radius: f32,
};

const SimulationOptionsUniforms = extern struct {
    left: f32,
    right: f32,
    bottom: f32,
    top: f32,
    friction: f32,
    dt: f32,
    bin_size: f32, // maxForceRadius in JS
    species_count: f32,
    central_force: f32,
    looping_borders: f32, // 0.0 or 1.0
    action_x: f32,
    action_y: f32,
    action_vx: f32,
    action_vy: f32,
    action_force: f32,
    action_radius: f32,
    _padding1: f32, // Ensure alignment if necessary, WGSL structs are packed by default.
    _padding2: f32,
    _padding3: f32,
    // Total size 16*4 = 64 bytes (as in JS example simulationOptionsBuffer)
    // Current fields: 16 f32s. Exact match.
};

const CameraUniforms = extern struct {
    center: [2]f32, // vec2f
    extent: [2]f32, // vec2f
    pixels_per_unit: f32,
    _padding: [3]f32, // Align to 16 bytes for vec2f, then to next 16 byte boundary for total struct
    // center: 8, extent: 8, pixels_per_unit: 4. Total 20. Pad to 24 (JS size) or 32.
    // JS cameraBuffer is 24 bytes. center=8, extent=8, pixels_per_unit=4. (5*f32) + 1 f32 padding.
    // Let's match JS: 5 floats. 5*4 = 20 bytes. Needs padding to be multiple of 16 for uniform buffer entry.
    // Smallest multiple of 16 >= 20 is 32. So 3 floats padding (12 bytes)
    // Correct padding based on JS: size 24. So 1 f32 padding for a total of 6 f32s.
    // center: [2]f32, extent: [2]f32, pixels_per_unit: f32, _p1: f32 -> 6 * 4 = 24 bytes.
};

pub const RendererError = error{
    ShaderModuleCreationError,
    BufferCreationError,
    TextureCreationError,
    TextureViewCreationError,
    DeviceOrQueueUnavailable,
    BindGroupLayoutCreationError,
};

// Default simulation parameters
const DEFAULT_SPECIES_COUNT: u32 = 8;
const DEFAULT_PARTICLE_COUNT: u32 = 65536;
const MAX_FORCE_RADIUS: f32 = 32.0;
const INITIAL_VELOCITY: f32 = 10.0;

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    wgpu_handler: *WebGPUHandler,

    // Shader Modules
    binning_module: webgpu.ShaderModule,
    compute_module: webgpu.ShaderModule,
    prefix_sum_module: webgpu.ShaderModule,
    render_module: webgpu.ShaderModule,
    sort_module: webgpu.ShaderModule,
    compose_module: webgpu.ShaderModule,

    // Buffers
    species_buffer: webgpu.Buffer,
    forces_buffer: webgpu.Buffer,
    particle_buffer_a: webgpu.Buffer, // Ping-pong buffers for particles
    particle_buffer_b: webgpu.Buffer,
    bin_offset_buffer_a: webgpu.Buffer, // Ping-pong for bin offsets
    bin_offset_buffer_b: webgpu.Buffer,
    bin_prefix_sum_step_size_buffer: webgpu.Buffer,
    camera_buffer: webgpu.Buffer,
    simulation_options_buffer: webgpu.Buffer,

    // Textures & Views
    blue_noise_texture: webgpu.Texture,
    blue_noise_texture_view: webgpu.TextureView,
    hdr_texture: webgpu.Texture,
    hdr_texture_view: webgpu.TextureView,

    // Bind Group Layouts
    particle_buffer_bgl: webgpu.BindGroupLayout, // For particle advance, expects particle R/W (storage), forces R (read-only storage)
    particle_buffer_read_only_bgl: webgpu.BindGroupLayout, // For rendering & some compute, expects particle R (read-only storage), species R (read-only storage)
    camera_bgl: webgpu.BindGroupLayout,
    simulation_options_bgl: webgpu.BindGroupLayout,
    bin_fill_size_bgl: webgpu.BindGroupLayout, // For binning shaders, expects bin_offset W (storage)
    bin_prefix_sum_bgl: webgpu.BindGroupLayout, // Expects source R (read-only storage), dest W (storage), step_size U (uniform)
    particle_sort_bgl: webgpu.BindGroupLayout, // Expects particle_src R, particle_dest W, bin_offset R, bin_size_atomic W
    particle_compute_forces_bgl: webgpu.BindGroupLayout, // Expects particle_src R, particle_dest W, bin_offset R, forces R
    compose_bgl: webgpu.BindGroupLayout, // Expects hdr_texture, blue_noise_texture (both texture_2d<f32>)

    // Current active particle buffers (for easier ping-pong management)
    current_particle_buffer: webgpu.Buffer,
    next_particle_buffer: webgpu.Buffer,
    current_bin_offset_buffer: webgpu.Buffer,
    next_bin_offset_buffer: webgpu.Buffer,

    // Other state
    particle_count: u32 = DEFAULT_PARTICLE_COUNT,
    species_count: u32 = DEFAULT_SPECIES_COUNT,
    simulation_box_width: f32 = 1024.0,
    simulation_box_height: f32 = 576.0,

    pub fn init(allocator: std.mem.Allocator, wgpu_handler: *WebGPUHandler) !*Renderer {
        var self = try allocator.create(Renderer);
        self.* = .{
            .allocator = allocator,
            .wgpu_handler = wgpu_handler,
            .binning_module = undefined,
            .compute_module = undefined,
            .prefix_sum_module = undefined,
            .render_module = undefined,
            .sort_module = undefined,
            .compose_module = undefined,
            .species_buffer = undefined,
            .forces_buffer = undefined,
            .particle_buffer_a = undefined,
            .particle_buffer_b = undefined,
            .bin_offset_buffer_a = undefined,
            .bin_offset_buffer_b = undefined,
            .bin_prefix_sum_step_size_buffer = undefined,
            .camera_buffer = undefined,
            .simulation_options_buffer = undefined,
            .blue_noise_texture = undefined,
            .blue_noise_texture_view = undefined,
            .hdr_texture = undefined,
            .hdr_texture_view = undefined,
            .particle_buffer_bgl = undefined,
            .particle_buffer_read_only_bgl = undefined,
            .camera_bgl = undefined,
            .simulation_options_bgl = undefined,
            .bin_fill_size_bgl = undefined,
            .bin_prefix_sum_bgl = undefined,
            .particle_sort_bgl = undefined,
            .particle_compute_forces_bgl = undefined,
            .compose_bgl = undefined,
            .current_particle_buffer = undefined,
            .next_particle_buffer = undefined,
            .current_bin_offset_buffer = undefined,
            .next_bin_offset_buffer = undefined,
            // particle_count, species_count, etc initialized by struct defaults
        };

        const device = wgpu_handler.device orelse return RendererError.DeviceOrQueueUnavailable;

        // Initialize Shader Modules (existing code)
        log.debug("Renderer.init: Creating shader modules...", .{});
        self.binning_module = try self.createShaderModule(device, particle_binning_wgsl, "particle_binning_shader");
        self.compute_module = try self.createShaderModule(device, particle_compute_wgsl, "particle_compute_shader");
        self.prefix_sum_module = try self.createShaderModule(device, particle_prefix_sum_wgsl, "particle_prefix_sum_shader");
        self.render_module = try self.createShaderModule(device, particle_render_wgsl, "particle_render_shader");
        self.sort_module = try self.createShaderModule(device, particle_sort_wgsl, "particle_sort_shader");
        self.compose_module = try self.createShaderModule(device, particle_compose_wgsl, "particle_compose_shader");
        log.info("Shader modules initialized.", .{});

        // Initialize Buffers
        log.debug("Renderer.init: Creating buffers...", .{});
        try self.createAndInitializeBuffers(device);
        log.info("Buffers initialized.", .{});

        // Initialize Textures (Placeholders for now)
        log.debug("Renderer.init: Creating textures...", .{});
        try self.createPlaceholderTextures(device);
        log.info("Placeholder textures initialized.", .{});

        // Setup ping-pong buffers initial state
        self.current_particle_buffer = self.particle_buffer_a;
        self.next_particle_buffer = self.particle_buffer_b;
        self.current_bin_offset_buffer = self.bin_offset_buffer_a;
        self.next_bin_offset_buffer = self.bin_offset_buffer_b;

        log.debug("Renderer.init: Creating bind group layouts...", .{});
        try self.createBindGroupLayouts(device);
        log.info("Bind group layouts initialized.", .{});

        log.info("Renderer initialized successfully.", .{});
        return self;
    }

    fn createShaderModule(self: *Renderer, device: webgpu.Device, code: []const u8, label: []const u8) !webgpu.ShaderModule {
        _ = self; // self not used yet, but might be if allocator needed for label clone
        const desc = webgpu.ShaderModuleDescriptor{
            .label = label,
            .code = code,
        };
        return webgpu.deviceCreateShaderModule(device, &desc) catch |err| {
            log.err("Failed to create shader module '{s}': {any}", .{ label, err });
            return RendererError.ShaderModuleCreationError;
        };
    }

    fn createAndInitializeBuffers(self: *Renderer, device: webgpu.Device) !void {
        const particle_buffer_size = @sizeOf(Particle) * self.particle_count;
        const species_buffer_size = @sizeOf(Species) * self.species_count;
        const forces_buffer_size = @sizeOf(Force) * self.species_count * self.species_count;

        const sim_box_width = self.simulation_box_width;
        const sim_box_height = self.simulation_box_height;
        const grid_size_x: f32 = @ceil(sim_box_width / MAX_FORCE_RADIUS);
        const grid_size_y: f32 = @ceil(sim_box_height / MAX_FORCE_RADIUS);
        const bin_count: u32 = @intFromFloat(grid_size_x * grid_size_y);
        const bin_offset_buffer_size = @sizeOf(u32) * (bin_count + 1);

        // Max prefix sum iterations: ceil(log2(binCount + 1)) / 2) * 2 -> simplified to just ceil(log2(N))
        const prefix_sum_iterations = if (bin_count == 0) 0 else math.log2_ceil_u32(bin_count + 1);
        const prefix_sum_step_buffer_size = @sizeOf(u32) * prefix_sum_iterations * 64; // *64 due to JS example structure, likely for uniform offset alignment per step

        self.species_buffer = try device.createBuffer(&webgpu.BufferDescriptor{
            .label = "species_buffer",
            .size = species_buffer_size,
            .usage = webgpu.BufferUsage.STORAGE | webgpu.BufferUsage.COPY_DST,
            .mapped_at_creation = false,
        });

        self.forces_buffer = try device.createBuffer(&webgpu.BufferDescriptor{
            .label = "forces_buffer",
            .size = forces_buffer_size,
            .usage = webgpu.BufferUsage.STORAGE | webgpu.BufferUsage.COPY_DST,
            .mapped_at_creation = false,
        });

        self.particle_buffer_a = try device.createBuffer(&webgpu.BufferDescriptor{
            .label = "particle_buffer_a",
            .size = particle_buffer_size,
            .usage = webgpu.BufferUsage.STORAGE | webgpu.BufferUsage.COPY_DST | webgpu.BufferUsage.COPY_SRC,
            .mapped_at_creation = false,
        });
        self.particle_buffer_b = try device.createBuffer(&webgpu.BufferDescriptor{
            .label = "particle_buffer_b",
            .size = particle_buffer_size,
            .usage = webgpu.BufferUsage.STORAGE | webgpu.BufferUsage.COPY_DST | webgpu.BufferUsage.COPY_SRC, // COPY_SRC if read back or for other copies
            .mapped_at_creation = false,
        });

        self.bin_offset_buffer_a = try device.createBuffer(&webgpu.BufferDescriptor{
            .label = "bin_offset_buffer_a",
            .size = bin_offset_buffer_size,
            .usage = webgpu.BufferUsage.STORAGE | webgpu.BufferUsage.COPY_SRC,
            .mapped_at_creation = false,
        });
        self.bin_offset_buffer_b = try device.createBuffer(&webgpu.BufferDescriptor{
            .label = "bin_offset_buffer_b",
            .size = bin_offset_buffer_size,
            .usage = webgpu.BufferUsage.STORAGE | webgpu.BufferUsage.COPY_SRC,
            .mapped_at_creation = false,
        });

        self.bin_prefix_sum_step_size_buffer = try device.createBuffer(&webgpu.BufferDescriptor{
            .label = "bin_prefix_sum_step_size_buffer",
            .size = prefix_sum_step_buffer_size,
            .usage = webgpu.BufferUsage.UNIFORM | webgpu.BufferUsage.COPY_DST,
            .mapped_at_creation = false,
        });

        self.camera_buffer = try device.createBuffer(&webgpu.BufferDescriptor{
            .label = "camera_buffer",
            .size = @sizeOf(CameraUniforms),
            .usage = webgpu.BufferUsage.UNIFORM | webgpu.BufferUsage.COPY_DST,
            .mapped_at_creation = false,
        });

        self.simulation_options_buffer = try device.createBuffer(&webgpu.BufferDescriptor{
            .label = "simulation_options_buffer",
            .size = @sizeOf(SimulationOptionsUniforms),
            .usage = webgpu.BufferUsage.UNIFORM | webgpu.BufferUsage.COPY_DST,
            .mapped_at_creation = false,
        });

        // Initial data population
        const queue = self.wgpu_handler.queue orelse return RendererError.DeviceOrQueueUnavailable;

        // Species Data (example: distinct colors)
        const species_data = try self.allocator.alloc(Species, self.species_count);
        defer self.allocator.free(species_data);
        for (species_data, 0..) |*s, i| {
            s.color[0] = @as(f32, @floatFromInt(i % 3)) * 0.5 + 0.2;
            s.color[1] = @as(f32, @floatFromInt((i + 1) % 3)) * 0.5 + 0.2;
            s.color[2] = @as(f32, @floatFromInt((i + 2) % 3)) * 0.5 + 0.2;
            s.color[3] = 1.0;
        }
        queue.writeBuffer(self.species_buffer, 0, std.mem.sliceAsBytes(species_data));

        // Forces Data (example: random forces)
        const forces_data = try self.allocator.alloc(Force, self.species_count * self.species_count);
        defer self.allocator.free(forces_data);
        for (forces_data) |*f| {
            f.strength = (random.float(f32) - 0.5) * 2.0 * MAX_FORCE_RADIUS; // Random strength
            f.radius = random.float(f32) * (MAX_FORCE_RADIUS - 2.0) + 2.0;
            f.collision_strength = random.float(f32) * 20.0;
            f.collision_radius = random.float(f32) * f.radius * 0.5;
        }
        queue.writeBuffer(self.forces_buffer, 0, std.mem.sliceAsBytes(forces_data));

        // Particle Data (random initial state)
        const particle_data = try self.allocator.alloc(Particle, self.particle_count);
        defer self.allocator.free(particle_data);
        const half_width = sim_box_width / 2.0;
        const half_height = sim_box_height / 2.0;
        for (particle_data) |*p| {
            p.x = (random.float(f32) - 0.5) * 2.0 * half_width;
            p.y = (random.float(f32) - 0.5) * 2.0 * half_height;
            p.vx = (random.float(f32) - 0.5) * 2.0 * INITIAL_VELOCITY;
            p.vy = (random.float(f32) - 0.5) * 2.0 * INITIAL_VELOCITY;
            p.species_id = @as(f32, @floatFromInt(random.intRangeAtMost(u32, 0, self.species_count - 1)));
        }
        queue.writeBuffer(self.particle_buffer_a, 0, std.mem.sliceAsBytes(particle_data));
        // particle_buffer_b doesn't need initial data, it's a destination first.

        // Bin Prefix Sum Step Size Buffer (powers of 2)
        if (prefix_sum_iterations > 0) { // only if bin_count > 0
            var step_data_aligned = try self.allocator.alloc(u32, prefix_sum_iterations * 64); // Each step value at offset i * 256 bytes
            defer self.allocator.free(step_data_aligned);
            @memset(step_data_aligned, 0); // Zero out, only specific indices are set
            for (0..prefix_sum_iterations) |i| {
                step_data_aligned[i * 64] = math.pow(u32, 2, i);
            }
            queue.writeBuffer(self.bin_prefix_sum_step_size_buffer, 0, std.mem.sliceAsBytes(step_data_aligned));
        }

        // Camera & Sim Options with some defaults (can be updated per frame)
        const initial_cam_data = CameraUniforms{
            .center = .{ 0.0, 0.0 },
            .extent = .{ sim_box_width / 2.0, sim_box_height / 2.0 },
            .pixels_per_unit = 1.0,
            ._padding = .{0} ** 1, // Adjusted padding to 1 f32 to make total 6 f32s = 24 bytes.
        };
        queue.writeBuffer(self.camera_buffer, 0, std.mem.asBytes(&initial_cam_data));

        const initial_sim_options = SimulationOptionsUniforms{
            .left = -half_width,
            .right = half_width,
            .bottom = -half_height,
            .top = half_height,
            .friction = 0.98, // Example, from friction factor exp(-simDt * friction_val)
            .dt = 1.0 / 60.0,
            .bin_size = MAX_FORCE_RADIUS,
            .species_count = @as(f32, @floatFromInt(self.species_count)),
            .central_force = 0.0,
            .looping_borders = 0.0, // false
            .action_x = 0,
            .action_y = 0,
            .action_vx = 0,
            .action_vy = 0,
            .action_force = 0,
            .action_radius = 0,
            ._padding1 = 0,
            ._padding2 = 0,
            ._padding3 = 0,
        };
        queue.writeBuffer(self.simulation_options_buffer, 0, std.mem.asBytes(&initial_sim_options));
    }

    fn createPlaceholderTextures(self: *Renderer, device: webgpu.Device) !void {
        // Blue Noise Texture (placeholder 64x64 RGBA8)
        // Actual loading from image would be more complex, involving JS interop typically
        self.blue_noise_texture = try device.createTexture(&webgpu.TextureDescriptor{
            .label = "blue_noise_texture",
            .size = .{ .width = 64, .height = 64, .depth_or_array_layers = 1 },
            .mip_level_count = 1,
            .sample_count = 1,
            .dimension = "2d",
            .format = .rgba8unorm_srgb, // Format from JS example
            .usage = webgpu.TextureUsage.TEXTURE_BINDING | webgpu.TextureUsage.COPY_DST | webgpu.TextureUsage.RENDER_ATTACHMENT, // As per JS
        });
        self.blue_noise_texture_view = try self.blue_noise_texture.createView(&webgpu.TextureViewDescriptor{}); // Default view

        // HDR Texture (placeholder, typically canvas sized, e.g., 1x1 initially)
        self.hdr_texture = try device.createTexture(&webgpu.TextureDescriptor{
            .label = "hdr_texture",
            .size = .{ .width = 1, .height = 1, .depth_or_array_layers = 1 }, // Will be resized
            .mip_level_count = 1,
            .sample_count = 1,
            .dimension = "2d",
            .format = .rgba16float, // HDR format from JS example
            .usage = webgpu.TextureUsage.RENDER_ATTACHMENT | webgpu.TextureUsage.TEXTURE_BINDING,
        });
        self.hdr_texture_view = try self.hdr_texture.createView(&webgpu.TextureViewDescriptor{});
    }

    fn createBindGroupLayouts(self: *Renderer, device: webgpu.Device) !void {
        // Particle Buffer BGL (for particle advance: particles R/W, forces R)
        // Corresponds to JS particleBufferBindGroupLayout
        // Used by particleAdvancePipeline (particle_buffer_bind_group)
        // Shader: particle_compute.wgsl (advance) -> group(0) binding(0) particles (read_write), binding(1) forces (read_only)
        // Note: original JS had forces in this BGL. The compute.wgsl for advance does not show forces. It's in computeForces. Let's verify.
        // particle_advance.wgsl (from old HTML): @group(0) @binding(0) var<storage, read_write> particles
        // So this BGL is simpler.
        // Let's make one for Particle Advance (particles R/W)
        // And another for Compute Forces (particles_src R, particles_dest W, bin_offset R, forces R)

        // BGL for Particle Advance (particles: read_write storage)
        // This matches particle_buffer_bind_group in JS if it were only for particle_advance_shader
        const particle_advance_bgl_entries = [_]webgpu.BindGroupLayoutEntry{
            .{ .binding = 0, .visibility = webgpu.ShaderStage.COMPUTE, .buffer = .{ .type = .storage } },
        };
        self.particle_buffer_bgl = try device.createBindGroupLayout(&webgpu.BindGroupLayoutDescriptor{
            .label = "particle_advance_bgl",
            .entries = &particle_advance_bgl_entries,
        });

        // Particle Buffer Read-Only BGL (particles R, species R)
        // Corresponds to JS particleBufferReadOnlyBindGroupLayout
        // Used by particleRenderPipelines, binFillSizePipeline, particleSortClearSizePipeline, particleSortPipeline (for source particles)
        // Shaders: particle_render.wgsl, particle_binning.wgsl (fillBinSize), particle_sort.wgsl (sortParticles source)
        const particle_read_only_bgl_entries = [_]webgpu.BindGroupLayoutEntry{
            .{ .binding = 0, .visibility = webgpu.ShaderStage.VERTEX | webgpu.ShaderStage.COMPUTE, .buffer = .{ .type = .read_only_storage } },
            .{ .binding = 1, .visibility = webgpu.ShaderStage.VERTEX | webgpu.ShaderStage.COMPUTE, .buffer = .{ .type = .read_only_storage } },
        };
        self.particle_buffer_read_only_bgl = try device.createBindGroupLayout(&webgpu.BindGroupLayoutDescriptor{
            .label = "particle_buffer_read_only_bgl",
            .entries = &particle_read_only_bgl_entries,
        });

        // Camera BGL (camera UBO)
        // Corresponds to JS cameraBindGroupLayout
        const camera_bgl_entries = [_]webgpu.BindGroupLayoutEntry{
            .{ .binding = 0, .visibility = webgpu.ShaderStage.VERTEX | webgpu.ShaderStage.FRAGMENT, .buffer = .{ .type = .uniform } },
        };
        self.camera_bgl = try device.createBindGroupLayout(&webgpu.BindGroupLayoutDescriptor{
            .label = "camera_bgl",
            .entries = &camera_bgl_entries,
        });

        // Simulation Options BGL (sim options UBO)
        // Corresponds to JS simulationOptionsBindGroupLayout
        const sim_options_bgl_entries = [_]webgpu.BindGroupLayoutEntry{
            .{ .binding = 0, .visibility = webgpu.ShaderStage.COMPUTE, .buffer = .{ .type = .uniform } },
        };
        self.simulation_options_bgl = try device.createBindGroupLayout(&webgpu.BindGroupLayoutDescriptor{
            .label = "simulation_options_bgl",
            .entries = &sim_options_bgl_entries,
        });

        // Bin Fill Size BGL (bin_offset W storage)
        // Corresponds to JS binFillSizeBindGroupLayout
        // Used by binClearSizePipeline, binFillSizePipeline (bin_fill_size_bind_group)
        // Shader: particle_binning.wgsl -> group(2) binding(0) binSize (atomic, so storage)
        const bin_fill_size_bgl_entries = [_]webgpu.BindGroupLayoutEntry{
            .{ .binding = 0, .visibility = webgpu.ShaderStage.COMPUTE, .buffer = .{ .type = .storage } },
        };
        self.bin_fill_size_bgl = try device.createBindGroupLayout(&webgpu.BindGroupLayoutDescriptor{
            .label = "bin_fill_size_bgl",
            .entries = &bin_fill_size_bgl_entries,
        });

        // Bin Prefix Sum BGL (source R, dest W, step_size UBO with dynamic offset)
        // Corresponds to JS binPrefixSumBindGroupLayout
        // Shader: particle_prefix_sum.wgsl -> group(0) binding(0) source (R), binding(1) dest (W), binding(2) stepSize (U)
        const prefix_sum_bgl_entries = [_]webgpu.BindGroupLayoutEntry{
            .{ .binding = 0, .visibility = webgpu.ShaderStage.COMPUTE, .buffer = .{ .type = .read_only_storage } },
            .{ .binding = 1, .visibility = webgpu.ShaderStage.COMPUTE, .buffer = .{ .type = .storage } },
            .{ .binding = 2, .visibility = webgpu.ShaderStage.COMPUTE, .buffer = .{ .type = .uniform, .has_dynamic_offset = true, .min_binding_size = @sizeOf(u32) } },
        };
        self.bin_prefix_sum_bgl = try device.createBindGroupLayout(&webgpu.BindGroupLayoutDescriptor{
            .label = "bin_prefix_sum_bgl",
            .entries = &prefix_sum_bgl_entries,
        });

        // Particle Sort BGL (source_particles R, dest_particles W, bin_offset R, bin_current_size_atomic W)
        // Corresponds to JS particleSortBindGroupLayout
        // Shader: particle_sort.wgsl -> group(0) binding(0) source R, binding(1) dest W, binding(2) binOffset R, binding(3) binSize W (atomic)
        const particle_sort_bgl_entries = [_]webgpu.BindGroupLayoutEntry{
            .{ .binding = 0, .visibility = webgpu.ShaderStage.COMPUTE, .buffer = .{ .type = .read_only_storage } },
            .{ .binding = 1, .visibility = webgpu.ShaderStage.COMPUTE, .buffer = .{ .type = .storage } },
            .{ .binding = 2, .visibility = webgpu.ShaderStage.COMPUTE, .buffer = .{ .type = .read_only_storage } },
            .{ .binding = 3, .visibility = webgpu.ShaderStage.COMPUTE, .buffer = .{ .type = .storage } }, // For atomic bin sizes
        };
        self.particle_sort_bgl = try device.createBindGroupLayout(&webgpu.BindGroupLayoutDescriptor{
            .label = "particle_sort_bgl",
            .entries = &particle_sort_bgl_entries,
        });

        // Particle Compute Forces BGL (particles_src R, particles_dest W, bin_offset R, forces R)
        // Corresponds to JS particleComputeForcesBindGroupLayout
        // Shader: particle_compute.wgsl (computeForces) -> group(0) binding(0) particlesSource R, binding(1) particlesDest W, binding(2) binOffset R, binding(3) forces R
        const particle_compute_forces_bgl_entries = [_]webgpu.BindGroupLayoutEntry{
            .{ .binding = 0, .visibility = webgpu.ShaderStage.COMPUTE, .buffer = .{ .type = .read_only_storage } },
            .{ .binding = 1, .visibility = webgpu.ShaderStage.COMPUTE, .buffer = .{ .type = .storage } },
            .{ .binding = 2, .visibility = webgpu.ShaderStage.COMPUTE, .buffer = .{ .type = .read_only_storage } },
            .{ .binding = 3, .visibility = webgpu.ShaderStage.COMPUTE, .buffer = .{ .type = .read_only_storage } },
        };
        self.particle_compute_forces_bgl = try device.createBindGroupLayout(&webgpu.BindGroupLayoutDescriptor{
            .label = "particle_compute_forces_bgl",
            .entries = &particle_compute_forces_bgl_entries,
        });

        // Compose BGL (hdrTexture texture_2d, blueNoiseTexture texture_2d)
        // Corresponds to JS composeBindGroupLayout
        // Shader: particle_compose.wgsl -> group(0) binding(0) hdrTexture, binding(1) blueNoiseTexture
        const compose_bgl_entries = [_]webgpu.BindGroupLayoutEntry{
            .{ .binding = 0, .visibility = webgpu.ShaderStage.FRAGMENT, .texture = .{ .sample_type = .float, .view_dimension = "2d" } },
            .{ .binding = 1, .visibility = webgpu.ShaderStage.FRAGMENT, .texture = .{ .sample_type = .float, .view_dimension = "2d" } }, // Assuming blue noise is also sampled as float in shader, though format is unorm
        };
        self.compose_bgl = try device.createBindGroupLayout(&webgpu.BindGroupLayoutDescriptor{
            .label = "compose_bgl",
            .entries = &compose_bgl_entries,
        });
    }

    pub fn deinit(self: *Renderer) void {
        log.debug("Renderer.deinit: Releasing resources...", .{});
        const device = self.wgpu_handler.device;
        // Release buffers
        // Check if device is null before releasing, though releaseHandle itself might be robust
        if (device != null) {
            webgpu.releaseHandle(self.species_buffer.handle, .Buffer);
            webgpu.releaseHandle(self.forces_buffer.handle, .Buffer);
            webgpu.releaseHandle(self.particle_buffer_a.handle, .Buffer);
            webgpu.releaseHandle(self.particle_buffer_b.handle, .Buffer);
            webgpu.releaseHandle(self.bin_offset_buffer_a.handle, .Buffer);
            webgpu.releaseHandle(self.bin_offset_buffer_b.handle, .Buffer);
            webgpu.releaseHandle(self.bin_prefix_sum_step_size_buffer.handle, .Buffer);
            webgpu.releaseHandle(self.camera_buffer.handle, .Buffer);
            webgpu.releaseHandle(self.simulation_options_buffer.handle, .Buffer);

            webgpu.releaseHandle(self.blue_noise_texture_view.handle, .TextureView);
            webgpu.releaseHandle(self.blue_noise_texture.handle, .Texture);
            webgpu.releaseHandle(self.hdr_texture_view.handle, .TextureView);
            webgpu.releaseHandle(self.hdr_texture.handle, .Texture);

            webgpu.releaseHandle(self.particle_buffer_bgl.handle, .BindGroupLayout);
            webgpu.releaseHandle(self.particle_buffer_read_only_bgl.handle, .BindGroupLayout);
            webgpu.releaseHandle(self.camera_bgl.handle, .BindGroupLayout);
            webgpu.releaseHandle(self.simulation_options_bgl.handle, .BindGroupLayout);
            webgpu.releaseHandle(self.bin_fill_size_bgl.handle, .BindGroupLayout);
            webgpu.releaseHandle(self.bin_prefix_sum_bgl.handle, .BindGroupLayout);
            webgpu.releaseHandle(self.particle_sort_bgl.handle, .BindGroupLayout);
            webgpu.releaseHandle(self.particle_compute_forces_bgl.handle, .BindGroupLayout);
            webgpu.releaseHandle(self.compose_bgl.handle, .BindGroupLayout);

            webgpu.releaseHandle(self.binning_module.handle, .ShaderModule);
            webgpu.releaseHandle(self.compute_module.handle, .ShaderModule);
            webgpu.releaseHandle(self.prefix_sum_module.handle, .ShaderModule);
            webgpu.releaseHandle(self.render_module.handle, .ShaderModule);
            webgpu.releaseHandle(self.sort_module.handle, .ShaderModule);
            webgpu.releaseHandle(self.compose_module.handle, .ShaderModule);
        } else {
            log.warn("Renderer.deinit: Device was null. Handles may not be released correctly if not already undefined.", .{});
            // If handles are non-zero, attempt release anyway as releaseHandle is global
            // This part is largely redundant if init fails before these are assigned valid handles from undefined
        }

        self.allocator.destroy(self);
        log.debug("Renderer deinitialized.", .{});
    }

    // renderFrame function will be added later
    // pub fn renderFrame(self: *Renderer) !void {
    //    const device = self.wgpu_handler.device orelse return error.DeviceNotAvailable;
    //    const queue = self.wgpu_handler.queue orelse return error.QueueNotAvailable;
    //    const surface_texture = self.wgpu_handler.surface_texture orelse return error.SurfaceTextureNotAvailable;
    //    const surface_view = self.wgpu_handler.surface_texture_view orelse return error.SurfaceViewNotAvailable;
    //
    // }
};
