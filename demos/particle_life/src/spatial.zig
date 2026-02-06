const std = @import("std");
const ffi = @import("zig-wasm-ffi");
const webgpu = ffi.webgpu;
const particle = @import("particle.zig");
const shaders = @import("shaders.zig");

pub fn calculateGridSize(sim_width: f32, sim_height: f32, bin_size: f32) struct { grid_x: u32, grid_y: u32, bin_count: u32 } {
    const grid_x = @as(u32, @intFromFloat(@ceil(sim_width / bin_size)));
    const grid_y = @as(u32, @intFromFloat(@ceil(sim_height / bin_size)));
    return .{ .grid_x = grid_x, .grid_y = grid_y, .bin_count = grid_x * grid_y };
}

pub fn calculatePrefixSumIterations(bin_count: u32) u32 {
    const log2_bins = std.math.log2_int_ceil(u32, bin_count);
    return ((log2_bins + 1) / 2) * 2;
}

pub const SpatialPipeline = struct {
    binning_shader: webgpu.ShaderModule,
    prefix_sum_shader: webgpu.ShaderModule,
    sort_shader: webgpu.ShaderModule,
    forces_shader: webgpu.ShaderModule,

    bin_clear_pipeline: webgpu.ComputePipeline,
    bin_fill_pipeline: webgpu.ComputePipeline,
    prefix_sum_pipeline: webgpu.ComputePipeline,
    sort_clear_pipeline: webgpu.ComputePipeline,
    sort_pipeline: webgpu.ComputePipeline,
    forces_pipeline: webgpu.ComputePipeline,

    particle_readonly_layout: webgpu.BindGroupLayout,
    options_layout: webgpu.BindGroupLayout,
    bin_size_layout: webgpu.BindGroupLayout,
    prefix_sum_layout: webgpu.BindGroupLayout,
    sort_layout: webgpu.BindGroupLayout,
    forces_layout: webgpu.BindGroupLayout,

    particle_readonly_group: webgpu.BindGroup,
    options_group: webgpu.BindGroup,
    bin_size_group: webgpu.BindGroup,
    prefix_sum_group_0: webgpu.BindGroup,
    prefix_sum_group_1: webgpu.BindGroup,
    sort_group: webgpu.BindGroup,
    forces_group: webgpu.BindGroup,

    particle_temp_buffer: webgpu.Buffer,
    bin_offset_buffer: webgpu.Buffer,
    bin_offset_temp_buffer: webgpu.Buffer,
    prefix_sum_step_buffer: webgpu.Buffer,

    bin_count: u32,
    prefix_sum_iterations: u32,

    pub fn init(
        particle_buffer: webgpu.Buffer,
        particle_count: u32,
        species_buffer: webgpu.Buffer,
        force_buffer: webgpu.Buffer,
        options_buffer: webgpu.Buffer,
        sim_width: f32,
        sim_height: f32,
        max_force_radius: f32,
    ) !SpatialPipeline {
        _ = particle_count;
        log("Setting up spatial optimization pipeline...");

        const grid = calculateGridSize(sim_width, sim_height, max_force_radius);
        const bin_count = grid.bin_count;
        const prefix_sum_iterations = calculatePrefixSumIterations(bin_count);

        logInt("  Grid size:", grid.grid_x);
        logInt("  Bin count:", bin_count);
        logInt("  Prefix sum iterations:", prefix_sum_iterations);

        const particle_temp_buffer = webgpu.createStorageBuffer(particle_buffer.size);
        const bin_offset_buffer = webgpu.createStorageBuffer((bin_count + 1) * 4);
        const bin_offset_temp_buffer = webgpu.createStorageBuffer((bin_count + 1) * 4);

        const prefix_sum_step_buffer = webgpu.createUniformBuffer(prefix_sum_iterations * 256);
        var step_sizes: [2048]u32 = undefined;
        @memset(&step_sizes, 0);
        for (0..prefix_sum_iterations) |i| {
            step_sizes[i * 64] = @as(u32, 1) << @intCast(i);
        }
        prefix_sum_step_buffer.writeTyped(u32, 0, step_sizes[0..(prefix_sum_iterations * 64)]);

        const binning_shader = webgpu.ShaderModule.create(shaders.spatial_binning);
        const prefix_sum_shader = webgpu.ShaderModule.create(shaders.prefix_sum);
        const sort_shader = webgpu.ShaderModule.create(shaders.particle_sort);
        const forces_shader = webgpu.ShaderModule.create(shaders.force_computation);

        const particle_readonly_layout = createParticleReadonlyLayout();
        const options_layout = createOptionsLayout();
        const bin_size_layout = createBinSizeLayout();
        const prefix_sum_layout = createPrefixSumLayout();
        const sort_layout = createSortLayout();
        const forces_layout = createForcesLayout();

        const particle_readonly_group = createParticleReadonlyBindGroup(particle_readonly_layout, particle_buffer, species_buffer);
        const options_group = createOptionsBindGroup(options_layout, options_buffer);
        const bin_size_group = createBinSizeBindGroup(bin_size_layout, bin_offset_buffer);

        const prefix_sum_group_0 = createPrefixSumBindGroup(prefix_sum_layout, bin_offset_buffer, bin_offset_temp_buffer, prefix_sum_step_buffer);
        const prefix_sum_group_1 = createPrefixSumBindGroup(prefix_sum_layout, bin_offset_temp_buffer, bin_offset_buffer, prefix_sum_step_buffer);

        const sort_group = createSortBindGroup(sort_layout, particle_buffer, particle_temp_buffer, bin_offset_buffer, bin_offset_temp_buffer);
        const forces_group = createForcesBindGroup(forces_layout, particle_temp_buffer, particle_buffer, bin_offset_buffer, force_buffer);

        const bin_clear_pipeline = makeComputePipeline(&[_]webgpu.BindGroupLayout{ particle_readonly_layout, options_layout, bin_size_layout }, binning_shader, "clearBinSize");
        const bin_fill_pipeline = makeComputePipeline(&[_]webgpu.BindGroupLayout{ particle_readonly_layout, options_layout, bin_size_layout }, binning_shader, "fillBinSize");
        const prefix_sum_pipeline_val = makeComputePipeline(&[_]webgpu.BindGroupLayout{prefix_sum_layout}, prefix_sum_shader, "prefixSumStep");
        const sort_clear_pipeline = makeComputePipeline(&[_]webgpu.BindGroupLayout{ sort_layout, options_layout }, sort_shader, "clearBinSize");
        const sort_pipeline_val = makeComputePipeline(&[_]webgpu.BindGroupLayout{ sort_layout, options_layout }, sort_shader, "sortParticles");
        const forces_pipeline_val = makeComputePipeline(&[_]webgpu.BindGroupLayout{ forces_layout, options_layout }, forces_shader, "computeForces");

        log("Spatial optimization pipeline created");

        return SpatialPipeline{
            .binning_shader = binning_shader,
            .prefix_sum_shader = prefix_sum_shader,
            .sort_shader = sort_shader,
            .forces_shader = forces_shader,
            .bin_clear_pipeline = bin_clear_pipeline,
            .bin_fill_pipeline = bin_fill_pipeline,
            .prefix_sum_pipeline = prefix_sum_pipeline_val,
            .sort_clear_pipeline = sort_clear_pipeline,
            .sort_pipeline = sort_pipeline_val,
            .forces_pipeline = forces_pipeline_val,
            .particle_readonly_layout = particle_readonly_layout,
            .options_layout = options_layout,
            .bin_size_layout = bin_size_layout,
            .prefix_sum_layout = prefix_sum_layout,
            .sort_layout = sort_layout,
            .forces_layout = forces_layout,
            .particle_readonly_group = particle_readonly_group,
            .options_group = options_group,
            .bin_size_group = bin_size_group,
            .prefix_sum_group_0 = prefix_sum_group_0,
            .prefix_sum_group_1 = prefix_sum_group_1,
            .sort_group = sort_group,
            .forces_group = forces_group,
            .particle_temp_buffer = particle_temp_buffer,
            .bin_offset_buffer = bin_offset_buffer,
            .bin_offset_temp_buffer = bin_offset_temp_buffer,
            .prefix_sum_step_buffer = prefix_sum_step_buffer,
            .bin_count = bin_count,
            .prefix_sum_iterations = prefix_sum_iterations,
        };
    }

    pub fn computeForces(self: *SpatialPipeline, particle_count: u32, particle_buffer: webgpu.Buffer, particle_temp_buffer: webgpu.Buffer) webgpu.CommandEncoder {
        const encoder = webgpu.CommandEncoder.create();

        encoder.copyBufferToBuffer(particle_buffer.handle, 0, particle_temp_buffer.handle, 0, particle_count * @sizeOf(particle.Particle));

        const binning_pass = encoder.beginComputePass();

        binning_pass.setPipeline(self.bin_clear_pipeline);
        binning_pass.setBindGroup(0, self.particle_readonly_group);
        binning_pass.setBindGroup(1, self.options_group);
        binning_pass.setBindGroup(2, self.bin_size_group);
        binning_pass.dispatch((self.bin_count + 1 + 63) / 64, 1, 1);

        binning_pass.setPipeline(self.bin_fill_pipeline);
        binning_pass.dispatch((particle_count + 63) / 64, 1, 1);

        binning_pass.setPipeline(self.prefix_sum_pipeline);
        for (0..self.prefix_sum_iterations) |i| {
            const group = if (i % 2 == 0) self.prefix_sum_group_0 else self.prefix_sum_group_1;
            const offset = @as(u32, @intCast(i)) * 256;
            binning_pass.setBindGroupWithOffset(0, group, offset);
            binning_pass.dispatch((self.bin_count + 1 + 63) / 64, 1, 1);
        }

        binning_pass.setPipeline(self.sort_clear_pipeline);
        binning_pass.setBindGroup(0, self.sort_group);
        binning_pass.setBindGroup(1, self.options_group);
        binning_pass.dispatch((self.bin_count + 1 + 63) / 64, 1, 1);

        binning_pass.setPipeline(self.sort_pipeline);
        binning_pass.dispatch((particle_count + 63) / 64, 1, 1);

        binning_pass.end();

        const forces_pass = encoder.beginComputePass();
        forces_pass.setPipeline(self.forces_pipeline);
        forces_pass.setBindGroup(0, self.forces_group);
        forces_pass.setBindGroup(1, self.options_group);
        forces_pass.dispatch((particle_count + 63) / 64, 1, 1);
        forces_pass.end();

        return encoder;
    }

    pub fn deinit(self: *SpatialPipeline) void {
        self.particle_temp_buffer.destroy();
        self.bin_offset_buffer.destroy();
        self.bin_offset_temp_buffer.destroy();
        self.prefix_sum_step_buffer.destroy();
    }
};

