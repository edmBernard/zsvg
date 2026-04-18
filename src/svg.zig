//! Minimal, allocation-light SVG document builder.
//!
//! A `Document` streams shape markup directly into an internal
//! `std.Io.Writer.Allocating` as the caller invokes `addX` methods. The
//! full `<svg>…</svg>` envelope is produced on demand through `writeTo`,
//! `toOwnedString`, or `save`.
//!
//! Design notes
//! ------------
//! * Opacity is carried by `Fill` and `Stroke` (not by `Color`), so the
//!   same color can be used with different alpha for fill vs. stroke.
//! * All path generation is pure streaming — no per-shape allocations.
//! * `addPath` takes an `anytype` slice/array and infers the element type
//!   from the iteration variable. No forced comptime type argument.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Writer = std.Io.Writer;

const geometry = @import("geometry.zig");
const Point = geometry.Point;
const Line = geometry.Line;
const Triangle = geometry.Triangle;
const Quadrilateral = geometry.Quadrilateral;
const Circle = geometry.Circle;
const Bezier = geometry.Bezier;

// -----------------------------------------------------------------------------
// Color

pub const Color = struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,

    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return .{ .r = r, .g = g, .b = b };
    }

    /// Decompose a 0xRRGGBB integer into a `Color`.
    pub fn fromHex(hex: u32) Color {
        return .{
            .r = @intCast((hex >> 16) & 0xff),
            .g = @intCast((hex >> 8) & 0xff),
            .b = @intCast(hex & 0xff),
        };
    }

    pub fn add(self: Color, other: Color) Color {
        return .{
            .r = self.r +| other.r,
            .g = self.g +| other.g,
            .b = self.b +| other.b,
        };
    }

    pub fn sub(self: Color, other: Color) Color {
        return .{
            .r = self.r -| other.r,
            .g = self.g -| other.g,
            .b = self.b -| other.b,
        };
    }

    pub fn scale(self: Color, factor: f32) Color {
        return .{
            .r = clampU8(factor * @as(f32, @floatFromInt(self.r))),
            .g = clampU8(factor * @as(f32, @floatFromInt(self.g))),
            .b = clampU8(factor * @as(f32, @floatFromInt(self.b))),
        };
    }

    pub fn format(self: Color, writer: *Writer) Writer.Error!void {
        try writer.print("rgb({d},{d},{d})", .{ self.r, self.g, self.b });
    }
};

fn clampU8(value: f32) u8 {
    if (value <= 0) return 0;
    if (value >= 255) return 255;
    return @intFromFloat(value);
}

// -----------------------------------------------------------------------------
// Fill / Stroke

pub const Fill = struct {
    color: Color,
    opacity: f32 = 1,

    pub fn init(color: Color, opacity: f32) Fill {
        return .{ .color = color, .opacity = opacity };
    }

    pub fn solid(color: Color) Fill {
        return .{ .color = color };
    }

    pub fn hex(hex_color: u32, opacity: f32) Fill {
        return .{ .color = .fromHex(hex_color), .opacity = opacity };
    }

    pub fn solidHex(hex_color: u32) Fill {
        return .{ .color = .fromHex(hex_color) };
    }
};

pub const Stroke = struct {
    color: Color,
    width: f32,
    opacity: f32 = 1,

    pub fn init(color: Color, width: f32, opacity: f32) Stroke {
        return .{ .color = color, .width = width, .opacity = opacity };
    }

    pub fn solid(color: Color, width: f32) Stroke {
        return .{ .color = color, .width = width };
    }

    pub fn hex(hex_color: u32, width: f32, opacity: f32) Stroke {
        return .{ .color = .fromHex(hex_color), .width = width, .opacity = opacity };
    }

    pub fn solidHex(hex_color: u32, width: f32) Stroke {
        return .{ .color = .fromHex(hex_color), .width = width };
    }
};

/// Optional paint configuration used by `addLine`, `addCircle`, `addShape`
/// and `addPath`. Both fields default to `null`, so callers can pass only
/// what they need: `.{ .stroke = ... }`, `.{ .fill = ... }`, or both.
pub const Style = struct {
    fill: ?Fill = null,
    stroke: ?Stroke = null,
};

// -----------------------------------------------------------------------------
// Internal streaming helpers

