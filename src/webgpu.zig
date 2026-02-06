const std = @import("std");
const builtin = @import("builtin");

// --- Handles ---

pub const Handle = u32;
pub const INVALID_HANDLE: Handle = 0;

pub const DeviceHandle = HandleType("Device");
pub const BufferHandle = HandleType("Buffer");
pub const ShaderModuleHandle = HandleType("ShaderModule");
pub const TextureHandle = HandleType("Texture");
pub const TextureViewHandle = HandleType("TextureView");
pub const BindGroupHandle = HandleType("BindGroup");
pub const BindGroupLayoutHandle = HandleType("BindGroupLayout");
pub const PipelineLayoutHandle = HandleType("PipelineLayout");
pub const ComputePipelineHandle = HandleType("ComputePipeline");
pub const RenderPipelineHandle = HandleType("RenderPipeline");
pub const CommandEncoderHandle = HandleType("CommandEncoder");
pub const RenderPassEncoderHandle = HandleType("RenderPassEncoder");
pub const ComputePassEncoderHandle = HandleType("ComputePassEncoder");

fn HandleType(comptime _: []const u8) type {
    return struct {
        id: Handle,

        pub fn isValid(self: @This()) bool {
            return self.id != INVALID_HANDLE;
        }

        pub fn invalid() @This() {
            return .{ .id = INVALID_HANDLE };
        }
    };
}

// --- FFI Binding Layer ---

extern "env" fn env_webgpu_create_buffer(device: u32, size: u64, usage: u32, mapped_at_creation: u32) u32;
extern "env" fn env_webgpu_buffer_write(device: u32, buffer: u32, offset: u64, data_ptr: [*]const u8, data_len: usize) void;
extern "env" fn env_webgpu_buffer_destroy(buffer: u32) void;
extern "env" fn env_webgpu_create_shader_module(device: u32, source_ptr: [*]const u8, source_len: usize) u32;

extern "env" fn env_webgpu_create_bind_group_layout(device: u32, entries_ptr: usize, entries_len: usize) u32;
extern "env" fn env_webgpu_create_bind_group(device: u32, layout: u32, entries_ptr: usize, entries_len: usize) u32;
extern "env" fn env_webgpu_create_pipeline_layout(device: u32, layouts_ptr: usize, layouts_len: usize) u32;
extern "env" fn env_webgpu_create_compute_pipeline(device: u32, layout: u32, shader: u32, entry_ptr: [*]const u8, entry_len: usize) u32;

extern "env" fn env_webgpu_create_command_encoder(device: u32) u32;
extern "env" fn env_webgpu_begin_compute_pass(encoder: u32) u32;
extern "env" fn env_webgpu_compute_pass_set_pipeline(pass: u32, pipeline: u32) void;
extern "env" fn env_webgpu_compute_pass_set_bind_group(pass: u32, index: u32, bind_group: u32) void;
extern "env" fn env_webgpu_compute_pass_dispatch(pass: u32, x: u32, y: u32, z: u32) void;
extern "env" fn env_webgpu_compute_pass_end(pass: u32) void;
extern "env" fn env_webgpu_command_encoder_finish(encoder: u32) u32;
extern "env" fn env_webgpu_queue_submit(device: u32, command_buffer: u32) void;

extern "env" fn env_webgpu_begin_render_pass(r: f32, g: f32, b: f32, a: f32) u32;
extern "env" fn env_webgpu_end_render_pass(encoder: u32) void;
extern "env" fn env_webgpu_present() void;

extern "env" fn env_webgpu_create_texture(device: u32, width: u32, height: u32, format: u32, usage: u32) u32;
extern "env" fn env_webgpu_create_texture_view(texture: u32) u32;
extern "env" fn env_webgpu_destroy_texture(texture: u32) void;

extern "env" fn env_webgpu_create_render_pipeline(device: u32, layout: u32, shader: u32, v_ptr: [*]const u8, v_len: usize, f_ptr: [*]const u8, f_len: usize) u32;
extern "env" fn env_webgpu_create_render_pipeline_hdr(device: u32, layout: u32, shader: u32, v_ptr: [*]const u8, v_len: usize, f_ptr: [*]const u8, f_len: usize, format: u32, blending: u32) u32;

