//! Draws every supported primitive into a single SVG file.

const std = @import("std");
const zsvg = @import("zsvg");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;

    var doc: zsvg.Document = .init(arena, 400, 300, .fromHex(0x1B1F23));
    defer doc.deinit();

    try doc.addLine(
        .{ .vertices = .{ .{ .x = 20, .y = 20 }, .{ .x = 180, .y = 140 } } },
        .{ .stroke = .solidHex(0xF28B82, 3) },
    );

    try doc.addShape(
        zsvg.Triangle{ .vertices = .{
            .{ .x = 220, .y = 20 },
            .{ .x = 380, .y = 20 },
            .{ .x = 300, .y = 140 },
        } },
        .{ .fill = .solidHex(0xFFD479), .stroke = .solidHex(0xFFFFFF, 1) },
    );

    try doc.addShape(
        zsvg.Quadrilateral{ .vertices = .{
            .{ .x = 100, .y = 180 },
            .{ .x = 180, .y = 220 },
            .{ .x = 100, .y = 260 },
            .{ .x = 20, .y = 220 },
        } },
        .{ .fill = .solidHex(0x81C995) },
    );

    try doc.addCircle(
        .{ .center = .{ .x = 300, .y = 220 }, .radius = 40 },
        .{ .fill = .hex(0x8AB4F8, 0.4), .stroke = .solidHex(0x8AB4F8, 2) },
    );

    try doc.addBezier(
        .{ .points = .{
            .{ .x = 20, .y = 280 },
            .{ .x = 120, .y = 150 },
            .{ .x = 260, .y = 300 },
            .{ .x = 380, .y = 170 },
        } },
        .solidHex(0xC58AF9, 2),
    );

    try doc.addText("zsvg demo", .{ .x = 150, .y = 290 }, .solidHex(0xFFFFFF));

    try doc.save(arena, io, "zig-out/shapes.svg");
    std.debug.print("wrote zig-out/shapes.svg\n", .{});
}
