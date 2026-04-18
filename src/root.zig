//! zsvg — compose 2D geometry primitives and emit SVG from Zig.
//!
//! Two namespaces are exposed:
//!   - `geometry` — Point, Line, Triangle, Quadrilateral, Circle, Bezier
//!   - `svg`      — Color, Fill, Stroke, Style, Document
//!
//! Common types are re-exported at the top level for convenience.

pub const geometry = @import("geometry.zig");
pub const svg = @import("svg.zig");

// Geometry re-exports.
pub const Point = geometry.Point;
pub const Line = geometry.Line;
pub const Triangle = geometry.Triangle;
pub const Quadrilateral = geometry.Quadrilateral;
pub const Circle = geometry.Circle;
pub const Bezier = geometry.Bezier;
pub const epsilon = geometry.epsilon;

// SVG re-exports.
pub const Color = svg.Color;
pub const Fill = svg.Fill;
pub const Stroke = svg.Stroke;
pub const Style = svg.Style;
pub const Document = svg.Document;

test {
    _ = geometry;
    _ = svg;
}
