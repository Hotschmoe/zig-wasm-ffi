const std = @import("std");
const ffi = @import("zig-wasm-ffi");
const webgpu = ffi.webgpu;
const particle = @import("particle.zig");
const shaders = @import("shaders.zig");

pub const Physics = struct {
    advance_shader: webgpu.ShaderModule,
    advance_pipeline: webgpu.ComputePipeline,
    particle_layout: webgpu.BindGroupLayout,
    options_layout: webgpu.BindGroupLayout,
    particle_group: webgpu.BindGroup,
    options_group: webgpu.BindGroup,

    pub fn init(particle_buffer: webgpu.Buffer, options_buffer: webgpu.Buffer) !Physics {
        log("Setting up physics pipeline...");

        const advance_shader = webgpu.ShaderModule.create(shaders.particle_advance);
        if (!advance_shader.isValid()) {
            log("ERROR: Failed to create advance shader");
            return error.ShaderCreationFailed;
        }

        const particle_layout_entries = [_]webgpu.BindGroupLayoutEntry{
            webgpu.BindGroupLayoutEntry.initBuffer(0, webgpu.ShaderStage.COMPUTE, .storage),
        };
        const particle_layout = webgpu.BindGroupLayout.create(&particle_layout_entries);

        const options_layout_entries = [_]webgpu.BindGroupLayoutEntry{
            webgpu.BindGroupLayoutEntry.initBuffer(0, webgpu.ShaderStage.COMPUTE, .uniform),
        };
        const options_layout = webgpu.BindGroupLayout.create(&options_layout_entries);

        const particle_entries = [_]webgpu.BindGroupEntry{
            webgpu.BindGroupEntry.initBufferFull(0, particle_buffer.handle, particle_buffer.size),
        };
        const particle_group = webgpu.BindGroup.create(particle_layout, &particle_entries);

        const options_entries = [_]webgpu.BindGroupEntry{
            webgpu.BindGroupEntry.initBufferFull(0, options_buffer.handle, options_buffer.size),
        };
        const options_group = webgpu.BindGroup.create(options_layout, &options_entries);

        const layouts = [_]webgpu.BindGroupLayout{ particle_layout, options_layout };
        const pipeline_layout = webgpu.PipelineLayout.create(&layouts);

        const advance_pipeline = webgpu.ComputePipeline.create(
            pipeline_layout,
            advance_shader,
            "particleAdvance",
        );

        if (!advance_pipeline.isValid()) {
            log("ERROR: Failed to create advance pipeline");
            return error.PipelineCreationFailed;
        }

        log("Physics pipeline created");

        return Physics{
            .advance_shader = advance_shader,
            .advance_pipeline = advance_pipeline,
            .particle_layout = particle_layout,
            .options_layout = options_layout,
            .particle_group = particle_group,
            .options_group = options_group,
        };
    }

    pub fn update(self: *Physics, particle_count: u32) void {
        const encoder = webgpu.CommandEncoder.create();
        const pass = encoder.beginComputePass();
        pass.setPipeline(self.advance_pipeline);
        pass.setBindGroup(0, self.particle_group);
        pass.setBindGroup(1, self.options_group);
        const workgroup_count = (particle_count + 63) / 64;
        pass.dispatch(workgroup_count, 1, 1);
        pass.end();
        const cmd_buffer = encoder.finish();
        cmd_buffer.submit();
    }
};

fn log(comptime msg: []const u8) void {
    js_console_log(msg.ptr, msg.len);
}

extern fn js_console_log(ptr: [*]const u8, len: usize) void;
