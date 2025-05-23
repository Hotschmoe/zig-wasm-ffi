const webutils = @import("webutils.zig");

// Opaque handles for WebGPU objects (represented as u32 IDs from JavaScript)
// pub const PromiseId = u32; // REMOVED as primary async mechanism changes
pub const Adapter = u32;
pub const Device = u32;
pub const Queue = u32;
pub const Buffer = u32;
pub const ShaderModule = u32;
pub const Texture = u32;
pub const TextureView = u32;
pub const Sampler = u32;
pub const BindGroupLayout = u32;
pub const BindGroup = u32;
pub const PipelineLayout = u32;
pub const ComputePipeline = u32;
pub const RenderPipeline = u32;
pub const CommandEncoder = u32;
pub const CommandBuffer = u32;
pub const RenderPassEncoder = u32;
pub const ComputePassEncoder = u32;
pub const QuerySet = u32;
// TODO: Add more handles: Texture, TextureView, Sampler, BindGroupLayout, PipelineLayout, RenderPipeline, ComputePipeline, BindGroup, CommandEncoder, CommandBuffer, RenderPassEncoder, ComputePassEncoder, QuerySet

// Enum for promise status - REMOVED as pollPromise is removed
// pub const PromiseStatus = enum(i32) {
//     pending = 0,
//     fulfilled = 1,
//     rejected = -1,
// };

// Enum for handle types for releasing
pub const HandleType = enum(u32) {
    // promise = 1, // REMOVED
    adapter = 2,
    device = 3,
    queue = 4,
    buffer = 5,
    shader_module = 6,
    texture = 7,
    texture_view = 8,
    sampler = 9,
    bind_group_layout = 10,
    bind_group = 11,
    pipeline_layout = 12,
    compute_pipeline = 13,
    render_pipeline = 14,
    command_encoder = 15,
    command_buffer = 16,
    render_pass_encoder = 17,
    compute_pass_encoder = 18,
    query_set = 19,
    canvas_context = 20,
    // TODO: Add other WebGPU object types here as they are introduced
};

// --- Feature Names (Spec §27.1) ---
pub const GPUFeatureName = enum(u32) {
    depth_clip_control, // "depth-clip-control"
    depth32float_stencil8, // "depth32float-stencil8"
    texture_compression_bc, // "texture-compression-bc"
    texture_compression_etc2, // "texture-compression-etc2"
    texture_compression_astc, // "texture-compression-astc"
    timestamp_query, // "timestamp-query"
    indirect_first_instance, // "indirect-first-instance"
    shader_f16, // "shader-f16"
    rg11b10ufloat_renderable, // "rg11b10ufloat-renderable"
    bgra8unorm_storage, // "bgra8unorm-storage"
    float32_filterable, // "float32-filterable"
    clip_distances, // "clip-distances" - WGSL feature
    dual_source_blending, // "dual-source-blending" - WGSL feature
    high_performance, // "high-performance"
};

pub const GPUPresentMode = enum(u32) {
    fifo = 0, // "fifo"
    fifo_relaxed = 1, // "fifo-relaxed"
    immediate = 2,    // "immediate"
    mailbox = 3,      // "mailbox"
};

// --- Canvas Types ---
pub const GPUCanvasContext = u32; // Opaque handle

pub const GPUCanvasAlphaMode = enum(u32) {
    opaque = 0,
    premultiplied = 1,
};

pub const PredefinedColorSpace = enum(u32) {
    srgb = 0, // Only "srgb" is currently widely supported
};

pub const GPUCanvasConfiguration = extern struct {
    device: Device,
    format: TextureFormat,
    usage: u32 = GPUTextureUsage.RENDER_ATTACHMENT, // Default usage
    view_formats: ?[*]const TextureFormat = null,
    view_formats_count: usize = 0,
    color_space: PredefinedColorSpace = .srgb,
    alpha_mode: GPUCanvasAlphaMode = .opaque,
};

// --- Descriptors ---

pub const BufferDescriptor = extern struct {
    label: ?[*:0]const u8,
    size: u64, // Corresponds to GPUSize64
    usage: u32, // Corresponds to GPUBufferUsageFlags (bitflags)
    mappedAtCreation: bool,

    // Helper to create a descriptor. `usage` should be a bitmask of GPUBufferUsageFlags.
    pub fn new(size_in_bytes: u64, usage_flags: u32) BufferDescriptor {
        return BufferDescriptor{
            .label = null,
            .size = size_in_bytes,
            .usage = usage_flags,
            .mappedAtCreation = false,
        };
    }

    pub fn newLabeled(label_text: ?[*:0]const u8, size_in_bytes: u64, usage_flags: u32) BufferDescriptor {
        return BufferDescriptor{
            .label = label_text,
            .size = size_in_bytes,
            .usage = usage_flags,
            .mappedAtCreation = false,
        };
    }
};

// GPUBufferUsageFlags - values should match WebGPU spec's GPUBufferUsage
// These are just examples; a full set would be needed.
pub const GPUBufferUsage = struct {
    pub const MAP_READ = 0x0001;
    pub const MAP_WRITE = 0x0002;
    pub const COPY_SRC = 0x0004;
    pub const COPY_DST = 0x0008;
    pub const INDEX = 0x0010;
    pub const VERTEX = 0x0020;
    pub const UNIFORM = 0x0040;
    pub const STORAGE = 0x0080;
    pub const INDIRECT = 0x0100;
    pub const QUERY_RESOLVE = 0x0200;
};

pub const ShaderModuleWGSLDescriptor = extern struct {
    // For now, directly pass code. Later might add entryPoints or other features.
    // Based on GPUShaderModuleDescriptor, which typically only has `code` and `label`.
    // `sourceMap` and `hints` are more advanced.
    code_ptr: [*c]const u8,
    code_len: usize,
};

pub const ShaderModuleDescriptor = extern struct {
    label: ?[*:0]const u8,
    // For now, only WGSL is directly supported in WebGPU by browsers.
    // If other shader types were supported via FFI, a tagged union or similar might be here.
    wgsl_code: ShaderModuleWGSLDescriptor,

    // DEPRECATED: newFromWGSL and newFromWGSLabeled. Use direct struct initialization.
    // pub fn newFromWGSL(wgsl_source: []const u8) ShaderModuleDescriptor {
    //     return ShaderModuleDescriptor{
    //         .label = null,
    //         .wgsl_code = ShaderModuleWGSLDescriptor{
    //             .code_ptr = wgsl_source.ptr,
    //             .code_len = wgsl_source.len,
    //         },
    //     };
    // }
    //
    // pub fn newFromWGSLabeled(label_text: ?[*:0]const u8, wgsl_source: []const u8) ShaderModuleDescriptor {
    //     return ShaderModuleDescriptor{
    //         .label = label_text,
    //         .wgsl_code = ShaderModuleWGSLDescriptor{
    //             .code_ptr = wgsl_source.ptr,
    //             .code_len = wgsl_source.len,
    //         },
    //     };
    // }
};

// Texture Related Enums and Structs (matching WebGPU spec)

/// Corresponds to GPUTextureDimension
pub const TextureDimension = enum(u32) {
    @"1d" = 0,
    @"2d" = 1,
    @"3d" = 2,
    // Removed fromStr and toJsStringId to avoid std dependency here
};

pub const GPUTextureViewDimension = enum(u32) {
    @"1d" = 0,
    @"2d" = 1,
    @"2d_array" = 2, // "2d-array"
    cube = 3,
    cube_array = 4,
    @"3d" = 5,
};

/// Corresponds to GPUTextureFormat
/// This is a partial list. Many more formats exist.
pub const TextureFormat = enum(u32) {
    // 8-bit formats
    r8unorm = 0,
    r8snorm = 1,
    r8uint = 2,
    r8sint = 3,
    // 16-bit formats
    r16uint = 4,
    r16sint = 5,
    r16float = 6,
    rg8unorm = 7,
    rg8snorm = 8,
    rg8uint = 9,
    rg8sint = 10,
    // 32-bit formats
    r32uint = 11,
    r32sint = 12,
    r32float = 13,
    rg16uint = 14,
    rg16sint = 15,
    rg16float = 16,
    rgba8unorm = 17,
    rgba8unorm_srgb = 18,
    rgba8snorm = 19,
    rgba8uint = 20,
    rgba8sint = 21,
    bgra8unorm = 22,
    bgra8unorm_srgb = 23,
    // More formats...
    rgb9e5ufloat = 24,
    rgb10a2unorm = 25,
    rg11b10ufloat = 26,
    // 64-bit formats
    rg32uint = 27,
    rg32sint = 28,
    rg32float = 29,
    rgba16uint = 30,
    rgba16sint = 31,
    rgba16float = 32,
    // 128-bit formats
    rgba32uint = 33,
    rgba32sint = 34,
    rgba32float = 35,
    // Depth/stencil formats
    stencil8 = 36,
    depth16unorm = 37,
    depth24plus = 38,
    depth24plus_stencil8 = 39,
    depth32float = 40,
    depth32float_stencil8 = 41, // If feature "depth32float-stencil8" is enabled
    depth24unorm_stencil8 = 42, // Added

    // BC compressed formats (feature: "texture-compression-bc")
    bc1_rgba_unorm = 43,
    bc1_rgba_unorm_srgb = 44,
    bc2_rgba_unorm = 45,
    bc2_rgba_unorm_srgb = 46,
    bc3_rgba_unorm = 47,
    bc3_rgba_unorm_srgb = 48,
    bc4_r_unorm = 49,
    bc4_r_snorm = 50,
    bc5_rg_unorm = 51,
    bc5_rg_snorm = 52,
    bc6h_rgb_ufloat = 53,
    bc6h_rgb_sfloat = 54,
    bc7_rgba_unorm = 55,
    bc7_rgba_unorm_srgb = 56,

    // ETC2 compressed formats (feature: "texture-compression-etc2")
    etc2_rgb8unorm = 57,
    etc2_rgb8unorm_srgb = 58,
    etc2_rgb8a1unorm = 59,
    etc2_rgb8a1unorm_srgb = 60,
    etc2_rgba8unorm = 61,
    etc2_rgba8unorm_srgb = 62,
    eac_r11unorm = 63,
    eac_r11snorm = 64,
    eac_rg11unorm = 65,
    eac_rg11snorm = 66,

    // ASTC compressed formats (feature: "texture-compression-astc")
    astc_4x4_unorm = 67,
    astc_4x4_unorm_srgb = 68,
    astc_5x4_unorm = 69,
    astc_5x4_unorm_srgb = 70,
    astc_5x5_unorm = 71,
    astc_5x5_unorm_srgb = 72,
    astc_6x5_unorm = 73,
    astc_6x5_unorm_srgb = 74,
    astc_6x6_unorm = 75,
    astc_6x6_unorm_srgb = 76,
    astc_8x5_unorm = 77,
    astc_8x5_unorm_srgb = 78,
    astc_8x6_unorm = 79,
    astc_8x6_unorm_srgb = 80,
    astc_8x8_unorm = 81,
    astc_8x8_unorm_srgb = 82,
    astc_10x5_unorm = 83,
    astc_10x5_unorm_srgb = 84,
    astc_10x6_unorm = 85,
    astc_10x6_unorm_srgb = 86,
    astc_10x8_unorm = 87,
    astc_10x8_unorm_srgb = 88,
    astc_10x10_unorm = 89,
    astc_10x10_unorm_srgb = 90,
    astc_12x10_unorm = 91,
    astc_12x10_unorm_srgb = 92,
    astc_12x12_unorm = 93,
    astc_12x12_unorm_srgb = 94,

    // Removed toJsStringId
};

