const std = @import("std");
const zsvg = @import("zsvg");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;

    var doc: zsvg.Document = .init(arena, 240, 180, .fromHex(0xf7f0e8));
    defer doc.deinit();

    try doc.addCircle(
        .{ .center = .{ .x = 70, .y = 90 }, .radius = 42 },
        .{ .fill = .hex(0xef8354, 0.9), .stroke = .solidHex(0x2d3142, 3) },
    );
    try doc.addCircle(
        .{ .center = .{ .x = 150, .y = 90 }, .radius = 30 },
        .{ .fill = .hex(0x4f5d75, 0.8), .stroke = .solidHex(0x2d3142, 2) },
    );

    try doc.save(arena, io, "zig-out/basic.svg");
    std.debug.print("wrote zig-out/basic.svg\n", .{});
}
