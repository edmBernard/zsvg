//! 12-petal flower made by rotating a single cubic bezier around a center.

const std = @import("std");
const zsvg = @import("zsvg");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;

    var doc: zsvg.Document = .init(arena, 600, 400, .fromHex(0x1A1A2E));
    defer doc.deinit();

    const base: zsvg.Bezier = .{ .points = .{
        .{ .x = 0, .y = -100 },
        .{ .x = 80, .y = -100 },
        .{ .x = 80, .y = 100 },
        .{ .x = 0, .y = 100 },
    } };

    const origin: zsvg.Point = .{ .x = 300, .y = 200 };
    const n_petals: usize = 12;

    for (0..n_petals) |i| {
        const fi: f32 = @floatFromInt(i);
        const angle = fi * (2.0 * std.math.pi / @as(f32, @floatFromInt(n_petals)));
        const petal = base.rotate(angle).translate(origin);

        const hue: f32 = fi / @as(f32, @floatFromInt(n_petals));
        const r: u8 = @intFromFloat(100 + 155 * hue);
        const g: u8 = @intFromFloat(50 + 100 * (1.0 - hue));
        const b: u8 = @intFromFloat(200 - 100 * hue);

        try doc.addBezier(petal, .init(.rgb(r, g, b), 2, 0.8));
    }

    try doc.addCircle(
        .{ .center = origin, .radius = 5 },
        .{ .fill = .solidHex(0xFFFFFF) },
    );
    try doc.addText("Bezier Flower", .{ .x = 230, .y = 380 }, .solidHex(0xCCCCCC));

    try doc.save(arena, io, "zig-out/bezier_curves.svg");
    std.debug.print("wrote zig-out/bezier_curves.svg\n", .{});
}