pub const Extent3D = extern struct { // Corresponds to GPUExtent3DDict
    width: u32, // GPUIntegerCoordinate
    height: u32 = 1, // GPUIntegerCoordinate
    depth_or_array_layers: u32 = 1, // GPUIntegerCoordinate
};

pub const TextureDescriptor = extern struct {
    label: ?[*:0]const u8,
    size: Extent3D,
    mip_level_count: u32 = 1, // GPUIntegerCoordinate
    sample_count: u32 = 1, // GPUIntegerCoordinate
    dimension: TextureDimension = .@"2d", // GPUTextureDimension, pass as u32 id
    format: TextureFormat, // GPUTextureFormat, pass as u32 id
    usage: u32, // GPUTextureUsageFlags (bitmask)
    view_formats: ?[*]const TextureFormat = null, // Optional: Pointer to array of TextureFormat enums
    view_formats_count: usize = 0,
};

pub const GPUTextureUsage = struct { // GPUTextureUsageFlags
    pub const COPY_SRC = 0x01;
    pub const COPY_DST = 0x02;
    pub const TEXTURE_BINDING = 0x04; // aka SAMPLED
    pub const STORAGE_BINDING = 0x08;
    pub const RENDER_ATTACHMENT = 0x10;
};

/// Corresponds to GPUTextureAspect
pub const TextureAspect = enum(u32) {
    all = 0,
    stencil_only = 1,
    depth_only = 2,
    // Removed toJsStringId
};

pub const TextureViewDescriptor = extern struct {
    label: ?[*:0]const u8,
    format: ?TextureFormat = null,
    dimension: ?GPUTextureViewDimension = null, // Use the new specific enum
    aspect: TextureAspect = .all,
    base_mip_level: u32 = 0,
    mip_level_count: ?u32 = null,
    base_array_layer: u32 = 0,
    array_layer_count: ?u32 = null,
};

// Bind Group Layout Related Enums and Structs

pub const ShaderStage = extern struct { // Corresponds to GPUShaderStageFlags (bitflags)
    pub const NONE: u32 = 0;
    pub const VERTEX: u32 = 1;
    pub const FRAGMENT: u32 = 2;
    pub const COMPUTE: u32 = 4;
};

pub const BufferBindingType = enum(u32) { // Corresponds to GPUBufferBindingType
    uniform = 0,
    storage = 1,
    read_only_storage = 2,
    // JS strings: "uniform", "storage", "read-only-storage"
};

pub const BufferBindingLayout = extern struct { // Corresponds to GPUBufferBindingLayout
    type: BufferBindingType, // = .uniform,
    has_dynamic_offset: bool, // = false,
    min_binding_size: u64, // = 0, // GPUSize64
};

// Re-using TextureDimension for view_dimension for now. WebGPU spec has GPUTextureViewDimension
// which includes "1d", "2d", "2d-array", "cube", "cube-array", "3d".
// Our TextureDimension only has 1d, 2d, 3d. This might need a separate enum if advanced views are used.
pub const TextureBindingLayout = extern struct { // Corresponds to GPUTextureBindingLayout
    sample_type: TextureSampleType, // = .float,
    view_dimension: TextureDimension, // = .@"2d", // This should be TextureViewDimension type
    multisampled: bool, // = false,
};

// More specific enums needed for StorageTextureBindingLayout if used (e.g. StorageTextureAccess)
// pub const StorageTextureAccess = enum(u32) { write_only = 0, read_only = 1, read_write = 2 };
// pub const StorageTextureBindingLayout = extern struct { ... }

pub const BGLResourceType = enum(u32) {
    buffer = 0,
    texture = 1,
    sampler = 2, // Placeholder for future use
    storage_texture = 3, // Placeholder for future use
    external_texture = 4, // Placeholder for future use
};

pub const BindGroupLayoutEntry = extern struct { // Corresponds to GPUBindGroupLayoutEntry
    binding: u32, // GPUIndex32
    visibility: u32, // GPUShaderStageFlags (bitmask of ShaderStage constants)
    resource_type: BGLResourceType,
    layout: ResourceLayout,

    pub const ResourceLayout = extern union {
        buffer: BufferBindingLayout,
        texture: TextureBindingLayout,
        // sampler: SamplerBindingLayout, // TODO for later
        // storage_texture: StorageTextureBindingLayout, // TODO for later
        // external_texture: ExternalTextureBindingLayout, // TODO for later
    };

    // Convenience constructors for Zig-side usage
    pub fn newBuffer(binding_idx: u32, visibility_flags: u32, layout_details: BufferBindingLayout) BindGroupLayoutEntry {
        return .{
            .binding = binding_idx,
            .visibility = visibility_flags,
            .resource_type = .buffer,
            .layout = .{ .buffer = layout_details },
        };
    }

    pub fn newTexture(binding_idx: u32, visibility_flags: u32, layout_details: TextureBindingLayout) BindGroupLayoutEntry {
        return .{
            .binding = binding_idx,
            .visibility = visibility_flags,
            .resource_type = .texture,
            .layout = .{ .texture = layout_details },
        };
    }
    // TODO: Add constructors for sampler, storage_texture etc. when implemented
};

pub const BindGroupLayoutDescriptor = extern struct {
    label: ?[*:0]const u8 = null,
    entries: [*]const BindGroupLayoutEntry,
    entries_len: usize,
};

// Pipeline Layout
pub const PipelineLayoutDescriptor = extern struct {
    label: ?[*:0]const u8 = null,
    bind_group_layouts: [*]const BindGroupLayout,
    bind_group_layouts_len: usize,
};

// Compute Pipeline
pub const ConstantEntry = extern struct { // Corresponds to GPUConstantEntry
    key: [*:0]const u8,
    value: f64, // GPUConstantValue (double)
};

pub const ProgrammableStageDescriptor = extern struct {
    module: ShaderModule,
    entry_point: ?[*:0]const u8,
    constants: ?[*]const ConstantEntry = null, // Pointer to array of ConstantEntry
    constants_len: usize = 0,
};

pub const ComputePipelineDescriptor = extern struct {
    label: ?[*:0]const u8 = null,
    layout: ?PipelineLayout = null, // Optional: if null, auto-layout is used
    compute: ProgrammableStageDescriptor,
};

// Render Pipeline

// --- Enums for RenderPipelineDescriptor ---
pub const GPUVertexStepMode = enum(u32) { vertex = 0, instance = 1 };
pub const GPUVertexFormat = enum(u32) { // GPUVertexFormat - this is a large enum, listing a few
    uint8x2 = 0,
    uint8x4 = 1,
    sint8x2 = 2,
    sint8x4 = 3,
    unorm8x2 = 4,
    unorm8x4 = 5,
    snorm8x2 = 6,
    snorm8x4 = 7,
    uint16x2 = 8,
    uint16x4 = 9,
    sint16x2 = 10,
    sint16x4 = 11,
    unorm16x2 = 12,
    unorm16x4 = 13,
    snorm16x2 = 14,
    snorm16x4 = 15,
    float16x2 = 16,
    float16x4 = 17,
    float32 = 18,
    float32x2 = 19,
    float32x3 = 20,
    float32x4 = 21,
    uint32 = 22,
    uint32x2 = 23,
    uint32x3 = 24,
    uint32x4 = 25,
    sint32 = 26,
    sint32x2 = 27,
    sint32x3 = 28,
    sint32x4 = 29,
    // Add all other vertex formats
};
pub const GPUPrimitiveTopology = enum(u32) { point_list = 0, line_list = 1, line_strip = 2, triangle_list = 3, triangle_strip = 4 };
pub const GPUIndexFormat = enum(u32) { uint16 = 0, uint32 = 1 };
pub const GPUFrontFace = enum(u32) { ccw = 0, cw = 1 };
pub const GPUCullMode = enum(u32) { none = 0, front = 1, back = 2 };
pub const GPUCompareFunction = enum(u32) { never = 0, less = 1, equal = 2, less_equal = 3, greater = 4, not_equal = 5, greater_equal = 6, always = 7 };
pub const GPUStencilOperation = enum(u32) { keep = 0, zero = 1, replace = 2, invert = 3, increment_clamp = 4, decrement_clamp = 5, increment_wrap = 6, decrement_wrap = 7 };
pub const GPUBlendOperation = enum(u32) { add = 0, subtract = 1, reverse_subtract = 2, min = 3, max = 4 };
pub const GPUBlendFactor = enum(u32) { zero = 0, one = 1, src = 2, one_minus_src = 3, src_alpha = 4, one_minus_src_alpha = 5, dst = 6, one_minus_dst = 7, dst_alpha = 8, one_minus_dst_alpha = 9, src_alpha_saturated = 10, constant = 11, one_minus_constant = 12 };

