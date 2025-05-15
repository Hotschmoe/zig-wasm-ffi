const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

// Import the module we are testing.
// This assumes webinput.zig is in the same directory or resolvable.
const webinput = @import("webinput.zig");

// Alias for convenience
const MouseButton = enum(u32) {
    Left = 0,
    Middle = 1,
    Right = 2,
    Back = 3,
    Forward = 4,
};

// Test mouse movement updates coordinates
test "mouse move updates coordinates" {
    webinput.testing_reset_internal_state_for_tests();
    webinput.zig_internal_on_mouse_move(123.0, 456.0);
    const pos = webinput.get_mouse_position();
    try expect(pos.x == 123.0);
    try expect(pos.y == 456.0);
}

// Test basic mouse button down and up state
test "mouse button is_down" {
    webinput.testing_reset_internal_state_for_tests();
    const button = MouseButton.Left;

    try expect(!webinput.is_mouse_button_down(@intFromEnum(button)));
    webinput.zig_internal_on_mouse_button(@intFromEnum(button), true, 10.0, 10.0);
    try expect(webinput.is_mouse_button_down(@intFromEnum(button)));
    webinput.zig_internal_on_mouse_button(@intFromEnum(button), false, 20.0, 20.0);
    try expect(!webinput.is_mouse_button_down(@intFromEnum(button)));
}

// Test mouse button "just pressed" and "just released" logic with frame updates
test "mouse button just_pressed and just_released" {
    webinput.testing_reset_internal_state_for_tests();
    const button = MouseButton.Right;

    // --- Frame 1: Press event ---
    // Initial state: button is up
    try expect(!webinput.is_mouse_button_down(@intFromEnum(button)));
    try expect(!webinput.was_mouse_button_just_pressed(@intFromEnum(button)));
    try expect(!webinput.was_mouse_button_just_released(@intFromEnum(button)));

    // Simulate JS calling the Wasm export for mouse button down
    webinput.zig_internal_on_mouse_button(@intFromEnum(button), true, 5.0, 5.0);
    // At this point, current state is 'down', previous state is still 'up' (from reset)
    try expect(webinput.is_mouse_button_down(@intFromEnum(button)));
    try expect(webinput.was_mouse_button_just_pressed(@intFromEnum(button))); // current=true, prev=false
    try expect(!webinput.was_mouse_button_just_released(@intFromEnum(button)));

    // Simulate end of application frame 1
    webinput.end_input_frame_state_update(); // prev_buttons_down now becomes true for 'button'

    // --- Frame 2: Button held, then released ---
    // Simulate start of application frame 2
    webinput.begin_input_frame_state_update();

    // Button is still down from frame 1, but should not be "just pressed"
    try expect(webinput.is_mouse_button_down(@intFromEnum(button)));
    try expect(!webinput.was_mouse_button_just_pressed(@intFromEnum(button))); // current=true, prev=true
    try expect(!webinput.was_mouse_button_just_released(@intFromEnum(button)));

    // Simulate JS calling the Wasm export for mouse button up (release)
    webinput.zig_internal_on_mouse_button(@intFromEnum(button), false, 7.0, 7.0);
    // Current state is 'up', previous state is 'down' (from end of frame 1)
    try expect(!webinput.is_mouse_button_down(@intFromEnum(button)));
    try expect(!webinput.was_mouse_button_just_pressed(@intFromEnum(button)));
    try expect(webinput.was_mouse_button_just_released(@intFromEnum(button))); // current=false, prev=true

    // Simulate end of application frame 2
    webinput.end_input_frame_state_update(); // prev_buttons_down now becomes false for 'button'

    // --- Frame 3: Button remains up ---
    // Simulate start of application frame 3
    webinput.begin_input_frame_state_update();

    // Button should be up, and not "just released"
    try expect(!webinput.is_mouse_button_down(@intFromEnum(button)));
    try expect(!webinput.was_mouse_button_just_pressed(@intFromEnum(button)));
    try expect(!webinput.was_mouse_button_just_released(@intFromEnum(button))); // current=false, prev=false
}

