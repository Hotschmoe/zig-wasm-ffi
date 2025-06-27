const std = @import("std");
const webgpu = @import("zig-wasm-ffi").webgpu;
const webinput = @import("zig-wasm-ffi").webinput;
const webutils = @import("zig-wasm-ffi").webutils;
const webgpu_handler = @import("webgpu_engine/webgpu_handler.zig");
const input_handler = @import("input_handler.zig");

// Simple particle data - just position and color
const Particle = extern struct {
    x: f32,
    y: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

// Simple renderer that just draws particles as points
var simple_renderer: ?SimpleRenderer = null;
var allocator: std.mem.Allocator = undefined;

// Global static clear color to avoid pointer out-of-scope issues
const static_clear_color = webgpu.Color{ .r = 0.1, .g = 0.1, .b = 0.2, .a = 1.0 };

const SimpleRenderer = struct {
    device: webgpu.Device,
    queue: webgpu.Queue,

    // Buffers
    particle_buffer: webgpu.Buffer,
    camera_buffer: webgpu.Buffer,

    // Bind groups and layouts
    camera_bind_group_layout: webgpu.BindGroupLayout,
    camera_bind_group: webgpu.BindGroup,

    // Pipelines
    render_pipeline: webgpu.RenderPipeline,

    // Particles data
    particles: []Particle,
    frame_count: u32,

    const particle_count = 1000;

    pub fn init(device: webgpu.Device, queue: webgpu.Queue, surface_format: webgpu.TextureFormat) !SimpleRenderer {
        webutils.log("SimpleRenderer.init() called");

        var self = SimpleRenderer{
            .device = device,
            .queue = queue,
            .particle_buffer = undefined,
            .camera_buffer = undefined,
            .camera_bind_group_layout = undefined,
            .camera_bind_group = undefined,
            .render_pipeline = undefined,
            .particles = undefined,
            .frame_count = 0,
        };

        webutils.log("Allocating particles...");
        // Initialize particles
        self.particles = try allocator.alloc(Particle, particle_count);

        webutils.log("Setting up initial particle data...");
        // Create particles in a nice pattern
        for (self.particles, 0..) |*particle, i| {
            const fi = @as(f32, @floatFromInt(i));
            const angle = fi * 0.1;
            const radius = 0.3 + 0.2 * @sin(fi * 0.05);

            particle.x = radius * @cos(angle);
            particle.y = radius * @sin(angle);
            particle.r = 0.5 + 0.5 * @sin(fi * 0.02);
            particle.g = 0.5 + 0.5 * @cos(fi * 0.03);
            particle.b = 0.5 + 0.5 * @sin(fi * 0.04);
            particle.a = 1.0;
        }

        webutils.log("Creating buffers...");
        // Create buffers
        try self.createBuffers();

        webutils.log("Creating bind group layouts...");
        // Create bind group layouts
        try self.createBindGroupLayouts();

        webutils.log("Creating bind groups...");
        // Create bind groups
        try self.createBindGroups();

        webutils.log("Creating render pipeline...");
        // Create pipeline
        try self.createRenderPipeline(surface_format);

        webutils.log("SimpleRenderer.init() completed successfully");
        return self;
    }

    fn createBuffers(self: *SimpleRenderer) !void {
        // Particle buffer
        self.particle_buffer = try webgpu.deviceCreateBuffer(self.device, &webgpu.BufferDescriptor{
            .label = "particle_buffer",
            .size = @sizeOf(Particle) * particle_count,
            .usage = webgpu.GPUBufferUsage.VERTEX | webgpu.GPUBufferUsage.COPY_DST,
            .mappedAtCreation = false,
        });

        // Camera buffer (just a simple projection matrix)
        self.camera_buffer = try webgpu.deviceCreateBuffer(self.device, &webgpu.BufferDescriptor{
            .label = "camera_buffer",
            .size = 16 * @sizeOf(f32), // 4x4 matrix
            .usage = webgpu.GPUBufferUsage.UNIFORM | webgpu.GPUBufferUsage.COPY_DST,
            .mappedAtCreation = false,
        });

        // Write initial data
        webgpu.queueWriteBuffer(self.queue, self.particle_buffer, 0, @sizeOf(Particle) * particle_count, @ptrCast(self.particles.ptr));

        // Simple identity matrix for camera
        const identity = [_]f32{
            1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            0.0, 0.0, 0.0, 1.0,
        };
        webgpu.queueWriteBuffer(self.queue, self.camera_buffer, 0, @sizeOf(@TypeOf(identity)), @ptrCast(&identity));
    }

    fn createBindGroupLayouts(self: *SimpleRenderer) !void {
        // Simple layouts that should work with the current FFI
        const camera_entries = [_]webgpu.BindGroupLayoutEntry{
            webgpu.BindGroupLayoutEntry.newBuffer(0, webgpu.ShaderStage.VERTEX, .{
                .type = .uniform,
                .has_dynamic_offset = false,
                .min_binding_size = 0,
            }),
        };

        self.camera_bind_group_layout = try webgpu.deviceCreateBindGroupLayout(self.device, &webgpu.BindGroupLayoutDescriptor{
            .label = "camera_bgl",
            .entries = &camera_entries,
            .entries_len = camera_entries.len,
        });
    }

    fn createBindGroups(self: *SimpleRenderer) !void {
        self.camera_bind_group = try webgpu.deviceCreateBindGroup(self.device, &webgpu.BindGroupDescriptor{
            .label = "camera_bg",
            .layout = self.camera_bind_group_layout,
            .entries = &[_]webgpu.BindGroupEntry{
                .{
                    .binding = 0,
                    .resource = .{ .buffer = .{
                        .buffer = self.camera_buffer,
                        .offset = 0,
                        .size = webgpu.WHOLE_SIZE,
                    } },
                },
            },
            .entries_len = 1,
        });
    }

    fn createRenderPipeline(self: *SimpleRenderer, surface_format: webgpu.TextureFormat) !void {
        const vertex_shader_source =
            \\struct VertexInput {
            \\    @location(0) position: vec2<f32>,
            \\    @location(1) color: vec4<f32>,
            \\}
            \\
            \\struct VertexOutput {
            \\    @builtin(position) clip_position: vec4<f32>,
            \\    @location(0) color: vec4<f32>,
            \\}
            \\
            \\@group(0) @binding(0) var<uniform> transform: mat4x4<f32>;
            \\
            \\@vertex
            \\fn vs_main(vertex: VertexInput) -> VertexOutput {
            \\    var out: VertexOutput;
            \\    out.clip_position = transform * vec4<f32>(vertex.position, 0.0, 1.0);
            \\    out.color = vertex.color;
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
            \\    return in.color;
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
            .bind_group_layouts = &[_]webgpu.BindGroupLayout{self.camera_bind_group_layout},
            .bind_group_layouts_len = 1,
        });

        const vertex_attributes = [_]webgpu.VertexAttribute{
            .{ .offset = 0, .shader_location = 0, .format = .float32x2 }, // position
            .{ .offset = 8, .shader_location = 1, .format = .float32x4 }, // color
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

    pub fn render(self: *SimpleRenderer, surface_view: webgpu.TextureView) !void {
        // Update particles (simple animation)
        for (self.particles, 0..) |*particle, i| {
            const fi = @as(f32, @floatFromInt(i));
            // Simple frame-based animation instead of time-based
            self.frame_count += 1;
            const time = @as(f32, @floatFromInt(self.frame_count)) * 0.01;
            const angle = fi * 0.1 + time * 0.5;
            const radius = 0.3 + 0.2 * @sin(fi * 0.05 + time);

            particle.x = radius * @cos(angle);
            particle.y = radius * @sin(angle);
        }

        // Update particle buffer
        webgpu.queueWriteBuffer(self.queue, self.particle_buffer, 0, @sizeOf(Particle) * particle_count, @ptrCast(self.particles.ptr));

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
        webgpu.renderPassEncoderSetBindGroup(render_pass, 0, self.camera_bind_group, null);
        webgpu.renderPassEncoderSetVertexBuffer(render_pass, 0, self.particle_buffer, 0, webgpu.WHOLE_SIZE);
        webgpu.renderPassEncoderDraw(render_pass, particle_count, 1, 0, 0);

        webgpu.renderPassEncoderEnd(render_pass);

        const command_buffer = try webgpu.commandEncoderFinish(command_encoder, &webgpu.CommandBufferDescriptor{
            .label = "render_commands",
        });

        webgpu.queueSubmit(self.queue, &[_]webgpu.CommandBuffer{command_buffer});
    }

    pub fn deinit(self: *SimpleRenderer) void {
        if (self.particles.len > 0) {
            allocator.free(self.particles);
        }
    }
};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

export fn _start() void {
    allocator = gpa.allocator();
    webutils.log("Starting simple particle demo...");

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

    if (simple_renderer == null) {
        webutils.log("Attempting to initialize renderer...");
        const device = webgpu_handler.g_wgpu_handler_instance.device;
        const queue = webgpu_handler.g_wgpu_handler_instance.queue;

        webutils.log("Checking device and queue handles...");
        if (device == 0 or queue == 0) {
            webutils.log("Device or queue not available");
            return;
        }
        webutils.log("Device and queue handles are valid, proceeding...");

        // Get surface format
        const surface_format = webgpu_handler.g_wgpu_handler_instance.getPreferredCanvasFormat() orelse .bgra8unorm;
        webutils.log("Got surface format, initializing renderer...");

        simple_renderer = SimpleRenderer.init(device, queue, surface_format) catch |err| {
            webutils.log("Failed to initialize renderer: ");
            webutils.log(@errorName(err));
            return;
        };

        webutils.log("Simple renderer initialized successfully!");
        return;
    }

    // Add debug for render calls
    webutils.log("Renderer exists, attempting to render frame...");

    // Get surface view and render
    const surface_view = webgpu.getCurrentTextureView() catch |err| {
        webutils.log("Failed to get surface view: ");
        webutils.log(@errorName(err));
        return;
    };

    webutils.log("Got surface view, calling render...");
    simple_renderer.?.render(surface_view) catch |err| {
        webutils.log("Render error: ");
        webutils.log(@errorName(err));
    };
    webutils.log("Render call completed.");
}

export fn shutdown() void {
    webutils.log("Wasm shutdown requested.");

    if (simple_renderer) |*r| {
        webutils.log("Deinitializing Renderer...");
        r.deinit();
        simple_renderer = null;
        webutils.log("Renderer deinitialized.");
    }

    webgpu_handler.deinitGlobalHandler();
}
