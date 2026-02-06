const std = @import("std");
const ffi = @import("zig-wasm-ffi");
const webgpu = ffi.webgpu;
const particle = @import("particle.zig");
const system = @import("system.zig");
const shaders = @import("shaders.zig");
const physics = @import("physics.zig");
const spatial = @import("spatial.zig");
const input_handler = @import("input_handler.zig");

pub const Simulation = struct {
    particle_count: u32,
    species_count: u32,
    sim_width: f32,
    sim_height: f32,

    particle_buffer: webgpu.Buffer,
    species_buffer: webgpu.Buffer,
    force_buffer: webgpu.Buffer,
    options_buffer: webgpu.Buffer,
    camera_buffer: webgpu.Buffer,

    hdr_texture: webgpu.Texture,
    hdr_texture_view: webgpu.TextureView,
    blue_noise_texture_view: ?webgpu.TextureViewHandle = null,
    canvas_width: u32,
    canvas_height: u32,

    glow_shader: webgpu.ShaderModule,
    circle_shader: webgpu.ShaderModule,
    point_shader: webgpu.ShaderModule,
    particle_bind_group_layout: webgpu.BindGroupLayout,
    camera_bind_group_layout: webgpu.BindGroupLayout,
    particle_bind_group: webgpu.BindGroup,
    camera_bind_group: webgpu.BindGroup,
    glow_pipeline: webgpu.RenderPipeline,
    circle_pipeline: webgpu.RenderPipeline,
    point_pipeline: webgpu.RenderPipeline,

    compose_shader: webgpu.ShaderModule,
    compose_pipeline: webgpu.RenderPipeline,
    compose_bind_group_layout: webgpu.BindGroupLayout,
    compose_bind_group: webgpu.BindGroup,

    render_shader: webgpu.ShaderModule,
    render_pipeline: webgpu.RenderPipeline,

    physics_pipeline: physics.Physics,
    spatial_pipeline: spatial.SpatialPipeline,
    use_spatial_optimization: bool,
    max_force_radius: f32,

    init_shader: webgpu.ShaderModule,
    init_pipeline: webgpu.ComputePipeline,
    init_seed_buffer: webgpu.Buffer,
    init_bind_group_particles: webgpu.BindGroup,
    init_bind_group_options: webgpu.BindGroup,
    init_bind_group_seed: webgpu.BindGroup,

    rng: system.Rng,
    options: particle.SimulationOptions,
    camera: particle.CameraParams,
    symmetric_forces: bool,
    friction_coefficient: f32,

    pub fn init(
        particle_count: u32,
        species_count: u32,
        sim_width: f32,
        sim_height: f32,
        seed: u32,
        symmetric_forces: bool,
        friction_coefficient: f32,
    ) !Simulation {
        var sim = Simulation{
            .particle_count = particle_count,
            .species_count = species_count,
            .sim_width = sim_width,
            .sim_height = sim_height,
            .rng = system.Rng.init(seed),
            .options = particle.SimulationOptions.init(sim_width, sim_height, species_count),
            .camera = particle.CameraParams.initForSimulation(1024.0, 768.0, sim_width, sim_height),
            .symmetric_forces = symmetric_forces,
            .friction_coefficient = friction_coefficient,
            .particle_buffer = undefined,
            .species_buffer = undefined,
            .force_buffer = undefined,
            .options_buffer = undefined,
            .camera_buffer = undefined,
            .hdr_texture = undefined,
            .hdr_texture_view = undefined,
            .canvas_width = 1024,
            .canvas_height = 768,
            .glow_shader = undefined,
            .circle_shader = undefined,
            .point_shader = undefined,
            .particle_bind_group_layout = undefined,
            .camera_bind_group_layout = undefined,
            .particle_bind_group = undefined,
            .camera_bind_group = undefined,
            .glow_pipeline = .{ .handle = webgpu.RenderPipelineHandle.invalid() },
            .circle_pipeline = .{ .handle = webgpu.RenderPipelineHandle.invalid() },
            .point_pipeline = .{ .handle = webgpu.RenderPipelineHandle.invalid() },
            .compose_shader = undefined,
            .compose_pipeline = .{ .handle = webgpu.RenderPipelineHandle.invalid() },
            .compose_bind_group_layout = undefined,
            .compose_bind_group = undefined,
            .render_shader = undefined,
            .render_pipeline = .{ .handle = webgpu.RenderPipelineHandle.invalid() },
            .physics_pipeline = undefined,
            .spatial_pipeline = undefined,
            .use_spatial_optimization = true,
            .max_force_radius = 80.0,
            .init_shader = undefined,
            .init_pipeline = undefined,
            .init_seed_buffer = undefined,
            .init_bind_group_particles = undefined,
            .init_bind_group_options = undefined,
            .init_bind_group_seed = undefined,
        };

        sim.particle_buffer = webgpu.createStorageBuffer(@sizeOf(particle.Particle) * particle_count);
        sim.species_buffer = webgpu.createStorageBuffer(@sizeOf(particle.Species) * species_count);
        sim.force_buffer = webgpu.createStorageBuffer(@sizeOf(particle.Force) * species_count * species_count);
        sim.options_buffer = webgpu.createUniformBuffer(@sizeOf(particle.SimulationOptions));
        sim.camera_buffer = webgpu.createUniformBuffer(@sizeOf(particle.CameraParams));
        sim.init_seed_buffer = webgpu.createUniformBuffer(4);

        sim.options.bin_size = sim.max_force_radius;

        try sim.setupInitPipeline();
        try sim.generateSystem();
        try sim.setupRenderPipeline();

        sim.physics_pipeline = try physics.Physics.init(sim.particle_buffer, sim.options_buffer);
        sim.spatial_pipeline = try spatial.SpatialPipeline.init(
            sim.particle_buffer,
            particle_count,
            sim.species_buffer,
            sim.force_buffer,
            sim.options_buffer,
            sim_width,
            sim_height,
            sim.max_force_radius,
        );

        return sim;
    }

    pub fn generateSystem(self: *Simulation) !void {
        const MAX_SPECIES = 16;
        const actual_species_count = @min(self.species_count, MAX_SPECIES);

        var species: [MAX_SPECIES]particle.Species = undefined;
        var forces: [MAX_SPECIES * MAX_SPECIES]particle.Force = undefined;

        log("Generating particles (GPU)...");

        self.options_buffer.writeTyped(particle.SimulationOptions, 0, &[_]particle.SimulationOptions{self.options});

        const seed = @as(u32, @intFromFloat(self.rng.next() * 4294967296.0));
        self.init_seed_buffer.writeTyped(u32, 0, &[_]u32{seed});

        const encoder = webgpu.CommandEncoder.create();
        const pass = encoder.beginComputePass();
        pass.setPipeline(self.init_pipeline);
        pass.setBindGroup(0, self.init_bind_group_particles);
        pass.setBindGroup(1, self.init_bind_group_options);
        pass.setBindGroup(2, self.init_bind_group_seed);
        const workgroup_count = (self.particle_count + 63) / 64;
        pass.dispatch(workgroup_count, 1, 1);
        pass.end();
        const cmd_buffer = encoder.finish();
        cmd_buffer.submit();

        log("Generating species colors...");
        system.generateSpeciesColors(species[0..actual_species_count], &self.rng);

        log("Generating force matrix...");
        const force_count = @as(usize, actual_species_count) * @as(usize, actual_species_count);
        system.generateForceMatrix(forces[0..force_count], actual_species_count, &self.rng, self.symmetric_forces);

        log("Uploading species/forces to GPU...");
        self.species_buffer.writeTyped(particle.Species, 0, species[0..actual_species_count]);
        self.force_buffer.writeTyped(particle.Force, 0, forces[0..force_count]);
        self.camera_buffer.writeTyped(particle.CameraParams, 0, &[_]particle.CameraParams{self.camera});

        log("Particle system generated");
        logInt("  Particles:", self.particle_count);
        logInt("  Species:", actual_species_count);
    }

    fn setupInitPipeline(self: *Simulation) !void {
        log("Setting up Init pipeline...");

        self.init_shader = webgpu.ShaderModule.create(shaders.particle_init);
        if (!self.init_shader.isValid()) {
            log("ERROR: Failed to create init shader");
            return error.ShaderCreationFailed;
        }

        const entries_0 = [_]webgpu.BindGroupLayoutEntry{
            webgpu.BindGroupLayoutEntry.initBuffer(0, webgpu.ShaderStage.COMPUTE, .storage),
        };
        const layout_0 = webgpu.BindGroupLayout.create(&entries_0);

        const entries_1 = [_]webgpu.BindGroupLayoutEntry{
            webgpu.BindGroupLayoutEntry.initBuffer(0, webgpu.ShaderStage.COMPUTE, .uniform),
        };
        const layout_1 = webgpu.BindGroupLayout.create(&entries_1);

        const entries_2 = [_]webgpu.BindGroupLayoutEntry{
            webgpu.BindGroupLayoutEntry.initBuffer(0, webgpu.ShaderStage.COMPUTE, .uniform),
        };
        const layout_2 = webgpu.BindGroupLayout.create(&entries_2);

        const layouts = [_]webgpu.BindGroupLayout{ layout_0, layout_1, layout_2 };
        const pipeline_layout = webgpu.PipelineLayout.create(&layouts);

        self.init_pipeline = webgpu.ComputePipeline.create(pipeline_layout, self.init_shader, "initParticles");

        const bg_entries_0 = [_]webgpu.BindGroupEntry{
            webgpu.BindGroupEntry.initBufferFull(0, self.particle_buffer.handle, self.particle_buffer.size),
        };
        self.init_bind_group_particles = webgpu.BindGroup.create(layout_0, &bg_entries_0);

        const bg_entries_1 = [_]webgpu.BindGroupEntry{
            webgpu.BindGroupEntry.initBufferFull(0, self.options_buffer.handle, self.options_buffer.size),
        };
        self.init_bind_group_options = webgpu.BindGroup.create(layout_1, &bg_entries_1);

        const bg_entries_2 = [_]webgpu.BindGroupEntry{
            webgpu.BindGroupEntry.initBufferFull(0, self.init_seed_buffer.handle, self.init_seed_buffer.size),
        };
        self.init_bind_group_seed = webgpu.BindGroup.create(layout_2, &bg_entries_2);

        log("Init pipeline created");
    }

    fn setupRenderPipeline(self: *Simulation) !void {
        log("Setting up HDR render pipeline...");

        self.hdr_texture = webgpu.createHDRTexture(self.canvas_width, self.canvas_height);
        if (!self.hdr_texture.isValid()) {
            log("ERROR: Failed to create HDR texture");
            return error.TextureCreationFailed;
        }
        self.hdr_texture_view = self.hdr_texture.createView();
        if (!self.hdr_texture_view.isValid()) {
            log("ERROR: Failed to create HDR texture view");
            return error.TextureViewCreationFailed;
        }
        log("HDR texture created");

        self.glow_shader = webgpu.ShaderModule.create(shaders.particle_render_glow);
        if (!self.glow_shader.isValid()) return error.ShaderCreationFailed;

        self.circle_shader = webgpu.ShaderModule.create(shaders.particle_render_circle);
        if (!self.circle_shader.isValid()) return error.ShaderCreationFailed;

        self.point_shader = webgpu.ShaderModule.create(shaders.particle_render_point_hdr);
        if (!self.point_shader.isValid()) return error.ShaderCreationFailed;

        log("HDR shaders created");

        self.render_shader = webgpu.ShaderModule.create(shaders.particle_render_point);

        const particle_layout_entries = [_]webgpu.BindGroupLayoutEntry{
            webgpu.BindGroupLayoutEntry.initBuffer(0, webgpu.ShaderStage.VERTEX, .read_only_storage),
            webgpu.BindGroupLayoutEntry.initBuffer(1, webgpu.ShaderStage.VERTEX, .read_only_storage),
        };
        self.particle_bind_group_layout = webgpu.BindGroupLayout.create(&particle_layout_entries);

        const camera_layout_entries = [_]webgpu.BindGroupLayoutEntry{
            webgpu.BindGroupLayoutEntry.initBuffer(0, webgpu.ShaderStage.VERTEX | webgpu.ShaderStage.FRAGMENT, .uniform),
        };
        self.camera_bind_group_layout = webgpu.BindGroupLayout.create(&camera_layout_entries);

        const particle_bind_entries = [_]webgpu.BindGroupEntry{
            webgpu.BindGroupEntry.initBufferFull(0, self.particle_buffer.handle, self.particle_buffer.size),
            webgpu.BindGroupEntry.initBufferFull(1, self.species_buffer.handle, self.species_buffer.size),
        };
        self.particle_bind_group = webgpu.BindGroup.create(self.particle_bind_group_layout, &particle_bind_entries);

        const camera_bind_entries = [_]webgpu.BindGroupEntry{
            webgpu.BindGroupEntry.initBufferFull(0, self.camera_buffer.handle, self.camera_buffer.size),
        };
        self.camera_bind_group = webgpu.BindGroup.create(self.camera_bind_group_layout, &camera_bind_entries);

        const layouts = [_]webgpu.BindGroupLayout{ self.particle_bind_group_layout, self.camera_bind_group_layout };
        const pipeline_layout = webgpu.PipelineLayout.create(&layouts);

        log("Creating HDR render pipelines...");

        self.glow_pipeline = webgpu.RenderPipeline.createHDR(pipeline_layout, self.glow_shader, "vertexGlow", "fragmentGlow", .rgba16float, true);
        if (!self.glow_pipeline.isValid()) return error.PipelineCreationFailed;

        self.circle_pipeline = webgpu.RenderPipeline.createHDR(pipeline_layout, self.circle_shader, "vertexCircle", "fragmentCircle", .rgba16float, true);
        if (!self.circle_pipeline.isValid()) return error.PipelineCreationFailed;

        self.point_pipeline = webgpu.RenderPipeline.createHDR(pipeline_layout, self.point_shader, "vertexPoint", "fragmentPoint", .rgba16float, true);
        if (!self.point_pipeline.isValid()) return error.PipelineCreationFailed;

        log("HDR pipelines created (glow, circle, point)");

        log("Creating compose pipeline...");

        self.compose_shader = webgpu.ShaderModule.create(shaders.compose_shader);
        if (!self.compose_shader.isValid()) return error.ShaderCreationFailed;

        const compose_layout_entries = [_]webgpu.BindGroupLayoutEntry{
            webgpu.BindGroupLayoutEntry.initTexture(0, webgpu.ShaderStage.FRAGMENT),
            webgpu.BindGroupLayoutEntry.initTexture(1, webgpu.ShaderStage.FRAGMENT),
        };
        self.compose_bind_group_layout = webgpu.BindGroupLayout.create(&compose_layout_entries);

        const compose_bind_entries = [_]webgpu.BindGroupEntry{
            webgpu.BindGroupEntry.initTextureView(0, self.hdr_texture_view.handle),
            webgpu.BindGroupEntry.initTextureView(1, self.hdr_texture_view.handle),
        };
        self.compose_bind_group = webgpu.BindGroup.create(self.compose_bind_group_layout, &compose_bind_entries);

        const compose_layout_array = [_]webgpu.BindGroupLayout{self.compose_bind_group_layout};
        const compose_pipeline_layout = webgpu.PipelineLayout.create(&compose_layout_array);

        self.compose_pipeline = webgpu.RenderPipeline.create(compose_pipeline_layout, self.compose_shader, "vertexMain", "fragmentMain");
        if (!self.compose_pipeline.isValid()) return error.PipelineCreationFailed;

        log("Compose pipeline created");

        self.render_pipeline = webgpu.RenderPipeline.create(pipeline_layout, self.render_shader, "vertex_main", "fragment_main");

        log("HDR render pipeline setup complete");
    }

    var camera_update_count: u32 = 0;

    pub fn handleInput(self: *Simulation, input: *const input_handler.InputState, _: f32) void {
        self.friction_coefficient = input.friction;
        self.options.dt = input.time_step;
        self.options.looping_borders = if (input.looping_borders) 1.0 else 0.0;
        self.options.central_force = input.central_force;

        if (input.pan_x != 0 or input.pan_y != 0) {
            const pan_speed = 1.0 / self.camera.pixels_per_unit;
            self.camera.center_x -= input.pan_x * pan_speed;
            self.camera.center_y += input.pan_y * pan_speed;
            self.camera_buffer.writeTyped(particle.CameraParams, 0, &[_]particle.CameraParams{self.camera});
        }

        if (input.zoom_delta != 0) {
            const zoom_speed = 0.001;
            const zoom_factor = 1.0 + input.zoom_delta * zoom_speed;

            const mouse_x_ndc = (input.mouse_x / @as(f32, @floatFromInt(self.canvas_width))) * 2.0 - 1.0;
            const mouse_y_ndc = 1.0 - (input.mouse_y / @as(f32, @floatFromInt(self.canvas_height))) * 2.0;

            const mouse_world_x = self.camera.center_x + mouse_x_ndc * self.camera.extent_x;
            const mouse_world_y = self.camera.center_y + mouse_y_ndc * self.camera.extent_y;

            self.camera.extent_x *= zoom_factor;
            self.camera.extent_y *= zoom_factor;

            self.camera.center_x = mouse_world_x - mouse_x_ndc * self.camera.extent_x;
            self.camera.center_y = mouse_world_y - mouse_y_ndc * self.camera.extent_y;
            self.camera.pixels_per_unit = @as(f32, @floatFromInt(self.canvas_width)) / (2.0 * self.camera.extent_x);

            self.camera_buffer.writeTyped(particle.CameraParams, 0, &[_]particle.CameraParams{self.camera});
        }

        if (input.mouse_down or input.mouse_right_down) {
            const canvas_width_f: f32 = @as(f32, @floatFromInt(self.canvas_width));
            const canvas_height_f: f32 = @as(f32, @floatFromInt(self.canvas_height));

            const mouse_x_ndc = if (canvas_width_f > 0) (input.mouse_x / canvas_width_f) * 2.0 - 1.0 else 0.0;
            const mouse_y_ndc = if (canvas_height_f > 0) 1.0 - (input.mouse_y / canvas_height_f) * 2.0 else 0.0;

            self.options.action_x = self.camera.center_x + mouse_x_ndc * self.camera.extent_x;
            self.options.action_y = self.camera.center_y + mouse_y_ndc * self.camera.extent_y;

            const drag_x_ndc = if (canvas_width_f > 0) (input.mouse_dx * 2.0) / canvas_width_f else 0.0;
            const drag_y_ndc = if (canvas_height_f > 0) (-input.mouse_dy * 2.0) / canvas_height_f else 0.0;

            self.options.action_vx = self.camera.extent_x * drag_x_ndc;
            self.options.action_vy = self.camera.extent_y * drag_y_ndc;

            self.options.action_radius = self.camera.extent_x / 16.0;
            self.options.action_force = if (input.mouse_down) 20.0 else -20.0;
        } else {
            self.options.action_force = 0.0;
            self.options.action_vx = 0.0;
            self.options.action_vy = 0.0;
            self.options.action_radius = 0.0;
        }
    }

    pub fn updateCamera(self: *Simulation, canvas_width: f32, canvas_height: f32) void {
        const new_width = @as(u32, @intFromFloat(canvas_width));
        const new_height = @as(u32, @intFromFloat(canvas_height));

        if (new_width != self.canvas_width or new_height != self.canvas_height) {
            self.canvas_width = new_width;
            self.canvas_height = new_height;

            self.hdr_texture.destroy();
            self.hdr_texture = webgpu.createHDRTexture(new_width, new_height);
            self.hdr_texture_view = self.hdr_texture.createView();

            const blue_noise_view = if (self.blue_noise_texture_view) |bn| bn else self.hdr_texture_view.handle;
            const compose_bind_entries = [_]webgpu.BindGroupEntry{
                webgpu.BindGroupEntry.initTextureView(0, self.hdr_texture_view.handle),
                webgpu.BindGroupEntry.initTextureView(1, blue_noise_view),
            };
            self.compose_bind_group = webgpu.BindGroup.create(self.compose_bind_group_layout, &compose_bind_entries);

            log("HDR texture recreated for new canvas size");
        }

        self.camera = particle.CameraParams.initForSimulation(canvas_width, canvas_height, self.sim_width, self.sim_height);
        self.camera_buffer.writeTyped(particle.CameraParams, 0, &[_]particle.CameraParams{self.camera});

        camera_update_count += 1;
        if (camera_update_count <= 2) {
            log("=== Camera Updated ===");
            logInt("  Canvas width:", new_width);
            logInt("  Canvas height:", new_height);
        }
    }

    var frame_count: u32 = 0;

    pub fn update(self: *Simulation, dt: f32) void {
        const clamped_dt = @min(dt, 0.025);
        self.options.dt = clamped_dt;
        const coeff = self.friction_coefficient;
        const friction_factor = if (coeff <= 0.0) 1.0 else std.math.exp(-clamped_dt * coeff);
        self.options.friction = friction_factor;
        self.options_buffer.writeTyped(particle.SimulationOptions, 0, &[_]particle.SimulationOptions{self.options});

        if (self.use_spatial_optimization) {
            const encoder = self.spatial_pipeline.computeForces(
                self.particle_count,
                self.particle_buffer,
                self.spatial_pipeline.particle_temp_buffer,
            );

            const advance_pass = encoder.beginComputePass();
            advance_pass.setPipeline(self.physics_pipeline.advance_pipeline);
            advance_pass.setBindGroup(0, self.physics_pipeline.particle_group);
            advance_pass.setBindGroup(1, self.physics_pipeline.options_group);
            const workgroup_count = (self.particle_count + 63) / 64;
            advance_pass.dispatch(workgroup_count, 1, 1);
            advance_pass.end();

            const cmd_buffer = encoder.finish();
            cmd_buffer.submit();
        } else {
            self.physics_pipeline.update(self.particle_count);
        }

        frame_count += 1;
        if (frame_count % 60 == 0) {
            log("Simulation running (60 frames)");
        }
    }

    var render_frame_count: u32 = 0;

    pub fn render(self: *Simulation) void {
        if (!self.glow_pipeline.isValid() or !self.circle_pipeline.isValid() or !self.point_pipeline.isValid()) {
            log("ERROR: HDR pipelines not initialized");
            return;
        }

        render_frame_count += 1;
        if (render_frame_count == 1) {
            log("=== First Render Frame ===");
            logInt("  Particle count:", self.particle_count);
        }

        const vertex_count = self.particle_count * 6;

        const hdr_pass = webgpu.beginRenderPassHDR(
            self.hdr_texture_view.handle,
            webgpu.ClearColor.init(0.001, 0.001, 0.001, 0.0),
        );

        hdr_pass.setBindGroup(0, self.particle_bind_group);
        hdr_pass.setBindGroup(1, self.camera_bind_group);

        hdr_pass.setPipeline(self.glow_pipeline);
        hdr_pass.draw(vertex_count, 1, 0, 0);

        if (self.camera.pixels_per_unit < 1.0) {
            hdr_pass.setPipeline(self.point_pipeline);
        } else {
            hdr_pass.setPipeline(self.circle_pipeline);
        }
        hdr_pass.draw(vertex_count, 1, 0, 0);

        hdr_pass.end();

        const compose_pass = webgpu.beginRenderPassForParticles(
            webgpu.ClearColor.init(0.1, 0.0, 0.1, 1.0),
        );

        if (self.compose_pipeline.isValid()) {
            compose_pass.setPipeline(self.compose_pipeline);
            compose_pass.setBindGroup(0, self.compose_bind_group);
            compose_pass.draw(3, 1, 0, 0);
        }

        compose_pass.end();

        webgpu.present();
    }

    pub fn setBlueNoiseTexture(self: *Simulation, view_handle: u32) void {
        self.blue_noise_texture_view = webgpu.TextureViewHandle{ .id = view_handle };
        const compose_bind_entries = [_]webgpu.BindGroupEntry{
            webgpu.BindGroupEntry.initTextureView(0, self.hdr_texture_view.handle),
            webgpu.BindGroupEntry.initTextureView(1, self.blue_noise_texture_view.?),
        };
        self.compose_bind_group = webgpu.BindGroup.create(self.compose_bind_group_layout, &compose_bind_entries);
        log("Blue noise texture set and bind group updated");
    }

    pub fn deinit(self: *Simulation) void {
        self.particle_buffer.destroy();
        self.species_buffer.destroy();
        self.force_buffer.destroy();
        self.options_buffer.destroy();
        self.camera_buffer.destroy();
        self.init_seed_buffer.destroy();
        self.spatial_pipeline.deinit();
    }
};

fn log(comptime msg: []const u8) void {
    js_console_log(msg.ptr, msg.len);
}

fn logInt(comptime prefix: []const u8, value: u32) void {
    var buf: [64]u8 = undefined;
    const str = std.fmt.bufPrint(&buf, "{s} {d}", .{ prefix, value }) catch "Error formatting";
    js_console_log(str.ptr, str.len);
}

extern fn js_console_log(ptr: [*]const u8, len: usize) void;
