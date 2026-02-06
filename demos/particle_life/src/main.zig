const ffi = @import("zig-wasm-ffi");
const webgpu = ffi.webgpu;

const simulation = @import("simulation.zig");
const input_handler = @import("input_handler.zig");

var sim: ?simulation.Simulation = null;
var sim_initialized: bool = false;
var initial_seed: u32 = 42;
var last_canvas_width: f32 = 0;
var last_canvas_height: f32 = 0;

var particle_count: u32 = 65536;
var species_count: u32 = 6;
var sim_width: f32 = 1024.0;
var sim_height: f32 = 1024.0;

export fn init(seed: u32) void {
    initial_seed = seed;
    log("Zig WebGPU Particle Life - Initialized!");
    log("WebGPU device ready");
}

export fn setDevice(device_handle: u32) void {
    webgpu.init(device_handle);
    if (webgpu.isInitialized()) {
        log("Device handle received and initialized");
    } else {
        log("ERROR: Failed to initialize device");
    }
}

export fn setBlueNoiseTexture(texture_handle: u32, view_handle: u32) void {
    _ = texture_handle;
    if (sim) |*s| {
        s.setBlueNoiseTexture(view_handle);
    }
}

export fn onResize(width: f32, height: f32) void {
    last_canvas_width = width;
    last_canvas_height = height;
    if (sim) |*s| {
        s.updateCamera(width, height);
    }
}

export fn update(dt: f32) void {
    if (!webgpu.isInitialized()) {
        return;
    }

    if (!sim_initialized) {
        initSimulation();
        sim_initialized = true;
    }

    if (sim) |*s| {
        s.handleInput(&input_handler.state, dt);
        s.update(dt);
        s.render();
        input_handler.state.resetPerFrame();
    }
}

fn initSimulation() void {
    log("=== Initializing Particle Life Simulation ===");

    if (sim) |*s| {
        s.deinit();
        sim = null;
    }

    sim = simulation.Simulation.init(
        particle_count,
        species_count,
        sim_width,
        sim_height,
        initial_seed,
        input_handler.state.symmetric_forces,
        input_handler.state.friction,
    ) catch {
        log("ERROR: Failed to initialize simulation");
        return;
    };

    if (last_canvas_width > 0 and last_canvas_height > 0) {
        if (sim) |*s| {
            s.updateCamera(last_canvas_width, last_canvas_height);
        }
    }

    log("Particle simulation initialized");
}

export fn setParticleCount(count: u32) void {
    if (particle_count != count) {
        particle_count = count;
        if (sim_initialized) initSimulation();
    }
}

export fn setSpeciesCount(count: u32) void {
    if (species_count != count) {
        species_count = count;
        if (sim_initialized) initSimulation();
    }
}

export fn setSimulationSize(width: f32, height: f32) void {
    if (sim_width != width or sim_height != height) {
        sim_width = width;
        sim_height = height;
        if (sim_initialized) initSimulation();
    }
}

export fn randomize() void {
    initial_seed = (initial_seed *% 1664525) +% 1013904223;
    if (sim_initialized) initSimulation();
}

export fn restart() void {
    if (sim_initialized) initSimulation();
}

export fn centerView() void {
    if (sim) |*s| {
        s.updateCamera(@floatFromInt(s.canvas_width), @floatFromInt(s.canvas_height));
    }
}

export fn getVersion() [*:0]const u8 {
    return "0.0.1";
}

fn log(comptime msg: []const u8) void {
    js_console_log(msg.ptr, msg.len);
}

extern fn js_console_log(ptr: [*]const u8, len: usize) void;
