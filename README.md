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
            .fill = .{ .color = .fromHex(0x8AB4F8) },
            .stroke = .{ .color = .fromHex(0xFFFFFF), .width = 2 },
        },
    );

    // Stream the document to any `std.Io.Writer`, or save to a file.
    try doc.save(arena, init.io, "circle.svg");
}
```

Geometry shapes and `Fill`/`Stroke` are plain structs — construct them with
`.{ .field = value }` syntax. Only `Color` ships with helper constructors
(`fromRgb`, `fromHex`, `withOpacity`) because they do real decoding work.

## API tour

### `geometry` — allocation-free value types

- `Point { x, y }` with `add`, `sub`, `scale`, `divScalar`, `dot`, `norm`,
  `rotate(angle)`, `eql` (epsilon-tolerant), `lessThan`
- `Line`, `Triangle`, `Quadrilateral` — each carries its `vertices` array
  and exposes `center` and `eql`
- `Circle { center, radius }`
- `Bezier` — cubic bezier with four control `points`, supports `rotate(angle)`

Every shape also implements `format` so you can print one with `{f}`:

```zig
std.debug.print("point = {f}\n", .{zsvg.Point{ .x = 1, .y = 2 }});
```

### `svg` — SVG document builder

- `Color { r, g, b, opacity }` with `fromRgb`, `fromHex`, `withOpacity`,
  and `add`/`sub`/`scale` for color interpolation (saturating at `u8` bounds)
- `Fill` wraps a `Color`; `Stroke` wraps a `Color` + width
- `Style { fill: ?Fill = null, stroke: ?Stroke = null }` — the paint
  configuration passed to `addLine`/`addCircle`/`addPath`. Both fields
  default to `null`, so you only set what you need:
  `.{ .stroke = ... }`, `.{ .fill = ... }`, or both.
- `Document` — owns an internal buffer and exposes:
  - **Output:** `writeTo(writer)`, `toOwnedString(allocator)`,
    `save(allocator, io, path)`
  - **Shapes:** `addLine(shape, Style)`, `addBezier(shape, Stroke)`,
    `addCircle(shape, Style)`, `addText(text, position, Fill)`, `addRaw`
  - **Generic:** `addPath(shapes, Style, predicate)` — comptime dispatches
    on element type (`Line`, `Triangle`, `Quadrilateral`, `Bezier`) and
    accepts either a filtering function or `zsvg.keep_all`

The primary API is writer-based (`writeTo`); `toOwnedString` and `save` are
convenience wrappers on top.

## Build commands

```sh
zig build test              # run all unit tests
zig build examples          # build + run all examples
zig build example-shapes    # run just the shapes example
zig build example-gradient  # run just the gradient example
```

Example output is written to `zig-out/` (e.g. `zig-out/shapes.svg`).

## Examples

- `examples/shapes.zig` — one canvas with a line, triangle, quadrilateral,
  stroked translucent circle, cubic bezier, and text.
- `examples/gradient.zig` — a 10×10 grid of circles with colors linearly
  interpolated between two endpoints, showcasing `Color` arithmetic.

## License

Distributed under the Apache License, Version 2.0. See
[LICENSE](LICENSE).

## Disclaimer

It has been completly vibe coded, but it's a port from this C++ header-only code that I hack on different projects :
[bg-generation-2d-blob](https://github.com/edmBernard/bg-generation-2d-blob).