// --- Structs for RenderPipelineDescriptor ---
pub const VertexBufferLayout = extern struct { // Corresponds to GPUVertexBufferLayout
    array_stride: u64, // GPUSize64
    step_mode: GPUVertexStepMode = .vertex,
    attributes: [*]const VertexAttribute,
    attributes_len: usize,
};

pub const VertexAttribute = extern struct { // Corresponds to GPUVertexAttribute
    format: GPUVertexFormat,
    offset: u64, // GPUSize64
    shader_location: u32, // GPUIndex32
};

pub const VertexState = extern struct { // Corresponds to GPUVertexState
    module: ShaderModule,
    entry_point: ?[*:0]const u8,
    constants: ?[*]const ConstantEntry = null,
    constants_len: usize = 0,
    buffers: ?[*]const VertexBufferLayout = null,
    buffers_len: usize = 0,
};

pub const PrimitiveState = extern struct { // Corresponds to GPUPrimitiveState
    topology: GPUPrimitiveTopology = .triangle_list,
    strip_index_format: ?GPUIndexFormat = null,
    front_face: GPUFrontFace = .ccw,
    cull_mode: GPUCullMode = .none,
    unclipped_depth: bool = false, // Requires "depth-clip-control" feature
};

pub const StencilFaceState = extern struct { // Corresponds to GPUStencilFaceState
    compare: GPUCompareFunction = .always,
    fail_op: GPUStencilOperation = .keep,
    depth_fail_op: GPUStencilOperation = .keep,
    pass_op: GPUStencilOperation = .keep,
};

pub const DepthStencilState = extern struct { // Corresponds to GPUDepthStencilState
    format: TextureFormat, // Must be a depth/stencil format
    depth_write_enabled: bool = false,
    depth_compare: GPUCompareFunction = .always,
    stencil_front: StencilFaceState = .{},
    stencil_back: StencilFaceState = .{},
    stencil_read_mask: u32 = 0xFFFFFFFF,
    stencil_write_mask: u32 = 0xFFFFFFFF,
    depth_bias: i32 = 0, // GPUDepthBias
    depth_bias_slope_scale: f32 = 0.0, // GPUSlopeScaledDepthBias
    depth_bias_clamp: f32 = 0.0,
};

// Ensure GPUStencilFaceState is defined (it should be from previous steps or needs to be added now)
// pub const GPUStencilFaceState = extern struct {
//    compare: GPUCompareFunction = .always,
//    fail_op: GPUStencilOperation = .keep,
//    depth_fail_op: GPUStencilOperation = .keep,
//    pass_op: GPUStencilOperation = .keep,
// };

// DepthStencilState was already mostly complete, just verifying.
// Defaults are handled by the user of the struct when initializing.
// pub const DepthStencilState = extern struct { // Corresponds to GPUDepthStencilState
//     format: TextureFormat, // Must be a depth/stencil format
//     depth_write_enabled: bool = false,
//     depth_compare: GPUCompareFunction = .always,
//     stencil_front: StencilFaceState = .{},
//     stencil_back: StencilFaceState = .{},
//     stencil_read_mask: u32 = 0xFFFFFFFF,
//     stencil_write_mask: u32 = 0xFFFFFFFF,
//     depth_bias: i32 = 0, // GPUDepthBias
//     depth_bias_slope_scale: f32 = 0.0, // GPUSlopeScaledDepthBias
//     depth_bias_clamp: f32 = 0.0,
// };

pub const MultisampleState = extern struct { // Corresponds to GPUMultisampleState
    count: u32 = 1,
    mask: u32 = 0xFFFFFFFF,
    alpha_to_coverage_enabled: bool = false,
};

pub const BlendComponent = extern struct { // Corresponds to GPUBlendComponent
    operation: GPUBlendOperation = .add,
    src_factor: GPUBlendFactor = .one,
    dst_factor: GPUBlendFactor = .zero,
};

pub const BlendState = extern struct { // Corresponds to GPUBlendState
    color: BlendComponent,
    alpha: BlendComponent,
};

pub const ColorWriteMask = struct { // Corresponds to GPUColorWriteFlags
    pub const RED: u32 = 0x1;
    pub const GREEN: u32 = 0x2;
    pub const BLUE: u32 = 0x4;
    pub const ALPHA: u32 = 0x8;
    pub const ALL: u32 = 0xF;
};

pub const ColorTargetState = extern struct { // Corresponds to GPUColorTargetState
    format: TextureFormat,
    blend: ?*const BlendState = null, // Pointer to BlendState
    write_mask: u32 = ColorWriteMask.ALL, // GPUColorWriteFlags
};

pub const FragmentState = extern struct { // Corresponds to GPUFragmentState
    module: ShaderModule,
    entry_point: ?[*:0]const u8,
    constants: ?[*]const ConstantEntry = null,
    constants_len: usize = 0,
    targets: [*]const ColorTargetState,
    targets_len: usize,
};

pub const RenderPipelineDescriptor = extern struct {
    label: ?[*:0]const u8 = null,
    layout: ?PipelineLayout = null,
    vertex: VertexState,
    primitive: PrimitiveState = .{},
    depth_stencil: ?*const DepthStencilState = null,
    multisample: MultisampleState = .{},
    fragment: ?*const FragmentState = null,
};

// Command Encoder
pub const CommandEncoderDescriptor = extern struct {
    label: ?[*:0]const u8 = null,
};

// Command Encoder FFI
pub extern "env" fn env_wgpu_device_create_command_encoder_js(device_handle: Device, descriptor_ptr: ?*const CommandEncoderDescriptor) callconv(.C) CommandEncoder;
pub extern "env" fn env_wgpu_command_encoder_copy_buffer_to_buffer_js(encoder_handle: CommandEncoder, source_buffer: Buffer, source_offset: u64, destination_buffer: Buffer, destination_offset: u64, size: u64) void;

// --- FFI Imports (JavaScript functions Zig will call) ---
// These functions are expected to be provided in the JavaScript 'env' object during Wasm instantiation.

// Async Init (Zig -> JS -> Zig callback)
pub extern "env" fn env_wgpu_request_adapter_js() void;
pub extern "env" fn env_wgpu_adapter_request_device_js(adapter_handle: Adapter) void;

// Synchronous Resource Creation & Operations (Zig -> JS)
pub extern "env" fn env_wgpu_device_get_queue_js(device_handle: Device) callconv(.C) Queue;
pub extern "env" fn env_wgpu_device_create_buffer_js(device_handle: Device, descriptor_ptr: *const BufferDescriptor) callconv(.C) Buffer;
pub extern "env" fn env_wgpu_queue_write_buffer_js(queue_handle: Queue, buffer_handle: Buffer, buffer_offset: u64, data_ptr: [*]const u8, data_size: usize) callconv(.C) void;
pub extern "env" fn env_wgpu_device_create_shader_module_js(device_handle: Device, descriptor_ptr: *const ShaderModuleDescriptor) callconv(.C) ShaderModule;
pub extern "env" fn env_wgpu_device_create_texture_js(device_handle: Device, descriptor_ptr: *const TextureDescriptor) callconv(.C) Texture;
pub extern "env" fn env_wgpu_texture_create_view_js(texture_handle: Texture, descriptor_ptr: ?*const TextureViewDescriptor) callconv(.C) TextureView;
pub extern "env" fn env_wgpu_device_create_bind_group_layout_js(device_handle: Device, descriptor_ptr: *const BindGroupLayoutDescriptor) callconv(.C) BindGroupLayout;
pub extern "env" fn env_wgpu_device_create_bind_group_js(device_handle: Device, descriptor_ptr: *const BindGroupDescriptor) callconv(.C) BindGroup;
pub extern "env" fn env_wgpu_device_create_pipeline_layout_js(device_handle: Device, descriptor_ptr: *const PipelineLayoutDescriptor) callconv(.C) PipelineLayout;
pub extern "env" fn env_wgpu_device_create_compute_pipeline_js(device_handle: Device, descriptor_ptr: *const ComputePipelineDescriptor) callconv(.C) ComputePipeline;
pub extern "env" fn env_wgpu_device_create_render_pipeline_js(device_handle: Device, descriptor_ptr: *const RenderPipelineDescriptor) callconv(.C) RenderPipeline;

// Canvas FFI
pub extern "env" fn env_html_canvas_get_context_js(canvas_selector_ptr: [*c]const u8, canvas_selector_len: usize) callconv(.C) GPUCanvasContext;
pub extern "env" fn env_gpu_get_preferred_canvas_format_js() callconv(.C) TextureFormat;
pub extern "env" fn env_canvas_context_configure_js(context_handle: GPUCanvasContext, config_ptr: *const GPUCanvasConfiguration) void;
pub extern "env" fn env_canvas_context_unconfigure_js(context_handle: GPUCanvasContext) void;
pub extern "env" fn env_canvas_context_get_current_texture_js(context_handle: GPUCanvasContext) callconv(.C) Texture;

