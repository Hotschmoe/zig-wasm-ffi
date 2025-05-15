const std = @import("std");

const _chained_struct = @import("chained_struct.zig");
const ChainedStruct = _chained_struct.ChainedStruct;
const ChainedStructOut = _chained_struct.ChainedStructOut;
const SType = _chained_struct.SType;

const _adapter = @import("adapter.zig");
const Adapter = _adapter.Adapter;
const RequestAdapterOptions = _adapter.RequestAdapterOptions;
const RequestAdapterCallbackInfo = _adapter.RequestAdapterCallbackInfo;
const RequestAdapterCallback = _adapter.RequestAdapterCallback;
const RequestAdapterStatus = _adapter.RequestAdapterStatus;
const RequestAdapterResponse = _adapter.RequestAdapterResponse;
const BackendType = _adapter.BackendType;

const _surface = @import("surface.zig");
const Surface = _surface.Surface;
const SurfaceDescriptor = _surface.SurfaceDescriptor;

const _misc = @import("misc.zig");
const WGPUFlags = _misc.WGPUFlags;
const WGPUBool = _misc.WGPUBool;
const StringView = _misc.StringView;

const Future = @import("async.zig").Future;

pub const InstanceBackend = WGPUFlags;
pub const InstanceBackends = struct {
    pub const all            = @as(InstanceBackend, 0x00000000);
    pub const vulkan         = @as(InstanceBackend, 0x00000001);
    pub const gl             = @as(InstanceBackend, 0x00000002);
    pub const metal          = @as(InstanceBackend, 0x00000004);
    pub const dx12           = @as(InstanceBackend, 0x00000008);
    pub const dx11           = @as(InstanceBackend, 0x00000010);
    pub const browser_webgpu = @as(InstanceBackend, 0x00000020);
    pub const primary        = vulkan | metal | dx12 | browser_webgpu;
    pub const secondary      = gl | dx11;
};

pub const InstanceFlag = WGPUFlags;
pub const InstanceFlags = struct {
    pub const default            = @as(InstanceFlag, 0x00000000);
    pub const debug              = @as(InstanceFlag, 0x00000001);
    pub const validation         = @as(InstanceFlag, 0x00000002);
    pub const discard_hal_labels = @as(InstanceFlag, 0x00000004);
};

pub const Dx12Compiler = enum(u32) {
    @"undefined" = 0x00000000,
    fxc          = 0x00000001,
    dxc          = 0x00000002,
};

pub const Gles3MinorVersion = enum(u32) {
    automatic  = 0x00000000,
    version_0  = 0x00000001,
    version_1  = 0x00000002,
    version_2  = 0x00000003,
};

pub const InstanceExtras = extern struct {
    chain: ChainedStruct = ChainedStruct {
        .s_type = SType.instance_extras,
    },
    backends: InstanceBackend,
    flags: InstanceFlag,
    dx12_shader_compiler: Dx12Compiler,
    gles3_minor_version: Gles3MinorVersion,
    dxil_path: StringView = StringView {},
    dxc_path: StringView = StringView {},
};

pub const InstanceCapabilities = extern struct {
    // This struct chain is used as mutable in some places and immutable in others.
    next_in_chain: ?*ChainedStructOut = null,

    // Enable use of ::wgpuInstanceWaitAny with `timeoutNS > 0`.
    timed_wait_any_enable: WGPUBool,

    // The maximum number FutureWaitInfo supported in a call to ::wgpuInstanceWaitAny with `timeoutNS > 0`.
    timed_wait_any_max_count: usize,
};

pub const InstanceDescriptor = extern struct {
    next_in_chain: ?*const ChainedStruct = null,

    // Instance features to enable
    features: InstanceCapabilities,

    pub inline fn withNativeExtras(self: InstanceDescriptor, extras: *InstanceExtras) InstanceDescriptor {
        var id = self;
        id.next_in_chain = @ptrCast(extras);
        return id;
    }
};

pub const WGSLLanguageFeatureName = enum(u32) {
    readonly_and_readwrite_storage_textures = 0x00000001,
    packed4x8_integer_dot_product           = 0x00000002,
    unrestricted_pointer_parameters         = 0x00000003,
    pointer_composite_access                = 0x00000004,
};

pub const SupportedWGSLLanguageFeatures = extern struct {
    feature_count: usize,
    features: [*]const WGSLLanguageFeatureName,
};

pub const InstanceProcs = struct {
    pub const CreateInstance = *const fn(?*const InstanceDescriptor) callconv(.C) ?*Instance;
    pub const CreateSurface = *const fn(*Instance, *const SurfaceDescriptor) ?*Surface;
    pub const HasWGSLLanguageFeature = *const fn(*Instance, WGSLLanguageFeatureName) WGPUBool;
    pub const ProcessEvents = *const fn(*Instance) callconv(.C) void;
    pub const RequestAdapter = *const fn(*Instance, ?*const RequestAdapterOptions, RequestAdapterCallbackInfo) callconv(.C) Future;
    pub const InstanceAddRef = *const fn(*Instance) callconv(.C) void;
    pub const InstanceRelease = *const fn(*Instance) callconv(.C) void;

    // wgpu-native procs?
    // pub const GenerateReport = *const fn(*Instance, *GlobalReport) callconv(.C) void;
    // pub const EnumerateAdapters = *const fn(*Instance, ?*const EnumerateAdapterOptions, ?[*]Adapter) callconv(.C) usize;
};

