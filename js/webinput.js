// zig-wasm-ffi/js/webinput.js
export function addKeyListener(event, callback, context_ptr) {
    window.addEventListener(event, e => {
        callback(context_ptr, e.type === "keydown", e.keyCode);
    });
}

export function getGamepads() {
    return navigator.getGamepads();
}

export function getGamepadButton(gamepad, index) {
    return gamepad.buttons[index].pressed;
}

export function getGamepadAxis(gamepad, index) {
    return gamepad.axes[index];
}