// Device Lost FFI
pub extern "env" fn env_device_get_lost_promise_js(device_handle: Device) void;
pub extern "env" fn env_get_last_device_lost_message_length_js() callconv(.C) usize;
pub extern "env" fn env_copy_last_device_lost_message_js(buffer_ptr: [*c]u8, buffer_len: usize) void;

// Error Handling & Release
pub extern "env" fn env_wgpu_get_last_error_msg_ptr_js() u32;
pub extern "env" fn env_wgpu_get_last_error_msg_len_js() usize;
pub extern "env" fn env_wgpu_copy_last_error_msg_js(buffer_ptr: [*c]u8, buffer_len: usize) void;
pub extern "env" fn env_wgpu_release_handle_js(handle_type: HandleType, handle_id: u32) void;
// pub extern "env" fn js_log_string(message_ptr: [*c]const u8, message_len: usize) void; // Now in webutils directly

// --- Zig functions exported to be called by JavaScript ---
// These functions will be implemented by the application using this FFI library (e.g., in webgpu_handler.zig)
// They are declared here so the FFI user knows what signatures to provide.
// It is the responsibility of the consuming application to define these exported functions.
// We declare them here as extern to indicate they are *expected* exports for the JS side to call.
// This is a bit of a convention; Zig doesn't require declaring expected exports this way,
// but it helps document the FFI contract.
// Actual `pub export fn` definitions will be in the application code.
// For the purpose of this library, we can comment them out or make them illustrative.
// pub export fn zig_receive_adapter(adapter_handle: Adapter, status: u32) void;
// pub export fn zig_receive_device(device_handle: Device, status: u32) void;

fn simple_min(a: u32, b: u32) u32 {
    return if (a < b) a else b;
}

// Logs an error message retrieved from JS FFI into a stack buffer.
// Renamed to avoid conflict if application also has a getLastErrorMsg
pub fn getAndLogWebGPUError(prefix: []const u8) void {
    if (env_wgpu_get_last_error_msg_ptr_js() == 0) { // Check if JS has an error message prepared
        if (prefix.len > 0) {
            webutils.log(prefix);
        }
        return;
    }
    const len = env_wgpu_get_last_error_msg_len_js();
    if (len == 0) {
        if (prefix.len > 0) webutils.log(prefix);
        return;
    }

    var error_buf: [256]u8 = undefined;
    const copy_len = simple_min(len, error_buf.len - 1);

    env_wgpu_copy_last_error_msg_js(&error_buf, copy_len);

    var log_buf: [512]u8 = undefined; // Combined buffer for prefix and error message
    var current_len: usize = 0;

    if (prefix.len > 0) {
        if (prefix.len < log_buf.len - current_len) {
            @memcpy(log_buf[current_len..][0..prefix.len], prefix[0..prefix.len]);
            current_len += prefix.len;
        } else {
            webutils.log(prefix); // Prefix too long for combined buffer, log separately
            webutils.log(error_buf[0..copy_len]);
            return;
        }
    }
    // Add a separator if prefix was added and error message is not empty
    if (prefix.len > 0 and copy_len > 0) {
        if (current_len < log_buf.len - 1) {
            log_buf[current_len] = ' ';
            current_len += 1;
        }
    }

    if (copy_len > 0) {
        if (copy_len < log_buf.len - current_len) {
            @memcpy(log_buf[current_len..][0..copy_len], error_buf[0..copy_len]);
            current_len += copy_len;
        } else {
            // Error message too long for remaining space, log separately if prefix was already copied
            if (prefix.len == 0) { // If prefix wasn't an issue, then just log error_buf directly
                webutils.log(error_buf[0..copy_len]);
            } else { // Prefix was copied, log error part that didn't fit
                webutils.log(log_buf[0..current_len]); // Log what fit (prefix + space)
                webutils.log(error_buf[0..copy_len]); // Log the error message
            }
            return;
        }
    }

    webutils.log(log_buf[0..current_len]);
}

// REMOVED pollPromise function
// REMOVED genericErrorHandlerPromise function as errors are now handled in callbacks

// Initiates the request for a WebGPU Adapter.
// The result will be delivered asynchronously to the exported Zig function `zig_receive_adapter`.
pub fn requestAdapter() void {
    webutils.log("Requesting WebGPU Adapter (async via callback)...");
    env_wgpu_request_adapter_js();
}

// Initiates the request for a WebGPU Device from an Adapter.
// The result will be delivered asynchronously to the exported Zig function `zig_receive_device`.
pub fn adapterRequestDevice(adapter: Adapter) void {
    webutils.log("Requesting WebGPU Device (async via callback)...");
    if (adapter == 0) {
        // This is a synchronous error check before making the async call.
        // The application needs a way to know this immediate failure.
        // For now, we log. A robust FFI might have requestAdapter return an error for invalid params.
        webutils.log("E00: Invalid adapter handle (0) passed to adapterRequestDevice. Device request not sent.");
        // Potentially, the JS side could also check and call back with an error,
        // but an early Zig-side check is good.
        // How to signal this back to the caller in an async model without return values here?
        // The calling code must ensure valid handles, or the callback for device request will indicate an error.
        return; // Or, if the JS can handle a 0 adapter handle and call back with error, let it.
        // For now, let's assume JS will handle it or the Zig callback for device will get an error.
    }
    env_wgpu_adapter_request_device_js(adapter);
}

pub fn deviceGetQueue(device: Device) !Queue {
    webutils.log("Getting WebGPU Queue...");
    if (device == 0) {
        webutils.log("E00: Invalid device handle (0) passed to deviceGetQueue.");
        return error.QueueRetrievalFailed; // Synchronous error for invalid input
    }
    const queue_handle = env_wgpu_device_get_queue_js(device);
    if (queue_handle == 0) {
        // Assuming JS sets an error that getAndLogWebGPUError can retrieve
        getAndLogWebGPUError("E09: Failed to get queue (JS queue_handle is 0). ");
        return error.QueueRetrievalFailed;
    }
    webutils.log("Queue acquired.");
    return queue_handle;
}

pub fn deviceCreateBuffer(device_handle: Device, descriptor: *const BufferDescriptor) !Buffer {
    webutils.log("Creating WebGPU Buffer (Zig FFI wrapper)...");
    if (device_handle == 0) {
        webutils.log("E00: Invalid device handle (0) passed to deviceCreateBuffer.");
        return error.InvalidHandle;
    }
    const buffer_handle = env_wgpu_device_create_buffer_js(device_handle, descriptor);
    if (buffer_handle == 0) {
        getAndLogWebGPUError("E11: Failed to create buffer (JS buffer_handle is 0). ");
        return error.OperationFailed;
    }
    webutils.log("Buffer created.");
    return buffer_handle;
}

pub fn queueWriteBuffer(queue_handle: Queue, buffer_handle: Buffer, buffer_offset: u64, data: []const u8) !void {
    webutils.log(
        "Writing to WebGPU Buffer (Zig FFI wrapper).",
    );
    if (queue_handle == 0 or buffer_handle == 0) {
        webutils.log("E00: Invalid handle (0) for queue or buffer passed to queueWriteBuffer.");
        return error.InvalidHandle;
    }
    env_wgpu_queue_write_buffer_js(queue_handle, buffer_handle, buffer_offset, data.ptr, data.len);
    // TODO: Check for errors after write? WebGPU doesn't throw sync errors for queue ops usually.
    webutils.log("Buffer write operation submitted.");
}

pub fn deviceCreateShaderModule(device_handle: Device, descriptor: *const ShaderModuleDescriptor) !ShaderModule {
    webutils.log("Creating WebGPU Shader Module (Zig FFI wrapper)...");
    if (device_handle == 0) {
        webutils.log("E00: Invalid device handle (0) passed to deviceCreateShaderModule.");
        return error.InvalidHandle;
    }
    const sm_handle = env_wgpu_device_create_shader_module_js(device_handle, descriptor);
    if (sm_handle == 0) {
        getAndLogWebGPUError("E12: Failed to create shader module (JS sm_handle is 0). ");
        return error.OperationFailed;
    }
    webutils.log("Shader module created.");
    return sm_handle;
}

pub fn releaseHandle(handle_type: HandleType, handle: u32) void {
    if (handle == 0) return;
    // Ensure type_id for releaseHandle in JS matches this HandleType enum.
    // Note: Promise handle type was 1. Adapter is 2, Device 3, Queue 4.
    // Need to ensure JS side env_wgpu_release_handle_js expects these integer values correctly.
    const type_id_for_js: u32 = switch (handle_type) {
        // .promise => 1, // Removed
        .adapter => @intFromEnum(HandleType.adapter),
        .device => @intFromEnum(HandleType.device),
        .queue => @intFromEnum(HandleType.queue),
        .buffer => @intFromEnum(HandleType.buffer),
        .shader_module => @intFromEnum(HandleType.shader_module),
        .texture => @intFromEnum(HandleType.texture),
        .texture_view => @intFromEnum(HandleType.texture_view),
        .sampler => @intFromEnum(HandleType.sampler),
        .bind_group_layout => @intFromEnum(HandleType.bind_group_layout),
        .bind_group => @intFromEnum(HandleType.bind_group),
        .pipeline_layout => @intFromEnum(HandleType.pipeline_layout),
        .compute_pipeline => @intFromEnum(HandleType.compute_pipeline),
        .render_pipeline => @intFromEnum(HandleType.render_pipeline),
        .command_encoder => @intFromEnum(HandleType.command_encoder),
        .command_buffer => @intFromEnum(HandleType.command_buffer),
        .render_pass_encoder => @intFromEnum(HandleType.render_pass_encoder),
        .compute_pass_encoder => @intFromEnum(HandleType.compute_pass_encoder),
        .query_set => @intFromEnum(HandleType.query_set),
        .canvas_context => @intFromEnum(HandleType.canvas_context),
    };
    env_wgpu_release_handle_js(@as(HandleType, @enumFromInt(type_id_for_js)), handle);
}

