# zsvg

A small Zig library for composing 2D geometry primitives and emitting SVG.

## Requirements

- Zig **0.16.0**

No external dependencies — everything is built on `std`.

## Install

Fetch the package into your project:

```sh
zig fetch --save git+https://github.com/edmBernard/zsvg
```

Then import it in your `build.zig`:

```zig
const zsvg = b.dependency("zsvg", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("zsvg", zsvg.module("zsvg"));
```

## Quickstart

```zig
const std = @import("std");
const zsvg = @import("zsvg");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();

    var doc: zsvg.Document = .init(arena, 200, 200, .fromHex(0x202124));
    defer doc.deinit();

    try doc.addCircle(
        .{ .center = .{ .x = 100, .y = 100 }, .radius = 40 },
        .{
            .fill = .hex(0x8AB4F8, 0.9),
            .stroke = .solidHex(0xFFFFFF, 2),
        },
    );

    // Stream the document to any `std.Io.Writer`, or save to a file.
    try doc.save(arena, init.io, "circle.svg");
}
```

Geometry shapes are plain structs — build them with `.{ .field = value }`
syntax. `Color`, `Fill`, and `Stroke` ship with small helper constructors
(`rgb`, `fromHex`, `solid`, `solidHex`, `hex`) so common cases stay terse.

## API tour

### `geometry` — allocation-free value types

- `Point { x, y }` with `add`, `sub`, `scale`, `divScalar`, `dot`, `norm`,
  `eql` (epsilon-tolerant), `lessThan` (strict, sort-safe), `transform(Matrix)`
- `Matrix` — 2D affine transform matching SVG's `matrix(a b c d e f)`. Build
  one with `.identity`, `.translation(dx, dy)`, `.rotation(angle)`,
  `.scaling(sx, sy)`, compose with `.mul` (right-to-left), apply with `.apply`.
- `Line`, `Triangle`, `Quadrilateral` — each carries its `vertices` array and
  exposes `center`, `eql`, and `transform(Matrix)`. Vertices are emitted in
  the order you provide them (no implicit reordering).
- `Circle { center, radius }` with `eql` and `transform(Matrix)` (radius scaled
  by the isotropic factor `sqrt(|det|)`).
- `Bezier` — cubic bezier with four control `points`, supports `transform(Matrix)`.

Every shape also implements `format` so you can print one with `{f}`:

```zig
std.debug.print("point = {f}\n", .{zsvg.Point{ .x = 1, .y = 2 }});
```

To rotate a shape about the origin and then move it, compose the matrices:

```zig
const m = zsvg.Matrix.translation(cx, cy).mul(.rotation(angle));
const moved = shape.transform(m);
```

### `svg` — SVG document builder

- `Color { r, g, b }` with `rgb`, `fromHex`, `add`/`sub`/`scale` (saturating
  at `u8` bounds), and `lerp(a, b, t)` for interpolation
- `Fill { color, opacity = 1 }` with `init`, `solid`, `hex`, `solidHex`
- `Stroke { color, width, opacity = 1, linecap = .butt, linejoin = .round }`
  with `init`, `solid`, `hex`, `solidHex`. `linecap` is a `LineCap`
  (`.butt`/`.round`/`.square`) and `linejoin` a `LineJoin`
  (`.miter`/`.round`/`.bevel`).
- `Style { fill: ?Fill = null, stroke: ?Stroke = null }` — the paint
  configuration passed to `addLine`/`addCircle`/`addShape`/`addPath`/`addBezier`.
  Both fields default to `null`, so you only set what you need:
  `.{ .stroke = ... }`, `.{ .fill = ... }`, or both.
- `TextStyle { fill = opaque black, font_size = 16, font_family = null, anchor = .start }`
  — passed to `addText`; `anchor` is a `TextAnchor` (`.start`/`.middle`/`.end`).
  Every field has a default, so `addText(text, pos, .{})` works.
- `Document` — owns an internal buffer. Construct it with
  `Document.init(allocator, width, height, background)` where `background` is
  an `?Color`: pass a color to paint a full-canvas backdrop `<rect>`, or `null`
  to leave the canvas transparent (no backdrop is emitted). It exposes:
  - **Output:** `writeTo(writer)`, `toOwnedString(allocator)`,
    `save(allocator, io, path)`
  - **Shapes:** `addLine(line, Style)`, `addCircle(circle, Style)`,
    `addBezier(bezier, Style)`, `addText(text, position, TextStyle)`, `addRaw`
  - **Generic:** `addShape(shape, Style)` — comptime dispatches on a single
    `Line`, `Triangle`, `Quadrilateral`, or `Bezier`
  - **Batch:** `addPath(shapes, Style)` — same comptime dispatch over a
    slice/array of one of those shape types

`addText` escapes `&`, `<`, and `>` in the supplied string; `addRaw` emits its
bytes verbatim, so the caller is responsible for well-formed markup there.

The primary API is writer-based (`writeTo`); `toOwnedString` and `save` are
convenience wrappers on top.

## Build commands

```sh
zig build test                    # run all unit tests
zig build examples                # build + run all examples
zig build example-shapes          # run just the shapes example
zig build example-gradient        # run just the gradient example
zig build example-bezier_curves   # run just the bezier flower example
```

Each example writes its output into `zig-out/` (e.g. `zig-out/shapes.svg`).

## Examples

- `examples/basic.zig` — two overlapping translucent circles, the smallest
  end-to-end snippet.
- `examples/basic_shapes.zig` — sampler of every primitive plus a row of
  translucent circles.
- `examples/shapes.zig` — line, triangle, quadrilateral, stroked
  translucent circle, cubic bezier, and text on one canvas.
- `examples/bezier_curves.zig` — 12-petal flower built by rotating a
  single cubic bezier around a center.
- `examples/paths.zig` — `addPath` over an array of triangles plus a
  standalone bezier wave.
- `examples/gradient.zig` — 10×10 grid of circles with colors linearly
  interpolated between two endpoints, showcasing `Color` arithmetic and
  streaming straight to a file with `writeTo`.
- `examples/text.zig` — text, line, and `addRaw` for inline SVG.
- `examples/save.zig` — minimal `Document.save` usage.

## License

Distributed under the Apache License, Version 2.0. See
[LICENSE](LICENSE).

## Disclaimer

It has been completly vibe coded, but it's a port from this C++ header-only code that I hack on different projects :
[bg-generation-2d-blob](https://github.com/edmBernard/bg-generation-2d-blob).