extern "env" fn env_webgpu_begin_render_pass_for_particles(r: f32, g: f32, b: f32, a: f32) u32;
extern "env" fn env_webgpu_begin_render_pass_hdr(texture_view: u32, r: f32, g: f32, b: f32, a: f32) u32;
extern "env" fn env_webgpu_render_pass_set_pipeline(pass: u32, pipeline: u32) void;
extern "env" fn env_webgpu_render_pass_set_bind_group(pass: u32, index: u32, bind_group: u32) void;
extern "env" fn env_webgpu_render_pass_draw(pass: u32, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void;
extern "env" fn env_webgpu_render_pass_end(pass: u32) void;

extern "env" fn env_webgpu_copy_buffer_to_buffer(src: u32, src_offset: u64, dst: u32, dst_offset: u64, size: u64) void;
extern "env" fn env_webgpu_copy_buffer_to_buffer_in_encoder(encoder: u32, src: u32, src_offset: u64, dst: u32, dst_offset: u64, size: u64) void;

extern "env" fn env_webgpu_compute_pass_set_bind_group_with_offset(pass: u32, index: u32, bind_group: u32, offset: u32) void;

fn noopRet0_u32(_: u32) u32 { return 0; }
fn noopRet0_u32_u64_u32_u32(_: u32, _: u64, _: u32, _: u32) u32 { return 0; }
fn noopRet0_u32_ptr_usize(_: u32, _: [*]const u8, _: usize) u32 { return 0; }
fn noopRet0_u32_usize_usize(_: u32, _: usize, _: usize) u32 { return 0; }
fn noopRet0_u32_u32_usize_usize(_: u32, _: u32, _: usize, _: usize) u32 { return 0; }
fn noopRet0_u32_u32_u32_ptr_usize(_: u32, _: u32, _: u32, _: [*]const u8, _: usize) u32 { return 0; }
fn noopRet0_u32_u32_u32_u32_u32(_: u32, _: u32, _: u32, _: u32, _: u32) u32 { return 0; }
fn noopRet0_4f32(_: f32, _: f32, _: f32, _: f32) u32 { return 0; }
fn noopRet0_u32_4f32(_: u32, _: f32, _: f32, _: f32, _: f32) u32 { return 0; }
fn noopRet0_7u32_ptr(_: u32, _: u32, _: u32, _: [*]const u8, _: usize, _: [*]const u8, _: usize) u32 { return 0; }
fn noopRet0_7u32_ptr_2u32(_: u32, _: u32, _: u32, _: [*]const u8, _: usize, _: [*]const u8, _: usize, _: u32, _: u32) u32 { return 0; }
fn noopVoid() void {}
fn noopVoid_u32(_: u32) void {}
fn noopVoid_u32_u32(_: u32, _: u32) void {}
fn noopVoid_u32_u32_u32(_: u32, _: u32, _: u32) void {}
fn noopVoid_u32_u32_u32_u32(_: u32, _: u32, _: u32, _: u32) void {}
fn noopVoid_u32_u32_u32_u32_u32(_: u32, _: u32, _: u32, _: u32, _: u32) void {}
fn noopVoid_u32_u32_u64_ptr_usize(_: u32, _: u32, _: u64, _: [*]const u8, _: usize) void {}
fn noopVoid_u32_u64_u32_u64_u64(_: u32, _: u64, _: u32, _: u64, _: u64) void {}
fn noopVoid_u32_u32_u64_u32_u64_u64(_: u32, _: u32, _: u64, _: u32, _: u64, _: u64) void {}

pub var mock_create_buffer: *const fn (u32, u64, u32, u32) u32 = &noopRet0_u32_u64_u32_u32;
pub var mock_buffer_write: *const fn (u32, u32, u64, [*]const u8, usize) void = &noopVoid_u32_u32_u64_ptr_usize;
pub var mock_buffer_destroy: *const fn (u32) void = &noopVoid_u32;
pub var mock_create_shader_module: *const fn (u32, [*]const u8, usize) u32 = &noopRet0_u32_ptr_usize;
pub var mock_create_bind_group_layout: *const fn (u32, usize, usize) u32 = &noopRet0_u32_usize_usize;
pub var mock_create_bind_group: *const fn (u32, u32, usize, usize) u32 = &noopRet0_u32_u32_usize_usize;
pub var mock_create_pipeline_layout: *const fn (u32, usize, usize) u32 = &noopRet0_u32_usize_usize;
pub var mock_create_compute_pipeline: *const fn (u32, u32, u32, [*]const u8, usize) u32 = &noopRet0_u32_u32_u32_ptr_usize;
pub var mock_create_command_encoder: *const fn (u32) u32 = &noopRet0_u32;
pub var mock_begin_compute_pass: *const fn (u32) u32 = &noopRet0_u32;
pub var mock_compute_pass_set_pipeline: *const fn (u32, u32) void = &noopVoid_u32_u32;
pub var mock_compute_pass_set_bind_group: *const fn (u32, u32, u32) void = &noopVoid_u32_u32_u32;
pub var mock_compute_pass_dispatch: *const fn (u32, u32, u32, u32) void = &noopVoid_u32_u32_u32_u32;
pub var mock_compute_pass_end: *const fn (u32) void = &noopVoid_u32;
pub var mock_command_encoder_finish: *const fn (u32) u32 = &noopRet0_u32;
pub var mock_queue_submit: *const fn (u32, u32) void = &noopVoid_u32_u32;
pub var mock_begin_render_pass: *const fn (f32, f32, f32, f32) u32 = &noopRet0_4f32;
pub var mock_end_render_pass: *const fn (u32) void = &noopVoid_u32;
pub var mock_present: *const fn () void = &noopVoid;
pub var mock_create_texture: *const fn (u32, u32, u32, u32, u32) u32 = &noopRet0_u32_u32_u32_u32_u32;
pub var mock_create_texture_view: *const fn (u32) u32 = &noopRet0_u32;
pub var mock_destroy_texture: *const fn (u32) void = &noopVoid_u32;
pub var mock_create_render_pipeline: *const fn (u32, u32, u32, [*]const u8, usize, [*]const u8, usize) u32 = &noopRet0_7u32_ptr;
pub var mock_create_render_pipeline_hdr: *const fn (u32, u32, u32, [*]const u8, usize, [*]const u8, usize, u32, u32) u32 = &noopRet0_7u32_ptr_2u32;
pub var mock_begin_render_pass_for_particles: *const fn (f32, f32, f32, f32) u32 = &noopRet0_4f32;
pub var mock_begin_render_pass_hdr: *const fn (u32, f32, f32, f32, f32) u32 = &noopRet0_u32_4f32;
pub var mock_render_pass_set_pipeline: *const fn (u32, u32) void = &noopVoid_u32_u32;
pub var mock_render_pass_set_bind_group: *const fn (u32, u32, u32) void = &noopVoid_u32_u32_u32;
pub var mock_render_pass_draw: *const fn (u32, u32, u32, u32, u32) void = &noopVoid_u32_u32_u32_u32_u32;
pub var mock_render_pass_end: *const fn (u32) void = &noopVoid_u32;
pub var mock_copy_buffer_to_buffer: *const fn (u32, u64, u32, u64, u64) void = &noopVoid_u32_u64_u32_u64_u64;
pub var mock_copy_buffer_to_buffer_in_encoder: *const fn (u32, u32, u64, u32, u64, u64) void = &noopVoid_u32_u32_u64_u32_u64_u64;
pub var mock_compute_pass_set_bind_group_with_offset: *const fn (u32, u32, u32, u32) void = &noopVoid_u32_u32_u32_u32;

inline fn ffiCreateBuffer(dev: u32, size: u64, usage: u32, mapped: u32) u32 {
    if (comptime builtin.is_test) return mock_create_buffer(dev, size, usage, mapped);
    return env_webgpu_create_buffer(dev, size, usage, mapped);
}
inline fn ffiBufferWrite(dev: u32, buf: u32, offset: u64, ptr: [*]const u8, len: usize) void {
    if (comptime builtin.is_test) return mock_buffer_write(dev, buf, offset, ptr, len);
    return env_webgpu_buffer_write(dev, buf, offset, ptr, len);
}
inline fn ffiBufferDestroy(buf: u32) void {
    if (comptime builtin.is_test) return mock_buffer_destroy(buf);
    return env_webgpu_buffer_destroy(buf);
}
inline fn ffiCreateShaderModule(dev: u32, ptr: [*]const u8, len: usize) u32 {
    if (comptime builtin.is_test) return mock_create_shader_module(dev, ptr, len);
    return env_webgpu_create_shader_module(dev, ptr, len);
}
inline fn ffiCreateBindGroupLayout(dev: u32, entries_ptr: usize, entries_len: usize) u32 {
    if (comptime builtin.is_test) return mock_create_bind_group_layout(dev, entries_ptr, entries_len);
    return env_webgpu_create_bind_group_layout(dev, entries_ptr, entries_len);
}
inline fn ffiCreateBindGroup(dev: u32, layout: u32, entries_ptr: usize, entries_len: usize) u32 {
    if (comptime builtin.is_test) return mock_create_bind_group(dev, layout, entries_ptr, entries_len);
    return env_webgpu_create_bind_group(dev, layout, entries_ptr, entries_len);
}
inline fn ffiCreatePipelineLayout(dev: u32, layouts_ptr: usize, layouts_len: usize) u32 {
    if (comptime builtin.is_test) return mock_create_pipeline_layout(dev, layouts_ptr, layouts_len);
    return env_webgpu_create_pipeline_layout(dev, layouts_ptr, layouts_len);
}
inline fn ffiCreateComputePipeline(dev: u32, layout: u32, shader: u32, ep_ptr: [*]const u8, ep_len: usize) u32 {
    if (comptime builtin.is_test) return mock_create_compute_pipeline(dev, layout, shader, ep_ptr, ep_len);
    return env_webgpu_create_compute_pipeline(dev, layout, shader, ep_ptr, ep_len);
}
inline fn ffiCreateCommandEncoder(dev: u32) u32 {
    if (comptime builtin.is_test) return mock_create_command_encoder(dev);
    return env_webgpu_create_command_encoder(dev);
}
inline fn ffiBeginComputePass(encoder: u32) u32 {
    if (comptime builtin.is_test) return mock_begin_compute_pass(encoder);
    return env_webgpu_begin_compute_pass(encoder);
}
inline fn ffiComputePassSetPipeline(pass: u32, pipe: u32) void {
    if (comptime builtin.is_test) return mock_compute_pass_set_pipeline(pass, pipe);
    return env_webgpu_compute_pass_set_pipeline(pass, pipe);
}
inline fn ffiComputePassSetBindGroup(pass: u32, index: u32, bg: u32) void {
    if (comptime builtin.is_test) return mock_compute_pass_set_bind_group(pass, index, bg);
    return env_webgpu_compute_pass_set_bind_group(pass, index, bg);
}
inline fn ffiComputePassDispatch(pass: u32, x: u32, y: u32, z: u32) void {
    if (comptime builtin.is_test) return mock_compute_pass_dispatch(pass, x, y, z);
    return env_webgpu_compute_pass_dispatch(pass, x, y, z);
}
inline fn ffiComputePassEnd(pass: u32) void {
    if (comptime builtin.is_test) return mock_compute_pass_end(pass);
    return env_webgpu_compute_pass_end(pass);
}
inline fn ffiCommandEncoderFinish(encoder: u32) u32 {
    if (comptime builtin.is_test) return mock_command_encoder_finish(encoder);
    return env_webgpu_command_encoder_finish(encoder);
}
inline fn ffiQueueSubmit(dev: u32, cmd: u32) void {
    if (comptime builtin.is_test) return mock_queue_submit(dev, cmd);
    return env_webgpu_queue_submit(dev, cmd);
}
inline fn ffiBeginRenderPass(r: f32, g: f32, b: f32, a: f32) u32 {
    if (comptime builtin.is_test) return mock_begin_render_pass(r, g, b, a);
    return env_webgpu_begin_render_pass(r, g, b, a);
}
inline fn ffiEndRenderPass(encoder: u32) void {
    if (comptime builtin.is_test) return mock_end_render_pass(encoder);
    return env_webgpu_end_render_pass(encoder);
}
inline fn ffiPresent() void {
    if (comptime builtin.is_test) return mock_present();
    return env_webgpu_present();
}
inline fn ffiCreateTexture(dev: u32, w: u32, h: u32, fmt: u32, usage: u32) u32 {
    if (comptime builtin.is_test) return mock_create_texture(dev, w, h, fmt, usage);
    return env_webgpu_create_texture(dev, w, h, fmt, usage);
}
inline fn ffiCreateTextureView(tex: u32) u32 {
    if (comptime builtin.is_test) return mock_create_texture_view(tex);
    return env_webgpu_create_texture_view(tex);
}
inline fn ffiDestroyTexture(tex: u32) void {
    if (comptime builtin.is_test) return mock_destroy_texture(tex);
    return env_webgpu_destroy_texture(tex);
}
inline fn ffiCreateRenderPipeline(dev: u32, layout: u32, shader: u32, v_ptr: [*]const u8, v_len: usize, f_ptr: [*]const u8, f_len: usize) u32 {
    if (comptime builtin.is_test) return mock_create_render_pipeline(dev, layout, shader, v_ptr, v_len, f_ptr, f_len);
    return env_webgpu_create_render_pipeline(dev, layout, shader, v_ptr, v_len, f_ptr, f_len);
}
inline fn ffiCreateRenderPipelineHDR(dev: u32, layout: u32, shader: u32, v_ptr: [*]const u8, v_len: usize, f_ptr: [*]const u8, f_len: usize, format: u32, blending: u32) u32 {
    if (comptime builtin.is_test) return mock_create_render_pipeline_hdr(dev, layout, shader, v_ptr, v_len, f_ptr, f_len, format, blending);
    return env_webgpu_create_render_pipeline_hdr(dev, layout, shader, v_ptr, v_len, f_ptr, f_len, format, blending);
}
inline fn ffiBeginRenderPassForParticles(r: f32, g: f32, b: f32, a: f32) u32 {
    if (comptime builtin.is_test) return mock_begin_render_pass_for_particles(r, g, b, a);
    return env_webgpu_begin_render_pass_for_particles(r, g, b, a);
}
inline fn ffiBeginRenderPassHDR(texture_view: u32, r: f32, g: f32, b: f32, a: f32) u32 {
    if (comptime builtin.is_test) return mock_begin_render_pass_hdr(texture_view, r, g, b, a);
    return env_webgpu_begin_render_pass_hdr(texture_view, r, g, b, a);
}
inline fn ffiRenderPassSetPipeline(pass: u32, pipe: u32) void {
    if (comptime builtin.is_test) return mock_render_pass_set_pipeline(pass, pipe);
    return env_webgpu_render_pass_set_pipeline(pass, pipe);
}
inline fn ffiRenderPassSetBindGroup(pass: u32, index: u32, bg: u32) void {
    if (comptime builtin.is_test) return mock_render_pass_set_bind_group(pass, index, bg);
    return env_webgpu_render_pass_set_bind_group(pass, index, bg);
}
inline fn ffiRenderPassDraw(pass: u32, vert_count: u32, inst_count: u32, first_vert: u32, first_inst: u32) void {
    if (comptime builtin.is_test) return mock_render_pass_draw(pass, vert_count, inst_count, first_vert, first_inst);
    return env_webgpu_render_pass_draw(pass, vert_count, inst_count, first_vert, first_inst);
}
inline fn ffiRenderPassEnd(pass: u32) void {
    if (comptime builtin.is_test) return mock_render_pass_end(pass);
    return env_webgpu_render_pass_end(pass);
}
inline fn ffiCopyBufferToBuffer(src: u32, src_offset: u64, dst: u32, dst_offset: u64, size: u64) void {
    if (comptime builtin.is_test) return mock_copy_buffer_to_buffer(src, src_offset, dst, dst_offset, size);
    return env_webgpu_copy_buffer_to_buffer(src, src_offset, dst, dst_offset, size);
}
inline fn ffiCopyBufferToBufferInEncoder(encoder: u32, src: u32, src_offset: u64, dst: u32, dst_offset: u64, size: u64) void {
    if (comptime builtin.is_test) return mock_copy_buffer_to_buffer_in_encoder(encoder, src, src_offset, dst, dst_offset, size);
    return env_webgpu_copy_buffer_to_buffer_in_encoder(encoder, src, src_offset, dst, dst_offset, size);
}
inline fn ffiComputePassSetBindGroupWithOffset(pass: u32, index: u32, bg: u32, offset: u32) void {
    if (comptime builtin.is_test) return mock_compute_pass_set_bind_group_with_offset(pass, index, bg, offset);
    return env_webgpu_compute_pass_set_bind_group_with_offset(pass, index, bg, offset);
}

// --- Device ---

var g_device: DeviceHandle = DeviceHandle.invalid();

pub fn init(device_handle: u32) void {
    g_device = .{ .id = device_handle };
}

pub fn getDevice() DeviceHandle {
    return g_device;
}

pub fn isInitialized() bool {
    return g_device.isValid();
}

// --- Buffer ---

pub const BufferUsage = packed struct(u32) {
    map_read: bool = false,
    map_write: bool = false,
    copy_src: bool = false,
    copy_dst: bool = false,
    index: bool = false,
    vertex: bool = false,
    uniform: bool = false,
    storage: bool = false,
    indirect: bool = false,
    query_resolve: bool = false,
    _padding: u22 = 0,
};

pub const Buffer = struct {
    handle: BufferHandle,
    size: u64,
    usage: BufferUsage,

    pub fn create(size: u64, usage: BufferUsage, mapped_at_creation: bool) Buffer {
        if (!g_device.isValid()) return .{ .handle = BufferHandle.invalid(), .size = 0, .usage = usage };
        const usage_flags: u32 = @bitCast(usage);
        const handle_id = ffiCreateBuffer(g_device.id, size, usage_flags, @intFromBool(mapped_at_creation));
        return .{ .handle = .{ .id = handle_id }, .size = size, .usage = usage };
    }

    pub fn write(self: Buffer, offset: u64, data: []const u8) void {
        if (!g_device.isValid() or !self.handle.isValid()) return;
        ffiBufferWrite(g_device.id, self.handle.id, offset, data.ptr, data.len);
    }

    pub fn writeTyped(self: Buffer, comptime T: type, offset: u64, data: []const T) void {
        self.write(offset, std.mem.sliceAsBytes(data));
    }

    pub fn destroy(self: Buffer) void {
        if (!self.handle.isValid()) return;
        ffiBufferDestroy(self.handle.id);
    }

    pub fn isValid(self: Buffer) bool {
        return self.handle.isValid();
    }
};

pub fn createStorageBuffer(size: u64) Buffer {
    return Buffer.create(size, .{ .storage = true, .copy_dst = true, .copy_src = true }, false);
}

pub fn createUniformBuffer(size: u64) Buffer {
    return Buffer.create(size, .{ .uniform = true, .copy_dst = true }, false);
}

pub fn createVertexBuffer(size: u64) Buffer {
    return Buffer.create(size, .{ .vertex = true, .copy_dst = true }, false);
}

pub fn createReadbackBuffer(size: u64) Buffer {
    return Buffer.create(size, .{ .map_read = true, .copy_dst = true }, false);
}

pub fn createStorageBufferWithData(comptime T: type, data: []const T) Buffer {
    const buf = createStorageBuffer(@sizeOf(T) * data.len);
    buf.writeTyped(T, 0, data);
    return buf;
}

pub fn createUniformBufferWithData(comptime T: type, data: []const T) Buffer {
    const buf = createUniformBuffer(@sizeOf(T) * data.len);
    buf.writeTyped(T, 0, data);
    return buf;
}

// --- Shader ---

pub const ShaderModule = struct {
    handle: ShaderModuleHandle,

    pub fn create(source: []const u8) ShaderModule {
        if (!g_device.isValid()) return .{ .handle = ShaderModuleHandle.invalid() };
        const handle_id = ffiCreateShaderModule(g_device.id, source.ptr, source.len);
        return .{ .handle = .{ .id = handle_id } };
    }

    pub fn isValid(self: ShaderModule) bool {
        return self.handle.isValid();
    }
};

// --- Pipeline ---

pub const ShaderStage = struct {
    pub const VERTEX: u32 = 0x1;
    pub const FRAGMENT: u32 = 0x2;
    pub const COMPUTE: u32 = 0x4;
};

pub const BufferBindingType = enum(u32) {
    uniform = 0,
    storage = 1,
    read_only_storage = 2,
};

pub const BindingType = enum(u32) {
    buffer = 0,
    texture = 1,
    sampler = 2,
};

pub const BindGroupLayoutEntry = extern struct {
    binding: u32,
    visibility: u32,
    entry_type: u32,
    buffer_type: u32,
    has_min_size: u32,
    has_dynamic_offset: u32,
    min_size: u64,
    _padding: u64,

    pub fn initBuffer(binding: u32, visibility: u32, buffer_type: BufferBindingType) BindGroupLayoutEntry {
        return .{
            .binding = binding,
            .visibility = visibility,
            .entry_type = @intFromEnum(BindingType.buffer),
            .buffer_type = @intFromEnum(buffer_type),
            .has_min_size = 0,
            .has_dynamic_offset = 0,
            .min_size = 0,
            ._padding = 0,
        };
    }

    pub fn initTexture(binding: u32, visibility: u32) BindGroupLayoutEntry {
        return .{
            .binding = binding,
            .visibility = visibility,
            .entry_type = @intFromEnum(BindingType.texture),
            .buffer_type = 0,
            .has_min_size = 0,
            .has_dynamic_offset = 0,
            .min_size = 0,
            ._padding = 0,
        };
    }

    pub fn withMinSize(self: BindGroupLayoutEntry, min_size: u64) BindGroupLayoutEntry {
        var entry = self;
        entry.has_min_size = 1;
        entry.min_size = min_size;
        return entry;
    }

    pub fn withDynamicOffset(self: BindGroupLayoutEntry) BindGroupLayoutEntry {
        var entry = self;
        entry.has_dynamic_offset = 1;
        return entry;
    }
};

pub const BindGroupLayout = struct {
    handle: BindGroupLayoutHandle,

    pub fn create(entries: []const BindGroupLayoutEntry) BindGroupLayout {
        if (!g_device.isValid()) return .{ .handle = BindGroupLayoutHandle.invalid() };
        const handle_id = ffiCreateBindGroupLayout(g_device.id, @intFromPtr(entries.ptr), entries.len);
        return .{ .handle = .{ .id = handle_id } };
    }

    pub fn isValid(self: BindGroupLayout) bool {
        return self.handle.isValid();
    }
};

pub const BindGroupEntry = extern struct {
    binding: u32,
    entry_type: u32,
    resource_handle: u32,
    _padding1: u32,
    offset: u64,
    size: u64,

    pub fn initBuffer(binding: u32, buffer_handle: BufferHandle, offset: u64, size: u64) BindGroupEntry {
        return .{
            .binding = binding,
            .entry_type = 0,
            .resource_handle = buffer_handle.id,
            ._padding1 = 0,
            .offset = offset,
            .size = size,
        };
    }

    pub fn initBufferFull(binding: u32, buffer_handle: BufferHandle, buffer_size: u64) BindGroupEntry {
        return initBuffer(binding, buffer_handle, 0, buffer_size);
    }

    pub fn initTextureView(binding: u32, texture_view_handle: TextureViewHandle) BindGroupEntry {
        return .{
            .binding = binding,
            .entry_type = 1,
            .resource_handle = texture_view_handle.id,
            ._padding1 = 0,
            .offset = 0,
            .size = 0,
        };
    }
};

pub const BindGroup = struct {
    handle: BindGroupHandle,

    pub fn create(layout: BindGroupLayout, entries: []const BindGroupEntry) BindGroup {
        if (!g_device.isValid() or !layout.isValid()) return .{ .handle = BindGroupHandle.invalid() };
        const handle_id = ffiCreateBindGroup(g_device.id, layout.handle.id, @intFromPtr(entries.ptr), entries.len);
        return .{ .handle = .{ .id = handle_id } };
    }

    pub fn isValid(self: BindGroup) bool {
        return self.handle.isValid();
    }
};

pub const PipelineLayout = struct {
    handle: PipelineLayoutHandle,

    pub fn create(bind_group_layouts: []const BindGroupLayout) PipelineLayout {
        if (!g_device.isValid()) return .{ .handle = PipelineLayoutHandle.invalid() };
        var layout_ids: [8]u32 = undefined;
        const count = @min(bind_group_layouts.len, layout_ids.len);
        for (bind_group_layouts[0..count], 0..) |layout, i| {
            layout_ids[i] = layout.handle.id;
        }
        const handle_id = ffiCreatePipelineLayout(g_device.id, @intFromPtr(&layout_ids), count);
        return .{ .handle = .{ .id = handle_id } };
    }

    pub fn isValid(self: PipelineLayout) bool {
        return self.handle.isValid();
    }
};

pub const ComputePipeline = struct {
    handle: ComputePipelineHandle,

    pub fn create(layout: PipelineLayout, shader_module: ShaderModule, entry_point: []const u8) ComputePipeline {
        if (!g_device.isValid() or !layout.isValid() or !shader_module.isValid())
            return .{ .handle = ComputePipelineHandle.invalid() };
        const handle_id = ffiCreateComputePipeline(g_device.id, layout.handle.id, shader_module.handle.id, entry_point.ptr, entry_point.len);
        return .{ .handle = .{ .id = handle_id } };
    }

    pub fn isValid(self: ComputePipeline) bool {
        return self.handle.isValid();
    }
};

// --- Compute ---

pub const CommandEncoder = struct {
    handle: CommandEncoderHandle,

    pub fn create() CommandEncoder {
        if (!g_device.isValid()) return .{ .handle = CommandEncoderHandle.invalid() };
        const handle_id = ffiCreateCommandEncoder(g_device.id);
        return .{ .handle = .{ .id = handle_id } };
    }

    pub fn beginComputePass(self: CommandEncoder) ComputePass {
        if (!self.isValid()) return .{ .handle = ComputePassEncoderHandle.invalid() };
        const handle_id = ffiBeginComputePass(self.handle.id);
        return .{ .handle = .{ .id = handle_id } };
    }

    pub fn copyBufferToBuffer(self: CommandEncoder, src: BufferHandle, src_offset: u64, dst: BufferHandle, dst_offset: u64, size: u64) void {
        if (!self.isValid()) return;
        ffiCopyBufferToBufferInEncoder(self.handle.id, src.id, src_offset, dst.id, dst_offset, size);
    }

    pub fn finish(self: CommandEncoder) CommandBuffer {
        if (!self.isValid()) return .{ .handle = 0 };
        const handle_id = ffiCommandEncoderFinish(self.handle.id);
        return .{ .handle = handle_id };
    }

    pub fn isValid(self: CommandEncoder) bool {
        return self.handle.isValid();
    }
};

pub const ComputePass = struct {
    handle: ComputePassEncoderHandle,

    pub fn setPipeline(self: ComputePass, compute_pipeline: ComputePipeline) void {
        if (!self.isValid() or !compute_pipeline.isValid()) return;
        ffiComputePassSetPipeline(self.handle.id, compute_pipeline.handle.id);
    }

    pub fn setBindGroup(self: ComputePass, index: u32, bind_group: BindGroup) void {
        if (!self.isValid() or !bind_group.isValid()) return;
        ffiComputePassSetBindGroup(self.handle.id, index, bind_group.handle.id);
    }

    pub fn setBindGroupWithOffset(self: ComputePass, index: u32, bind_group: BindGroup, dynamic_offset: u32) void {
        if (!self.isValid() or !bind_group.isValid()) return;
        ffiComputePassSetBindGroupWithOffset(self.handle.id, index, bind_group.handle.id, dynamic_offset);
    }

    pub fn dispatch(self: ComputePass, x: u32, y: u32, z: u32) void {
        if (!self.isValid()) return;
        ffiComputePassDispatch(self.handle.id, x, y, z);
    }

    pub fn end(self: ComputePass) void {
        if (!self.isValid()) return;
        ffiComputePassEnd(self.handle.id);
    }

    pub fn isValid(self: ComputePass) bool {
        return self.handle.isValid();
    }
};

pub const CommandBuffer = struct {
    handle: u32,

    pub fn submit(self: CommandBuffer) void {
        if (!g_device.isValid() or self.handle == 0) return;
        ffiQueueSubmit(g_device.id, self.handle);
    }
};

pub fn dispatchCompute(compute_pipeline: ComputePipeline, bind_group: BindGroup, x: u32, y: u32, z: u32) void {
    const encoder = CommandEncoder.create();
    const pass = encoder.beginComputePass();
    pass.setPipeline(compute_pipeline);
    pass.setBindGroup(0, bind_group);
    pass.dispatch(x, y, z);
    pass.end();
    const cmd = encoder.finish();
    cmd.submit();
}

pub fn copyBufferToBuffer(src: BufferHandle, src_offset: u64, dst: BufferHandle, dst_offset: u64, size: u64) void {
    ffiCopyBufferToBuffer(src.id, src_offset, dst.id, dst_offset, size);
}

// --- Render ---

pub const ClearColor = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub fn init(r: f32, g: f32, b: f32, a: f32) ClearColor {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn black() ClearColor {
        return ClearColor.init(0.0, 0.0, 0.0, 1.0);
    }

    pub fn white() ClearColor {
        return ClearColor.init(1.0, 1.0, 1.0, 1.0);
    }

    pub fn fromHSV(h: f32, s: f32, v: f32) ClearColor {
        const c = v * s;
        const x = c * (1.0 - @abs(@mod(h / 60.0, 2.0) - 1.0));
        const m = v - c;

        var r: f32 = 0;
        var g: f32 = 0;
        var b: f32 = 0;

        if (h < 60.0) {
            r = c;
            g = x;
        } else if (h < 120.0) {
            r = x;
            g = c;
        } else if (h < 180.0) {
            g = c;
            b = x;
        } else if (h < 240.0) {
            g = x;
            b = c;
        } else if (h < 300.0) {
            r = x;
            b = c;
        } else {
            r = c;
            b = x;
        }

        return ClearColor.init(r + m, g + m, b + m, 1.0);
    }
};

pub fn beginRenderPass(clear_color: ClearColor) RenderPassEncoderHandle {
    const handle_id = ffiBeginRenderPass(clear_color.r, clear_color.g, clear_color.b, clear_color.a);
    return .{ .id = handle_id };
}

pub fn endRenderPass(encoder: RenderPassEncoderHandle) void {
    if (!encoder.isValid()) return;
    ffiEndRenderPass(encoder.id);
}

pub fn present() void {
    ffiPresent();
}

pub fn clearScreen(color: ClearColor) void {
    const encoder = beginRenderPass(color);
    endRenderPass(encoder);
    present();
}

pub const RenderPipeline = struct {
    handle: RenderPipelineHandle,

    pub fn create(layout: PipelineLayout, shader_module: ShaderModule, vertex_entry: []const u8, fragment_entry: []const u8) RenderPipeline {
        if (!g_device.isValid() or !layout.isValid() or !shader_module.isValid())
            return .{ .handle = RenderPipelineHandle.invalid() };
        const id = ffiCreateRenderPipeline(g_device.id, layout.handle.id, shader_module.handle.id, vertex_entry.ptr, vertex_entry.len, fragment_entry.ptr, fragment_entry.len);
        return .{ .handle = .{ .id = id } };
    }

    pub fn createHDR(layout: PipelineLayout, shader_module: ShaderModule, vertex_entry: []const u8, fragment_entry: []const u8, format: TextureFormat, enable_blending: bool) RenderPipeline {
        if (!g_device.isValid() or !layout.isValid() or !shader_module.isValid())
            return .{ .handle = RenderPipelineHandle.invalid() };
        const id = ffiCreateRenderPipelineHDR(g_device.id, layout.handle.id, shader_module.handle.id, vertex_entry.ptr, vertex_entry.len, fragment_entry.ptr, fragment_entry.len, @intFromEnum(format), @intFromBool(enable_blending));
        return .{ .handle = .{ .id = id } };
    }

    pub fn isValid(self: RenderPipeline) bool {
        return self.handle.isValid();
    }
};

pub const RenderPass = struct {
    handle: RenderPassEncoderHandle,

    pub fn setPipeline(self: RenderPass, render_pipeline: RenderPipeline) void {
        if (!self.isValid() or !render_pipeline.isValid()) return;
        ffiRenderPassSetPipeline(self.handle.id, render_pipeline.handle.id);
    }

    pub fn setBindGroup(self: RenderPass, index: u32, bind_group: BindGroup) void {
        if (!self.isValid() or !bind_group.isValid()) return;
        ffiRenderPassSetBindGroup(self.handle.id, index, bind_group.handle.id);
    }

    pub fn draw(self: RenderPass, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
        if (!self.isValid()) return;
        ffiRenderPassDraw(self.handle.id, vertex_count, instance_count, first_vertex, first_instance);
    }

    pub fn end(self: RenderPass) void {
        if (!self.isValid()) return;
        ffiRenderPassEnd(self.handle.id);
    }

    pub fn isValid(self: RenderPass) bool {
        return self.handle.isValid();
    }
};

pub fn beginRenderPassForParticles(clear_color: ClearColor) RenderPass {
    const id = ffiBeginRenderPassForParticles(clear_color.r, clear_color.g, clear_color.b, clear_color.a);
    return .{ .handle = .{ .id = id } };
}

pub fn beginRenderPassHDR(texture_view: TextureViewHandle, clear_color: ClearColor) RenderPass {
    const id = ffiBeginRenderPassHDR(texture_view.id, clear_color.r, clear_color.g, clear_color.b, clear_color.a);
    return .{ .handle = .{ .id = id } };
}

// --- Texture ---

pub const TextureFormat = enum(u32) {
    rgba16float = 0,
    rgba32float = 1,
    bgra8unorm = 2,
    rgba8unorm = 3,
    rgba8unorm_srgb = 4,
    depth24plus = 5,
    depth32float = 6,

    pub fn toString(self: TextureFormat) []const u8 {
        return switch (self) {
            .rgba16float => "rgba16float",
            .rgba32float => "rgba32float",
            .bgra8unorm => "bgra8unorm",
            .rgba8unorm => "rgba8unorm",
            .rgba8unorm_srgb => "rgba8unorm-srgb",
            .depth24plus => "depth24plus",
            .depth32float => "depth32float",
        };
    }
};

pub const TextureUsage = packed struct(u32) {
    copy_src: bool = false,
    copy_dst: bool = false,
    texture_binding: bool = false,
    storage_binding: bool = false,
    render_attachment: bool = false,
    _padding: u27 = 0,

    pub fn toU32(self: TextureUsage) u32 {
        return @bitCast(self);
    }
};

pub const TextureDimension = enum(u32) {
    dimension_1d = 0,
    dimension_2d = 1,
    dimension_3d = 2,
};

pub const Texture = struct {
    handle: TextureHandle,
    width: u32,
    height: u32,
    format: TextureFormat,

    pub fn create(width: u32, height: u32, format: TextureFormat, usage: TextureUsage) Texture {
        if (!g_device.isValid()) return .{ .handle = TextureHandle.invalid(), .width = 0, .height = 0, .format = format };
        const handle_id = ffiCreateTexture(g_device.id, width, height, @intFromEnum(format), usage.toU32());
        return .{ .handle = .{ .id = handle_id }, .width = width, .height = height, .format = format };
    }

    pub fn createView(self: Texture) TextureView {
        if (!self.isValid()) return .{ .handle = TextureViewHandle.invalid(), .texture = self };
        const view_id = ffiCreateTextureView(self.handle.id);
        return .{ .handle = .{ .id = view_id }, .texture = self };
    }

    pub fn destroy(self: *Texture) void {
        if (self.isValid()) {
            ffiDestroyTexture(self.handle.id);
            self.handle = TextureHandle.invalid();
        }
    }

    pub fn isValid(self: Texture) bool {
        return self.handle.isValid();
    }
};

pub const TextureView = struct {
    handle: TextureViewHandle,
    texture: Texture,

    pub fn isValid(self: TextureView) bool {
        return self.handle.isValid();
    }
};

pub fn createHDRTexture(width: u32, height: u32) Texture {
    return Texture.create(width, height, .rgba16float, .{ .render_attachment = true, .texture_binding = true });
}

pub fn createRenderTexture(width: u32, height: u32, format: TextureFormat) Texture {
    return Texture.create(width, height, format, .{ .render_attachment = true, .texture_binding = true });
}

// --- Test Utilities ---

pub fn testing_reset_state() void {
    g_device = DeviceHandle.invalid();
}