// Error set for functions that can return synchronous errors
// Async operations will report errors via callbacks.
pub const GeneralWebGPUError = error{
    AdapterRequestFailed, // Might be used by application in callback
    DeviceRequestFailed, // Might be used by application in callback
    QueueRetrievalFailed,
    InvalidHandle,
    OperationFailed,
    InvalidDescriptor, // Added for descriptor validation
};

pub const DeviceLostReason = enum(u32) {
    undefined = 0,
    destroyed = 1,
};

pub const GPUDeviceLostInfo = extern struct {
    reason: DeviceLostReason,
    message: [*:0]const u8,
};

// HTMLCanvas convenience (not a direct WebGPU object, but related for setup)
// These are non-handle returning functions, direct calls.
pub const HTMLCanvas = struct {
    pub fn getContext(canvas_selector: []const u8) !GPUCanvasContext {
        webutils.log("HTMLCanvas: Getting WebGPU context (Zig FFI wrapper)...");
        if (canvas_selector.len == 0) {
            webutils.log("E00: Empty canvas selector passed to HTMLCanvas.getContext.");
            return error.InvalidSelector; // Define InvalidSelector if needed, or use InvalidHandle
        }
        const context_handle = env_html_canvas_get_context_js(canvas_selector.ptr, canvas_selector.len);
        if (context_handle == 0) {
            getAndLogWebGPUError("E25: Failed to get GPUCanvasContext (JS context_handle is 0)."); // New Error Code E25
            return error.OperationFailed;
        }
        webutils.log("GPUCanvasContext obtained.");
        return context_handle;
    }
};

// GPU global object convenience (navigator.gpu)
pub const GPU = struct {
    pub fn getPreferredCanvasFormat() !TextureFormat {
        webutils.log("GPU: Getting preferred canvas format (Zig FFI wrapper)...");
        const format_val = env_gpu_get_preferred_canvas_format_js();
        // Assuming TextureFormat enum starts at 0 and is contiguous.
        // JS will return the enum u32 value. If it's an invalid/unsupported format, JS might return a sentinel like max_u32
        // or we rely on the mapping in JS to be correct.
        // For now, directly cast. Robustness might involve checking if the value is a valid TextureFormat member.
        if (@intToEnum(TextureFormat, format_val) == .rgba8unorm and format_val != @intFromEnum(TextureFormat.rgba8unorm)) { // Basic check
             getAndLogWebGPUError("E26: Failed to get preferred canvas format or format is invalid."); // New Error Code E26
             return error.OperationFailed;
        }
        webutils.log("Preferred canvas format obtained.");
        return @intToEnum(TextureFormat, format_val);
    }
};

// GPUCanvasContext methods
pub fn canvasContextConfigure(context_handle: GPUCanvasContext, config: *const GPUCanvasConfiguration) !void {
    webutils.log("GPUCanvasContext: Configuring (Zig FFI wrapper)...");
    if (context_handle == 0) {
        webutils.log("E00: Invalid GPUCanvasContext handle (0) passed to canvasContextConfigure.");
        return error.InvalidHandle;
    }
    if (config.device == 0) {
        webutils.log("E00: Invalid device handle (0) in GPUCanvasConfiguration.");
        return error.InvalidDescriptor;
    }
    env_canvas_context_configure_js(context_handle, config);
    // Check for JS errors if env_canvas_context_configure_js can set them
    // getAndLogWebGPUError("Error during canvas context configuration: "); // Potentially
    webutils.log("GPUCanvasContext configured.");
}

pub fn canvasContextUnconfigure(context_handle: GPUCanvasContext) !void {
    webutils.log("GPUCanvasContext: Unconfiguring (Zig FFI wrapper)...");
    if (context_handle == 0) {
        webutils.log("E00: Invalid GPUCanvasContext handle (0) passed to canvasContextUnconfigure.");
        return error.InvalidHandle;
    }
    env_canvas_context_unconfigure_js(context_handle);
    webutils.log("GPUCanvasContext unconfigured.");
}

pub fn canvasContextGetCurrentTexture(context_handle: GPUCanvasContext) !Texture {
    webutils.log("GPUCanvasContext: Getting current texture (Zig FFI wrapper)...");
    if (context_handle == 0) {
        webutils.log("E00: Invalid GPUCanvasContext handle (0) passed to canvasContextGetCurrentTexture.");
        return error.InvalidHandle;
    }
    const texture_handle = env_canvas_context_get_current_texture_js(context_handle);
    if (texture_handle == 0) {
        getAndLogWebGPUError("E27: Failed to get current texture from canvas context (JS texture_handle is 0)."); // New Error Code E27
        return error.OperationFailed;
    }
    webutils.log("Current texture obtained from GPUCanvasContext.");
    return texture_handle;
}

pub fn deviceCreateTexture(device_handle: Device, descriptor: *const TextureDescriptor) !Texture {
    webutils.log("Creating WebGPU Texture (Zig FFI wrapper)...");
    if (device_handle == 0) {
        webutils.log("E00: Invalid device handle (0) passed to deviceCreateTexture.");
        return error.InvalidHandle;
    }
    const tex_handle = env_wgpu_device_create_texture_js(device_handle, descriptor);
    if (tex_handle == 0) {
        getAndLogWebGPUError("E13: Failed to create texture (JS tex_handle is 0). ");
        return error.OperationFailed;
    }
    webutils.log("Texture created.");
    return tex_handle;
}

pub fn textureCreateView(texture_handle: Texture, descriptor: ?*const TextureViewDescriptor) !TextureView {
    webutils.log("Creating WebGPU Texture View (Zig FFI wrapper)...");
    if (texture_handle == 0) {
        webutils.log("E00: Invalid texture handle (0) passed to textureCreateView.");
        return error.InvalidHandle;
    }
    const tv_handle = env_wgpu_texture_create_view_js(texture_handle, descriptor);
    if (tv_handle == 0) {
        getAndLogWebGPUError("E14: Failed to create texture view (JS tv_handle is 0). ");
        return error.OperationFailed;
    }
    webutils.log("Texture View created.");
    return tv_handle;
}

pub fn deviceCreateBindGroupLayout(device_handle: Device, descriptor: *const BindGroupLayoutDescriptor) !BindGroupLayout {
    webutils.log("Creating WebGPU BindGroupLayout (Zig FFI wrapper)...");
    if (device_handle == 0) {
        webutils.log("E00: Invalid device handle (0) passed to deviceCreateBindGroupLayout.");
        return error.InvalidHandle;
    }
    if (descriptor.entries_len > 0 and descriptor.entries == null) {
        webutils.log("E00: Invalid descriptor (null entries with non-zero length) passed to deviceCreateBindGroupLayout.");
        return error.InvalidDescriptor;
    }
    const bgl_handle = env_wgpu_device_create_bind_group_layout_js(device_handle, descriptor);
    if (bgl_handle == 0) {
        getAndLogWebGPUError("E15: Failed to create bind group layout (JS bgl_handle is 0). ");
        return error.OperationFailed;
    }
    webutils.log("BindGroupLayout created.");
    return bgl_handle;
}

pub fn deviceCreateBindGroup(device_handle: Device, descriptor: *const BindGroupDescriptor) !BindGroup {
    webutils.log("Creating WebGPU BindGroup (Zig FFI wrapper)...");
    if (device_handle == 0) {
        webutils.log("E00: Invalid device handle (0) passed to deviceCreateBindGroup.");
        return error.InvalidHandle;
    }
    if (descriptor.entries_len > 0 and descriptor.entries == null) {
        webutils.log("E00: Invalid descriptor (null entries with non-zero length) passed to deviceCreateBindGroup.");
        return error.InvalidDescriptor;
    }
    const bg_handle = env_wgpu_device_create_bind_group_js(device_handle, descriptor);
    if (bg_handle == 0) {
        getAndLogWebGPUError("E16: Failed to create bind group (JS bg_handle is 0). ");
        return error.OperationFailed;
    }
    webutils.log("BindGroup created.");
    return bg_handle;
}

pub fn deviceCreatePipelineLayout(device_handle: Device, descriptor: *const PipelineLayoutDescriptor) !PipelineLayout {
    webutils.log("Creating WebGPU PipelineLayout (Zig FFI wrapper)...");
    if (device_handle == 0) {
        webutils.log("E00: Invalid device handle (0) passed to deviceCreatePipelineLayout.");
        return error.InvalidHandle;
    }
    if (descriptor.bind_group_layouts_len > 0 and descriptor.bind_group_layouts == null) {
        webutils.log("E00: Invalid descriptor (null bind_group_layouts with non-zero length) passed to deviceCreatePipelineLayout.");
        return error.InvalidDescriptor;
    }
    const pl_handle = env_wgpu_device_create_pipeline_layout_js(device_handle, descriptor);
    if (pl_handle == 0) {
        getAndLogWebGPUError("E17: Failed to create pipeline layout (JS pl_handle is 0). "); // New Error Code E17
        return error.OperationFailed;
    }
    webutils.log("PipelineLayout created.");
    return pl_handle;
}

