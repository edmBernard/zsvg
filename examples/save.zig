const std = @import("std");
const zsvg = @import("zsvg");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;

    var doc: zsvg.Document = .init(arena, 220, 140, .fromHex(0xf4f1ea));
    defer doc.deinit();

    try doc.addCircle(
        .{ .center = .{ .x = 72, .y = 72 }, .radius = 28 },
        .{ .fill = .solidHex(0xbc4749), .stroke = .solidHex(0x283618, 2) },
    );
    try doc.addText("saved by zsvg", .{ .x = 118, .y = 76 }, .solidHex(0x283618));

    try doc.save(arena, io, "zig-out/save.svg");
    std.debug.print("wrote zig-out/save.svg\n", .{});
}