fn createParticleReadonlyLayout() webgpu.BindGroupLayout {
    const entries = [_]webgpu.BindGroupLayoutEntry{
        webgpu.BindGroupLayoutEntry.initBuffer(0, webgpu.ShaderStage.COMPUTE, .read_only_storage),
        webgpu.BindGroupLayoutEntry.initBuffer(1, webgpu.ShaderStage.COMPUTE, .read_only_storage),
    };
    return webgpu.BindGroupLayout.create(&entries);
}

fn createOptionsLayout() webgpu.BindGroupLayout {
    const entries = [_]webgpu.BindGroupLayoutEntry{
        webgpu.BindGroupLayoutEntry.initBuffer(0, webgpu.ShaderStage.COMPUTE, .uniform),
    };
    return webgpu.BindGroupLayout.create(&entries);
}

fn createBinSizeLayout() webgpu.BindGroupLayout {
    const entries = [_]webgpu.BindGroupLayoutEntry{
        webgpu.BindGroupLayoutEntry.initBuffer(0, webgpu.ShaderStage.COMPUTE, .storage),
    };
    return webgpu.BindGroupLayout.create(&entries);
}

fn createPrefixSumLayout() webgpu.BindGroupLayout {
    const entries = [_]webgpu.BindGroupLayoutEntry{
        webgpu.BindGroupLayoutEntry.initBuffer(0, webgpu.ShaderStage.COMPUTE, .read_only_storage),
        webgpu.BindGroupLayoutEntry.initBuffer(1, webgpu.ShaderStage.COMPUTE, .storage),
        webgpu.BindGroupLayoutEntry.initBuffer(2, webgpu.ShaderStage.COMPUTE, .uniform).withDynamicOffset(),
    };
    return webgpu.BindGroupLayout.create(&entries);
}