pub fn deviceCreateComputePipeline(device_handle: Device, descriptor: *const ComputePipelineDescriptor) !ComputePipeline {
    webutils.log("Creating WebGPU ComputePipeline (Zig FFI wrapper)...");
    if (device_handle == 0) {
        webutils.log("E00: Invalid device handle (0) passed to deviceCreateComputePipeline.");
        return error.InvalidHandle;
    }
    // Add more validation for descriptor if necessary
    if (descriptor.compute.module == 0) {
        webutils.log("E00: Invalid descriptor (compute.module is 0) passed to deviceCreateComputePipeline.");
        return error.InvalidDescriptor;
    }

    const cp_handle = env_wgpu_device_create_compute_pipeline_js(device_handle, descriptor);
    if (cp_handle == 0) {
        getAndLogWebGPUError("E18: Failed to create compute pipeline (JS cp_handle is 0). "); // New Error Code E18
        return error.OperationFailed;
    }
    webutils.log("ComputePipeline created.");
    return cp_handle;
}

pub fn deviceCreateRenderPipeline(device_handle: Device, descriptor: *const RenderPipelineDescriptor) !RenderPipeline {
    webutils.log("Creating WebGPU RenderPipeline (Zig FFI wrapper)...");
    if (device_handle == 0) {
        webutils.log("E00: Invalid device handle (0) passed to deviceCreateRenderPipeline.");
        return error.InvalidHandle;
    }
    // Add more validation for descriptor if necessary
    if (descriptor.vertex.module == 0) {
        webutils.log("E00: Invalid descriptor (vertex.module is 0) passed to deviceCreateRenderPipeline.");
        return error.InvalidDescriptor;
    }
    if (descriptor.fragment != null and descriptor.fragment.?.*.targets_len > 0 and descriptor.fragment.?.*.targets == null) {
        webutils.log("E00: Invalid descriptor (fragment.targets is null with non-zero length) passed to deviceCreateRenderPipeline.");
        return error.InvalidDescriptor;
    }

    const rp_handle = env_wgpu_device_create_render_pipeline_js(device_handle, descriptor);
    if (rp_handle == 0) {
        getAndLogWebGPUError("E19: Failed to create render pipeline (JS rp_handle is 0). "); // New Error Code E19
        return error.OperationFailed;
    }
    webutils.log("RenderPipeline created.");
    return rp_handle;
}

// New FFI Structs for BindGroup
pub const WHOLE_SIZE: u64 = 0xffffffffffffffff;

pub const BufferBinding = extern struct {
    buffer: Buffer,
    offset: u64 = 0,
    size: u64 = WHOLE_SIZE, // WGPU.BIND_BUFFER_WHOLE_SIZE - JS will handle 'undefined' if passed as a specific large u64 value or similar sentinel.
};

pub const SamplerBinding = extern struct { // Placeholder - Sampler FFI not yet defined
    sampler: Sampler,
};

pub const TextureBinding = extern struct {
    texture_view: TextureView,
};

pub const BindGroupEntry = extern struct {
    binding: u32,
    resource: Resource,

    pub const Resource = extern union {
        buffer: BufferBinding,
        sampler: SamplerBinding,
        texture: TextureBinding,
    };
};

pub const BindGroupDescriptor = extern struct {
    label: ?[*:0]const u8 = null,
    layout: BindGroupLayout,
    entries: [*]const BindGroupEntry,
    entries_len: usize,
};

pub const TextureSampleType = enum(u32) { // Corresponds to GPUTextureSampleType
    float = 0,
    unfilterable_float = 1,
    depth = 2,
    sint = 3,
    uint = 4,
    // JS strings: "float", "unfilterable-float", "depth", "sint", "uint"
};

pub fn deviceCreateCommandEncoder(device_handle: Device, descriptor: ?*const CommandEncoderDescriptor) !CommandEncoder {
    webutils.log("Creating WebGPU CommandEncoder (Zig FFI wrapper)...");
    if (device_handle == 0) {
        webutils.log("E00: Invalid device handle (0) passed to deviceCreateCommandEncoder.");
        return error.InvalidHandle;
    }
    const ce_handle = env_wgpu_device_create_command_encoder_js(device_handle, descriptor);
    if (ce_handle == 0) {
        getAndLogWebGPUError("E20: Failed to create command encoder (JS ce_handle is 0). "); // New Error Code E20
        return error.OperationFailed;
    }
    webutils.log("CommandEncoder created.");
    return ce_handle;
}

pub fn commandEncoderCopyBufferToBuffer(encoder: CommandEncoder, source_buffer: Buffer, source_offset: u64, destination_buffer: Buffer, destination_offset: u64, size: u64) void {
    // No return value, so no !error. Errors would be via uncaptured device errors or validation layers.
    webutils.log("CommandEncoder: CopyBufferToBuffer...");
    if (encoder == 0) {
        webutils.log("E00: Invalid command encoder handle (0) for copyBufferToBuffer.");
        return;
    }
    if (source_buffer == 0 or destination_buffer == 0) {
        webutils.log("E00: Invalid buffer handle (0) for copyBufferToBuffer source or destination.");
        return;
    }
    env_wgpu_command_encoder_copy_buffer_to_buffer_js(encoder, source_buffer, source_offset, destination_buffer, destination_offset, size);
}

// Compute Pass
pub const ComputePassTimestampWrite = extern struct { // Corresponds to GPUComputePassTimestampWrite
    query_set: QuerySet,
    query_index: u32, // GPUSize32
    location: enum(u32) { beginning = 0, end = 1 }, // GPUComputePassTimestampLocation
};

pub const ComputePassDescriptor = extern struct {
    label: ?[*:0]const u8 = null,
    timestamp_writes: ?[*]const ComputePassTimestampWrite = null,
    timestamp_writes_len: usize = 0,
};

pub const ComputePassTimestampLocation = enum(u32) { // Added as it was missing
    beginning,
    end,
};

// Compute Pass FFI
pub extern "env" fn env_wgpu_command_encoder_begin_compute_pass_js(encoder_handle: CommandEncoder, descriptor_ptr: ?*const ComputePassDescriptor) callconv(.C) ComputePassEncoder;
pub extern "env" fn env_wgpu_compute_pass_encoder_set_pipeline_js(pass_handle: ComputePassEncoder, pipeline_handle: ComputePipeline) void;
pub extern "env" fn env_wgpu_compute_pass_encoder_set_bind_group_js(pass_handle: ComputePassEncoder, index: u32, bind_group_handle: BindGroup, dynamic_offsets_data_ptr: ?[*]const u32, dynamic_offsets_data_start: usize, dynamic_offsets_data_length: usize) void;
pub extern "env" fn env_wgpu_compute_pass_encoder_dispatch_workgroups_js(pass_handle: ComputePassEncoder, workgroup_count_x: u32, workgroup_count_y: u32, workgroup_count_z: u32) void;
pub extern "env" fn env_wgpu_compute_pass_encoder_dispatch_workgroups_indirect_js(pass_handle: ComputePassEncoder, indirect_buffer_handle: Buffer, indirect_offset: u64) void;
pub extern "env" fn env_wgpu_compute_pass_encoder_write_timestamp_js(pass_handle: ComputePassEncoder, query_set_handle: QuerySet, query_index: u32) void; // Simplified: location is handled by having separate begin/end pass timestamp_writes array in descriptor
pub extern "env" fn env_wgpu_compute_pass_encoder_end_js(pass_handle: ComputePassEncoder) void;

pub fn commandEncoderBeginComputePass(encoder_handle: CommandEncoder, descriptor: ?*const ComputePassDescriptor) !ComputePassEncoder {
    webutils.log("CommandEncoder: Beginning Compute Pass (Zig FFI wrapper)...");
    if (encoder_handle == 0) {
        webutils.log("E00: Invalid command encoder handle (0) passed to commandEncoderBeginComputePass.");
        return error.InvalidHandle;
    }
    const pass_handle = env_wgpu_command_encoder_begin_compute_pass_js(encoder_handle, descriptor);
    if (pass_handle == 0) {
        getAndLogWebGPUError("E21: Failed to begin compute pass (JS pass_handle is 0). "); // New Error Code E21
        return error.OperationFailed;
    }
    webutils.log("ComputePassEncoder created.");
    return pass_handle;
}

pub fn computePassEncoderSetPipeline(pass_handle: ComputePassEncoder, pipeline_handle: ComputePipeline) void {
    webutils.log("ComputePassEncoder: SetPipeline...");
    if (pass_handle == 0 or pipeline_handle == 0) {
        webutils.log("E00: Invalid handle (0) for compute pass or pipeline in setPipeline.");
        return;
    }
    env_wgpu_compute_pass_encoder_set_pipeline_js(pass_handle, pipeline_handle);
}

pub fn computePassEncoderSetBindGroup(pass_handle: ComputePassEncoder, index: u32, bind_group_handle: BindGroup, dynamic_offsets: ?[]const u32) void {
    webutils.log("ComputePassEncoder: SetBindGroup...");
    if (pass_handle == 0 or bind_group_handle == 0) {
        webutils.log("E00: Invalid handle (0) for compute pass or bind group in setBindGroup.");
        return;
    }
    var data_ptr: ?[*]const u32 = null;
    const data_start: usize = 0;
    var data_length: usize = 0;
    if (dynamic_offsets) |offsets| {
        if (offsets.len > 0) {
            data_ptr = offsets.ptr;
            data_length = offsets.len;
            // data_start is typically used if the slice is a sub-slice of a larger allocation,
            // but JS side usually expects just ptr and length from a new Uint32Array view.
            // For simplicity, if we pass offsets.ptr, JS will read from that start.
            // The JS side will receive this as pointer to u32 and length of u32s.
        }
    }
    env_wgpu_compute_pass_encoder_set_bind_group_js(pass_handle, index, bind_group_handle, data_ptr, data_start, data_length);
}

pub fn computePassEncoderDispatchWorkgroups(pass_handle: ComputePassEncoder, count_x: u32, count_y: u32, count_z: u32) void {
    webutils.log("ComputePassEncoder: DispatchWorkgroups...");
    if (pass_handle == 0) {
        webutils.log("E00: Invalid compute pass handle (0) in dispatchWorkgroups.");
        return;
    }
    env_wgpu_compute_pass_encoder_dispatch_workgroups_js(pass_handle, count_x, count_y, count_z);
}

