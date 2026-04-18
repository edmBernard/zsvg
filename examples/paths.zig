const std = @import("std");
const zsvg = @import("zsvg");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;

    var doc: zsvg.Document = .init(arena, 320, 200, .fromHex(0xf9f7f3));
    defer doc.deinit();

    const triangles = [_]zsvg.Triangle{
        .{ .vertices = .{
            .{ .x = 40, .y = 120 },
            .{ .x = 90, .y = 50 },
            .{ .x = 140, .y = 120 },
        } },
        .{ .vertices = .{
            .{ .x = 140, .y = 120 },
            .{ .x = 190, .y = 50 },
            .{ .x = 240, .y = 120 },
        } },
    };

    try doc.addPath(
        &triangles,
        .{ .fill = .hex(0xb8d8d8, 0.85), .stroke = .solidHex(0x4f6367, 2) },
    );

    const wave: zsvg.Bezier = .{ .points = .{
        .{ .x = 20, .y = 150 },
        .{ .x = 90, .y = 190 },
        .{ .x = 180, .y = 110 },
        .{ .x = 280, .y = 150 },
    } };
    try doc.addBezier(wave, .solidHex(0xfe5f55, 4));

    try doc.save(arena, io, "zig-out/paths.svg");
    std.debug.print("wrote zig-out/paths.svg\n", .{});
}
