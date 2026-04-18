//! Sampler of primitives plus a row of translucent circles.

const std = @import("std");
const zsvg = @import("zsvg");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;

    var doc: zsvg.Document = .init(arena, 600, 400, .fromHex(0xF5F5F5));
    defer doc.deinit();

    // Circle
    try doc.addCircle(
        .{ .center = .{ .x = 100, .y = 100 }, .radius = 40 },
        .{
            .fill = .hex(0x4488CC, 0.8),
            .stroke = .solidHex(0x224466, 2),
        },
    );

    // Line
    try doc.addLine(
        .{ .vertices = .{ .{ .x = 200, .y = 50 }, .{ .x = 350, .y = 150 } } },
        .{ .stroke = .solidHex(0xCC4444, 3) },
    );

    // Triangle via addShape
    try doc.addShape(
        zsvg.Triangle{ .vertices = .{
            .{ .x = 400, .y = 50 },
            .{ .x = 500, .y = 150 },
            .{ .x = 350, .y = 150 },
        } },
        .{ .fill = .solidHex(0x44CC88), .stroke = .solidHex(0x226644, 2) },
    );

    // Quadrilateral via addShape
    try doc.addShape(
        zsvg.Quadrilateral{ .vertices = .{
            .{ .x = 50, .y = 220 },
            .{ .x = 180, .y = 200 },
            .{ .x = 60, .y = 350 },
            .{ .x = 190, .y = 370 },
        } },
        .{ .fill = .hex(0xCC8844, 0.7), .stroke = .solidHex(0x664422, 2) },
    );

    // Labels
    try doc.addText("Circle", .{ .x = 75, .y = 160 }, .solidHex(0x333333));
    try doc.addText("Line", .{ .x = 250, .y = 170 }, .solidHex(0x333333));
    try doc.addText("Triangle", .{ .x = 400, .y = 170 }, .solidHex(0x333333));
    try doc.addText("Quad", .{ .x = 90, .y = 390 }, .solidHex(0x333333));

    // Multiple circles in a row — demonstrate Color arithmetic.
    for (0..5) |i| {
        const fi: f32 = @floatFromInt(i);
        const r: u8 = @intFromFloat(50 + fi * 40);
        const b: u8 = @intFromFloat(200 - fi * 30);
        try doc.addCircle(
            .{ .center = .{ .x = 250 + fi * 60, .y = 300 }, .radius = 20 },
            .{ .fill = .init(.rgb(r, 100, b), 0.6) },
        );
    }

    try doc.save(arena, io, "zig-out/basic_shapes.svg");
    std.debug.print("wrote zig-out/basic_shapes.svg\n", .{});
}