pub fn computePassEncoderDispatchWorkgroupsIndirect(pass_handle: ComputePassEncoder, indirect_buffer: Buffer, indirect_offset: u64) void {
    webutils.log("ComputePassEncoder: DispatchWorkgroupsIndirect...");
    if (pass_handle == 0 or indirect_buffer == 0) {
        webutils.log("E00: Invalid handle (0) for pass or indirect_buffer in dispatchWorkgroupsIndirect.");
        return;
    }
    env_wgpu_compute_pass_encoder_dispatch_workgroups_indirect_js(pass_handle, indirect_buffer, indirect_offset);
}

pub fn computePassEncoderWriteTimestamp(pass_handle: ComputePassEncoder, query_set: QuerySet, query_index: u32) void {
    webutils.log("ComputePassEncoder: WriteTimestamp...");
    if (pass_handle == 0 or query_set == 0) {
        webutils.log("E00: Invalid handle (0) for pass or query_set in writeTimestamp.");
        return;
    }
    // Note: The actual WebGPU API is `writeTimestamp(querySet, queryIndex)`.
    // The `location` ('beginning'/'end') is part of the `ComputePassDescriptor.timestampWrites` array.
    // The JS FFI `env_wgpu_compute_pass_encoder_write_timestamp_js` is simplified here
    // as it's only called if timestampWrites are present in the descriptor. The particle_sim.html example
    // uses timestampWrites in the descriptor rather than calling an explicit writeTimestamp on the encoder.
    // For parity, we will assume the JS side handles this based on the descriptor.
    // However, if particle_sim.html directly calls pass.writeTimestamp(), this FFI needs adjustment,
    // and the JS implementation will need to call the underlying encoder.writeTimestamp directly.
    // `particle_sim.html` uses `timestampWrites` in `beginComputePass`'s descriptor.
    // So, this specific FFI function `env_wgpu_compute_pass_encoder_write_timestamp_js` might not be directly called
    // by the Zig wrapper if all timestamps are handled via descriptor. Let's keep it for completeness
    // in case a user wants to call it explicitly outside the descriptor mechanism.
    env_wgpu_compute_pass_encoder_write_timestamp_js(pass_handle, query_set, query_index);
}

pub fn computePassEncoderEnd(pass_handle: ComputePassEncoder) void {
    webutils.log("ComputePassEncoder: EndPass...");
    if (pass_handle == 0) {
        webutils.log("E00: Invalid compute pass handle (0) in endPass.");
        return;
    }
    env_wgpu_compute_pass_encoder_end_js(pass_handle);
    // After end, the handle is invalid. JS side should release it.
    // Or we can call releaseHandle here explicitly if JS doesn't auto-release on end.
    // WebGPU spec implies pass encoder is consumed by end(). JS side should nullify its stored handle.
}

// Render Pass
pub const GPULoadOp = enum(u32) {
    load = 0,
    clear = 1,
};

pub const GPUStoreOp = enum(u32) {
    store = 0,
    discard = 1,
};

pub const Color = extern struct { // Corresponds to GPUColor { r: f64, g: f64, b: f64, a: f64 }
    r: f64,
    g: f64,
    b: f64,
    a: f64,
};

pub const RenderPassColorAttachment = extern struct { // Corresponds to GPURenderPassColorAttachment
    view: TextureView,
    resolve_target: ?TextureView = null,
    clear_value: ?*const Color = null,
    load_op: GPULoadOp,
    store_op: GPUStoreOp,
};

pub const RenderPassDepthStencilAttachment = extern struct { // Corresponds to GPURenderPassDepthStencilAttachment
    view: TextureView,
    // Fields for depth/stencil clear values, load/store ops, read-only flags would go here.
    // Simplified for now as particle_sim.html doesn't use them directly in its RenderPassDescriptor.
    // For a full FFI, these would be:
    // depth_clear_value: ?f32 = null,
    // depth_load_op: ?GPULoadOp = null,
    // depth_store_op: ?GPUStoreOp = null,
    // depth_read_only: bool = false, // Consider how bools are passed (u8 or u32)
    // stencil_clear_value: ?u32 = null,
    // stencil_load_op: ?GPULoadOp = null,
    // stencil_store_op: ?GPUStoreOp = null,
    // stencil_read_only: bool = false,
};

pub const RenderPassTimestampWrites = extern struct { // Corresponds to GPURenderPassTimestampWrites
    query_set: QuerySet,
    beginning_of_pass_write_index: ?u32 = null,
    end_of_pass_write_index: ?u32 = null,
};

pub const RenderPassDescriptor = extern struct {
    label: ?[*:0]const u8 = null,
    color_attachments: [*]const RenderPassColorAttachment,
    color_attachments_len: usize,
    depth_stencil_attachment: ?*const RenderPassDepthStencilAttachment = null,
    occlusion_query_set: ?QuerySet = null,
    timestamp_writes: ?*const RenderPassTimestampWrites = null, // This struct name matches spec
};

// RenderPassTimestampWrites struct itself was correct as per spec (QuerySet, optional beginning/end indices)
// pub const RenderPassTimestampWrites = extern struct { 
//     query_set: QuerySet,
//     beginning_of_pass_write_index: ?u32 = null, // Optional GPUSize32
//     end_of_pass_write_index: ?u32 = null,     // Optional GPUSize32
// };
// No change needed for RenderPassTimestampWrites struct definition, it's already correct.