fn writeShapePath(writer: *Writer, shape: anytype) Writer.Error!void {
    const T = @TypeOf(shape);
    switch (T) {
        Line => {
            const v = shape.vertices;
            try writer.print("M {d} {d} L {d} {d}", .{
                v[0].x, v[0].y, v[1].x, v[1].y,
            });
        },
        Triangle => {
            const v = shape.vertices;
            try writer.print("M {d} {d} L {d} {d} L {d} {d} Z", .{
                v[2].x, v[2].y, v[0].x, v[0].y, v[1].x, v[1].y,
            });
        },
        Quadrilateral => {
            const v = shape.vertices;
            try writer.print("M {d} {d} L {d} {d} L {d} {d} L {d} {d} Z", .{
                v[0].x, v[0].y, v[1].x, v[1].y, v[3].x, v[3].y, v[2].x, v[2].y,
            });
        },
        Bezier => {
            const p = shape.points;
            try writer.print("M {d} {d} C {d} {d}, {d} {d}, {d} {d}", .{
                p[0].x, p[0].y, p[1].x, p[1].y, p[2].x, p[2].y, p[3].x, p[3].y,
            });
        },
        else => @compileError("writeShapePath: unsupported shape " ++ @typeName(T)),
    }
}

fn writeFillStyle(writer: *Writer, fill: ?Fill) Writer.Error!void {
    if (fill) |f| {
        try writer.print("fill:rgb({d},{d},{d});fill-opacity:{d}", .{
            f.color.r, f.color.g, f.color.b, f.opacity,
        });
    } else {
        try writer.writeAll("fill:none");
    }
}

fn writeStrokeStyle(writer: *Writer, stroke: ?Stroke) Writer.Error!void {
    if (stroke) |s| {
        try writer.print(
            "stroke:rgb({d},{d},{d});stroke-width:{d};stroke-opacity:{d};stroke-linecap:butt;stroke-linejoin:round",
            .{ s.color.r, s.color.g, s.color.b, s.width, s.opacity },
        );
    }
}

// -----------------------------------------------------------------------------
// Document

pub const Document = struct {
    canvas_width: u32,
    canvas_height: u32,
    background: Color,
    content: Writer.Allocating,

    pub fn init(
        allocator: Allocator,
        canvas_width: u32,
        canvas_height: u32,
        background: Color,
    ) Document {
        return .{
            .canvas_width = canvas_width,
            .canvas_height = canvas_height,
            .background = background,
            .content = .init(allocator),
        };
    }

    pub fn deinit(self: *Document) void {
        self.content.deinit();
    }

    // ---- Output ----------------------------------------------------------

    /// Primary output: render the full SVG document to `writer`.
    pub fn writeTo(self: *const Document, writer: *Writer) Writer.Error!void {
        try writer.print(
            "<svg xmlns='http://www.w3.org/2000/svg' height='{d}' width='{d}' viewBox='0 0 {d} {d}'>\n",
            .{ self.canvas_height, self.canvas_width, self.canvas_width, self.canvas_height },
        );
        try writer.print(
            "<rect height='100%' width='100%' fill='rgb({d},{d},{d})'/>\n",
            .{ self.background.r, self.background.g, self.background.b },
        );
        try writer.writeAll("<g id='surface1'>\n");
        try writer.writeAll(self.content.writer.buffered());
        try writer.writeAll("</g>\n</svg>\n");
    }

    /// Render the full SVG document into a freshly allocated slice owned
    /// by the caller.
    pub fn toOwnedString(
        self: *const Document,
        allocator: Allocator,
    ) (Writer.Error || Allocator.Error)![]u8 {
        var out: Writer.Allocating = .init(allocator);
        errdefer out.deinit();
        try self.writeTo(&out.writer);
        return try out.toOwnedSlice();
    }

    /// Convenience: render to a file on disk.
    pub fn save(
        self: *const Document,
        allocator: Allocator,
        io: std.Io,
        path: []const u8,
    ) !void {
        const bytes = try self.toOwnedString(allocator);
        defer allocator.free(bytes);
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = bytes });
    }

    // ---- Shape addition --------------------------------------------------

    pub fn addRaw(self: *Document, bytes: []const u8) Writer.Error!void {
        try self.content.writer.writeAll(bytes);
    }

    pub fn addCircle(self: *Document, circle: Circle, style: Style) Writer.Error!void {
        const writer = &self.content.writer;
        try writer.writeAll("<circle style='");
        try writeFillStyle(writer, style.fill);
        try writer.writeByte(';');
        try writeStrokeStyle(writer, style.stroke);
        try writer.print("' cx='{d}' cy='{d}' r='{d}' />\n", .{
            circle.center.x, circle.center.y, circle.radius,
        });
    }

    pub fn addLine(self: *Document, line: Line, style: Style) Writer.Error!void {
        try self.writeSingleShape(line, style);
    }

    /// Add a single `Triangle`, `Quadrilateral`, `Line`, or `Bezier` as a
    /// `<path>`. For `Bezier` the caller is probably better served by
    /// `addBezier`, which defaults `fill` to `none`.
    pub fn addShape(self: *Document, shape: anytype, style: Style) Writer.Error!void {
        try self.writeSingleShape(shape, style);
    }

    pub fn addBezier(self: *Document, bezier: Bezier, stroke: Stroke) Writer.Error!void {
        const writer = &self.content.writer;
        try writer.writeAll("<path style='fill:none;");
        try writeStrokeStyle(writer, stroke);
        try writer.writeAll("' d='");
        try writeShapePath(writer, bezier);
        try writer.writeAll("'></path>\n");
    }

    pub fn addText(
        self: *Document,
        text: []const u8,
        position: Point,
        color: Fill,
    ) Writer.Error!void {
        try self.content.writer.print(
            "<text style='fill:rgb({d},{d},{d});fill-opacity:{d}' x='{d}' y='{d}' font-size='0.5em' dy='0.25em'>{s}</text>\n",
            .{
                color.color.r, color.color.g, color.color.b, color.opacity,
                position.x,    position.y,    text,
            },
        );
    }

    /// Render a collection of shapes as a single `<path>`. `shapes` is any
    /// slice/array whose elements are `Line`, `Triangle`, `Quadrilateral`,
    /// or `Bezier`. The element type is inferred — no comptime argument
    /// required. To filter, build the slice first.
    pub fn addPath(self: *Document, shapes: anytype, style: Style) Writer.Error!void {
        const writer = &self.content.writer;
        try writer.writeAll("<path style='");
        try writeFillStyle(writer, style.fill);
        try writer.writeByte(';');
        try writeStrokeStyle(writer, style.stroke);
        try writer.writeAll(";stroke-linecap:round' d='");

        var first = true;
        for (shapes) |elem| {
            if (!first) try writer.writeByte(' ');
            try writeShapePath(writer, elem);
            first = false;
        }
        try writer.writeAll("'></path>\n");
    }

    // ---- internal --------------------------------------------------------

    fn writeSingleShape(
        self: *Document,
        shape: anytype,
        style: Style,
    ) Writer.Error!void {
        const writer = &self.content.writer;
        try writer.writeAll("<path style='");
        try writeFillStyle(writer, style.fill);
        try writer.writeByte(';');
        try writeStrokeStyle(writer, style.stroke);
        try writer.writeAll(";stroke-linecap:round' d='");
        try writeShapePath(writer, shape);
        try writer.writeAll("'></path>\n");
    }
};

