const wasm_ffi = @import("zig-wasm-ffi");
const webinput = @import("zig-wasm-ffi").webinput;
// const std = @import("std"); // Removed std

// FFI import for JavaScript's console.log
// The JS side must provide this in the Wasm importObject.env
extern "env" fn js_log_string(message_ptr: [*c]const u8, message_len: u32) void;

// Helper function to log strings from Zig
fn log_info(message: []const u8) void {
    js_log_string(message.ptr, @intCast(message.len));
}

// Key codes (example)
const KEY_SPACE: u32 = 32;

var g_last_mouse_x: f32 = -1.0;
var g_last_mouse_y: f32 = -1.0;

pub fn main() void {
    log_info("Zig Wasm Example: main() called. Input polling will occur in update_frame().");
    // Initial input state for the first frame (optional, as update_frame will also call it)
    // webinput.update_input_frame_start();
}

// This function should be called repeatedly from JavaScript (e.g., via requestAnimationFrame)
pub export fn update_frame() void {
    // 1. Update input state at the beginning of the frame
    webinput.update_input_frame_start();

    // 2. Query and log mouse state
    const mouse_pos = webinput.get_mouse_position();
    if (mouse_pos.x != g_last_mouse_x or mouse_pos.y != g_last_mouse_y) {
        log_info("Mouse moved."); // Log a generic message when mouse moves
        // To log actual coordinates, you would need f32 to string conversion
        // or an FFI call like js_log_f32(mouse_pos.x);
        g_last_mouse_x = mouse_pos.x;
        g_last_mouse_y = mouse_pos.y;
    }

    if (webinput.was_mouse_button_just_pressed(0)) { // Left mouse button (button_code 0)
        log_info("Left mouse button just pressed!");
    }

    const wheel = webinput.get_mouse_wheel_delta();
    if (wheel.dx != 0.0 or wheel.dy != 0.0) {
        log_info("Mouse wheel scrolled.");
    }

    // 3. Query and log keyboard state
    if (webinput.was_key_just_pressed(KEY_SPACE)) {
        log_info("Spacebar just pressed!");
    }

    if (webinput.is_key_down(KEY_SPACE)) {
        // log_info("Spacebar is currently down."); // This can be noisy, commented out for now
    }
}

// To make logging f32 values simpler from Zig without full std.fmt, you could add:
// extern "env" fn js_log_f32(value: f32) void;
// extern "env" fn js_log_f32_pair(name_ptr: [*c]const u8, name_len: u32, v1: f32, v2: f32) void;
// And then in Zig: js_log_f32_pair("Mouse: ", 7, mouse_pos.x, mouse_pos.y);