pub extern "env" fn env_wgpu_command_encoder_begin_render_pass_js(encoder_handle: CommandEncoder, descriptor_ptr: *const RenderPassDescriptor) callconv(.C) RenderPassEncoder;
pub extern "env" fn env_wgpu_render_pass_encoder_set_pipeline_js(pass_handle: RenderPassEncoder, pipeline_handle: RenderPipeline) void;
pub extern "env" fn env_wgpu_render_pass_encoder_set_bind_group_js(pass_handle: RenderPassEncoder, index: u32, bind_group_handle: BindGroup, dynamic_offsets_data_ptr: ?[*]const u32, dynamic_offsets_data_start: usize, dynamic_offsets_data_length: usize) void;
pub extern "env" fn env_wgpu_render_pass_encoder_set_vertex_buffer_js(pass_handle: RenderPassEncoder, slot: u32, buffer_handle: ?Buffer, offset: u64, size: u64) void;
pub extern "env" fn env_wgpu_render_pass_encoder_set_index_buffer_js(pass_handle: RenderPassEncoder, buffer_handle: Buffer, index_format: GPUIndexFormat, offset: u64, size: u64) void;
pub extern "env" fn env_wgpu_render_pass_encoder_draw_js(pass_handle: RenderPassEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void;
pub extern "env" fn env_wgpu_render_pass_encoder_draw_indexed_js(pass_handle: RenderPassEncoder, index_count: u32, instance_count: u32, first_index: u32, base_vertex: i32, first_instance: u32) void;
pub extern "env" fn env_wgpu_render_pass_encoder_draw_indirect_js(pass_handle: RenderPassEncoder, indirect_buffer_handle: Buffer, indirect_offset: u64) void;
pub extern "env" fn env_wgpu_render_pass_encoder_draw_indexed_indirect_js(pass_handle: RenderPassEncoder, indirect_buffer_handle: Buffer, indirect_offset: u64) void;
pub extern "env" fn env_wgpu_render_pass_encoder_write_timestamp_js(pass_handle: RenderPassEncoder, query_set_handle: QuerySet, query_index: u32) void;
pub extern "env" fn env_wgpu_render_pass_encoder_end_js(pass_handle: RenderPassEncoder) void;

pub fn commandEncoderBeginRenderPass(encoder_handle: CommandEncoder, descriptor: *const RenderPassDescriptor) !RenderPassEncoder {
    webutils.log("CommandEncoder: Beginning Render Pass (Zig FFI wrapper)...");
    if (encoder_handle == 0) {
        webutils.log("E00: Invalid command encoder handle (0) passed to commandEncoderBeginRenderPass.");
        return error.InvalidHandle;
    }
    if (descriptor.color_attachments_len > 0 and descriptor.color_attachments == null) {
        webutils.log("E00: Invalid RenderPassDescriptor (null color_attachments with non-zero length).");
        return error.InvalidDescriptor;
    }
    const pass_handle = env_wgpu_command_encoder_begin_render_pass_js(encoder_handle, descriptor);
    if (pass_handle == 0) {
        getAndLogWebGPUError("E22: Failed to begin render pass (JS pass_handle is 0).");
        return error.OperationFailed;
    }
    webutils.log("RenderPassEncoder created.");
    return pass_handle;
}

pub fn renderPassEncoderSetPipeline(pass_handle: RenderPassEncoder, pipeline_handle: RenderPipeline) void {
    webutils.log("RenderPassEncoder: SetPipeline...");
    if (pass_handle == 0 or pipeline_handle == 0) {
        webutils.log("E00: Invalid handle (0) for render pass or pipeline in setPipeline.");
        return;
    }
    env_wgpu_render_pass_encoder_set_pipeline_js(pass_handle, pipeline_handle);
}

pub fn renderPassEncoderSetBindGroup(pass_handle: RenderPassEncoder, index: u32, bind_group_handle: BindGroup, dynamic_offsets: ?[]const u32) void {
    webutils.log("RenderPassEncoder: SetBindGroup...");
    if (pass_handle == 0 or bind_group_handle == 0) {
        webutils.log("E00: Invalid handle (0) for render pass or bind group in setBindGroup.");
        return;
    }
    var data_ptr: ?[*]const u32 = null;
    const data_start: usize = 0;
    var data_length: usize = 0;
    if (dynamic_offsets) |offsets| {
        if (offsets.len > 0) {
            data_ptr = offsets.ptr;
            data_length = offsets.len;
        }
    }
    env_wgpu_render_pass_encoder_set_bind_group_js(pass_handle, index, bind_group_handle, data_ptr, data_start, data_length);
}

pub fn renderPassEncoderSetVertexBuffer(pass_handle: RenderPassEncoder, slot: u32, buffer_handle: ?Buffer, offset: u64, size: u64) void {
    webutils.log("RenderPassEncoder: SetVertexBuffer...");
    if (pass_handle == 0) {
        webutils.log("E00: Invalid render pass handle (0) in setVertexBuffer.");
        return;
    }
    env_wgpu_render_pass_encoder_set_vertex_buffer_js(pass_handle, slot, buffer_handle, offset, size);
}

pub fn renderPassEncoderSetIndexBuffer(pass_handle: RenderPassEncoder, buffer_handle: Buffer, index_format: GPUIndexFormat, offset: u64, size: u64) void {
    webutils.log("RenderPassEncoder: SetIndexBuffer...");
    if (pass_handle == 0 or buffer_handle == 0) {
        webutils.log("E00: Invalid handle (0) for render pass or buffer in setIndexBuffer.");
        return;
    }
    env_wgpu_render_pass_encoder_set_index_buffer_js(pass_handle, buffer_handle, index_format, offset, size);
}

pub fn renderPassEncoderDraw(pass_handle: RenderPassEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
    webutils.log("RenderPassEncoder: Draw...");
    if (pass_handle == 0) {
        webutils.log("E00: Invalid render pass handle (0) in draw.");
        return;
    }
    env_wgpu_render_pass_encoder_draw_js(pass_handle, vertex_count, instance_count, first_vertex, first_instance);
}

pub fn renderPassEncoderDrawIndexed(pass_handle: RenderPassEncoder, index_count: u32, instance_count: u32, first_index: u32, base_vertex: i32, first_instance: u32) void {
    webutils.log("RenderPassEncoder: DrawIndexed...");
    if (pass_handle == 0) {
        webutils.log("E00: Invalid render pass handle (0) in drawIndexed.");
        return;
    }
    env_wgpu_render_pass_encoder_draw_indexed_js(pass_handle, index_count, instance_count, first_index, base_vertex, first_instance);
}

pub fn renderPassEncoderDrawIndirect(pass_handle: RenderPassEncoder, indirect_buffer: Buffer, indirect_offset: u64) void {
    webutils.log("RenderPassEncoder: DrawIndirect...");
    if (pass_handle == 0 or indirect_buffer == 0) {
        webutils.log("E00: Invalid handle (0) for pass or indirect_buffer in drawIndirect.");
        return;
    }
    env_wgpu_render_pass_encoder_draw_indirect_js(pass_handle, indirect_buffer, indirect_offset);
}

pub fn renderPassEncoderDrawIndexedIndirect(pass_handle: RenderPassEncoder, indirect_buffer: Buffer, indirect_offset: u64) void {
    webutils.log("RenderPassEncoder: DrawIndexedIndirect...");
    if (pass_handle == 0 or indirect_buffer == 0) {
        webutils.log("E00: Invalid handle (0) for pass or indirect_buffer in drawIndexedIndirect.");
        return;
    }
    env_wgpu_render_pass_encoder_draw_indexed_indirect_js(pass_handle, indirect_buffer, indirect_offset);
}

pub fn renderPassEncoderWriteTimestamp(pass_handle: RenderPassEncoder, query_set: QuerySet, query_index: u32) void {
    webutils.log("RenderPassEncoder: WriteTimestamp...");
    if (pass_handle == 0 or query_set == 0) {
        webutils.log("E00: Invalid handle (0) for pass or query_set in writeTimestamp.");
        return;
    }
    env_wgpu_render_pass_encoder_write_timestamp_js(pass_handle, query_set, query_index);
}

pub fn renderPassEncoderEnd(pass_handle: RenderPassEncoder) void {
    webutils.log("RenderPassEncoder: EndPass...");
    if (pass_handle == 0) {
        webutils.log("E00: Invalid render pass handle (0) in endPass.");
        return;
    }
    env_wgpu_render_pass_encoder_end_js(pass_handle);
}

// Command Buffer
pub const CommandBufferDescriptor = extern struct {
    label: ?[*:0]const u8 = null,
};

// Command Finishing & Queue Submission FFI
pub extern "env" fn env_wgpu_command_encoder_finish_js(encoder_handle: CommandEncoder, descriptor_ptr: ?*const CommandBufferDescriptor) callconv(.C) CommandBuffer;
pub extern "env" fn env_wgpu_queue_submit_js(queue_handle: Queue, command_buffers_ptr: [*]const CommandBuffer, command_buffers_len: usize) void;
pub extern "env" fn env_wgpu_queue_on_submitted_work_done_js(queue_handle: Queue) void; // New

pub fn commandEncoderFinish(encoder_handle: CommandEncoder, descriptor: ?*const CommandBufferDescriptor) !CommandBuffer {
    webutils.log("CommandEncoder: Finish (Zig FFI wrapper)...");
    if (encoder_handle == 0) {
        webutils.log("E00: Invalid command encoder handle (0) passed to commandEncoderFinish.");
        return error.InvalidHandle;
    }
    const cb_handle = env_wgpu_command_encoder_finish_js(encoder_handle, descriptor);
    if (cb_handle == 0) {
        getAndLogWebGPUError("E23: Failed to finish command encoder (JS cb_handle is 0)."); // New Error Code E23
        return error.OperationFailed;
    }
    webutils.log("CommandBuffer created (from finish).");
    // JS side should release the command encoder handle as it's consumed by finish()
    return cb_handle;
}

pub fn queueSubmit(queue_handle: Queue, command_buffers: []const CommandBuffer) void {
    webutils.log("Queue: Submit (Zig FFI wrapper)...");
    if (queue_handle == 0) {
        webutils.log("E00: Invalid queue handle (0) passed to queueSubmit.");
        return;
    }
    if (command_buffers.len == 0) {
        webutils.log("W01: No command buffers passed to queueSubmit. Nothing to do.");
        return;
    }
    for (command_buffers) |cb_handle| {
        if (cb_handle == 0) {
            webutils.log("E00: Invalid command buffer handle (0) in list passed to queueSubmit.");
            return; // Or handle error more gracefully, e.g. skip invalid ones
        }
    }
    env_wgpu_queue_submit_js(queue_handle, command_buffers.ptr, command_buffers.len);
    // Submitted command buffers are consumed and should be released if not already by JS.
    // For now, assume JS handles release of command buffers if they are single-use from JS perspective.
}

pub fn queueOnSubmittedWorkDone(queue_handle: Queue) void {
    webutils.log("Queue: OnSubmittedWorkDone (Zig FFI wrapper). Will call Zig export 'zig_on_queue_work_done' upon completion...");
    if (queue_handle == 0) {
        webutils.log("E00: Invalid queue handle (0) passed to queueOnSubmittedWorkDone. Callback will not be invoked.");
        // Optionally, could immediately call the Zig callback with an error status if desired.
        // globalWebGPU.wasmExports.zig_on_queue_work_done(queue_handle, 0); // Example if JS side had direct access to wasmExports
        return;
    }
    env_wgpu_queue_on_submitted_work_done_js(queue_handle);
}

// AFTER existing GPUCompareFunction enum
pub const GPUAddressMode = enum(u32) { clamp_to_edge = 0, repeat = 1, mirror_repeat = 2 };
pub const GPUFilterMode = enum(u32) { nearest = 0, linear = 1 };
pub const GPUMipmapFilterMode = enum(u32) { nearest = 0, linear = 1 };

// AFTER RenderPassDescriptor struct
pub const SamplerDescriptor = extern struct {
    label: ?[*:0]const u8 = null,
    address_mode_u: GPUAddressMode = .clamp_to_edge,
    address_mode_v: GPUAddressMode = .clamp_to_edge,
    address_mode_w: GPUAddressMode = .clamp_to_edge,
    mag_filter: GPUFilterMode = .nearest,
    min_filter: GPUFilterMode = .nearest,
    mipmap_filter: GPUMipmapFilterMode = .nearest,
    lod_min_clamp: f32 = 0.0,
    lod_max_clamp: f32 = 32.0,
    compare: ?GPUCompareFunction = null, // Optional: only for comparison samplers
    max_anisotropy: u16 = 1, // GPUSize16, typically 1 or higher if anisotropic filtering is used.
};

// AFTER existing FFI externs for queue operations
// pub extern "env" fn env_wgpu_queue_on_submitted_work_done_js(queue_handle: Queue) void;
pub extern "env" fn env_wgpu_device_create_sampler_js(device_handle: Device, descriptor_ptr: ?*const SamplerDescriptor) callconv(.C) Sampler;

// AFTER deviceCreateRenderPipeline Zig wrapper function
pub fn deviceCreateSampler(device_handle: Device, descriptor: ?*const SamplerDescriptor) !Sampler {
    webutils.log("Creating WebGPU Sampler (Zig FFI wrapper)...");
    if (device_handle == 0) {
        webutils.log("E00: Invalid device handle (0) passed to deviceCreateSampler.");
        return error.InvalidHandle;
    }
    // descriptor can be null for default sampler settings
    const sampler_handle = env_wgpu_device_create_sampler_js(device_handle, descriptor);
    if (sampler_handle == 0) {
        getAndLogWebGPUError("E24: Failed to create sampler (JS sampler_handle is 0)."); // New Error Code E24
        return error.OperationFailed;
    }
    webutils.log("Sampler created.");
    return sampler_handle;
}

pub fn deviceWatchLost(device_handle: Device) void {
    env_device_get_lost_promise_js(device_handle);
}
