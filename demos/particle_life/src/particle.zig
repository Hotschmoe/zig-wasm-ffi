const std = @import("std");

pub const Particle = extern struct {
    x: f32,
    y: f32,
    vx: f32,
    vy: f32,
    species: f32,

    pub fn init(x: f32, y: f32, species: u32) Particle {
        return .{
            .x = x,
            .y = y,
            .vx = 0.0,
            .vy = 0.0,
            .species = @floatFromInt(species),
        };
    }
};

pub const Species = extern struct {
    color: [4]f32,

    pub fn init(r: f32, g: f32, b: f32, a: f32) Species {
        return .{ .color = [4]f32{ r, g, b, a } };
    }

    pub fn fromRGB(r: f32, g: f32, b: f32) Species {
        return init(r, g, b, 1.0);
    }
};

pub const Force = extern struct {
    strength: f32,
    radius: f32,
    collision_strength: f32,
    collision_radius: f32,

    pub fn init(strength: f32, radius: f32) Force {
        return .{
            .strength = strength,
            .radius = radius,
            .collision_strength = 10.0,
            .collision_radius = 0.5,
        };
    }
};

pub const SimulationOptions = extern struct {
    left: f32,
    right: f32,
    bottom: f32,
    top: f32,
    friction: f32,
    dt: f32,
    bin_size: f32,
    species_count: f32,
    central_force: f32,
    looping_borders: f32,
    action_x: f32,
    action_y: f32,
    action_vx: f32,
    action_vy: f32,
    action_force: f32,
    action_radius: f32,

    pub fn init(width: f32, height: f32, species_count: u32) SimulationOptions {
        return .{
            .left = -width / 2.0,
            .right = width / 2.0,
            .bottom = -height / 2.0,
            .top = height / 2.0,
            .friction = 1.0,
            .dt = 0.016,
            .bin_size = 32.0,
            .species_count = @floatFromInt(species_count),
            .central_force = 0.0,
            .looping_borders = 0.0,
            .action_x = 0.0,
            .action_y = 0.0,
            .action_vx = 0.0,
            .action_vy = 0.0,
            .action_force = 0.0,
            .action_radius = 0.0,
        };
    }
};

pub const CameraParams = extern struct {
    center_x: f32,
    center_y: f32,
    extent_x: f32,
    extent_y: f32,
    pixels_per_unit: f32,
    _padding: [3]f32 = undefined,

    pub fn init(canvas_width: f32, canvas_height: f32) CameraParams {
        const aspect_ratio = canvas_width / canvas_height;
        const extent_x = 512.0;
        const extent_y = extent_x / aspect_ratio;
        return .{
            .center_x = 0.0,
            .center_y = 0.0,
            .extent_x = extent_x,
            .extent_y = extent_y,
            .pixels_per_unit = canvas_width / (2.0 * extent_x),
        };
    }

    pub fn initForSimulation(canvas_width: f32, canvas_height: f32, sim_width: f32, sim_height: f32) CameraParams {
        const aspect_ratio = canvas_width / canvas_height;
        const extent_x = if ((sim_width / sim_height) > aspect_ratio)
            sim_width / 2.0
        else
            (sim_height / 2.0) * aspect_ratio;
        const extent_y = extent_x / aspect_ratio;
        const pixels_per_unit = canvas_width / (2.0 * extent_x);
        return .{
            .center_x = 0.0,
            .center_y = 0.0,
            .extent_x = extent_x,
            .extent_y = extent_y,
            .pixels_per_unit = pixels_per_unit,
        };
    }
};
