const std = @import("std");
const webgpu = @import("zig-wasm-ffi").webgpu;
const WebGPUHandler = @import("webgpu_handler.zig").WebGPUHandler;
const log = @import("zig-wasm-ffi").utils.log;

// Embed shader code
const particle_binning_wgsl = @embedFile("../../shaders/particle_binning.wgsl");
const particle_compute_wgsl = @embedFile("../../shaders/particle_compute.wgsl");
const particle_prefix_sum_wgsl = @embedFile("../../shaders/particle_prefix_sum.wgsl");
const particle_render_wgsl = @embedFile("../../shaders/particle_render.wgsl");
const particle_sort_wgsl = @embedFile("../../shaders/particle_sort.wgsl");
const particle_compose_wgsl = @embedFile("../../shaders/particle_compose.wgsl");

pub const RendererError = error{
    ShaderModuleCreationError,
};

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

    pub fn init(allocator: std.mem.Allocator, wgpu_handler: *WebGPUHandler) !*Renderer {
        const self = try allocator.create(Renderer);
        self.* = .{
            .allocator = allocator,
            .wgpu_handler = wgpu_handler,
            // Initialize shader module fields to undefined or handle potential creation errors
            // For now, assuming creation will succeed or ! will propagate
            .binning_module = undefined,
            .compute_module = undefined,
            .prefix_sum_module = undefined,
            .render_module = undefined,
            .sort_module = undefined,
            .compose_module = undefined,
        };

        const device = wgpu_handler.device orelse return RendererError.ShaderModuleCreationError; // Ensure device is valid

        log.debug("Renderer.init: Creating shader modules...", .{});

        // Binning Shader
        const binning_module_desc = webgpu.ShaderModuleDescriptor{
            .label = "particle_binning_shader",
            .code = particle_binning_wgsl,
        };
        self.binning_module = webgpu.deviceCreateShaderModule(device, &binning_module_desc) catch |err| {
            log.err("Failed to create binning shader module: {any}", .{err});
            return RendererError.ShaderModuleCreationError;
        };
        log.debug("Renderer.init: Created binning_module {any}", .{self.binning_module});

        // Compute Shader
        const compute_module_desc = webgpu.ShaderModuleDescriptor{
            .label = "particle_compute_shader",
            .code = particle_compute_wgsl,
        };
        self.compute_module = webgpu.deviceCreateShaderModule(device, &compute_module_desc) catch |err| {
            log.err("Failed to create compute shader module: {any}", .{err});
            // TODO: Release previously created modules if one fails
            return RendererError.ShaderModuleCreationError;
        };
        log.debug("Renderer.init: Created compute_module {any}", .{self.compute_module});

        // Prefix Sum Shader
        const prefix_sum_module_desc = webgpu.ShaderModuleDescriptor{
            .label = "particle_prefix_sum_shader",
            .code = particle_prefix_sum_wgsl,
        };
        self.prefix_sum_module = webgpu.deviceCreateShaderModule(device, &prefix_sum_module_desc) catch |err| {
            log.err("Failed to create prefix_sum shader module: {any}", .{err});
            return RendererError.ShaderModuleCreationError;
        };
        log.debug("Renderer.init: Created prefix_sum_module {any}", .{self.prefix_sum_module});

        // Render Shader
        const render_module_desc = webgpu.ShaderModuleDescriptor{
            .label = "particle_render_shader",
            .code = particle_render_wgsl,
        };
        self.render_module = webgpu.deviceCreateShaderModule(device, &render_module_desc) catch |err| {
            log.err("Failed to create render shader module: {any}", .{err});
            return RendererError.ShaderModuleCreationError;
        };
        log.debug("Renderer.init: Created render_module {any}", .{self.render_module});

        // Sort Shader
        const sort_module_desc = webgpu.ShaderModuleDescriptor{
            .label = "particle_sort_shader",
            .code = particle_sort_wgsl,
        };
        self.sort_module = webgpu.deviceCreateShaderModule(device, &sort_module_desc) catch |err| {
            log.err("Failed to create sort shader module: {any}", .{err});
            return RendererError.ShaderModuleCreationError;
        };
        log.debug("Renderer.init: Created sort_module {any}", .{self.sort_module});

        // Compose Shader
        const compose_module_desc = webgpu.ShaderModuleDescriptor{
            .label = "particle_compose_shader",
            .code = particle_compose_wgsl,
        };
        self.compose_module = webgpu.deviceCreateShaderModule(device, &compose_module_desc) catch |err| {
            log.err("Failed to create compose shader module: {any}", .{err});
            return RendererError.ShaderModuleCreationError;
        };
        log.debug("Renderer.init: Created compose_module {any}", .{self.compose_module});

        log.info("Renderer initialized successfully with all shader modules.", .{});
        return self;
    }

    pub fn deinit(self: *Renderer) void {
        log.debug("Renderer.deinit: Releasing shader modules...", .{});
        // Ensure device is valid before trying to release
        // Note: releaseHandle is a global function in webgpu.zig, not device-specific
        if (self.wgpu_handler.device != null) {
            webgpu.releaseHandle(self.binning_module.handle, .ShaderModule);
            webgpu.releaseHandle(self.compute_module.handle, .ShaderModule);
            webgpu.releaseHandle(self.prefix_sum_module.handle, .ShaderModule);
            webgpu.releaseHandle(self.render_module.handle, .ShaderModule);
            webgpu.releaseHandle(self.sort_module.handle, .ShaderModule);
            webgpu.releaseHandle(self.compose_module.handle, .ShaderModule);
        } else {
            log.warn("Renderer.deinit: Device was null, cannot release shader module handles via wgpu_handler.device. Manually releasing.", .{});
            // This branch might be hit if init failed very early or wgpu_handler was tampered with.
            // releaseHandle itself doesn't need the device, just the handle and type.
            webgpu.releaseHandle(self.binning_module.handle, .ShaderModule);
            webgpu.releaseHandle(self.compute_module.handle, .ShaderModule);
            webgpu.releaseHandle(self.prefix_sum_module.handle, .ShaderModule);
            webgpu.releaseHandle(self.render_module.handle, .ShaderModule);
            webgpu.releaseHandle(self.sort_module.handle, .ShaderModule);
            webgpu.releaseHandle(self.compose_module.handle, .ShaderModule);
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
