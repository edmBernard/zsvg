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

    /// Apply an affine `Matrix` to this point.
    pub fn transform(self: Point, matrix: Matrix) Point {
        return matrix.apply(self);
    }

    /// Epsilon-tolerant equality.
    pub fn eql(self: Point, other: Point) bool {
        return self.sub(other).norm() < epsilon;
    }

    /// Strict lexicographic ordering (x, then y).
    pub fn lessThan(self: Point, other: Point) bool {
        if (self.x != other.x) return self.x < other.x;
        return self.y < other.y;
    }

    pub fn format(self: Point, writer: *Writer) Writer.Error!void {
        try writer.print("({d}, {d})", .{ self.x, self.y });
    }
};

// -----------------------------------------------------------------------------
// Matrix — 2D affine transform
//
//   | x' |   | a c e |   | x |
//   | y' | = | b d f | * | y |
//   |  1 |   | 0 0 1 |   | 1 |
//
// i.e. x' = a*x + c*y + e,  y' = b*x + d*y + f. Layout matches the six-value
// form of the SVG `transform="matrix(a b c d e f)"` attribute.

pub const Matrix = struct {
    a: f32 = 1,
    b: f32 = 0,
    c: f32 = 0,
    d: f32 = 1,
    e: f32 = 0,
    f: f32 = 0,

    pub const identity: Matrix = .{};

    /// Translation by (`dx`, `dy`).
    pub fn translation(dx: f32, dy: f32) Matrix {
        return .{ .e = dx, .f = dy };
    }

    /// Rotation by `angle` radians about the origin.
    pub fn rotation(angle: f32) Matrix {
        const co = math.cos(angle);
        const si = math.sin(angle);
        return .{ .a = co, .b = si, .c = -si, .d = co };
    }

    /// Scaling by (`sx`, `sy`).
    pub fn scaling(sx: f32, sy: f32) Matrix {
        return .{ .a = sx, .d = sy };
    }

    /// Apply this transform to a point.
    pub fn apply(self: Matrix, p: Point) Point {
        return .{
            .x = self.a * p.x + self.c * p.y + self.e,
            .y = self.b * p.x + self.d * p.y + self.f,
        };
    }

    /// Compose two transforms. The result applies `other` first, then
    /// `self` — i.e. `self.mul(other).apply(p) == self.apply(other.apply(p))`.
    pub fn mul(self: Matrix, other: Matrix) Matrix {
        return .{
            .a = self.a * other.a + self.c * other.b,
            .b = self.b * other.a + self.d * other.b,
            .c = self.a * other.c + self.c * other.d,
            .d = self.b * other.c + self.d * other.d,
            .e = self.a * other.e + self.c * other.f + self.e,
            .f = self.b * other.e + self.d * other.f + self.f,
        };
    }

    /// Determinant of the linear (2×2) part. Used to derive the isotropic
    /// scale factor applied to a `Circle`'s radius.
    pub fn determinant(self: Matrix) f32 {
        return self.a * self.d - self.b * self.c;
    }
};

// -----------------------------------------------------------------------------
// Line

