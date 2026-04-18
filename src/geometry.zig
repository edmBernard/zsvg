//! 2D geometry primitives used by the SVG builder.
//!
//! Value-semantic, allocation-free. Each shape is a plain struct —
//! construct one with the usual `.{ .field = value }` syntax. Behaviour
//! lives in explicit methods (`add`, `sub`, `rotate`, …) rather than
//! operator overloading.

const std = @import("std");
const math = std.math;
const Writer = std.Io.Writer;

/// Tolerance used for Point equality and related comparisons.
pub const epsilon: f32 = 0.1;

// -----------------------------------------------------------------------------
// Point

pub const Point = struct {
    x: f32 = 0,
    y: f32 = 0,

    pub fn add(self: Point, other: Point) Point {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    pub fn sub(self: Point, other: Point) Point {
        return .{ .x = self.x - other.x, .y = self.y - other.y };
    }

    pub fn scale(self: Point, factor: f32) Point {
        return .{ .x = self.x * factor, .y = self.y * factor };
    }

    pub fn divScalar(self: Point, divisor: f32) Point {
        return .{ .x = self.x / divisor, .y = self.y / divisor };
    }

    pub fn dot(self: Point, other: Point) f32 {
        return self.x * other.x + self.y * other.y;
    }

    pub fn norm(self: Point) f32 {
        return math.hypot(self.x, self.y);
    }

    pub fn rotate(self: Point, angle: f32) Point {
        const c = math.cos(angle);
        const s = math.sin(angle);
        return .{
            .x = self.x * c - self.y * s,
            .y = self.x * s + self.y * c,
        };
    }

    /// Epsilon-tolerant equality.
    pub fn eql(self: Point, other: Point) bool {
        return self.sub(other).norm() < epsilon;
    }

    /// Lexicographic ordering with an epsilon on `x`.
    pub fn lessThan(self: Point, other: Point) bool {
        if (@abs(self.x - other.x) < epsilon) return self.y < other.y;
        return self.x < other.x;
    }

    pub fn format(self: Point, writer: *Writer) Writer.Error!void {
        try writer.print("({d}, {d})", .{ self.x, self.y });
    }
};

// -----------------------------------------------------------------------------
// Line

pub const Line = struct {
    vertices: [2]Point,

    pub fn center(self: Line) Point {
        return self.vertices[0].add(self.vertices[1]).divScalar(2);
    }

    pub fn eql(self: Line, other: Line) bool {
        return self.vertices[0].eql(other.vertices[0]) and
            self.vertices[1].eql(other.vertices[1]);
    }

    pub fn format(self: Line, writer: *Writer) Writer.Error!void {
        try writer.print("{f}, {f}", .{ self.vertices[0], self.vertices[1] });
    }
};

// -----------------------------------------------------------------------------
// Triangle

pub const Triangle = struct {
    vertices: [3]Point,

    pub fn center(self: Triangle) Point {
        return self.vertices[0]
            .add(self.vertices[1])
            .add(self.vertices[2])
            .divScalar(3);
    }

    pub fn eql(self: Triangle, other: Triangle) bool {
        return self.vertices[0].eql(other.vertices[0]) and
            self.vertices[1].eql(other.vertices[1]) and
            self.vertices[2].eql(other.vertices[2]);
    }

    pub fn format(self: Triangle, writer: *Writer) Writer.Error!void {
        try writer.print("{f}, {f}, {f}", .{
            self.vertices[0], self.vertices[1], self.vertices[2],
        });
    }
};

// -----------------------------------------------------------------------------
// Quadrilateral

pub const Quadrilateral = struct {
    vertices: [4]Point,

    pub fn center(self: Quadrilateral) Point {
        return self.vertices[0]
            .add(self.vertices[1])
            .add(self.vertices[2])
            .add(self.vertices[3])
            .divScalar(4);
    }

    /// Gravity-center comparison: two quads are considered equal when
    /// their centers fall within `epsilon` of each other.
    pub fn eql(self: Quadrilateral, other: Quadrilateral) bool {
        return self.center().eql(other.center());
    }

    pub fn lessThan(self: Quadrilateral, other: Quadrilateral) bool {
        return self.center().lessThan(other.center());
    }

    pub fn format(self: Quadrilateral, writer: *Writer) Writer.Error!void {
        try writer.print("{f}, {f}, {f}, {f}", .{
            self.vertices[0], self.vertices[1], self.vertices[2], self.vertices[3],
        });
    }
};

// -----------------------------------------------------------------------------
// Circle

pub const Circle = struct {
    center: Point,
    radius: f32,

    pub fn format(self: Circle, writer: *Writer) Writer.Error!void {
        try writer.print("center:{f}, radius:{d}", .{ self.center, self.radius });
    }
};

// -----------------------------------------------------------------------------
// Bezier (cubic)

pub const Bezier = struct {
    points: [4]Point,

    pub fn rotate(self: Bezier, angle: f32) Bezier {
        return .{ .points = .{
            self.points[0].rotate(angle),
            self.points[1].rotate(angle),
            self.points[2].rotate(angle),
            self.points[3].rotate(angle),
        } };
    }

    pub fn translate(self: Bezier, offset: Point) Bezier {
        return .{ .points = .{
            self.points[0].add(offset),
            self.points[1].add(offset),
            self.points[2].add(offset),
            self.points[3].add(offset),
        } };
    }

    pub fn format(self: Bezier, writer: *Writer) Writer.Error!void {
        try writer.print("{f}, {f}, {f}, {f}", .{
            self.points[0], self.points[1], self.points[2], self.points[3],
        });
    }
};

// =============================================================================
// Tests

const testing = std.testing;

test "Point arithmetic" {
    const a: Point = .{ .x = 1, .y = 2 };
    const b: Point = .{ .x = 3, .y = 5 };

    try testing.expect(a.add(b).eql(.{ .x = 4, .y = 7 }));
    try testing.expect(b.sub(a).eql(.{ .x = 2, .y = 3 }));
    try testing.expect(a.scale(2).eql(.{ .x = 2, .y = 4 }));
    try testing.expect(a.divScalar(2).eql(.{ .x = 0.5, .y = 1 }));
}

test "Point dot and norm" {
    const a: Point = .{ .x = 1, .y = 2 };
    const b: Point = .{ .x = 3, .y = 4 };
    try testing.expectApproxEqAbs(@as(f32, 11), a.dot(b), epsilon);
    try testing.expectApproxEqAbs(@as(f32, 5), b.norm(), epsilon);
}

test "Point rotate by pi/2" {
    const p: Point = .{ .x = 1, .y = 0 };
    try testing.expect(p.rotate(math.pi / 2.0).eql(.{ .x = 0, .y = 1 }));
}

test "Point eql is epsilon tolerant" {
    const a: Point = .{ .x = 1, .y = 1 };
    try testing.expect(a.eql(.{ .x = 1.05, .y = 1.05 }));
    try testing.expect(!a.eql(.{ .x = 1.5, .y = 1.5 }));
}

test "Point lessThan" {
    const a: Point = .{ .x = 0, .y = 0 };
    const b: Point = .{ .x = 1, .y = 0 };
    const c: Point = .{ .x = 1, .y = 1 };
    try testing.expect(a.lessThan(b));
    try testing.expect(b.lessThan(c));
    try testing.expect(!c.lessThan(b));
}

test "Line center" {
    const line: Line = .{ .vertices = .{
        .{ .x = 0, .y = 0 },
        .{ .x = 2, .y = 4 },
    } };
    try testing.expect(line.center().eql(.{ .x = 1, .y = 2 }));
}

test "Triangle center" {
    const tri: Triangle = .{ .vertices = .{
        .{ .x = 0, .y = 0 },
        .{ .x = 3, .y = 0 },
        .{ .x = 0, .y = 3 },
    } };
    try testing.expect(tri.center().eql(.{ .x = 1, .y = 1 }));
}

test "Quadrilateral center and eql" {
    const q1: Quadrilateral = .{ .vertices = .{
        .{ .x = 0, .y = 0 },
        .{ .x = 2, .y = 0 },
        .{ .x = 2, .y = 2 },
        .{ .x = 0, .y = 2 },
    } };
    const q2: Quadrilateral = .{ .vertices = .{
        .{ .x = 1, .y = 1 },
        .{ .x = 3, .y = 1 },
        .{ .x = 3, .y = 3 },
        .{ .x = 1, .y = 3 },
    } };
    try testing.expect(q1.center().eql(.{ .x = 1, .y = 1 }));
    try testing.expect(!q1.eql(q2));
}

test "Bezier rotate rotates every control point" {
    const b: Bezier = .{ .points = .{
        .{ .x = 1, .y = 0 },
        .{ .x = 0, .y = 1 },
        .{ .x = -1, .y = 0 },
        .{ .x = 0, .y = -1 },
    } };
    const r = b.rotate(math.pi / 2.0);
    try testing.expect(r.points[0].eql(.{ .x = 0, .y = 1 }));
    try testing.expect(r.points[1].eql(.{ .x = -1, .y = 0 }));
    try testing.expect(r.points[2].eql(.{ .x = 0, .y = -1 }));
    try testing.expect(r.points[3].eql(.{ .x = 1, .y = 0 }));
}

test "Bezier translate" {
    const b: Bezier = .{ .points = .{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 2, .y = 2 },
        .{ .x = 3, .y = 3 },
    } };
    const t = b.translate(.{ .x = 10, .y = 20 });
    try testing.expect(t.points[0].eql(.{ .x = 10, .y = 20 }));
    try testing.expect(t.points[3].eql(.{ .x = 13, .y = 23 }));
}

test "Point format" {
    var buf: [64]u8 = undefined;
    var writer: Writer = .fixed(&buf);
    try writer.print("{f}", .{Point{ .x = 1.5, .y = 2.5 }});
    try testing.expectEqualStrings("(1.5, 2.5)", writer.buffered());
}