extern fn wgpuCreateInstance(descriptor: ?*const InstanceDescriptor) ?*Instance;
extern fn wgpuInstanceCreateSurface(instance: *Instance, descriptor: *const SurfaceDescriptor) ?*Surface;
extern fn wgpuInstanceHasWGSLLanguageFeature(instance: *Instance, feature: WGSLLanguageFeatureName) WGPUBool;
extern fn wgpuInstanceProcessEvents(instance: *Instance) void;
extern fn wgpuInstanceRequestAdapter(instance: *Instance, options: ?*const RequestAdapterOptions, callback_info: RequestAdapterCallbackInfo) Future;
extern fn wgpuInstanceAddRef(instance: *Instance) void;
extern fn wgpuInstanceRelease(instance: *Instance) void;

pub const RegistryReport = extern struct {
    num_allocated: usize,
    num_kept_from_user: usize,
    num_released_from_user: usize,
    element_size: usize,
};

pub const HubReport = extern struct {
    adapters: RegistryReport,
    devices: RegistryReport,
    queues: RegistryReport,
    pipeline_layouts: RegistryReport,
    shader_modules: RegistryReport,
    bind_group_layouts: RegistryReport,
    bind_groups: RegistryReport,
    command_buffers: RegistryReport,
    render_bundles: RegistryReport,
    render_pipelines: RegistryReport,
    compute_pipelines: RegistryReport,
    pipeline_caches: RegistryReport,
    query_sets: RegistryReport,
    buffers: RegistryReport,
    textures: RegistryReport,
    texture_views: RegistryReport,
    samplers: RegistryReport,
};

pub const GlobalReport = extern struct {
    surfaces: RegistryReport,
    hub: HubReport,
};

pub const EnumerateAdapterOptions = extern struct {
    next_in_chain: ?*const ChainedStruct = null,
    backends: InstanceBackend,
};

// wgpu-native
extern fn wgpuGenerateReport(instance: *Instance, report: *GlobalReport) void;
extern fn wgpuInstanceEnumerateAdapters(instance: *Instance, options: ?*EnumerateAdapterOptions, adapters: ?[*]Adapter) usize;

pub const Instance = opaque {
    pub inline fn create(descriptor: ?*const InstanceDescriptor) ?*Instance {
        return wgpuCreateInstance(descriptor);
    }

    pub inline fn createSurface(self: *Instance, descriptor: *const SurfaceDescriptor) ?*Surface {
        return wgpuInstanceCreateSurface(self, descriptor);
    }

    pub inline fn hasWGSLLanguageFeature(self: *Instance, feature: WGSLLanguageFeatureName) bool {
        return wgpuInstanceHasWGSLLanguageFeature(self, feature) != 0;
    }

    pub inline fn processEvents(self: *Instance) void {
        wgpuInstanceProcessEvents(self);
    }

    fn defaultAdapterCallback(status: RequestAdapterStatus, adapter: ?*Adapter, message: StringView, userdata1: ?*anyopaque, userdata2: ?*anyopaque) callconv(.C) void {
        const ud_response: *RequestAdapterResponse = @ptrCast(@alignCast(userdata1));
        ud_response.* = RequestAdapterResponse {
            .status = status,
            .message = message.toSlice(),
            .adapter = adapter,
        };

        const completed: *bool = @ptrCast(@alignCast(userdata2));
        completed.* = true;
    }

    // This is a synchronous wrapper that handles asynchronous (callback) logic.
    // It uses polling to see when the request has been fulfilled, so needs a polling interval parameter.
    pub fn requestAdapterSync(self: *Instance, options: ?*const RequestAdapterOptions, polling_interval_nanoseconds: u64) RequestAdapterResponse {
        var response: RequestAdapterResponse = undefined;
        var completed = false;
        const callback_info = RequestAdapterCallbackInfo {
            .callback = defaultAdapterCallback,
            .userdata1 = @ptrCast(&response),
            .userdata2 = @ptrCast(&completed),
        };
        const adapter_future = wgpuInstanceRequestAdapter(self, options, callback_info);

        // TODO: Revisit once Instance.waitAny() is implemented in wgpu-native,
        //       it takes in futures and returns when one of them completes.
        _ = adapter_future;
        self.processEvents();
        while (!completed) {
            std.Thread.sleep(polling_interval_nanoseconds);
            self.processEvents();
        }

        return response;
    }

    pub inline fn requestAdapter(self: *Instance, options: ?*const RequestAdapterOptions, callback_info: RequestAdapterCallbackInfo) Future {
        return wgpuInstanceRequestAdapter(self, options, callback_info);
    }

    pub inline fn addRef(self: *Instance) void {
        wgpuInstanceAddRef(self);
    }


    pub inline fn release(self: *Instance) void {
        wgpuInstanceRelease(self);
    }

    // wgpu-native
    pub inline fn generateReport(self: *Instance, report: *GlobalReport) void {
        wgpuGenerateReport(self, report);
    }
    pub inline fn enumerateAdapters(self: *Instance, options: ?*EnumerateAdapterOptions, adapters: ?[*]Adapter) usize {
        return wgpuInstanceEnumerateAdapters(self, options, adapters);
    }
};

test "can create instance (and release it afterwards)" {
    const testing = @import("std").testing;

    const instance = Instance.create(null);
    try testing.expect(instance != null);
    instance.?.release();
}

test "can request adapter" {
    const testing = @import("std").testing;

    const instance = Instance.create(null);
    const response = instance.?.requestAdapterSync(null, 200_000_000);
    const adapter: ?*Adapter = switch(response.status) {
        .success => response.adapter,
        else => null,
    };
    try testing.expect(adapter != null);
}