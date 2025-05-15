const webgpu = @import("zig-wasm-ffi").webgpu;
const webutils = @import("zig-wasm-ffi").webutils;
// const std = @import("std"); // No longer needed, @memcpy is a builtin

// Define the Handler Struct
pub const WebGPUHandler = struct {
    adapter: webgpu.Adapter,
    device: webgpu.Device,
    queue: webgpu.Queue,
    initialization_status: InitializationStatus,

    // Public API methods that operate on an instance of WebGPUHandler
    pub fn init(self: *WebGPUHandler) void { // Changed from !void, errors handled by status
        webutils.log("[WebGPUHandler] Initializing WebGPU (async via callbacks)...Instance method");
        self.initialization_status = .pending;
        self.adapter = 0;
        self.device = 0;
        self.queue = 0;
        webgpu.requestAdapter(); // This will callback to global zig_receive_adapter
    }

    pub fn isInitialized(self: *const WebGPUHandler) bool {
        return self.initialization_status == .complete;
    }

    pub fn hasFailed(self: *const WebGPUHandler) bool {
        return self.initialization_status == .failed or
            self.initialization_status == .adapter_failed or
            self.initialization_status == .device_failed or
            self.initialization_status == .queue_failed;
    }

    // getAdapter, getDevice, getQueue are used by Renderer, so keep them
    // They should refer to self fields if called on an instance.
    // However, Renderer.init takes *WebGPUHandler, so it can access fields directly.
    // Let's keep them for symmetry for now, though Renderer might not call them.
    pub fn getAdapter(self: *const WebGPUHandler) webgpu.Adapter {
        return self.adapter;
    }

    pub fn getDevice(self: *const WebGPUHandler) webgpu.Device {
        return self.device;
    }

    pub fn getQueue(self: *const WebGPUHandler) webgpu.Queue {
        return self.queue;
    }

    // Expose getPreferredCanvasFormat for the renderer
    // This would typically query the canvas configuration context.
    // For now, returning a common default. This needs FFI to JS to get the real value.
    pub fn getPreferredCanvasFormat(self: *const WebGPUHandler) ?webgpu.TextureFormat {
        _ = self; // self not used yet
        // Placeholder - In a real scenario, this would call a JS function via FFI
        // to get navigator.gpu.getPreferredCanvasFormat()
        webutils.log("[WebGPUHandler] getPreferredCanvasFormat called - returning placeholder .bgra8unorm");
        return .bgra8unorm;
    }

    pub fn deinit(self: *WebGPUHandler) void {
        webutils.log("[WebGPUHandler] Deinitializing WebGPU (instance)..._fields_before_release: A(" ++ "TODO_INT_TO_STRING" ++ ") D(" ++ "TODO_INT_TO_STRING" ++ ") Q(" ++ "TODO_INT_TO_STRING" ++ ")"); // TODO: Format numbers
        if (self.queue != 0) {
            webgpu.releaseHandle(.Queue, self.queue); // Corrected HandleType casing
            self.queue = 0;
            webutils.log("[WebGPUHandler] Queue released.");
        }
        if (self.device != 0) {
            webgpu.releaseHandle(.Device, self.device); // Corrected HandleType casing
            self.device = 0;
            webutils.log("[WebGPUHandler] Device released.");
        }
        if (self.adapter != 0) {
            webgpu.releaseHandle(.Adapter, self.adapter); // Corrected HandleType casing
            self.adapter = 0;
            webutils.log("[WebGPUHandler] Adapter released.");
        }
        self.initialization_status = .pending;
        webutils.log("[WebGPUHandler] WebGPU deinitialized (instance).");
    }
};

// Global instance of the handler
pub var g_wgpu_handler_instance: WebGPUHandler = WebGPUHandler{
    .adapter = 0,
    .device = 0,
    .queue = 0,
    .initialization_status = .pending,
};

const InitializationStatus = enum {
    pending,
    adapter_success,
    adapter_failed,
    device_success,
    device_failed,
    queue_success,
    queue_failed,
    complete,
    failed,
};

