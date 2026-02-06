const std = @import("std");
const particle = @import("particle.zig");

pub const Rng = struct {
    state: u32,

    pub fn init(seed: u32) Rng {
        return .{ .state = seed };
    }

    pub fn next(self: *Rng) f32 {
        self.state +%= 0x9e3779b9;
        var t = self.state ^ (self.state >> 16);
        t = t *% 0x21f0aaad;
        t = t ^ (t >> 15);
        t = t *% 0x735a2d97;
        t = t ^ (t >> 15);
        return @as(f32, @floatFromInt(t)) / 4294967296.0;
    }

    pub fn range(self: *Rng, min: f32, max: f32) f32 {
        return min + self.next() * (max - min);
    }
};

pub fn generateSpeciesColors(species: []particle.Species, rng: *Rng) void {
    for (species) |*s| {
        const r = std.math.pow(f32, 0.25 + rng.next() * 0.75, 2.2);
        const g = std.math.pow(f32, 0.25 + rng.next() * 0.75, 2.2);
        const b = std.math.pow(f32, 0.25 + rng.next() * 0.75, 2.2);
        s.* = particle.Species.init(r, g, b, 1.0);
    }
}

pub fn generateForceMatrix(forces: []particle.Force, species_count: u32, rng: *Rng, symmetric: bool) void {
    const n = species_count;
    const max_force_strength = 100.0;
    const max_force_radius = 32.0;

    for (0..n) |i| {
        for (0..n) |j| {
            const idx = i * @as(usize, n) + j;
            const strength_magnitude = max_force_strength * (0.25 + 0.75 * rng.next());
            const strength = if (rng.next() < 0.5) strength_magnitude else -strength_magnitude;
            const collision_strength = (5.0 + 15.0 * rng.next()) * @abs(strength);
            const radius = 2.0 + rng.next() * (max_force_radius - 2.0);
            const collision_radius = rng.next() * 0.5 * radius;
            forces[idx] = .{
                .strength = strength,
                .radius = radius,
                .collision_strength = collision_strength,
                .collision_radius = collision_radius,
            };
        }
    }

    if (symmetric) {
        for (0..n) |i| {
            for ((i + 1)..n) |j| {
                const idx_ij = i * @as(usize, n) + j;
                const idx_ji = j * @as(usize, n) + i;
                const avg = particle.Force{
                    .strength = (forces[idx_ij].strength + forces[idx_ji].strength) / 2.0,
                    .radius = (forces[idx_ij].radius + forces[idx_ji].radius) / 2.0,
                    .collision_strength = (forces[idx_ij].collision_strength + forces[idx_ji].collision_strength) / 2.0,
                    .collision_radius = (forces[idx_ij].collision_radius + forces[idx_ji].collision_radius) / 2.0,
                };
                forces[idx_ij] = avg;
                forces[idx_ji] = avg;
            }
        }
    }
}