// =============================================================================
// Tests

const testing = std.testing;

test "Color fromHex decomposes channels" {
    const c = Color.fromHex(0xFF8040);
    try testing.expectEqual(@as(u8, 0xFF), c.r);
    try testing.expectEqual(@as(u8, 0x80), c.g);
    try testing.expectEqual(@as(u8, 0x40), c.b);
}

test "Color add/sub saturate" {
    const a = Color.rgb(200, 200, 200);
    const b = Color.rgb(100, 100, 100);
    try testing.expectEqual(@as(u8, 255), a.add(b).r);
    try testing.expectEqual(@as(u8, 0), b.sub(a).r);
}

test "Color scale clamps" {
    const c = Color.rgb(100, 100, 100);
    try testing.expectEqual(@as(u8, 200), c.scale(2.0).r);
    try testing.expectEqual(@as(u8, 255), c.scale(10.0).r);
    try testing.expectEqual(@as(u8, 0), c.scale(-1.0).r);
}

test "Fill / Stroke factories agree" {
    try testing.expectEqualDeep(
        Fill.init(Color.rgb(0xaa, 0xbb, 0xcc), 0.5),
        Fill.hex(0xaabbcc, 0.5),
    );
    try testing.expectEqualDeep(
        Fill.init(Color.rgb(0xaa, 0xbb, 0xcc), 1),
        Fill.solid(.fromHex(0xaabbcc)),
    );
    try testing.expectEqualDeep(
        Stroke.init(Color.rgb(1, 2, 3), 4, 1),
        Stroke.solidHex(0x010203, 4),
    );
}

test "Document empty renders valid skeleton" {
    var doc: Document = .init(testing.allocator, 100, 80, .fromHex(0x112233));
    defer doc.deinit();

    const svg = try doc.toOwnedString(testing.allocator);
    defer testing.allocator.free(svg);

    try testing.expect(std.mem.startsWith(u8, svg, "<svg"));
    try testing.expect(std.mem.endsWith(u8, svg, "</svg>\n"));
    try testing.expect(std.mem.indexOf(u8, svg, "viewBox='0 0 100 80'") != null);
    try testing.expect(std.mem.indexOf(u8, svg, "rgb(17,34,51)") != null);
}