// fn log(message: []const u8) void {
//     webgpu.log(message);
// }

// --- Exported Zig functions for JavaScript to call back into ---
// These now operate on the global g_wgpu_handler_instance

pub export fn zig_receive_adapter(adapter_handle: webgpu.Adapter, status: u32) void {
    webutils.log("[WebGPUHandler] zig_receive_adapter called (global instance update).");
    if (status == 1 and adapter_handle != 0) { // 1 for success
        g_wgpu_handler_instance.adapter = adapter_handle;
        g_wgpu_handler_instance.initialization_status = .adapter_success;
        webutils.log("[WebGPUHandler] Adapter received successfully. Requesting device...");
        webgpu.adapterRequestDevice(g_wgpu_handler_instance.adapter);
    } else {
        g_wgpu_handler_instance.initialization_status = .adapter_failed;
        webgpu.getAndLogWebGPUError("[WebGPUHandler] Failed to get adapter (JS error context): ");
        webutils.log("[WebGPUHandler] Adapter request failed. Further initialization halted.");
    }
}

pub export fn zig_receive_device(device_handle: webgpu.Device, status: u32) void {
    webutils.log("[WebGPUHandler] zig_receive_device called (global instance update).");
    if (status == 1 and device_handle != 0) { // 1 for success
        g_wgpu_handler_instance.device = device_handle;
        g_wgpu_handler_instance.initialization_status = .device_success;
        webutils.log("[WebGPUHandler] Device received successfully. Getting queue...");

        var q_handle_optional: ?webgpu.Queue = null;
        q_handle_optional = webgpu.deviceGetQueue(g_wgpu_handler_instance.device) catch |err| {
            g_wgpu_handler_instance.initialization_status = .queue_failed;
            webgpu.getAndLogWebGPUError("[WebGPUHandler] FFI error during deviceGetQueue: ");
            webutils.log("Zig error details from FFI deviceGetQueue: ");
            webutils.log(@errorName(err));
            g_wgpu_handler_instance.initialization_status = .failed;
            return; // Stop further processing if FFI call failed.
        };

        if (q_handle_optional) |q_handle| {
            g_wgpu_handler_instance.queue = q_handle;
            g_wgpu_handler_instance.initialization_status = .queue_success;
            webutils.log("[WebGPUHandler] Queue obtained successfully. Initialization complete.");
            g_wgpu_handler_instance.initialization_status = .complete;
        } else {
            // This case means deviceGetQueue FFI call succeeded (no Zig error), but JS returned null/0 for queue.
            g_wgpu_handler_instance.initialization_status = .queue_failed;
            webgpu.getAndLogWebGPUError("[WebGPUHandler] JS error context for queue retrieval failure (JS returned no queue): ");
            webutils.log("[WebGPUHandler] Overall: Failed to get queue. Initialization failed.");
            g_wgpu_handler_instance.initialization_status = .failed;
        }
    } else {
        g_wgpu_handler_instance.initialization_status = .device_failed;
        webgpu.getAndLogWebGPUError("[WebGPUHandler] Failed to get device (JS error context): ");
        webutils.log("[WebGPUHandler] Device request failed. Further initialization halted.");
        g_wgpu_handler_instance.initialization_status = .failed;
    }
}

// --- Public API wrappers that call methods on the global instance ---

pub fn initGlobalHandler() void {
    g_wgpu_handler_instance.init();
}

pub fn isGlobalHandlerInitialized() bool {
    return g_wgpu_handler_instance.isInitialized();
}

pub fn hasGlobalHandlerFailed() bool {
    return g_wgpu_handler_instance.hasFailed();
}

// No need for getAdapter, getDevice, getQueue wrappers if main.zig uses &g_wgpu_handler_instance directly.
// Renderer directly accesses fields of the WebGPUHandler struct passed to it.

pub fn deinitGlobalHandler() void {
    g_wgpu_handler_instance.deinit();
}
