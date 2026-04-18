const std = @import("std");
const zsvg = @import("zsvg");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;

    var doc: zsvg.Document = .init(arena, 320, 120, .fromHex(0xfffcf2));
    defer doc.deinit();

    try doc.addLine(
        .{ .vertices = .{ .{ .x = 24, .y = 84 }, .{ .x = 296, .y = 84 } } },
        .{ .stroke = .solidHex(0x252422, 2) },
    );
    try doc.addText("hello zig svg", .{ .x = 32, .y = 52 }, .solidHex(0xeb5e28));
    try doc.addRaw("<circle cx='268' cy='42' r='18' fill='rgb(64,61,57)' />\n");

    try doc.save(arena, io, "zig-out/text.svg");
    std.debug.print("wrote zig-out/text.svg\n", .{});
}