test "Document addCircle embeds radius and center" {
    var doc: Document = .init(testing.allocator, 100, 100, .rgb(0, 0, 0));
    defer doc.deinit();

    try doc.addCircle(
        .{ .center = .{ .x = 50, .y = 50 }, .radius = 10 },
        .{ .fill = .solidHex(0xFFFFFF) },
    );

    const svg = try doc.toOwnedString(testing.allocator);
    defer testing.allocator.free(svg);
    try testing.expect(std.mem.indexOf(u8, svg, "cx='50'") != null);
    try testing.expect(std.mem.indexOf(u8, svg, "cy='50'") != null);
    try testing.expect(std.mem.indexOf(u8, svg, "r='10'") != null);
}

test "Document addLine builds a path" {
    var doc: Document = .init(testing.allocator, 100, 100, .rgb(0, 0, 0));
    defer doc.deinit();

    try doc.addLine(
        .{ .vertices = .{ .{ .x = 0, .y = 0 }, .{ .x = 10, .y = 20 } } },
        .{ .stroke = .solidHex(0xFF0000, 2) },
    );

    const svg = try doc.toOwnedString(testing.allocator);
    defer testing.allocator.free(svg);
    try testing.expect(std.mem.indexOf(u8, svg, "M 0 0 L 10 20") != null);
    try testing.expect(std.mem.indexOf(u8, svg, "stroke:rgb(255,0,0)") != null);
}

test "Document addBezier has fill:none" {
    var doc: Document = .init(testing.allocator, 100, 100, .rgb(0, 0, 0));
    defer doc.deinit();

    try doc.addBezier(
        .{ .points = .{
            .{ .x = 0, .y = 0 },   .{ .x = 10, .y = 10 },
            .{ .x = 20, .y = 10 }, .{ .x = 30, .y = 0 },
        } },
        .solidHex(0x00FF00, 2),
    );

    const svg = try doc.toOwnedString(testing.allocator);
    defer testing.allocator.free(svg);
    try testing.expect(std.mem.indexOf(u8, svg, "fill:none") != null);
    try testing.expect(std.mem.indexOf(u8, svg, "C ") != null);
}

test "Document addPath infers element type" {
    var doc: Document = .init(testing.allocator, 100, 100, .rgb(0, 0, 0));
    defer doc.deinit();

    const lines = [_]Line{
        .{ .vertices = .{ .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 1 } } },
        .{ .vertices = .{ .{ .x = 2, .y = 2 }, .{ .x = 3, .y = 3 } } },
    };
    try doc.addPath(&lines, .{ .stroke = .solidHex(0x000000, 1) });

    const svg = try doc.toOwnedString(testing.allocator);
    defer testing.allocator.free(svg);
    try testing.expect(std.mem.indexOf(u8, svg, "M 0 0 L 1 1 M 2 2 L 3 3") != null);
}

test "Document addShape works for Triangle" {
    var doc: Document = .init(testing.allocator, 100, 100, .rgb(0, 0, 0));
    defer doc.deinit();

    const tri: Triangle = .{ .vertices = .{
        .{ .x = 0, .y = 0 }, .{ .x = 10, .y = 0 }, .{ .x = 5, .y = 10 },
    } };
    try doc.addShape(tri, .{ .fill = .solidHex(0xFF0000) });

    const svg = try doc.toOwnedString(testing.allocator);
    defer testing.allocator.free(svg);
    try testing.expect(std.mem.indexOf(u8, svg, "M 5 10 L 0 0 L 10 0 Z") != null);
}

test "Document writeTo matches toOwnedString" {
    var doc: Document = .init(testing.allocator, 50, 50, .fromHex(0xAABBCC));
    defer doc.deinit();
    try doc.addCircle(
        .{ .center = .{ .x = 25, .y = 25 }, .radius = 5 },
        .{ .fill = .solidHex(0xFFFFFF) },
    );

    var sink: Writer.Allocating = .init(testing.allocator);
    defer sink.deinit();
    try doc.writeTo(&sink.writer);

    const owned = try doc.toOwnedString(testing.allocator);
    defer testing.allocator.free(owned);

    try testing.expectEqualStrings(owned, sink.written());
}

test "Document save round-trips through disk" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    var doc: Document = .init(testing.allocator, 48, 32, .rgb(255, 255, 255));
    defer doc.deinit();
    try doc.addCircle(
        .{ .center = .{ .x = 10, .y = 12 }, .radius = 4 },
        .{ .fill = .solidHex(0xff0000) },
    );

    // Write to the test tmp dir rather than cwd.
    const bytes = try doc.toOwnedString(testing.allocator);
    defer testing.allocator.free(bytes);
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "out.svg", .data = bytes });

    var buf: [1024]u8 = undefined;
    const read = try tmp.dir.readFile(testing.io, "out.svg", &buf);
    try testing.expect(std.mem.indexOf(u8, read, "<circle") != null);
    try testing.expect(std.mem.indexOf(u8, read, "fill:rgb(255,0,0)") != null);
}
