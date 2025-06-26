const input_handler = @import("input_handler.zig");
const webgpu_handler = @import("webgpu_engine/webgpu_handler.zig");
const webgpu_ffi = @import("zig-wasm-ffi").webgpu; // FFI library
const renderer = @import("webgpu_engine/renderer.zig");
const std = @import("std"); // Added for allocator
const webutils = @import("zig-wasm-ffi").webutils;

// New function to log frame updates without std.fmt
fn log_frame_update_info(count: u32, dt_ms: f32) void {
    _ = count;
    _ = dt_ms;
    webutils.log("Frame update processed by main.zig.");
    // For more complex formatting, would need to implement int/float to string for wasm32-freestanding
    // For now, keeping it simple.
}

var frame_count: u32 = 0;
var g_renderer: ?*renderer.Renderer = null;
var g_main_allocator: ?std.mem.Allocator = null;
// Keep gpa_instance global to deinit it properly
var g_gpa_instance: std.heap.GeneralPurposeAllocator(.{}) = undefined;
var renderer_initialized: bool = false;
var renderer_init_failed: bool = false;

pub export fn _start() void {
    webutils.log("Zig _start called from main.zig.");

    // Initialize a global allocator for main.zig scope
    g_gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
    g_main_allocator = g_gpa_instance.allocator();

    // Initialize WebGPU through the handler (now using global handler instance)
    webgpu_handler.initGlobalHandler();
    // Error state is checked via isGlobalHandlerInitialized() / hasGlobalHandlerFailed() in update_frame.

    webutils.log("WebGPU Handler initGlobalHandler() call made. Check console for async callback status.");

    // Debug printing for struct sizes and offsets
    webutils.log("--- WebGPU Struct Sizes (main.zig) ---");

    // Simple way to print numbers by checking ranges
    const bindgroup_entry_size = @sizeOf(webgpu_ffi.BindGroupEntry);
    if (bindgroup_entry_size == 24) webutils.log("BindGroupEntry size: 24 bytes");
    if (bindgroup_entry_size == 28) webutils.log("BindGroupEntry size: 28 bytes");
    if (bindgroup_entry_size == 32) webutils.log("BindGroupEntry size: 32 bytes");
    if (bindgroup_entry_size == 44) webutils.log("BindGroupEntry size: 44 bytes");
    if (bindgroup_entry_size == 48) webutils.log("BindGroupEntry size: 48 bytes");
    if (bindgroup_entry_size > 48) webutils.log("BindGroupEntry size: > 48 bytes");

    const buffer_binding_size = @sizeOf(webgpu_ffi.BufferBinding);
    if (buffer_binding_size == 20) webutils.log("BufferBinding size: 20 bytes");
    if (buffer_binding_size == 24) webutils.log("BufferBinding size: 24 bytes");
    if (buffer_binding_size == 32) webutils.log("BufferBinding size: 32 bytes");

    const resource_union_size = @sizeOf(webgpu_ffi.BindGroupEntry.Resource);
    if (resource_union_size == 20) webutils.log("Resource union size: 20 bytes");
    if (resource_union_size == 24) webutils.log("Resource union size: 24 bytes");
    if (resource_union_size == 32) webutils.log("Resource union size: 32 bytes");

    webutils.log("--- End WebGPU Struct Sizes ---");
    // For now, I've replaced the dynamic offset logging with placeholders ("TODO_log_offset")
    // because implementing a robust int-to-string without std for wasm32-freestanding
    // is a bit involved for this quick fix. The key is removing `std.debug.print`.
    // If these specific offset logs are critical, a simple int-to-string can be added later.

    // The original message assumed success or pending. We should rely on isGlobalHandlerInitialized() in update_frame.
    webutils.log("Initial setup in _start complete. WebGPU initialization is asynchronous.");
}

// This function is called repeatedly from JavaScript (e.g., via requestAnimationFrame)
export fn update_frame(delta_time_ms: f32) void {
    if (renderer_init_failed) {
        return;
    }

    if (!webgpu_handler.isGlobalHandlerInitialized()) {
        if (webgpu_handler.hasGlobalHandlerFailed()) {
            webutils.log("WebGPU initialization failed, cannot initialize renderer or update frame.");
            renderer_init_failed = true; // Prevent further attempts if WebGPU itself failed
        } else {
            // log("WebGPU not yet initialized, waiting...");
        }
        return; // Wait for WebGPU to be ready
    }

    // WebGPU is initialized, proceed to initialize renderer if not already done
    if (!renderer_initialized) {
        webutils.log("WebGPU initialized. Now initializing Renderer...");
        if (g_main_allocator) |allocator| {
            // Pass pointer to the global handler instance
            g_renderer = renderer.Renderer.init(allocator, &webgpu_handler.g_wgpu_handler_instance) catch |err| {
                webutils.log("Failed to initialize Renderer: ");
                webutils.log(@errorName(err));
                renderer_init_failed = true;
                // Allocator deinit is handled in _wasm_shutdown
                webutils.log("Renderer init failed. Allocator will be deinitialized at shutdown.");
                return;
            };
            renderer_initialized = true;
            webutils.log("Renderer initialized successfully.");
        } else {
            webutils.log("Main allocator not available for Renderer initialization.");
            renderer_init_failed = true;
            return;
        }
    }

    frame_count += 1;
    log_frame_update_info(frame_count, delta_time_ms);

    input_handler.update();

    if (input_handler.was_left_mouse_button_just_pressed()) {
        webutils.log("Left mouse button was pressed (detected in main.zig).");
    }

    if (input_handler.was_right_mouse_button_just_pressed()) {
        webutils.log("Right mouse button was pressed (detected in main.zig).");
    }

    if (input_handler.was_space_just_pressed()) {
        webutils.log("Spacebar was just pressed (detected in main.zig)!");
    }

    // Call renderer's renderFrame
    if (g_renderer) |r| {
        r.renderFrame() catch |err| {
            webutils.log("Error during renderer.renderFrame: ");
            webutils.log(@errorName(err));
            // Depending on the error, might need to stop rendering or attempt recovery.
        };
    } else if (renderer_initialized and !renderer_init_failed) {
        // This case should ideally not be hit if init logic is correct.
        webutils.log("Renderer was marked initialized, but g_renderer is null. RenderFrame skipped.");
    }
}

// Ensure that if the Wasm module has a way to be explicitly torn down by JS,
// an exported function could call webgpu_handler.deinit().
// For now, `_start` sets up and `update_frame` runs. Deinit in `_start` might be too early
// if `_start` is just an init and not the main loop itself.
// If JS calls _start once and then update_frame in a loop, then deinit should be handled
// by a separate exported shutdown function or managed by JS when the page unloads.
// The original defer in _start in the previous main.zig version would deinit immediately after _start finishes.
// We want WebGPU to stay alive for update_frame. So, deinit must be handled differently.

pub export fn _wasm_shutdown() void {
    webutils.log("Wasm shutdown requested.");

    if (g_renderer) |r| {
        webutils.log("Deinitializing Renderer...");
        r.deinit();
        g_renderer = null;
        webutils.log("Renderer deinitialized.");
    }

    // Deinitialize the main allocator if it was initialized
    if (g_main_allocator != null) {
        webutils.log("Deinitializing main allocator (GPA)...");
        _ = g_gpa_instance.deinit(); // Deinit the GPA instance itself
        g_main_allocator = null;
        webutils.log("Main allocator deinitialized.");
    }

    webgpu_handler.deinitGlobalHandler();
    webutils.log("WebGPU handler deinitialized during Wasm shutdown.");
}