fn createSortLayout() webgpu.BindGroupLayout {
    const entries = [_]webgpu.BindGroupLayoutEntry{
        webgpu.BindGroupLayoutEntry.initBuffer(0, webgpu.ShaderStage.COMPUTE, .read_only_storage),
        webgpu.BindGroupLayoutEntry.initBuffer(1, webgpu.ShaderStage.COMPUTE, .storage),
        webgpu.BindGroupLayoutEntry.initBuffer(2, webgpu.ShaderStage.COMPUTE, .read_only_storage),
        webgpu.BindGroupLayoutEntry.initBuffer(3, webgpu.ShaderStage.COMPUTE, .storage),
    };
    return webgpu.BindGroupLayout.create(&entries);
}

fn createForcesLayout() webgpu.BindGroupLayout {
    const entries = [_]webgpu.BindGroupLayoutEntry{
        webgpu.BindGroupLayoutEntry.initBuffer(0, webgpu.ShaderStage.COMPUTE, .read_only_storage),
        webgpu.BindGroupLayoutEntry.initBuffer(1, webgpu.ShaderStage.COMPUTE, .storage),
        webgpu.BindGroupLayoutEntry.initBuffer(2, webgpu.ShaderStage.COMPUTE, .read_only_storage),
        webgpu.BindGroupLayoutEntry.initBuffer(3, webgpu.ShaderStage.COMPUTE, .read_only_storage),
    };
    return webgpu.BindGroupLayout.create(&entries);
}