pub const Line = struct {
    vertices: [2]Point,

    pub fn center(self: Line) Point {
        return self.vertices[0].add(self.vertices[1]).divScalar(2);
    }

    pub fn transform(self: Line, matrix: Matrix) Line {
        return .{ .vertices = .{
            matrix.apply(self.vertices[0]),
            matrix.apply(self.vertices[1]),
        } };
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

    pub fn transform(self: Triangle, matrix: Matrix) Triangle {
        return .{ .vertices = .{
            matrix.apply(self.vertices[0]),
            matrix.apply(self.vertices[1]),
            matrix.apply(self.vertices[2]),
        } };
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

    pub fn transform(self: Quadrilateral, matrix: Matrix) Quadrilateral {
        return .{ .vertices = .{
            matrix.apply(self.vertices[0]),
            matrix.apply(self.vertices[1]),
            matrix.apply(self.vertices[2]),
            matrix.apply(self.vertices[3]),
        } };
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

    /// Apply an affine `Matrix`. The center is transformed directly; the
    /// radius is scaled by the isotropic factor `sqrt(|det|)`.
    pub fn transform(self: Circle, matrix: Matrix) Circle {
        return .{
            .center = matrix.apply(self.center),
            .radius = self.radius * @sqrt(@abs(matrix.determinant())),
        };
    }

    pub fn eql(self: Circle, other: Circle) bool {
        return self.center.eql(other.center) and
            @abs(self.radius - other.radius) < epsilon;
    }

    pub fn format(self: Circle, writer: *Writer) Writer.Error!void {
        try writer.print("center:{f}, radius:{d}", .{ self.center, self.radius });
    }
};

// -----------------------------------------------------------------------------
// Bezier (cubic)

pub const Bezier = struct {
    points: [4]Point,

    pub fn transform(self: Bezier, matrix: Matrix) Bezier {
        return .{ .points = .{
            matrix.apply(self.points[0]),
            matrix.apply(self.points[1]),
            matrix.apply(self.points[2]),
            matrix.apply(self.points[3]),
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

test "Point transform: rotation by pi/2" {
    const p: Point = .{ .x = 1, .y = 0 };
    try testing.expect(p.transform(.rotation(math.pi / 2.0)).eql(.{ .x = 0, .y = 1 }));
}

test "Matrix translation and scaling" {
    const p: Point = .{ .x = 2, .y = 3 };
    try testing.expect(p.transform(.translation(10, 20)).eql(.{ .x = 12, .y = 23 }));
    try testing.expect(p.transform(.scaling(2, 3)).eql(.{ .x = 4, .y = 9 }));
}

test "Matrix mul composes right-to-left" {
    // Rotate 90° about origin, then translate — matches the old
    // `rotate(a).translate(o)` chain.
    const p: Point = .{ .x = 1, .y = 0 };
    const m = Matrix.translation(10, 20).mul(.rotation(math.pi / 2.0));
    try testing.expect(p.transform(m).eql(.{ .x = 10, .y = 21 }));
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

test "Bezier transform rotates every control point" {
    const b: Bezier = .{ .points = .{
        .{ .x = 1, .y = 0 },
        .{ .x = 0, .y = 1 },
        .{ .x = -1, .y = 0 },
        .{ .x = 0, .y = -1 },
    } };
    const r = b.transform(.rotation(math.pi / 2.0));
    try testing.expect(r.points[0].eql(.{ .x = 0, .y = 1 }));
    try testing.expect(r.points[1].eql(.{ .x = -1, .y = 0 }));
    try testing.expect(r.points[2].eql(.{ .x = 0, .y = -1 }));
    try testing.expect(r.points[3].eql(.{ .x = 1, .y = 0 }));
}

test "Bezier transform translates every control point" {
    const b: Bezier = .{ .points = .{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 2, .y = 2 },
        .{ .x = 3, .y = 3 },
    } };
    const t = b.transform(.translation(10, 20));
    try testing.expect(t.points[0].eql(.{ .x = 10, .y = 20 }));
    try testing.expect(t.points[3].eql(.{ .x = 13, .y = 23 }));
}

test "Circle transform scales radius by isotropic factor" {
    const circle: Circle = .{ .center = .{ .x = 1, .y = 1 }, .radius = 4 };
    // Uniform scale of 2 about origin: center doubles, radius doubles.
    const scaled = circle.transform(.scaling(2, 2));
    try testing.expect(scaled.center.eql(.{ .x = 2, .y = 2 }));
    try testing.expectApproxEqAbs(@as(f32, 8), scaled.radius, epsilon);
    // Pure rotation leaves the radius unchanged.
    const rotated = circle.transform(.rotation(math.pi / 3.0));
    try testing.expectApproxEqAbs(@as(f32, 4), rotated.radius, epsilon);
}

test "Point format" {
    var buf: [64]u8 = undefined;
    var writer: Writer = .fixed(&buf);
    try writer.print("{f}", .{Point{ .x = 1.5, .y = 2.5 }});
    try testing.expectEqualStrings("(1.5, 2.5)", writer.buffered());
}