// Test mouse wheel delta accumulation and reset
test "mouse wheel delta" {
    webinput.testing_reset_internal_state_for_tests();

    // Frame 1
    webinput.begin_input_frame_state_update(); // Resets deltas
    var delta = webinput.get_mouse_wheel_delta();
    try expect(delta.dx == 0.0 and delta.dy == 0.0);

    webinput.zig_internal_on_mouse_wheel(10.0, -5.0);
    webinput.zig_internal_on_mouse_wheel(2.0, 3.0);
    delta = webinput.get_mouse_wheel_delta();
    try expect(delta.dx == 12.0);
    try expect(delta.dy == -2.0);
    webinput.end_input_frame_state_update();

    // Frame 2 - deltas should be reset by begin_input_frame_state_update
    webinput.begin_input_frame_state_update();
    delta = webinput.get_mouse_wheel_delta();
    try expect(delta.dx == 0.0 and delta.dy == 0.0);
    webinput.end_input_frame_state_update();
}

// Placeholder for Keyboard tests
const KeyCode = enum(u32) {
    A = 65,
    Space = 32,
};

test "keyboard key is_down" {
    webinput.testing_reset_internal_state_for_tests();
    const key = KeyCode.A;

    try expect(!webinput.is_key_down(@intFromEnum(key)));
    webinput.zig_internal_on_key_event(@intFromEnum(key), true);
    try expect(webinput.is_key_down(@intFromEnum(key)));
    webinput.zig_internal_on_key_event(@intFromEnum(key), false);
    try expect(!webinput.is_key_down(@intFromEnum(key)));
}

test "keyboard key just_pressed and just_released" {
    webinput.testing_reset_internal_state_for_tests();
    const key = KeyCode.Space;

    // Frame 1: Press
    webinput.begin_input_frame_state_update();
    try expect(!webinput.is_key_down(@intFromEnum(key)));
    try expect(!webinput.was_key_just_pressed(@intFromEnum(key)));

    webinput.zig_internal_on_key_event(@intFromEnum(key), true);
    try expect(webinput.is_key_down(@intFromEnum(key)));
    try expect(webinput.was_key_just_pressed(@intFromEnum(key))); // current=true, prev=false (from reset)
    webinput.end_input_frame_state_update(); // prev_keys_down becomes true

    // Frame 2: Held, then Released
    webinput.begin_input_frame_state_update();
    try expect(webinput.is_key_down(@intFromEnum(key)));
    try expect(!webinput.was_key_just_pressed(@intFromEnum(key))); // current=true, prev=true

    webinput.zig_internal_on_key_event(@intFromEnum(key), false);
    try expect(!webinput.is_key_down(@intFromEnum(key)));
    try expect(webinput.was_key_just_released(@intFromEnum(key))); // current=false, prev=true
    webinput.end_input_frame_state_update(); // prev_keys_down becomes false

    // Frame 3: Stays released
    webinput.begin_input_frame_state_update();
    try expect(!webinput.is_key_down(@intFromEnum(key)));
    try expect(!webinput.was_key_just_pressed(@intFromEnum(key)));
    try expect(!webinput.was_key_just_released(@intFromEnum(key))); // current=false, prev=false
    webinput.end_input_frame_state_update();
}

// Test for out-of-bounds button codes
test "mouse button out_of_bounds access" {
    webinput.testing_reset_internal_state_for_tests();
    const invalid_button_code = webinput.MAX_MOUSE_BUTTONS + 10; // well beyond the limit

    // These calls should not crash and getters should return false or default values
    webinput.zig_internal_on_mouse_button(invalid_button_code, true, 0, 0);
    try expect(!webinput.is_mouse_button_down(invalid_button_code));
    try expect(!webinput.was_mouse_button_just_pressed(invalid_button_code));
    try expect(!webinput.was_mouse_button_just_released(invalid_button_code));

    // After frame updates, still should be safe
    webinput.end_input_frame_state_update();
    webinput.begin_input_frame_state_update();
    try expect(!webinput.is_mouse_button_down(invalid_button_code));
    try expect(!webinput.was_mouse_button_just_pressed(invalid_button_code));
    try expect(!webinput.was_mouse_button_just_released(invalid_button_code));
}

// Test for out-of-bounds key codes
test "key event out_of_bounds access" {
    webinput.testing_reset_internal_state_for_tests();
    const invalid_key_code = webinput.MAX_KEY_CODES + 10; // well beyond the limit

    webinput.zig_internal_on_key_event(invalid_key_code, true);
    try expect(!webinput.is_key_down(invalid_key_code));
    try expect(!webinput.was_key_just_pressed(invalid_key_code));
    try expect(!webinput.was_key_just_released(invalid_key_code));

    webinput.end_input_frame_state_update();
    webinput.begin_input_frame_state_update();
    try expect(!webinput.is_key_down(invalid_key_code));
    try expect(!webinput.was_key_just_pressed(invalid_key_code));
    try expect(!webinput.was_key_just_released(invalid_key_code));
}
