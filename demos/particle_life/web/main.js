// Particle Life Demo - JavaScript Entry Point
// Initializes WebGPU, loads WASM, and drives the animation loop

import { setupWebGPU, loadBlueNoiseTexture } from './webgpu.js';
import * as webgpu_glue from './webgpu.js';
import { setupInputSystem } from './webinput.js';
import { UI } from './ui.js';

const state = {
    wasm: null,
    canvas: null,
    lastFrameTime: 0,
    frameCount: 0,
    ui: null,
};

function buildEnvImports() {
    const env = {};

    // Spread all env_webgpu_* functions from the library
    for (const [key, value] of Object.entries(webgpu_glue)) {
        if (key.startsWith('env_') && typeof value === 'function') {
            env[key] = value;
        }
    }

    // Demo-specific imports
    env.js_console_log = (ptr, len) => {
        const memory = state.wasm.exports.memory;
        const text = new TextDecoder().decode(new Uint8Array(memory.buffer, ptr, len));
        console.log(`[Zig] ${text}`);
    };

    return env;
}

async function initWASM() {
    try {
        updateStatus('Loading WASM...');
        const response = await fetch(`app.wasm?t=${Date.now()}`);
        if (!response.ok) throw new Error(`Failed to fetch app.wasm: ${response.status}`);

        const wasmBytes = await response.arrayBuffer();
        const wasmModule = await WebAssembly.instantiate(wasmBytes, { env: buildEnvImports() });
        state.wasm = wasmModule.instance;

        updateStatus('Initializing WebGPU...');
        state.canvas = document.getElementById('canvas');
        await setupWebGPU(state.wasm, state.canvas);

        await loadBlueNoiseTexture(state.wasm, 'blue-noise.png');

        updateStatus('Initializing simulation...');

        if (state.wasm.exports.init) {
            state.wasm.exports.init(Math.floor(Math.random() * 0xFFFFFFFF));
        }

        setupInputSystem(state.wasm.exports, state.canvas);

        const dpr = window.devicePixelRatio || 1;
        state.canvas.width = Math.round(state.canvas.clientWidth * dpr);
        state.canvas.height = Math.round(state.canvas.clientHeight * dpr);
        if (state.wasm.exports.onResize) {
            state.wasm.exports.onResize(state.canvas.width, state.canvas.height);
        }

        state.ui = new UI(state.wasm, state.canvas);

        updateStatus('Running');
        requestAnimationFrame(animationLoop);

    } catch (error) {
        console.error('WASM init failed:', error);
        updateStatus(`Error: ${error.message}`);
    }
}

function animationLoop(timestamp) {
    const dt = timestamp - state.lastFrameTime;
    state.lastFrameTime = timestamp;
    state.frameCount++;

    if (state.frameCount % 60 === 0) {
        document.getElementById('fps').textContent = `FPS: ${Math.round(1000 / dt)}`;
    }

    if (state.wasm && state.wasm.exports.update) {
        if (state.ui && state.ui.isPaused()) {
            state.wasm.exports.update(0);
        } else {
            state.wasm.exports.update(dt / 1000);
        }
    }

    requestAnimationFrame(animationLoop);
}

function updateStatus(text) {
    document.getElementById('status').textContent = text;
}

function resizeCanvas() {
    if (!state.canvas) return;
    const dpr = window.devicePixelRatio || 1;
    state.canvas.width = state.canvas.clientWidth * dpr;
    state.canvas.height = state.canvas.clientHeight * dpr;
    if (state.wasm && state.wasm.exports.onResize) {
        state.wasm.exports.onResize(state.canvas.width, state.canvas.height);
    }
}

async function init() {
    try {
        resizeCanvas();
        window.addEventListener('resize', resizeCanvas);
        await initWASM();
    } catch (error) {
        console.error('Initialization failed:', error);
        updateStatus(`Fatal error: ${error.message}`);
    }
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}
