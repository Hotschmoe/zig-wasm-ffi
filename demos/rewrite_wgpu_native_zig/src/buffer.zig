const _misc = @import("misc.zig");
const WGPUBool = _misc.WGPUBool;
const WGPUFlags = _misc.WGPUFlags;
const StringView = _misc.StringView;
const USIZE_MAX = _misc.USIZE_MAX;


pub const WGPU_WHOLE_MAP_SIZE = USIZE_MAX;

const _async = @import("async.zig");
const CallbackMode = _async.CallbackMode;
const Future = _async.Future;

const ChainedStruct = @import("chained_struct.zig").ChainedStruct;

pub const BufferBindingType = enum(u32) {
    binding_not_used  = 0x00000000, // Indicates that this BufferBindingLayout member of its parent BindGroupLayoutEntry is not used.
    @"undefined"      = 0x00000001, // Indicates no value is passed for this argument
    uniform           = 0x00000002,
    storage           = 0x00000003,
    read_only_storage = 0x00000004,
};

pub const BufferBindingLayout = extern struct {
    next_in_chain: ?*const ChainedStruct = null,
    @"type": BufferBindingType = BufferBindingType.@"undefined",
    has_dynamic_offset: WGPUBool = @intFromBool(false),
    min_binding_size: u64 = 0,
};

pub const BufferUsage = WGPUFlags;
pub const BufferUsages = struct {
    pub const none          = @as(BufferUsage, 0x0000000000000000);
    pub const map_read      = @as(BufferUsage, 0x0000000000000001);
    pub const map_write     = @as(BufferUsage, 0x0000000000000002);
    pub const copy_src      = @as(BufferUsage, 0x0000000000000004);
    pub const copy_dst      = @as(BufferUsage, 0x0000000000000008);
    pub const index         = @as(BufferUsage, 0x0000000000000010);
    pub const vertex        = @as(BufferUsage, 0x0000000000000020);
    pub const uniform       = @as(BufferUsage, 0x0000000000000040);
    pub const storage       = @as(BufferUsage, 0x0000000000000080);
    pub const indirect      = @as(BufferUsage, 0x0000000000000100);
    pub const query_resolve = @as(BufferUsage, 0x0000000000000200);
};

pub const BufferMapState = enum(u32) {
    unmapped = 0x00000001,
    pending  = 0x00000002,
    mapped   = 0x00000003,
};

pub const MapMode = WGPUFlags;
pub const MapModes = struct {
    pub const none  = @as(MapMode, 0x0000000000000000);
    pub const read  = @as(MapMode, 0x0000000000000001);
    pub const write = @as(MapMode, 0x0000000000000002);
};

pub const MapAsyncStatus = enum(u32) {
    success          = 0x00000001,
    instance_dropped = 0x00000002,
    @"error"         = 0x00000003,
    aborted          = 0x00000004,
    unknown          = 0x00000005,
};

pub const BufferMapCallbackInfo = extern struct {
    next_in_chain: ?*ChainedStruct = null,

    // TODO: Revisit this default if/when Instance.waitAny() is implemented.
    mode: CallbackMode = CallbackMode.allow_process_events,

    callback: BufferMapCallback,
    userdata1: ?*anyopaque = null,
    userdata2: ?*anyopaque = null,
};

pub const BufferMapCallback = *const fn(status: MapAsyncStatus, message: StringView, userdata1: ?*anyopaque, userdata2: ?*anyopaque) callconv(.C) void;

pub const BufferDescriptor = extern struct {
    next_in_chain: ?*const ChainedStruct = null,
    label: StringView = StringView {},
    usage: BufferUsage,
    size: u64,
    mapped_at_creation: WGPUBool = @intFromBool(false),
};

pub const BufferProcs = struct {
    pub const Destroy = *const fn(*Buffer) callconv(.C) void;
    pub const GetConstMappedRange = *const fn(*Buffer, usize, usize) callconv(.C) ?*const anyopaque;
    pub const GetMapState = *const fn(*Buffer) callconv(.C) BufferMapState;
    pub const GetMappedRange = *const fn(*Buffer, usize, usize) callconv(.C) ?*anyopaque;
    pub const GetSize = *const fn(*Buffer) callconv(.C) u64;
    pub const GetUsage = *const fn(*Buffer) callconv(.C) BufferUsage;
    pub const MapAsync = *const fn(*Buffer, MapMode, usize, usize, BufferMapCallbackInfo) callconv(.C) Future;
    pub const SetLabel = *const fn(*Buffer, ?[*:0]const u8) callconv(.C) void;
    pub const Unmap = *const fn(*Buffer) callconv(.C) void;
    pub const AddRef = *const fn(*Buffer) callconv(.C) void;
    pub const Release = *const fn(*Buffer) callconv(.C) void;
};

extern fn wgpuBufferDestroy(buffer: *Buffer) void;
extern fn wgpuBufferGetConstMappedRange(buffer: *Buffer, offset: usize, size: usize) ?*const anyopaque;
extern fn wgpuBufferGetMapState(buffer: *Buffer) BufferMapState;
extern fn wgpuBufferGetMappedRange(buffer: *Buffer, offset: usize, size: usize) ?*anyopaque;
extern fn wgpuBufferGetSize(buffer: *Buffer) u64;
extern fn wgpuBufferGetUsage(buffer: *Buffer) BufferUsage;
extern fn wgpuBufferMapAsync(buffer: *Buffer, mode: MapMode, offset: usize, size: usize, callback_info: BufferMapCallbackInfo) Future;
extern fn wgpuBufferSetLabel(buffer: *Buffer, label: ?[*:0]const u8) void;
extern fn wgpuBufferUnmap(buffer: *Buffer) void;
extern fn wgpuBufferAddRef(buffer: *Buffer) void;
extern fn wgpuBufferRelease(buffer: *Buffer) void;

pub const Buffer = opaque {
    pub inline fn destroy(self: *Buffer) void {
        wgpuBufferDestroy(self);
    }
    // wgpu-native translates a size of WGPU_WHOLE_MAP_SIZE to "None" internally
    pub inline fn getConstMappedRange(self: *Buffer, offset: usize, size: usize) ?*const anyopaque {
        return wgpuBufferGetConstMappedRange(self, offset, size);
    }
    pub inline fn getMapState(self: *Buffer) BufferMapState {
        return wgpuBufferGetMapState(self);
    }
    // wgpu-native translates a size of WGPU_WHOLE_MAP_SIZE to "None" internally
    pub inline fn getMappedRange(self: *Buffer, offset: usize, size: usize) ?*anyopaque {
        return wgpuBufferGetMappedRange(self, offset, size);
    }
    pub inline fn getSize(self: *Buffer) u64 {
        return wgpuBufferGetSize(self);
    }
    pub inline fn getUsage(self: *Buffer) BufferUsage {
        return wgpuBufferGetUsage(self);
    }

    pub inline fn mapAsync(self: *Buffer, mode: MapMode, offset: usize, size: usize, callback_info: BufferMapCallbackInfo) Future {
        return wgpuBufferMapAsync(self, mode, offset, size, callback_info);
    }

    pub inline fn setLabel(self: *Buffer, label: ?[*:0]const u8) void {
        wgpuBufferSetLabel(self, label);
    }
    pub inline fn unmap(self: *Buffer) void {
        wgpuBufferUnmap(self);
    }
    pub inline fn addRef(self: *Buffer) void {
        wgpuBufferAddRef(self);
    }
    pub inline fn release(self: *Buffer) void {
        wgpuBufferRelease(self);
    }
};