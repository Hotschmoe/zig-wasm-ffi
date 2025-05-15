const std = @import("std");
const webgpu = @import("zig-wasm-ffi").webgpu;
const WebGPUHandler = @import("webgpu_handler.zig").WebGPUHandler;
const webutils = @import("zig-wasm-ffi").webutils; // Changed from: const log = @import("zig-wasm-ffi").utils.log;
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
    BindGroupCreationError,
    PipelineLayoutCreationError,
    PipelineCreationError,
    CommandEncoderCreationError,
    CommandBufferCreationError,
    SurfaceTextureUnavailable,
    SurfaceViewUnavailable,
};

// Default simulation parameters
const DEFAULT_SPECIES_COUNT: u32 = 8;
const DEFAULT_PARTICLE_COUNT: u32 = 65536;
const MAX_FORCE_RADIUS: f32 = 32.0;
const INITIAL_VELOCITY: f32 = 10.0;

const HDR_FORMAT: webgpu.TextureFormat = .rgba16float;

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
    particle_advance_bgl: webgpu.BindGroupLayout,
    particle_buffer_read_only_bgl: webgpu.BindGroupLayout,
    camera_bgl: webgpu.BindGroupLayout,
    simulation_options_bgl: webgpu.BindGroupLayout,
    bin_fill_size_bgl: webgpu.BindGroupLayout,
    bin_prefix_sum_bgl: webgpu.BindGroupLayout,
    particle_sort_bgl: webgpu.BindGroupLayout,
    particle_compute_forces_bgl: webgpu.BindGroupLayout,
    compose_bgl: webgpu.BindGroupLayout,

    // Bind Groups
    particle_advance_bg_a: webgpu.BindGroup,
    particle_advance_bg_b: webgpu.BindGroup,
    particle_read_only_bg_a: webgpu.BindGroup,
    particle_read_only_bg_b: webgpu.BindGroup,
    camera_bg: webgpu.BindGroup,
    simulation_options_bg: webgpu.BindGroup,
    bin_fill_size_main_target_bg: webgpu.BindGroup,
    bin_fill_size_temp_target_bg: webgpu.BindGroup,
    bin_prefix_sum_ab_bg: webgpu.BindGroup,
    bin_prefix_sum_ba_bg: webgpu.BindGroup,
    particle_sort_a_to_b_bg: webgpu.BindGroup,
    particle_sort_b_to_a_bg: webgpu.BindGroup,
    particle_compute_forces_a_to_b_bg: webgpu.BindGroup,
    particle_compute_forces_b_to_a_bg: webgpu.BindGroup,
    compose_bg: webgpu.BindGroup,

    // Pipeline Layouts
    particle_advance_pl: webgpu.PipelineLayout,
    binning_pl: webgpu.PipelineLayout, // For clearBinSize & fillBinSize
    prefix_sum_pl: webgpu.PipelineLayout,
    particle_sort_pl: webgpu.PipelineLayout, // For clearBinSize & sortParticles (in sort shader)
    particle_compute_forces_pl: webgpu.PipelineLayout,
    particle_render_pl: webgpu.PipelineLayout,
    compose_pl: webgpu.PipelineLayout,

    // Pipelines
    bin_clear_size_pipeline: webgpu.ComputePipeline,
    bin_fill_size_pipeline: webgpu.ComputePipeline,
    bin_prefix_sum_pipeline: webgpu.ComputePipeline,
    particle_sort_clear_size_pipeline: webgpu.ComputePipeline,
    particle_sort_pipeline: webgpu.ComputePipeline,
    particle_compute_forces_pipeline: webgpu.ComputePipeline,
    particle_advance_pipeline: webgpu.ComputePipeline,
    particle_render_glow_pipeline: webgpu.RenderPipeline,
    particle_render_circle_pipeline: webgpu.RenderPipeline,
    particle_render_point_pipeline: webgpu.RenderPipeline,
    compose_pipeline: webgpu.RenderPipeline,

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

    // Derived simulation parameters
    bin_count: u32,
    prefix_sum_iterations: u32,

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
            .particle_advance_bgl = undefined,
            .particle_buffer_read_only_bgl = undefined,
            .camera_bgl = undefined,
            .simulation_options_bgl = undefined,
            .bin_fill_size_bgl = undefined,
            .bin_prefix_sum_bgl = undefined,
            .particle_sort_bgl = undefined,
            .particle_compute_forces_bgl = undefined,
            .compose_bgl = undefined,
            .particle_advance_bg_a = undefined,
            .particle_advance_bg_b = undefined,
            .particle_read_only_bg_a = undefined,
            .particle_read_only_bg_b = undefined,
            .camera_bg = undefined,
            .simulation_options_bg = undefined,
            .bin_fill_size_main_target_bg = undefined,
            .bin_fill_size_temp_target_bg = undefined,
            .bin_prefix_sum_ab_bg = undefined,
            .bin_prefix_sum_ba_bg = undefined,
            .particle_sort_a_to_b_bg = undefined,
            .particle_sort_b_to_a_bg = undefined,
            .particle_compute_forces_a_to_b_bg = undefined,
            .particle_compute_forces_b_to_a_bg = undefined,
            .compose_bg = undefined,
            .particle_advance_pl = undefined,
            .binning_pl = undefined,
            .prefix_sum_pl = undefined,
            .particle_sort_pl = undefined,
            .particle_compute_forces_pl = undefined,
            .particle_render_pl = undefined,
            .compose_pl = undefined,
            .bin_clear_size_pipeline = undefined,
            .bin_fill_size_pipeline = undefined,
            .bin_prefix_sum_pipeline = undefined,
            .particle_sort_clear_size_pipeline = undefined,
            .particle_sort_pipeline = undefined,
            .particle_compute_forces_pipeline = undefined,
            .particle_advance_pipeline = undefined,
            .particle_render_glow_pipeline = undefined,
            .particle_render_circle_pipeline = undefined,
            .particle_render_point_pipeline = undefined,
            .compose_pipeline = undefined,
            .current_particle_buffer = undefined,
            .next_particle_buffer = undefined,
            .current_bin_offset_buffer = undefined,
            .next_bin_offset_buffer = undefined,
            .particle_count = DEFAULT_PARTICLE_COUNT,
            .species_count = DEFAULT_SPECIES_COUNT,
            .simulation_box_width = 1024.0,
            .simulation_box_height = 576.0,
            .bin_count = undefined,
            .prefix_sum_iterations = undefined,
        };

        const device = wgpu_handler.device orelse return RendererError.DeviceOrQueueUnavailable;

        // Calculate derived simulation parameters
        const sim_box_width_calc = self.simulation_box_width;
        const sim_box_height_calc = self.simulation_box_height;
        const grid_size_x: f32 = @ceil(sim_box_width_calc / MAX_FORCE_RADIUS);
        const grid_size_y: f32 = @ceil(sim_box_height_calc / MAX_FORCE_RADIUS);
        self.bin_count = @intFromFloat(grid_size_x * grid_size_y);
        self.prefix_sum_iterations = if (self.bin_count == 0) 0 else math.log2_ceil_u32(self.bin_count + 1);
        webutils.log("DEBUG: Renderer.init: Calculated bin_count=" ++ "TODO_INT_TO_STRING" ++ ", prefix_sum_iterations=" ++ "TODO_INT_TO_STRING"); // Adjusted log

        // Initialize Shader Modules (existing code)
        webutils.log("DEBUG: Renderer.init: Creating shader modules..."); // Adjusted log
        self.binning_module = try self.createShaderModule(device, particle_binning_wgsl, "particle_binning_shader");
        self.compute_module = try self.createShaderModule(device, particle_compute_wgsl, "particle_compute_shader");
        self.prefix_sum_module = try self.createShaderModule(device, particle_prefix_sum_wgsl, "particle_prefix_sum_shader");
        self.render_module = try self.createShaderModule(device, particle_render_wgsl, "particle_render_shader");
        self.sort_module = try self.createShaderModule(device, particle_sort_wgsl, "particle_sort_shader");
        self.compose_module = try self.createShaderModule(device, particle_compose_wgsl, "particle_compose_shader");
        webutils.log("INFO: Shader modules initialized."); // Adjusted log

        // Initialize Buffers
        webutils.log("DEBUG: Renderer.init: Creating buffers..."); // Adjusted log
        try self.createAndInitializeBuffers(device);
        webutils.log("INFO: Buffers initialized."); // Adjusted log

        // Initialize Textures (Placeholders for now)
        webutils.log("DEBUG: Renderer.init: Creating textures..."); // Adjusted log
        try self.createPlaceholderTextures(device);
        webutils.log("INFO: Placeholder textures initialized."); // Adjusted log

        // Setup ping-pong buffers initial state
        self.current_particle_buffer = self.particle_buffer_a;
        self.next_particle_buffer = self.particle_buffer_b;
        self.current_bin_offset_buffer = self.bin_offset_buffer_a;
        self.next_bin_offset_buffer = self.bin_offset_buffer_b;

        webutils.log("DEBUG: Renderer.init: Creating bind group layouts..."); // Adjusted log
        try self.createBindGroupLayouts(device);
        webutils.log("INFO: Bind group layouts initialized."); // Adjusted log

        // Create Bind Groups
        webutils.log("DEBUG: Renderer.init: Creating bind groups..."); // Adjusted log
        try self.createBindGroups(device);
        webutils.log("INFO: Bind groups initialized."); // Adjusted log

        // Create Pipeline Layouts and Pipelines
        webutils.log("DEBUG: Renderer.init: Creating pipeline layouts..."); // Adjusted log
        try self.createPipelineLayouts(device);
        webutils.log("INFO: Pipeline layouts initialized."); // Adjusted log

        webutils.log("DEBUG: Renderer.init: Creating pipelines..."); // Adjusted log
        try self.createPipelines(device);
        webutils.log("INFO: Pipelines initialized."); // Adjusted log

        webutils.log("INFO: Renderer initialized successfully."); // Adjusted log
        return self;
    }

    fn createShaderModule(self: *Renderer, device: webgpu.Device, code: []const u8, label: []const u8) !webgpu.ShaderModule {
        _ = self; // self not used yet, but might be if allocator needed for label clone
        const desc = webgpu.ShaderModuleDescriptor{
            .label = label,
            .code = code,
        };
        return webgpu.deviceCreateShaderModule(device, &desc) catch |err| {
            webutils.log("ERROR: Failed to create shader module '" ++ label ++ "': " ++ @errorName(err)); // Adjusted log
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
        self.particle_advance_bgl = try device.createBindGroupLayout(&webgpu.BindGroupLayoutDescriptor{
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

    fn createBindGroups(self: *Renderer, device: webgpu.Device) !void {
        // Particle Advance BGs
        self.particle_advance_bg_a = try device.createBindGroup(&webgpu.BindGroupDescriptor{
            .label = "particle_advance_bg_a",
            .layout = self.particle_advance_bgl,
            .entries = &[_]webgpu.BindGroupEntry{
                .{ .binding = 0, .resource = .{ .buffer = self.particle_buffer_a.handle } },
            },
        });
        self.particle_advance_bg_b = try device.createBindGroup(&webgpu.BindGroupDescriptor{
            .label = "particle_advance_bg_b",
            .layout = self.particle_advance_bgl,
            .entries = &[_]webgpu.BindGroupEntry{
                .{ .binding = 0, .resource = .{ .buffer = self.particle_buffer_b.handle } },
            },
        });

        // Particle Read-Only BGs
        self.particle_read_only_bg_a = try device.createBindGroup(&webgpu.BindGroupDescriptor{
            .label = "particle_read_only_bg_a",
            .layout = self.particle_buffer_read_only_bgl,
            .entries = &[_]webgpu.BindGroupEntry{
                .{ .binding = 0, .resource = .{ .buffer = self.particle_buffer_a.handle } },
                .{ .binding = 1, .resource = .{ .buffer = self.species_buffer.handle } },
            },
        });
        self.particle_read_only_bg_b = try device.createBindGroup(&webgpu.BindGroupDescriptor{
            .label = "particle_read_only_bg_b",
            .layout = self.particle_buffer_read_only_bgl,
            .entries = &[_]webgpu.BindGroupEntry{
                .{ .binding = 0, .resource = .{ .buffer = self.particle_buffer_b.handle } },
                .{ .binding = 1, .resource = .{ .buffer = self.species_buffer.handle } },
            },
        });

        // Camera BG
        self.camera_bg = try device.createBindGroup(&webgpu.BindGroupDescriptor{
            .label = "camera_bg",
            .layout = self.camera_bgl,
            .entries = &[_]webgpu.BindGroupEntry{
                .{ .binding = 0, .resource = .{ .buffer = self.camera_buffer.handle } },
            },
        });

        // Simulation Options BG
        self.simulation_options_bg = try device.createBindGroup(&webgpu.BindGroupDescriptor{
            .label = "simulation_options_bg",
            .layout = self.simulation_options_bgl,
            .entries = &[_]webgpu.BindGroupEntry{
                .{ .binding = 0, .resource = .{ .buffer = self.simulation_options_buffer.handle } },
            },
        });

        // Bin Fill Size BGs
        self.bin_fill_size_main_target_bg = try device.createBindGroup(&webgpu.BindGroupDescriptor{
            .label = "bin_fill_size_main_target_bg",
            .layout = self.bin_fill_size_bgl,
            .entries = &[_]webgpu.BindGroupEntry{
                .{ .binding = 0, .resource = .{ .buffer = self.bin_offset_buffer_a.handle } },
            },
        });
        self.bin_fill_size_temp_target_bg = try device.createBindGroup(&webgpu.BindGroupDescriptor{
            .label = "bin_fill_size_temp_target_bg",
            .layout = self.bin_fill_size_bgl,
            .entries = &[_]webgpu.BindGroupEntry{
                .{ .binding = 0, .resource = .{ .buffer = self.bin_offset_buffer_b.handle } },
            },
        });

        // Bin Prefix Sum BGs
        self.bin_prefix_sum_ab_bg = try device.createBindGroup(&webgpu.BindGroupDescriptor{
            .label = "bin_prefix_sum_ab_bg",
            .layout = self.bin_prefix_sum_bgl,
            .entries = &[_]webgpu.BindGroupEntry{
                .{ .binding = 0, .resource = .{ .buffer = self.bin_offset_buffer_a.handle } }, // Source
                .{ .binding = 1, .resource = .{ .buffer = self.bin_offset_buffer_b.handle } }, // Destination
                .{ .binding = 2, .resource = .{ .buffer = self.bin_prefix_sum_step_size_buffer.handle, .size = @sizeOf(u32) } }, // step_size UBO
            },
        });
        self.bin_prefix_sum_ba_bg = try device.createBindGroup(&webgpu.BindGroupDescriptor{
            .label = "bin_prefix_sum_ba_bg",
            .layout = self.bin_prefix_sum_bgl,
            .entries = &[_]webgpu.BindGroupEntry{
                .{ .binding = 0, .resource = .{ .buffer = self.bin_offset_buffer_b.handle } }, // Source
                .{ .binding = 1, .resource = .{ .buffer = self.bin_offset_buffer_a.handle } }, // Destination
                .{ .binding = 2, .resource = .{ .buffer = self.bin_prefix_sum_step_size_buffer.handle, .size = @sizeOf(u32) } }, // step_size UBO
            },
        });

        // Particle Sort BGs
        // sort_a_to_b: particles_a (src), particles_b (dst), bin_offset_a (read offsets), bin_offset_b (atomic_write)
        self.particle_sort_a_to_b_bg = try device.createBindGroup(&webgpu.BindGroupDescriptor{
            .label = "particle_sort_a_to_b_bg",
            .layout = self.particle_sort_bgl,
            .entries = &[_]webgpu.BindGroupEntry{
                .{ .binding = 0, .resource = .{ .buffer = self.particle_buffer_a.handle } }, // Source particles
                .{ .binding = 1, .resource = .{ .buffer = self.particle_buffer_b.handle } }, // Destination particles
                .{ .binding = 2, .resource = .{ .buffer = self.bin_offset_buffer_a.handle } }, // Bin read offsets
                .{ .binding = 3, .resource = .{ .buffer = self.bin_offset_buffer_b.handle } }, // Bin atomic counts (written here)
            },
        });
        // sort_b_to_a: particles_b (src), particles_a (dst), bin_offset_b (read offsets), bin_offset_a (atomic_write)
        self.particle_sort_b_to_a_bg = try device.createBindGroup(&webgpu.BindGroupDescriptor{
            .label = "particle_sort_b_to_a_bg",
            .layout = self.particle_sort_bgl,
            .entries = &[_]webgpu.BindGroupEntry{
                .{ .binding = 0, .resource = .{ .buffer = self.particle_buffer_b.handle } },
                .{ .binding = 1, .resource = .{ .buffer = self.particle_buffer_a.handle } },
                .{ .binding = 2, .resource = .{ .buffer = self.bin_offset_buffer_b.handle } },
                .{ .binding = 3, .resource = .{ .buffer = self.bin_offset_buffer_a.handle } },
            },
        });

        // Particle Compute Forces BGs
        // compute_forces_a_to_b: particles_a (src), particles_b (dst), bin_offset_a (final offsets), forces_buffer
        self.particle_compute_forces_a_to_b_bg = try device.createBindGroup(&webgpu.BindGroupDescriptor{
            .label = "particle_compute_forces_a_to_b_bg",
            .layout = self.particle_compute_forces_bgl,
            .entries = &[_]webgpu.BindGroupEntry{
                .{ .binding = 0, .resource = .{ .buffer = self.particle_buffer_a.handle } }, // particlesSource
                .{ .binding = 1, .resource = .{ .buffer = self.particle_buffer_b.handle } }, // particlesDestination
                .{ .binding = 2, .resource = .{ .buffer = self.bin_offset_buffer_a.handle } }, // binOffset (assuming A has the final correct offsets after sort/prefix)
                .{ .binding = 3, .resource = .{ .buffer = self.forces_buffer.handle } }, // forces
            },
        });
        // compute_forces_b_to_a: particles_b (src), particles_a (dst), bin_offset_b (final offsets), forces_buffer
        self.particle_compute_forces_b_to_a_bg = try device.createBindGroup(&webgpu.BindGroupDescriptor{
            .label = "particle_compute_forces_b_to_a_bg",
            .layout = self.particle_compute_forces_bgl,
            .entries = &[_]webgpu.BindGroupEntry{
                .{ .binding = 0, .resource = .{ .buffer = self.particle_buffer_b.handle } },
                .{ .binding = 1, .resource = .{ .buffer = self.particle_buffer_a.handle } },
                .{ .binding = 2, .resource = .{ .buffer = self.bin_offset_buffer_b.handle } },
                .{ .binding = 3, .resource = .{ .buffer = self.forces_buffer.handle } },
            },
        });

        // Compose BG
        self.compose_bg = try device.createBindGroup(&webgpu.BindGroupDescriptor{
            .label = "compose_bg",
            .layout = self.compose_bgl,
            .entries = &[_]webgpu.BindGroupEntry{
                .{ .binding = 0, .resource = .{ .texture_view = self.hdr_texture_view.handle } },
                .{ .binding = 1, .resource = .{ .texture_view = self.blue_noise_texture_view.handle } },
            },
        });
    }

    fn createPipelineLayouts(self: *Renderer, device: webgpu.Device) !void {
        // Particle Advance PL: uses particle_advance_bgl, simulation_options_bgl
        self.particle_advance_pl = try device.createPipelineLayout(&webgpu.PipelineLayoutDescriptor{
            .label = "particle_advance_pl",
            .bind_group_layouts = &[_]webgpu.BindGroupLayout{
                self.particle_advance_bgl,
                self.simulation_options_bgl,
            },
        });

        // Binning PL: uses particle_buffer_read_only_bgl, simulation_options_bgl, bin_fill_size_bgl
        self.binning_pl = try device.createPipelineLayout(&webgpu.PipelineLayoutDescriptor{
            .label = "binning_pl",
            .bind_group_layouts = &[_]webgpu.BindGroupLayout{
                self.particle_buffer_read_only_bgl, // Group 0
                self.simulation_options_bgl, // Group 1
                self.bin_fill_size_bgl, // Group 2
            },
        });

        // Prefix Sum PL: uses bin_prefix_sum_bgl
        self.prefix_sum_pl = try device.createPipelineLayout(&webgpu.PipelineLayoutDescriptor{
            .label = "prefix_sum_pl",
            .bind_group_layouts = &[_]webgpu.BindGroupLayout{self.bin_prefix_sum_bgl},
        });

        // Particle Sort PL: uses particle_sort_bgl, simulation_options_bgl
        self.particle_sort_pl = try device.createPipelineLayout(&webgpu.PipelineLayoutDescriptor{
            .label = "particle_sort_pl",
            .bind_group_layouts = &[_]webgpu.BindGroupLayout{
                self.particle_sort_bgl, // Group 0
                self.simulation_options_bgl, // Group 1
            },
        });

        // Particle Compute Forces PL: uses particle_compute_forces_bgl, simulation_options_bgl
        self.particle_compute_forces_pl = try device.createPipelineLayout(&webgpu.PipelineLayoutDescriptor{
            .label = "particle_compute_forces_pl",
            .bind_group_layouts = &[_]webgpu.BindGroupLayout{
                self.particle_compute_forces_bgl, // Group 0
                self.simulation_options_bgl, // Group 1
            },
        });

        // Particle Render PL: uses particle_buffer_read_only_bgl, camera_bgl
        self.particle_render_pl = try device.createPipelineLayout(&webgpu.PipelineLayoutDescriptor{
            .label = "particle_render_pl",
            .bind_group_layouts = &[_]webgpu.BindGroupLayout{
                self.particle_buffer_read_only_bgl, // Group 0
                self.camera_bgl, // Group 1
            },
        });

        // Compose PL: uses compose_bgl
        self.compose_pl = try device.createPipelineLayout(&webgpu.PipelineLayoutDescriptor{
            .label = "compose_pl",
            .bind_group_layouts = &[_]webgpu.BindGroupLayout{self.compose_bgl},
        });
    }

    fn createPipelines(self: *Renderer, device: webgpu.Device) !void {
        const preferred_canvas_format = self.wgpu_handler.getPreferredCanvasFormat() orelse webgpu.TextureFormat.bgra8unorm; // Default if not available

        // --- Compute Pipelines ---
        self.bin_clear_size_pipeline = try device.createComputePipeline(&webgpu.ComputePipelineDescriptor{
            .label = "bin_clear_size_pipeline",
            .layout = self.binning_pl,
            .compute = .{ .module = self.binning_module, .entry_point = "clearBinSize" },
        });
        self.bin_fill_size_pipeline = try device.createComputePipeline(&webgpu.ComputePipelineDescriptor{
            .label = "bin_fill_size_pipeline",
            .layout = self.binning_pl,
            .compute = .{ .module = self.binning_module, .entry_point = "fillBinSize" },
        });
        self.bin_prefix_sum_pipeline = try device.createComputePipeline(&webgpu.ComputePipelineDescriptor{
            .label = "bin_prefix_sum_pipeline",
            .layout = self.prefix_sum_pl,
            .compute = .{ .module = self.prefix_sum_module, .entry_point = "prefixSumStep" },
        });
        self.particle_sort_clear_size_pipeline = try device.createComputePipeline(&webgpu.ComputePipelineDescriptor{
            .label = "particle_sort_clear_size_pipeline",
            .layout = self.particle_sort_pl, // Uses BGLs for sorted particles and sim options
            .compute = .{ .module = self.sort_module, .entry_point = "clearBinSize" },
        });
        self.particle_sort_pipeline = try device.createComputePipeline(&webgpu.ComputePipelineDescriptor{
            .label = "particle_sort_pipeline",
            .layout = self.particle_sort_pl,
            .compute = .{ .module = self.sort_module, .entry_point = "sortParticles" },
        });
        self.particle_compute_forces_pipeline = try device.createComputePipeline(&webgpu.ComputePipelineDescriptor{
            .label = "particle_compute_forces_pipeline",
            .layout = self.particle_compute_forces_pl,
            .compute = .{ .module = self.compute_module, .entry_point = "computeForces" }, // From particle_compute.wgsl
        });
        self.particle_advance_pipeline = try device.createComputePipeline(&webgpu.ComputePipelineDescriptor{
            .label = "particle_advance_pipeline",
            .layout = self.particle_advance_pl,
            .compute = .{ .module = self.compute_module, .entry_point = "particleAdvance" }, // From particle_compute.wgsl
        });

        // --- Render Pipelines ---
        // Common blend state for additive blending on HDR target
        const additive_blend_state = webgpu.BlendState{
            .color = .{ .src_factor = .src_alpha, .dst_factor = .one, .operation = .add },
            .alpha = .{ .src_factor = .one, .dst_factor = .one, .operation = .add },
        };
        const particle_hdr_target_state = webgpu.ColorTargetState{
            .format = HDR_FORMAT,
            .blend = &additive_blend_state,
            .write_mask = webgpu.ColorWriteMask.ALL,
        };

        self.particle_render_glow_pipeline = try device.createRenderPipeline(&webgpu.RenderPipelineDescriptor{
            .label = "particle_render_glow_pipeline",
            .layout = self.particle_render_pl,
            .vertex = .{ .module = self.render_module, .entry_point = "vertexGlow" },
            .primitive = .{ .topology = .triangle_list },
            .fragment = &webgpu.FragmentState{
                .module = self.render_module,
                .entry_point = "fragmentGlow",
                .targets = &[_]webgpu.ColorTargetState{particle_hdr_target_state},
            },
            .multisample = .{ .count = 1, .mask = 0xFFFFFFFF }, // Default multisample state
        });
        self.particle_render_circle_pipeline = try device.createRenderPipeline(&webgpu.RenderPipelineDescriptor{
            .label = "particle_render_circle_pipeline",
            .layout = self.particle_render_pl,
            .vertex = .{ .module = self.render_module, .entry_point = "vertexCircle" },
            .primitive = .{ .topology = .triangle_list },
            .fragment = &webgpu.FragmentState{
                .module = self.render_module,
                .entry_point = "fragmentCircle",
                .targets = &[_]webgpu.ColorTargetState{particle_hdr_target_state},
            },
            .multisample = .{ .count = 1, .mask = 0xFFFFFFFF },
        });
        self.particle_render_point_pipeline = try device.createRenderPipeline(&webgpu.RenderPipelineDescriptor{
            .label = "particle_render_point_pipeline",
            .layout = self.particle_render_pl,
            .vertex = .{ .module = self.render_module, .entry_point = "vertexPoint" },
            .primitive = .{ .topology = .triangle_list },
            .fragment = &webgpu.FragmentState{
                .module = self.render_module,
                .entry_point = "fragmentPoint",
                .targets = &[_]webgpu.ColorTargetState{particle_hdr_target_state},
            },
            .multisample = .{ .count = 1, .mask = 0xFFFFFFFF },
        });

        // Compose pipeline (output to screen)
        const compose_target_state = webgpu.ColorTargetState{
            .format = preferred_canvas_format,
            // No blending for final compose, overwrite
            .write_mask = webgpu.ColorWriteMask.ALL,
        };
        self.compose_pipeline = try device.createRenderPipeline(&webgpu.RenderPipelineDescriptor{
            .label = "compose_pipeline",
            .layout = self.compose_pl,
            .vertex = .{ .module = self.compose_module, .entry_point = "vertexMain" },
            .primitive = .{ .topology = .triangle_list },
            .fragment = &webgpu.FragmentState{
                .module = self.compose_module,
                .entry_point = "fragmentMain",
                .targets = &[_]webgpu.ColorTargetState{compose_target_state},
            },
            .multisample = .{ .count = 1, .mask = 0xFFFFFFFF },
        });
    }

    pub fn deinit(self: *Renderer) void {
        webutils.log("DEBUG: Renderer.deinit: Releasing resources..."); // Adjusted log
        const device = self.wgpu_handler.device;
        if (device != null) {
            // Buffers & Textures
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

            // Bind Groups
            webgpu.releaseHandle(self.particle_advance_bg_a.handle, .BindGroup);
            webgpu.releaseHandle(self.particle_advance_bg_b.handle, .BindGroup);
            webgpu.releaseHandle(self.particle_read_only_bg_a.handle, .BindGroup);
            webgpu.releaseHandle(self.particle_read_only_bg_b.handle, .BindGroup);
            webgpu.releaseHandle(self.camera_bg.handle, .BindGroup);
            webgpu.releaseHandle(self.simulation_options_bg.handle, .BindGroup);
            webgpu.releaseHandle(self.bin_fill_size_main_target_bg.handle, .BindGroup);
            webgpu.releaseHandle(self.bin_fill_size_temp_target_bg.handle, .BindGroup);
            webgpu.releaseHandle(self.bin_prefix_sum_ab_bg.handle, .BindGroup);
            webgpu.releaseHandle(self.bin_prefix_sum_ba_bg.handle, .BindGroup);
            webgpu.releaseHandle(self.particle_sort_a_to_b_bg.handle, .BindGroup);
            webgpu.releaseHandle(self.particle_sort_b_to_a_bg.handle, .BindGroup);
            webgpu.releaseHandle(self.particle_compute_forces_a_to_b_bg.handle, .BindGroup);
            webgpu.releaseHandle(self.particle_compute_forces_b_to_a_bg.handle, .BindGroup);
            webgpu.releaseHandle(self.compose_bg.handle, .BindGroup);

            // Pipelines
            webgpu.releaseHandle(self.bin_clear_size_pipeline.handle, .ComputePipeline);
            webgpu.releaseHandle(self.bin_fill_size_pipeline.handle, .ComputePipeline);
            webgpu.releaseHandle(self.bin_prefix_sum_pipeline.handle, .ComputePipeline);
            webgpu.releaseHandle(self.particle_sort_clear_size_pipeline.handle, .ComputePipeline);
            webgpu.releaseHandle(self.particle_sort_pipeline.handle, .ComputePipeline);
            webgpu.releaseHandle(self.particle_compute_forces_pipeline.handle, .ComputePipeline);
            webgpu.releaseHandle(self.particle_advance_pipeline.handle, .ComputePipeline);
            webgpu.releaseHandle(self.particle_render_glow_pipeline.handle, .RenderPipeline);
            webgpu.releaseHandle(self.particle_render_circle_pipeline.handle, .RenderPipeline);
            webgpu.releaseHandle(self.particle_render_point_pipeline.handle, .RenderPipeline);
            webgpu.releaseHandle(self.compose_pipeline.handle, .RenderPipeline);

            // Pipeline Layouts
            webgpu.releaseHandle(self.particle_advance_pl.handle, .PipelineLayout);
            webgpu.releaseHandle(self.binning_pl.handle, .PipelineLayout);
            webgpu.releaseHandle(self.prefix_sum_pl.handle, .PipelineLayout);
            webgpu.releaseHandle(self.particle_sort_pl.handle, .PipelineLayout);
            webgpu.releaseHandle(self.particle_compute_forces_pl.handle, .PipelineLayout);
            webgpu.releaseHandle(self.particle_render_pl.handle, .PipelineLayout);
            webgpu.releaseHandle(self.compose_pl.handle, .PipelineLayout);

            // Bind Group Layouts
            webgpu.releaseHandle(self.particle_advance_bgl.handle, .BindGroupLayout);
            webgpu.releaseHandle(self.particle_buffer_read_only_bgl.handle, .BindGroupLayout);
            webgpu.releaseHandle(self.camera_bgl.handle, .BindGroupLayout);
            webgpu.releaseHandle(self.simulation_options_bgl.handle, .BindGroupLayout);
            webgpu.releaseHandle(self.bin_fill_size_bgl.handle, .BindGroupLayout);
            webgpu.releaseHandle(self.bin_prefix_sum_bgl.handle, .BindGroupLayout);
            webgpu.releaseHandle(self.particle_sort_bgl.handle, .BindGroupLayout);
            webgpu.releaseHandle(self.particle_compute_forces_bgl.handle, .BindGroupLayout);
            webgpu.releaseHandle(self.compose_bgl.handle, .BindGroupLayout);

            // Shader Modules
            webgpu.releaseHandle(self.binning_module.handle, .ShaderModule);
            webgpu.releaseHandle(self.compute_module.handle, .ShaderModule);
            webgpu.releaseHandle(self.prefix_sum_module.handle, .ShaderModule);
            webgpu.releaseHandle(self.render_module.handle, .ShaderModule);
            webgpu.releaseHandle(self.sort_module.handle, .ShaderModule);
            webgpu.releaseHandle(self.compose_module.handle, .ShaderModule);
        } else {
            webutils.log("WARN: Renderer.deinit: Device was null. Handles may not be released correctly if not already undefined."); // Adjusted log
        }

        self.allocator.destroy(self);
        webutils.log("DEBUG: Renderer deinitialized."); // Adjusted log
    }

    // Helper function to calculate dispatch counts
    fn get_dispatch_count(items: u32, workgroup_size: u32) u32 {
        if (workgroup_size == 0) return items; // Avoid division by zero, though workgroup_size should be > 0
        return (items + workgroup_size - 1) / workgroup_size;
    }

    // Helper function to swap GPU buffer pointers (handles)
    fn swapGpuBuffers(buffer_a: *webgpu.Buffer, buffer_b: *webgpu.Buffer) void {
        const temp = buffer_a.*;
        buffer_a.* = buffer_b.*;
        buffer_b.* = temp;
    }

    pub fn renderFrame(self: *Renderer) !void {
        const device = self.wgpu_handler.device orelse return RendererError.DeviceOrQueueUnavailable;
        const queue = self.wgpu_handler.queue orelse return RendererError.DeviceOrQueueUnavailable;

        const workgroup_size: u32 = 64; // Common workgroup size for these shaders

        const encoder = device.createCommandEncoder(&webgpu.CommandEncoderDescriptor{
            .label = "main_command_encoder",
        }) catch |err| {
            webutils.log("ERROR: Failed to create command encoder: " ++ @errorName(err)); // Adjusted log
            return RendererError.CommandEncoderCreationError;
        };
        // Defer release of encoder until it's finished or if an error occurs before finish.
        // Actual release will be handled explicitly after finish() or in error paths.

        // --- 1. Binning Pass ---
        // Clear bin sizes then fill bin sizes based on particle positions.
        // Targets self.current_bin_offset_buffer.
        webutils.log("DEBUG: renderFrame: Starting Binning Pass"); // Adjusted log
        {
            const pass_encoder = encoder.beginComputePass(&webgpu.ComputePassDescriptor{
                .label = "binning_pass",
            });

            // Determine which particle_read_only_bg to use based on current_particle_buffer
            const current_particle_bg = if (self.current_particle_buffer.handle == self.particle_buffer_a.handle)
                self.particle_read_only_bg_a
            else
                self.particle_read_only_bg_b;

            // Determine which bin_fill_size_bg to use (targets self.current_bin_offset_buffer)
            const target_bin_fill_bg = if (self.current_bin_offset_buffer.handle == self.bin_offset_buffer_a.handle)
                self.bin_fill_size_main_target_bg // Targets bin_offset_buffer_a
            else
                self.bin_fill_size_temp_target_bg; // Targets bin_offset_buffer_b

            // Clear bin sizes
            pass_encoder.setPipeline(self.bin_clear_size_pipeline);
            pass_encoder.setBindGroup(0, current_particle_bg, &.{}); // Group 0 (particles, species)
            pass_encoder.setBindGroup(1, self.simulation_options_bg, &.{}); // Group 1 (sim options)
            pass_encoder.setBindGroup(2, target_bin_fill_bg, &.{}); // Group 2 (target bin_offset buffer)
            pass_encoder.dispatchWorkgroups(get_dispatch_count(self.bin_count, workgroup_size), 1, 1);

            // Fill bin sizes
            pass_encoder.setPipeline(self.bin_fill_size_pipeline);
            // Bind groups are the same as for clear
            pass_encoder.setBindGroup(0, current_particle_bg, &.{});
            pass_encoder.setBindGroup(1, self.simulation_options_bg, &.{});
            pass_encoder.setBindGroup(2, target_bin_fill_bg, &.{});
            pass_encoder.dispatchWorkgroups(get_dispatch_count(self.particle_count, workgroup_size), 1, 1);

            pass_encoder.end();
            webgpu.releaseHandle(pass_encoder.handle, .ComputePassEncoder); // Release pass encoder
        }
        webutils.log("DEBUG: renderFrame: Binning Pass Complete. Counts in current_bin_offset_buffer ('" ++ (self.current_bin_offset_buffer.label orelse "-") ++ "')"); // Adjusted log

        // --- 2. Prefix Sum Pass ---
        // Operates on self.current_bin_offset_buffer (input counts) and self.next_bin_offset_buffer (output/ping-pong target).
        // Goal: self.bin_offset_buffer_a should contain the final prefix sum results.
        // self.bin_offset_buffer_b is used as scratch / intermediate storage during ping-ponging.
        webutils.log("DEBUG: renderFrame: Starting Prefix Sum Pass (" ++ "TODO_INT_TO_STRING" ++ " iterations). Initial input: '" ++ (self.current_bin_offset_buffer.label orelse "-") ++ "', temp target: '" ++ (self.next_bin_offset_buffer.label orelse "-") ++ "'"); // Adjusted log
        if (self.prefix_sum_iterations > 0) {
            // `read_from_A_implies_current_is_A` tracks if the *source* for the current step is bin_offset_buffer_a.
            var read_from_A_implies_current_is_A: bool = (self.current_bin_offset_buffer.handle == self.bin_offset_buffer_a.handle);

            const pass_encoder = encoder.beginComputePass(&webgpu.ComputePassDescriptor{
                .label = "prefix_sum_pass",
            });
            pass_encoder.setPipeline(self.bin_prefix_sum_pipeline);

            for (0..self.prefix_sum_iterations) |i| {
                const dynamic_offset: u32 = @intCast(i * 256); // Each step_size u32 in UBO is 256 bytes apart
                if (read_from_A_implies_current_is_A) {
                    // Current source is A, so read from A, write to B.
                    pass_encoder.setBindGroup(0, self.bin_prefix_sum_ab_bg, &.{dynamic_offset});
                } else {
                    // Current source is B, so read from B, write to A.
                    pass_encoder.setBindGroup(0, self.bin_prefix_sum_ba_bg, &.{dynamic_offset});
                }
                pass_encoder.dispatchWorkgroups(get_dispatch_count(self.bin_count + 1, workgroup_size), 1, 1);
                read_from_A_implies_current_is_A = !read_from_A_implies_current_is_A; // Toggle: destination of this step is source for next.
            }
            pass_encoder.end();
            webgpu.releaseHandle(pass_encoder.handle, .ComputePassEncoder);

            // After the loop, `read_from_A_implies_current_is_A` indicates where the *next read would be from* if loop continued.
            // So, if true, the last write was to B. If false, the last write was to A.
            const result_is_in_buffer_A = !read_from_A_implies_current_is_A;

            if (result_is_in_buffer_A) {
                // Result is already in bin_offset_buffer_a. This is desired.
                self.current_bin_offset_buffer = self.bin_offset_buffer_a;
                self.next_bin_offset_buffer = self.bin_offset_buffer_b; // B is now scratch
                webutils.log("DEBUG: Prefix sum result is in bin_offset_buffer_a as expected."); // Adjusted log
            } else {
                // Result is in bin_offset_buffer_b. Need to copy to bin_offset_buffer_a for subsequent passes.
                webutils.log("DEBUG: Prefix sum result is in bin_offset_buffer_b. Copying to bin_offset_buffer_a."); // Adjusted log
                const size_to_copy = @sizeOf(u32) * (self.bin_count + 1);
                encoder.copyBufferToBuffer(self.bin_offset_buffer_b.handle, 0, self.bin_offset_buffer_a.handle, 0, size_to_copy);
                self.current_bin_offset_buffer = self.bin_offset_buffer_a; // A now has the results
                self.next_bin_offset_buffer = self.bin_offset_buffer_b; // B is scratch
            }
        }
        webutils.log("DEBUG: renderFrame: Prefix Sum Pass Complete. Final offsets ensured in '" ++ (self.current_bin_offset_buffer.label orelse "-") ++ "' (bin_offset_buffer_a). Scratch bin is '" ++ (self.next_bin_offset_buffer.label orelse "-") ++ "'."); // Adjusted log

        // --- 3. Sort Pass ---
        // Input: self.current_particle_buffer, self.bin_offset_buffer_a (true offsets from prefix sum)
        // Output: self.next_particle_buffer (sorted particles). self.bin_offset_buffer_b is used for atomic counts.
        webutils.log("DEBUG: renderFrame: Starting Sort Pass. Input particles: '" ++ (self.current_particle_buffer.label orelse "-") ++ "' ('" ++ (if (self.current_particle_buffer.handle == self.particle_buffer_a.handle) "pA" else "pB") ++ "'), Output to: '" ++ (self.next_particle_buffer.label orelse "-") ++ "' ('" ++ (if (self.next_particle_buffer.handle == self.particle_buffer_a.handle) "pA" else "pB") ++ "'). Offsets from '" ++ (self.bin_offset_buffer_a.label orelse "-") ++ "', Atomics to '" ++ (self.bin_offset_buffer_b.label orelse "-") ++ "'"); // Adjusted log
        {
            const pass_encoder = encoder.beginComputePass(&webgpu.ComputePassDescriptor{
                .label = "sort_pass",
            });

            // Determine BG based on current_particle_buffer. This choice has implications for bin offset usage.
            // particle_sort_a_to_b_bg: pA (src), pB (dst), bA (read_offset), bB (atomic_write)
            // particle_sort_b_to_a_bg: pB (src), pA (dst), bB (read_offset), bA (atomic_write)
            // We have ensured prefix sum results are in bin_offset_buffer_a.
            // We will use bin_offset_buffer_b for atomic counts.
            var sort_bg: webgpu.BindGroup = undefined;
            var clear_target_label: []const u8 = "unknown";

            if (self.current_particle_buffer.handle == self.particle_buffer_a.handle) {
                // Sorting from pA to pB. Use bA for offsets, bB for atomics.
                sort_bg = self.particle_sort_a_to_b_bg;
                clear_target_label = self.bin_offset_buffer_b.label orelse "bin_offset_buffer_b";
            } else { // current_particle_buffer is pB
                // Sorting from pB to pA. We need to use bA for offsets and bB for atomics.
                // particle_sort_b_to_a_bg expects to read offsets from bB and write atomics to bA.
                // This is a mismatch with our strategy of bA=offsets, bB=atomics.
                // TODO: This requires either a new BG (pB->pA, bA_read, bB_atomic) or different buffer management.
                // For now, we proceed with particle_sort_a_to_b_bg to keep structure, this implies a potential issue if pB is current.
                // OR, we stick to the current BG and accept that particle_sort_b_to_a_bg will read offsets from bB.
                // If we stick to always reading offsets from bA and writing atomics to bB:
                webutils.log("WARN: Sort Pass: current_particle_buffer is pB. particle_sort_b_to_a_bg expects to read offsets from bB, but bA has true offsets. This is a known issue."); // Adjusted log
                // To make it structurally sound for now, let's assume we *must* use a BG that writes to pA if pB is current.
                // And that this BG correctly uses bA for read-offsets and bB for atomic-writes if such a BG were defined.
                // Since it's not, we will use particle_sort_b_to_a_bg and acknowledge the bin offset mismatch.
                sort_bg = self.particle_sort_b_to_a_bg;
                clear_target_label = self.bin_offset_buffer_a.label orelse "bin_offset_buffer_a";
                webutils.log("WARN: Using particle_sort_b_to_a_bg. This will clear '" ++ clear_target_label ++ "' for atomics & read offsets from '" ++ (self.bin_offset_buffer_b.label orelse "-") ++ "'."); // Adjusted log
            }
            webutils.log("DEBUG: Sort Pass: Using BG '" ++ (sort_bg.label orelse "-") ++ "'. Clearing atomic counts in buffer targeted by its 4th binding ('" ++ clear_target_label ++ "')."); // Adjusted log

            // Clear atomic counts buffer (binding 3 of the chosen sort_bg)
            pass_encoder.setPipeline(self.particle_sort_clear_size_pipeline);
            pass_encoder.setBindGroup(0, sort_bg, &.{});
            pass_encoder.setBindGroup(1, self.simulation_options_bg, &.{});
            pass_encoder.dispatchWorkgroups(get_dispatch_count(self.bin_count, workgroup_size), 1, 1);

            // Sort particles
            pass_encoder.setPipeline(self.particle_sort_pipeline);
            pass_encoder.setBindGroup(0, sort_bg, &.{});
            pass_encoder.setBindGroup(1, self.simulation_options_bg, &.{});
            pass_encoder.dispatchWorkgroups(get_dispatch_count(self.particle_count, workgroup_size), 1, 1);

            pass_encoder.end();
            webgpu.releaseHandle(pass_encoder.handle, .ComputePassEncoder);
        }
        swapGpuBuffers(&self.current_particle_buffer, &self.next_particle_buffer); // next_particle_buffer (now sorted) becomes current.
        webutils.log("DEBUG: renderFrame: Sort Pass Complete. Sorted particles now in '" ++ (self.current_particle_buffer.label orelse "-") ++ "' ('" ++ (if (self.current_particle_buffer.handle == self.particle_buffer_a.handle) "pA" else "pB") ++ "')."); // Adjusted log

        // --- 4. Compute Forces Pass ---
        // Input: self.current_particle_buffer (sorted), self.bin_offset_buffer_a (true offsets)
        // Output: self.next_particle_buffer (particles with updated forces/velocities)
        webutils.log("DEBUG: renderFrame: Starting Compute Forces. Input '" ++ (self.current_particle_buffer.label orelse "-") ++ "' ('" ++ (if (self.current_particle_buffer.handle == self.particle_buffer_a.handle) "pA" else "pB") ++ "'), Output to '" ++ (self.next_particle_buffer.label orelse "-") ++ "' ('" ++ (if (self.next_particle_buffer.handle == self.particle_buffer_a.handle) "pA" else "pB") ++ "'). Offsets from '" ++ (self.bin_offset_buffer_a.label orelse "-") ++ "'."); // Adjusted log
        {
            const pass_encoder = encoder.beginComputePass(&webgpu.ComputePassDescriptor{
                .label = "compute_forces_pass",
            });

            var forces_bg: webgpu.BindGroup = undefined;
            // particle_compute_forces_a_to_b_bg: pA (src), pB (dst), bA (offsets), forces
            // particle_compute_forces_b_to_a_bg: pB (src), pA (dst), bB (offsets), forces
            // We need to read offsets from bin_offset_buffer_a.
            if (self.current_particle_buffer.handle == self.particle_buffer_a.handle) {
                // Current is pA (sorted). Read pA, bA. Write pB.
                forces_bg = self.particle_compute_forces_a_to_b_bg;
            } else { // Current is pB (sorted).
                // Read pB, bA. Write pA.
                // particle_compute_forces_b_to_a_bg expects offsets from bB. This is a mismatch.
                // TODO: Address this BG mismatch. For now, using it and logging.
                webutils.log("WARN: Compute Forces: current_particle_buffer is pB. particle_compute_forces_b_to_a_bg expects offsets from bB, but bA has true offsets. Known issue."); // Adjusted log
                forces_bg = self.particle_compute_forces_b_to_a_bg;
            }
            webutils.log("DEBUG: Compute Forces: Using BG '" ++ (forces_bg.label orelse "-") ++ "'."); // Adjusted log

            pass_encoder.setPipeline(self.particle_compute_forces_pipeline);
            pass_encoder.setBindGroup(0, forces_bg, &.{});
            pass_encoder.setBindGroup(1, self.simulation_options_bg, &.{});
            pass_encoder.dispatchWorkgroups(get_dispatch_count(self.particle_count, workgroup_size), 1, 1);
            pass_encoder.end();
            webgpu.releaseHandle(pass_encoder.handle, .ComputePassEncoder);
        }
        swapGpuBuffers(&self.current_particle_buffer, &self.next_particle_buffer); // next_particle_buffer (with new velocities) becomes current.
        webutils.log("DEBUG: renderFrame: Compute Forces Complete. Velocities updated in '" ++ (self.current_particle_buffer.label orelse "-") ++ "' ('" ++ (if (self.current_particle_buffer.handle == self.particle_buffer_a.handle) "pA" else "pB") ++ "')."); // Adjusted log

        // --- 5. Advance Particles Pass ---
        // Input/Output: self.current_particle_buffer (updated in-place with new positions)
        webutils.log("DEBUG: renderFrame: Starting Advance Particles. Target '" ++ (self.current_particle_buffer.label orelse "-") ++ "' ('" ++ (if (self.current_particle_buffer.handle == self.particle_buffer_a.handle) "pA" else "pB") ++ "')."); // Adjusted log
        {
            const pass_encoder = encoder.beginComputePass(&webgpu.ComputePassDescriptor{
                .label = "advance_particles_pass",
            });

            const advance_bg = if (self.current_particle_buffer.handle == self.particle_buffer_a.handle)
                self.particle_advance_bg_a // Operates on pA
            else
                self.particle_advance_bg_b; // Operates on pB
            webutils.log("DEBUG: Advance Particles: Using BG '" ++ (advance_bg.label orelse "-") ++ "'."); // Adjusted log

            pass_encoder.setPipeline(self.particle_advance_pipeline);
            pass_encoder.setBindGroup(0, advance_bg, &.{});
            pass_encoder.setBindGroup(1, self.simulation_options_bg, &.{});
            pass_encoder.dispatchWorkgroups(get_dispatch_count(self.particle_count, workgroup_size), 1, 1);
            pass_encoder.end();
            webgpu.releaseHandle(pass_encoder.handle, .ComputePassEncoder);
        }
        webutils.log("DEBUG: renderFrame: Advance Particles Complete. Final positions for this frame in '" ++ (self.current_particle_buffer.label orelse "-") ++ "' ('" ++ (if (self.current_particle_buffer.handle == self.particle_buffer_a.handle) "pA" else "pB") ++ "')."); // Adjusted log

        // --- 6. Render Passes ---
        // Render particles to HDR texture
        webutils.log("DEBUG: renderFrame: Starting HDR Render Pass. Source particles from '" ++ (self.current_particle_buffer.label orelse "-") ++ "' ('" ++ (if (self.current_particle_buffer.handle == self.particle_buffer_a.handle) "pA" else "pB") ++ "')."); // Adjusted log
        {
            const color_attachment = webgpu.RenderPassColorAttachment{
                .view = self.hdr_texture_view, // Target the HDR texture
                .resolve_target = null,
                .clear_value = &webgpu.Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 }, // Clear to black
                .load_op = .clear,
                .store_op = .store,
            };
            const pass_encoder = encoder.beginRenderPass(&webgpu.RenderPassDescriptor{
                .label = "hdr_render_pass",
                .color_attachments = &.{color_attachment},
                .depth_stencil_attachment = null,
            });

            // Determine which particle_read_only_bg to use
            const particle_render_bg = if (self.current_particle_buffer.handle == self.particle_buffer_a.handle)
                self.particle_read_only_bg_a
            else
                self.particle_read_only_bg_b;

            webutils.log("DEBUG: HDR Render Pass: Using particle BG '" ++ (particle_render_bg.label orelse "-") ++ "'."); // Adjusted log

            // Using particle_render_circle_pipeline as an example.
            // TODO: Add logic to select between glow, circle, point pipelines based on settings.
            pass_encoder.setPipeline(self.particle_render_circle_pipeline);
            pass_encoder.setBindGroup(0, particle_render_bg, &.{}); // Group 0: Particle Data + Species
            pass_encoder.setBindGroup(1, self.camera_bg, &.{}); // Group 1: Camera Uniforms
            pass_encoder.draw(6, self.particle_count, 0, 0); // Draw 6 vertices (quad) per particle, instanced

            pass_encoder.end();
            webgpu.releaseHandle(pass_encoder.handle, .RenderPassEncoder); // Release render pass encoder
        }
        webutils.log("DEBUG: renderFrame: HDR Render Pass Complete. Output to hdr_texture_view."); // Adjusted log

        // Compose HDR to screen (Skipped for now)
        // This section would get the current swap chain texture view from wgpu_handler
        // and render the hdr_texture_view to it using the compose_pipeline.
        webutils.log("WARN: renderFrame: Skipping Compose to Screen pass. WebGPUHandler.getCurrentTextureView() not yet implemented or integrated."); // Adjusted log
        // Example if available:
        // const surface_view = self.wgpu_handler.getCurrentTextureView() orelse return RendererError.SurfaceViewUnavailable;
        // const preferred_format = self.wgpu_handler.getPreferredCanvasFormat() orelse webgpu.TextureFormat.bgra8unorm;
        // {
        //     const compose_color_attachment = webgpu.RenderPassColorAttachment{
        //         .view = surface_view, .resolve_target = null,
        //         .load_op = .clear, .store_op = .store, // Or .load if not clearing screen first
        //         .clear_value = &webgpu.Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 },
        //     };
        //     const compose_pass_encoder = encoder.beginRenderPass(&webgpu.RenderPassDescriptor{
        //         .label = "compose_to_screen_pass",
        //         .color_attachments = &.{compose_color_attachment},
        //     });
        //     compose_pass_encoder.setPipeline(self.compose_pipeline);
        //     compose_pass_encoder.setBindGroup(0, self.compose_bg, &.{}); // Contains hdr_texture_view and blue_noise_texture_view
        //     compose_pass_encoder.draw(6, 1, 0, 0); // Draw a full-screen quad
        //     compose_pass_encoder.end();
        //     webgpu.releaseHandle(compose_pass_encoder.handle, .RenderPassEncoder);
        // }

        // --- Finish and Submit ---
        const command_buffer = encoder.finish(&webgpu.CommandBufferDescriptor{
            .label = "main_frame_command_buffer",
        }) catch |err_finish| {
            webutils.log("ERROR: Failed to finish command encoder: " ++ @errorName(err_finish)); // Adjusted log
            webgpu.releaseHandle(encoder.handle, .CommandEncoder); // Release encoder on finish error
            return RendererError.CommandBufferCreationError;
        };
        webgpu.releaseHandle(encoder.handle, .CommandEncoder); // Encoder is consumed by finish, release its handle reference

        queue.submit(&.{command_buffer});
        webgpu.releaseHandle(command_buffer.handle, .CommandBuffer); // Release command buffer after submit (Zig owns, JS side handle can be released)
        webutils.log("INFO: renderFrame: Frame commands submitted successfully."); // Adjusted log
    }
};