fn createParticleReadonlyBindGroup(layout: webgpu.BindGroupLayout, particle_buf: webgpu.Buffer, species_buf: webgpu.Buffer) webgpu.BindGroup {
    const entries = [_]webgpu.BindGroupEntry{
        webgpu.BindGroupEntry.initBufferFull(0, particle_buf.handle, particle_buf.size),
        webgpu.BindGroupEntry.initBufferFull(1, species_buf.handle, species_buf.size),
    };
    return webgpu.BindGroup.create(layout, &entries);
}

fn createOptionsBindGroup(layout: webgpu.BindGroupLayout, options_buf: webgpu.Buffer) webgpu.BindGroup {
    const entries = [_]webgpu.BindGroupEntry{
        webgpu.BindGroupEntry.initBufferFull(0, options_buf.handle, options_buf.size),
    };
    return webgpu.BindGroup.create(layout, &entries);
}

fn createBinSizeBindGroup(layout: webgpu.BindGroupLayout, bin_offset_buf: webgpu.Buffer) webgpu.BindGroup {
    const entries = [_]webgpu.BindGroupEntry{
        webgpu.BindGroupEntry.initBufferFull(0, bin_offset_buf.handle, bin_offset_buf.size),
    };
    return webgpu.BindGroup.create(layout, &entries);
}

fn createPrefixSumBindGroup(layout: webgpu.BindGroupLayout, source_buf: webgpu.Buffer, dest_buf: webgpu.Buffer, step_buf: webgpu.Buffer) webgpu.BindGroup {
    const entries = [_]webgpu.BindGroupEntry{
        webgpu.BindGroupEntry.initBufferFull(0, source_buf.handle, source_buf.size),
        webgpu.BindGroupEntry.initBufferFull(1, dest_buf.handle, dest_buf.size),
        webgpu.BindGroupEntry.initBuffer(2, step_buf.handle, 0, 4),
    };
    return webgpu.BindGroup.create(layout, &entries);
}

fn createSortBindGroup(layout: webgpu.BindGroupLayout, particle_buf: webgpu.Buffer, temp_buf: webgpu.Buffer, offset_buf: webgpu.Buffer, offset_temp_buf: webgpu.Buffer) webgpu.BindGroup {
    const entries = [_]webgpu.BindGroupEntry{
        webgpu.BindGroupEntry.initBufferFull(0, particle_buf.handle, particle_buf.size),
        webgpu.BindGroupEntry.initBufferFull(1, temp_buf.handle, temp_buf.size),
        webgpu.BindGroupEntry.initBufferFull(2, offset_buf.handle, offset_buf.size),
        webgpu.BindGroupEntry.initBufferFull(3, offset_temp_buf.handle, offset_temp_buf.size),
    };
    return webgpu.BindGroup.create(layout, &entries);
}

fn createForcesBindGroup(layout: webgpu.BindGroupLayout, temp_buf: webgpu.Buffer, particle_buf: webgpu.Buffer, offset_buf: webgpu.Buffer, force_buf: webgpu.Buffer) webgpu.BindGroup {
    const entries = [_]webgpu.BindGroupEntry{
        webgpu.BindGroupEntry.initBufferFull(0, temp_buf.handle, temp_buf.size),
        webgpu.BindGroupEntry.initBufferFull(1, particle_buf.handle, particle_buf.size),
        webgpu.BindGroupEntry.initBufferFull(2, offset_buf.handle, offset_buf.size),
        webgpu.BindGroupEntry.initBufferFull(3, force_buf.handle, force_buf.size),
    };
    return webgpu.BindGroup.create(layout, &entries);
}

fn makeComputePipeline(layouts: []const webgpu.BindGroupLayout, shader_mod: webgpu.ShaderModule, entry_point: []const u8) webgpu.ComputePipeline {
    const pipeline_layout = webgpu.PipelineLayout.create(layouts);
    return webgpu.ComputePipeline.create(pipeline_layout, shader_mod, entry_point);
}

fn log(comptime msg: []const u8) void {
    js_console_log(msg.ptr, msg.len);
}

fn logInt(comptime prefix: []const u8, value: u32) void {
    var buf: [64]u8 = undefined;
    const str = std.fmt.bufPrint(&buf, "{s} {d}", .{ prefix, value }) catch "Error";
    js_console_log(str.ptr, str.len);
}

extern fn js_console_log(ptr: [*]const u8, len: usize) void;
