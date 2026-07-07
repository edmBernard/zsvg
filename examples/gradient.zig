//! Renders a 10x10 grid of circles whose color is linearly interpolated
//! between two endpoints, demonstrating `Color` arithmetic and streaming
//! directly to a file with `writeTo`.

const std = @import("std");
const zsvg = @import("zsvg");

const grid: u32 = 10;
const spacing: u32 = 40;
const margin: u32 = 25;
const radius: u32 = 14;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;

    const canvas: u32 = grid * spacing + 2 * margin - spacing;
    var doc: zsvg.Document = .init(arena, canvas, canvas, .fromHex(0x0D0D12));
    defer doc.deinit();

    const start: zsvg.Color = .fromHex(0x4E9AF1);
    const end: zsvg.Color = .fromHex(0xF25C8A);

    const steps: f32 = @floatFromInt((grid - 1) * 2);
    var y: u32 = 0;
    while (y < grid) : (y += 1) {
        var x: u32 = 0;
        while (x < grid) : (x += 1) {
            const t = @as(f32, @floatFromInt(x + y)) / steps;
            const color = start.scale(1 - t).add(end.scale(t));

            try doc.addCircle(
                .{
                    .center = .{
                        .x = @floatFromInt(margin + x * spacing),
                        .y = @floatFromInt(margin + y * spacing),
                    },
                    .radius = @floatFromInt(radius),
                },
                .{ .fill = .solid(color) },
            );
        }
    }

    // Stream straight to disk without building the full string first.
    const out_file = try std.Io.Dir.cwd().createFile(io, "zig-out/gradient.svg", .{});
    defer out_file.close(io);

    var file_buf: [4096]u8 = undefined;
    var file_writer: std.Io.File.Writer = .init(out_file, io, &file_buf);
    try doc.writeTo(&file_writer.interface);
    try file_writer.interface.flush();

    std.debug.print("wrote zig-out/gradient.svg\n", .{});
}
